IMPLEMENTATION MODULE Encounter;

(* Enemy encounter/spawn system matching original FTA.
   Two-phase: queue encounter (every 32 ticks) then place (every 16 ticks).
   Random encounters only in xtype < 50 regions, gated by danger roll. *)

FROM Actor IMPORT actors, actorCount, MaxActors,
                  TypeEnemy, StStill, StDead, StDying,
                  GoalAttack1, GoalAttack2, GoalArcher1, GoalArcher2;
FROM Movement IMPORT ProxCheck;
FROM Platform IMPORT GetTicks;
FROM Assets IMPORT currentRegion, GetTerrainAt;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;

CONST
  MaxTry = 10;
  MaxEncounterActors = 8;  (* player=0, raft=1, setfig=2, carrier=3, enemies=4-7 *)

TYPE
  EncounterRec = RECORD
    hitpoints:  INTEGER;
    aggressive: BOOLEAN;
    arms:       INTEGER;
    cleverness: INTEGER;
    treasure:   INTEGER;
    fileId:     INTEGER
  END;

  ExtentRec = RECORD
    x1, y1, x2, y2: INTEGER;
    etype:  INTEGER;
    v1:     INTEGER;
    v2:     INTEGER;
    v3:     INTEGER
  END;

VAR
  chart:   ARRAY [0..10] OF EncounterRec;
  extents: ARRAY [0..22] OF ExtentRec;
  weaponProbs: ARRAY [0..31] OF INTEGER;

  (* Two-phase spawn state *)
  loadPending:   BOOLEAN;
  pendingRace:   INTEGER;
  pendingCount:  INTEGER;
  pendingMix:    INTEGER;   (* mixflag: bit1=race mix, bit2=weapon re-rand *)
  tick:          INTEGER;   (* internal frame counter *)

  rngState: INTEGER;

  (* Spawn direction tables *)
  spawnDirX: ARRAY [0..7] OF INTEGER;
  spawnDirY: ARRAY [0..7] OF INTEGER;

PROCEDURE Rand(limit: INTEGER): INTEGER;
BEGIN
  rngState := rngState * 1103515245 + 12345;
  IF limit <= 0 THEN RETURN 0 END;
  RETURN INTEGER(BAND(CARDINAL(rngState DIV 65536), 7FFFH)) MOD limit
END Rand;

(* --- Data initialization (unchanged) --- *)

PROCEDURE SetChart(i, hp, arms, clev, treas, fid: INTEGER; aggr: BOOLEAN);
BEGIN
  chart[i].hitpoints := hp;
  chart[i].aggressive := aggr;
  chart[i].arms := arms;
  chart[i].cleverness := clev;
  chart[i].treasure := treas;
  chart[i].fileId := fid
END SetChart;

PROCEDURE SetExtent(i, ax1, ay1, ax2, ay2, et, ev1, ev2, ev3: INTEGER);
BEGIN
  extents[i].x1 := ax1; extents[i].y1 := ay1;
  extents[i].x2 := ax2; extents[i].y2 := ay2;
  extents[i].etype := et;
  extents[i].v1 := ev1;
  extents[i].v2 := ev2;
  extents[i].v3 := ev3
END SetExtent;

PROCEDURE InitCharts;
BEGIN
  SetChart(0,   18,  2,   0,   2,   6,  TRUE);
  SetChart(1,   12,  4,   1,   1,   6,  TRUE);
  SetChart(2,   16,  6,   1,   4,   7,  TRUE);
  SetChart(3,    8,  3,   0,   3,   7,  TRUE);
  SetChart(4,   16,  6,   1,   0,   8,  TRUE);
  SetChart(5,    9,  3,   0,   0,   7,  TRUE);
  SetChart(6,   10,  6,   1,   0,   8,  TRUE);
  SetChart(7,   40,  7,   1,   0,   8,  TRUE);
  SetChart(8,   12,  6,   1,   0,   9,  TRUE);
  SetChart(9,   50,  5,   0,   0,   9,  TRUE);
  SetChart(10,   4,  0,   0,   0,   9,  FALSE)
END InitCharts;

PROCEDURE InitWeaponProbs;
BEGIN
  weaponProbs[0]  := 0; weaponProbs[1]  := 0;
  weaponProbs[2]  := 0; weaponProbs[3]  := 0;
  weaponProbs[4]  := 1; weaponProbs[5]  := 1;
  weaponProbs[6]  := 1; weaponProbs[7]  := 1;
  weaponProbs[8]  := 1; weaponProbs[9]  := 2;
  weaponProbs[10] := 1; weaponProbs[11] := 2;
  weaponProbs[12] := 1; weaponProbs[13] := 2;
  weaponProbs[14] := 3; weaponProbs[15] := 2;
  weaponProbs[16] := 4; weaponProbs[17] := 4;
  weaponProbs[18] := 3; weaponProbs[19] := 2;
  weaponProbs[20] := 5; weaponProbs[21] := 5;
  weaponProbs[22] := 5; weaponProbs[23] := 5;
  weaponProbs[24] := 8; weaponProbs[25] := 8;
  weaponProbs[26] := 8; weaponProbs[27] := 8;
  weaponProbs[28] := 3; weaponProbs[29] := 3;
  weaponProbs[30] := 3; weaponProbs[31] := 3
END InitWeaponProbs;

PROCEDURE InitExtents;
BEGIN
  SetExtent( 0,  2118,27237,  2618,27637, 70, 0,1,11);
  SetExtent( 1,     0,    0,     0,    0, 70, 0,1, 5);
  SetExtent( 2,  6749,34951,  7249,35351, 70, 0,1,10);
  SetExtent( 3,  4063,34819,  4909,35125, 53, 4,1, 6);
  SetExtent( 4,  9563,33883, 10144,34462, 60, 1,1, 9);
  SetExtent( 5, 22945, 5597, 23225, 5747, 61, 3,2, 4);
  SetExtent( 6, 10820,35646, 10877,35670, 83, 1,1, 0);
  SetExtent( 7, 19596,17123, 19974,17401, 48, 8,8, 2);
  SetExtent( 8, 19400,17034, 20240,17484, 80, 4,20,0);
  SetExtent( 9,  9216,33280, 12544,35328, 52, 3,1, 8);
  SetExtent(10,  5272,33300,  6112,34200, 81, 0,1, 0);
  SetExtent(11, 11712,37350, 12416,38020, 82, 0,1, 0);
  SetExtent(12,  2752,33300,  8632,35400, 80, 0,1, 0);
  SetExtent(13, 10032,35550, 12976,40270, 80, 0,1, 0);
  SetExtent(14,  4712,38100, 10032,40350, 80, 0,1, 0);
  SetExtent(15, 21405,25583, 21827,26028, 60, 1,1, 7);
  SetExtent(16,  6156,12755, 12316,15905,  7, 1,8, 0);
  SetExtent(17,  5140,34860,  6260,37260,  8, 1,8, 0);
  SetExtent(18,   660,33510,  2060,34560,  8, 1,8, 0);
  SetExtent(19, 18687,15338, 19211,16136, 80, 0,1, 0);
  SetExtent(20, 16953,17484, 20240,18719,  3, 1,3, 0);  (* y swapped to fix extent *)
  SetExtent(21, 20593,18719, 23113,22769,  3, 1,3, 0);
  SetExtent(22,     0,    0, 32767,40959,  3, 1,8, 0)
END InitExtents;

PROCEDURE InitSpawnDirs;
BEGIN
  spawnDirX[0] :=  0; spawnDirY[0] := -2;
  spawnDirX[1] :=  2; spawnDirY[1] := -2;
  spawnDirX[2] :=  2; spawnDirY[2] :=  0;
  spawnDirX[3] :=  2; spawnDirY[3] :=  2;
  spawnDirX[4] :=  0; spawnDirY[4] :=  2;
  spawnDirX[5] := -2; spawnDirY[5] :=  2;
  spawnDirX[6] := -2; spawnDirY[6] :=  0;
  spawnDirX[7] := -2; spawnDirY[7] := -2
END InitSpawnDirs;

(* --- Actor setup (unchanged) --- *)

PROCEDURE SetupEnemy(idx, race, x, y: INTEGER);
VAR wt, w: INTEGER;
BEGIN
  actors[idx].absX := x;
  actors[idx].absY := y;
  actors[idx].actorType := TypeEnemy;
  actors[idx].race := race;
  actors[idx].state := StStill;
  actors[idx].environ := 0;
  actors[idx].facing := 0;
  actors[idx].visible := TRUE;
  wt := Rand(4);
  w := chart[race].arms * 4 + wt;
  IF w > 31 THEN w := 31 END;
  actors[idx].weapon := weaponProbs[w];
  IF BAND(CARDINAL(actors[idx].weapon), 4) # 0 THEN
    actors[idx].goal := GoalArcher1 + chart[race].cleverness
  ELSE
    actors[idx].goal := GoalAttack1 + chart[race].cleverness
  END;
  IF actors[idx].goal > GoalArcher2 THEN
    actors[idx].goal := GoalArcher2
  END;
  actors[idx].vitality := chart[race].hitpoints;
  actors[idx].tactic := 0;
  actors[idx].velX := 0;
  actors[idx].velY := 0
END SetupEnemy;

(* --- Find free slot --- *)

PROCEDURE FindFreeSlot(): INTEGER;
VAR i: INTEGER;
BEGIN
  (* Reuse dead/dying enemy slots *)
  FOR i := 1 TO actorCount - 1 DO
    IF (actors[i].actorType = TypeEnemy) AND
       ((actors[i].state = StDead) OR (actors[i].state = StDying)) THEN
      RETURN i
    END
  END;
  (* Skip slots used by raft (1) and carrier (3) *)
  IF actorCount < MaxEncounterActors THEN
    RETURN actorCount
  END;
  RETURN -1
END FindFreeSlot;

(* --- Place a pending encounter --- *)

PROCEDURE PlaceEncounter(heroX, heroY: INTEGER);
VAR slot, j, k, xtest, ytest, spawned, dir, dist, race: INTEGER;
    encX, encY: INTEGER;
BEGIN
  IF (pendingRace < 0) OR (pendingRace > 10) THEN
    loadPending := FALSE;
    RETURN
  END;

  (* Try up to 10 times to find a valid encounter center *)
  FOR k := 0 TO MaxTry - 1 DO
    dir := Rand(8);
    dist := 150 + Rand(64);
    encX := heroX + (spawnDirX[dir] * dist) DIV 2;
    encY := heroY + (spawnDirY[dir] * dist) DIV 2;

    (* Original: only spawn if px_to_im returns 0 (open terrain).
       This prevents spawning inside buildings, walls, water etc. *)
    IF (currentRegion >= 0) AND (GetTerrainAt(encX, encY) = 0) THEN
      (* Place individual enemies around this center *)
      spawned := 0;
      WHILE spawned < pendingCount DO
        slot := FindFreeSlot();
        IF slot < 0 THEN
          loadPending := FALSE;
          RETURN
        END;
        j := 0;
        LOOP
          xtest := encX + Rand(64) - 32;
          ytest := encY + Rand(64) - 32;
          IF ProxCheck(xtest, ytest, slot) = 0 THEN EXIT END;
          INC(j);
          IF j >= MaxTry THEN EXIT END
        END;
        IF j < MaxTry THEN
          (* Race mixing: if mixflag bit 1 set and not snakes (race 4),
             alternate between adjacent race pairs *)
          IF (BAND(CARDINAL(pendingMix), 2) # 0) AND
             (pendingRace # 4) THEN
            race := BAND(CARDINAL(pendingRace), 0EH) + Rand(2)
          ELSE
            race := pendingRace
          END;
          SetupEnemy(slot, race, xtest, ytest);
          IF slot >= actorCount THEN actorCount := slot + 1 END;
          INC(spawned)
        ELSE
          (* Can't place this one — stop trying *)
          loadPending := FALSE;
          RETURN
        END
      END;
      loadPending := FALSE;
      RETURN
    END
  END;
  (* All 10 center attempts failed — keep pending for next check *)
END PlaceEncounter;

(* --- Extent detection --- *)

PROCEDURE FindExtent(heroX, heroY: INTEGER): INTEGER;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO MaxExtents - 2 DO
    IF (heroX > extents[i].x1) AND (heroX < extents[i].x2) AND
       (heroY > extents[i].y1) AND (heroY < extents[i].y2) THEN
      RETURN i
    END
  END;
  RETURN MaxExtents - 1
END FindExtent;

(* --- Check if any living enemies are visible near player --- *)

PROCEDURE EnemiesNearby(heroX, heroY: INTEGER): BOOLEAN;
VAR i, dx, dy: INTEGER;
BEGIN
  FOR i := 1 TO actorCount - 1 DO
    IF (actors[i].actorType = TypeEnemy) AND
       (actors[i].state # StDead) AND
       (actors[i].state # StDying) THEN
      dx := actors[i].absX - heroX;
      dy := actors[i].absY - heroY;
      IF dx < 0 THEN dx := -dx END;
      IF dy < 0 THEN dy := -dy END;
      IF (dx < 300) AND (dy < 300) THEN
        RETURN TRUE
      END
    END
  END;
  RETURN FALSE
END EnemiesNearby;

(* --- Exported spawn for forced encounters --- *)

PROCEDURE SpawnGroup(heroX, heroY, race, count, spread: INTEGER);
VAR slot, j, xtest, ytest, spawned, dir, dist: INTEGER;
    encX, encY: INTEGER;
BEGIN
  IF (race < 0) OR (race > 10) THEN RETURN END;
  dir := Rand(8);
  dist := 150 + Rand(64);
  encX := heroX + (spawnDirX[dir] * dist) DIV 2;
  encY := heroY + (spawnDirY[dir] * dist) DIV 2;
  spawned := 0;
  WHILE spawned < count DO
    slot := FindFreeSlot();
    IF slot < 0 THEN RETURN END;
    j := 0;
    LOOP
      xtest := encX + Rand(64) - 32;
      ytest := encY + Rand(64) - 32;
      IF ProxCheck(xtest, ytest, slot) = 0 THEN EXIT END;
      INC(j);
      IF j >= MaxTry THEN EXIT END
    END;
    IF j < MaxTry THEN
      SetupEnemy(slot, race, xtest, ytest);
      IF slot >= actorCount THEN actorCount := slot + 1 END;
      INC(spawned)
    ELSE
      RETURN
    END
  END
END SpawnGroup;

(* --- Main update: two-phase encounter system --- *)

PROCEDURE UpdateEncounters(heroX, heroY, region: INTEGER);
VAR ei, et, race, cnt, dangerLevel: INTEGER;
BEGIN
  IF region < 0 THEN RETURN END;
  INC(tick);

  ei := FindExtent(heroX, heroY);
  et := extents[ei].etype;
  curExtent := ei;
  xtype := et;

  (* Peace zones — no spawning *)
  IF et >= 80 THEN RETURN END;

  (* === PHASE 2: Place pending encounter ===
     Original: every 16 daynight ticks, if load pending and no actors visible.
     We use (cycle & 15) = 0 as the 16-tick gate. *)
  IF loadPending AND (BAND(CARDINAL(tick), 15) = 0) THEN
    IF NOT EnemiesNearby(heroX, heroY) THEN
      PlaceEncounter(heroX, heroY)
    END
  END;

  (* === PHASE 1: Queue new random encounter ===
     Original: every 32 daynight ticks.
     Gates: no battle, no actors visible, no load pending,
            xtype < 50, danger roll succeeds. *)
  IF BAND(CARDINAL(tick), 31) # 0 THEN RETURN END;

  (* Already have a pending load *)
  IF loadPending THEN RETURN END;

  (* Actors still visible — suppress *)
  IF EnemiesNearby(heroX, heroY) THEN RETURN END;

  (* Only ordinary random encounter regions *)
  IF et >= 50 THEN RETURN END;

  (* Too many living actors — count only alive ones *)
  IF FindFreeSlot() < 0 THEN RETURN END;

  (* Danger level roll — original: rand64() <= danger_level *)
  IF region > 7 THEN
    dangerLevel := 5 + et
  ELSE
    dangerLevel := 2 + et
  END;
  (* Original: rand64() <= danger_level — low roll = spawn *)
  IF Rand(64) > dangerLevel THEN RETURN END;

  (* Roll passed — queue encounter *)
  (* mixflag: random bitmask — bit1=race mixing, bit2=weapon re-rand.
     Original: mixflag = rand(); then cleared for certain xtypes *)
  cnt := Rand(256);  (* use as mixflag source *)
  IF (et >= 50) OR (BAND(CARDINAL(et), 3) = 0) THEN cnt := 0 END;

  race := Rand(4);
  IF (et = 7) AND (race = 2) THEN race := 4; cnt := 0 END;
  IF et = 8 THEN race := 6; cnt := 0 END;
  IF et = 49 THEN race := 2; cnt := 0 END;

  pendingMix := cnt;

  (* Enemy count from extent v1 + rand(v2), matching original *)
  cnt := extents[ei].v1;
  IF extents[ei].v2 > 0 THEN
    INC(cnt, Rand(extents[ei].v2))
  END;
  IF cnt > MaxEncounterActors - actorCount THEN
    cnt := MaxEncounterActors - actorCount
  END;
  IF cnt < 1 THEN RETURN END;

  pendingRace := race;
  pendingCount := cnt;
  loadPending := TRUE
END UpdateEncounters;

PROCEDURE InitEncounters;
BEGIN
  rngState := GetTicks();  (* seed from system clock for variety *)
  IF rngState = 0 THEN rngState := 54321 END;
  curExtent := -1;
  xtype := 0;
  loadPending := FALSE;
  pendingRace := 0;
  pendingCount := 0;
  pendingMix := 0;
  tick := 0;
  InitCharts;
  InitWeaponProbs;
  InitExtents;
  InitSpawnDirs
END InitEncounters;

END Encounter.
