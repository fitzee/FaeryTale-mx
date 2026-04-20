IMPLEMENTATION MODULE Movement;

FROM Actor IMPORT actors, actorCount, StDead, StDying, TypeEnemy, TypeCarrier;
FROM Brothers IMPORT brothers, activeBrother, StShard;
FROM Doors IMPORT OpenDoorTile;
FROM Carrier IMPORT riding, RideRaft, RideTurtle, RideSwan;
FROM World IMPORT GetTerrain, IsPassable, TerrainSpeed;
FROM Assets IMPORT currentRegion, IsBlocked, GetTerrainAt;

(* Direction tables from original: N, NE, E, SE, S, SW, W, NW, none, none *)
VAR
  xDir: ARRAY [0..9] OF INTEGER;
  yDir: ARRAY [0..9] OF INTEGER;

PROCEDURE InitDirTables;
BEGIN
  (* Original from fsubs.c newx/newy:
     xdir = {-2, 0, 2, 3, 2, 0,-2,-3}
     ydir = {-2,-3,-2, 0, 2, 3, 2, 0}
     But original dir 0 = NW. Our dir 0 = N.
     Remapped to match our N=0,NE=1,...NW=7 convention: *)
  xDir[0] :=  0; yDir[0] := -2;  (* N *)
  xDir[1] :=  2; yDir[1] := -2;  (* NE *)
  xDir[2] :=  2; yDir[2] :=  0;  (* E *)
  xDir[3] :=  2; yDir[3] :=  2;  (* SE *)
  xDir[4] :=  0; yDir[4] :=  2;  (* S *)
  xDir[5] := -2; yDir[5] :=  2;  (* SW *)
  xDir[6] := -2; yDir[6] :=  0;  (* W *)
  xDir[7] := -2; yDir[7] := -2;  (* NW *)
  xDir[8] :=  0; yDir[8] :=  0;  (* none *)
  xDir[9] :=  0; yDir[9] :=  0   (* none *)
END InitDirTables;

PROCEDURE NewX(x, dir, speed: INTEGER): INTEGER;
BEGIN
  IF dir < 8 THEN
    RETURN x + (xDir[dir] * speed) DIV 2
  END;
  RETURN x
END NewX;

PROCEDURE NewY(y, dir, speed: INTEGER): INTEGER;
BEGIN
  IF dir < 8 THEN
    RETURN y + (yDir[dir] * speed) DIV 2
  END;
  RETURN y
END NewY;

PROCEDURE ProxCheck(x, y, actorIdx: INTEGER): INTEGER;
VAR
  terrain, t, j, dx, dy: INTEGER;
BEGIN
  (* Swan riding: skip ALL terrain collision for player *)
  IF (actorIdx = 0) AND (riding = RideSwan) THEN RETURN 0 END;

  (* Wraiths (race=2) skip tile collision — they pass through walls.
     Original: proxcheck skips prox() for ENEMY type with race==2. *)
  IF NOT ((actors[actorIdx].actorType = TypeEnemy) AND
          (actors[actorIdx].race = 2)) THEN
  IF currentRegion >= 0 THEN
    t := GetTerrainAt(x + 4, y + 2);
    IF t = 1 THEN RETURN t END;
    (* Original prox(): non-zero terrain blocks enemies.
       Water (4,5) blocks enemies but NOT the player.
       Player: terrain 8,9 allowed (swamp/palace). *)
    IF (t >= 4) AND (t <= 5) AND (actorIdx # 0) AND
       (actors[actorIdx].race # 4) THEN RETURN t END;
    IF t >= 10 THEN
      IF (actorIdx = 0) AND (t = 15) THEN
        OpenDoorTile(x, y);
        RETURN 15
      ELSIF (actorIdx = 0) AND (t = 12) AND
            (brothers[activeBrother].stuff[StShard] > 0) THEN
        (* Shard allows passing barrier terrain *)
      ELSE RETURN t
      END
    END;
    t := GetTerrainAt(x - 4, y + 2);
    IF t = 1 THEN RETURN t END;
    IF (t >= 4) AND (t <= 5) AND (actorIdx # 0) AND
       (actors[actorIdx].race # 4) THEN RETURN t END;
    IF t >= 8 THEN
      IF (actorIdx = 0) AND ((t = 8) OR (t = 9)) THEN
        (* player walks through swamp/palace *)
      ELSIF (actorIdx = 0) AND (t = 12) AND
            (brothers[activeBrother].stuff[StShard] > 0) THEN
        (* Shard allows passing barrier *)
      ELSIF (actorIdx = 0) AND (t = 15) THEN
        OpenDoorTile(x, y);
        RETURN 15
      ELSE RETURN t
      END
    END;
    (* Additional check at character center *)
    t := GetTerrainAt(x, y);
    IF t = 1 THEN RETURN t END;
    IF (t >= 4) AND (t <= 5) AND (actorIdx # 0) AND
       (actors[actorIdx].race # 4) THEN RETURN t END;
    IF t >= 10 THEN
      IF (actorIdx = 0) AND (t = 15) THEN
        OpenDoorTile(x, y);
        RETURN 15
      ELSIF (actorIdx = 0) AND (t = 12) AND
            (brothers[activeBrother].stuff[StShard] > 0) THEN
        (* Shard allows passing barrier *)
      ELSE RETURN t
      END
    END;
    (* Directional door checks — detect doors in all approach directions.
       The y+2 checks above catch south-approach (walking north).
       These catch north/east/west approaches. *)
    FOR terrain := -8 TO 8 BY 4 DO
      t := GetTerrainAt(x + terrain, y - 4);
      IF (t = 15) AND (actorIdx = 0) THEN
        OpenDoorTile(x + terrain, y - 4);
        RETURN 15
      END;
      t := GetTerrainAt(x + terrain, y + 8);
      IF (t = 15) AND (actorIdx = 0) THEN
        OpenDoorTile(x + terrain, y + 8);
        RETURN 15
      END
    END
  ELSE
    (* Fallback handcrafted world *)
    terrain := GetTerrain(x, y);
    IF NOT IsPassable(terrain) THEN
      RETURN terrain
    END
  END;
  END; (* wraith guard *)

  (* Entity collision: 11x9 bounding box from original.
     Dead actors are walkable. Dying actors become walkable after
     their death animation progresses (tactic counts down from 30).
     Original: "can walk over dead and rafts" *)
  FOR j := 0 TO actorCount - 1 DO
    IF (j # actorIdx) AND
       (actors[j].state # StDead) AND
       (actors[j].actorType # TypeCarrier) THEN
      (* Dying actors become passable halfway through death anim *)
      IF (actors[j].state = StDying) AND (actors[j].tactic < 15) THEN
        (* soft obstacle — passable *)
      ELSE
        dx := x - actors[j].absX;
        dy := y - actors[j].absY;
        IF (dx < 11) AND (dx > -11) AND (dy < 9) AND (dy > -9) THEN
          RETURN 16
        END
      END
    END
  END;
  RETURN 0
END ProxCheck;

PROCEDURE EnvironToSpeed(k: INTEGER): INTEGER;
BEGIN
  (* Original mapping from environ (k) to walk speed (e):
     k = -1: fast road (e=4)
     k = 0: normal (e=2)
     k = 2 or k > 6: slow terrain like forest/water edge (e=1)
     k = -3: walk backwards (e=-2, treat as 1 for now)
     else: normal (e=2) *)
  IF k = -1 THEN RETURN 4
  ELSIF k = -3 THEN RETURN 1
  ELSIF (k = 2) OR (k > 6) THEN RETURN 1
  ELSE RETURN 2
  END
END EnvironToSpeed;

PROCEDURE UpdateEnviron(terrCode, curEnv: INTEGER): INTEGER;
VAR target: INTEGER;
BEGIN
  (* Original logic from fmain.c:2300-2358.
     Terrain codes 4,5 (water) ramp gradually toward target.
     Other terrain codes set environ directly. *)
  CASE terrCode OF
    0:  (* normal — ramp down gradually *)
      IF curEnv > 0 THEN RETURN curEnv - 1
      ELSIF curEnv < 0 THEN RETURN 0
      ELSE RETURN 0
      END |
    2:  RETURN 2  |  (* slow/brush — legs hidden *)
    3:  (* shore — ramp toward 5 *)
      IF curEnv > 5 THEN RETURN curEnv - 1
      ELSIF curEnv < 5 THEN RETURN curEnv + 1
      ELSE RETURN 5
      END |
    6:  RETURN -1 |  (* fast road *)
    7:  RETURN -2 |  (* slippery *)
    8:  RETURN -3 |  (* backwards *)
    10: RETURN 0  |  (* blocked terrain — should not reach here *)
    15: RETURN 0  |  (* blocked terrain — should not reach here *)
    4:
      (* Shallow water: target environ = 10, ramp gradually *)
      target := 10;
      IF curEnv > target THEN RETURN curEnv - 1
      ELSIF curEnv < target THEN RETURN curEnv + 1
      ELSE RETURN curEnv
      END |
    5:
      (* Deep water: target environ = 30, ramp gradually *)
      target := 30;
      IF curEnv > target THEN RETURN curEnv - 1
      ELSIF curEnv < target THEN RETURN curEnv + 1
      ELSE RETURN curEnv
      END
  ELSE
    RETURN 0
  END
END UpdateEnviron;

PROCEDURE MoveActor(actorIdx, dir, speed: INTEGER): BOOLEAN;
VAR xTest, yTest, effSpeed, terrCode, env: INTEGER;
BEGIN
  IF currentRegion >= 0 THEN
    (* Use environ-based speed like the original *)
    effSpeed := EnvironToSpeed(actors[actorIdx].environ)
  ELSE
    effSpeed := speed
  END;

  xTest := NewX(actors[actorIdx].absX, dir, effSpeed);
  yTest := NewY(actors[actorIdx].absY, dir, effSpeed);

  (* World boundary clamp — keep within valid map area *)
  IF xTest < 0 THEN RETURN FALSE END;
  IF yTest < 0 THEN RETURN FALSE END;
  IF xTest > 32767 THEN RETURN FALSE END;
  IF yTest > 40959 THEN RETURN FALSE END;

  IF ProxCheck(xTest, yTest, actorIdx) # 0 THEN
    RETURN FALSE
  END;
  actors[actorIdx].absX := xTest;
  actors[actorIdx].absY := yTest;

  (* Update environ from terrain at new position — skip for swan rider *)
  IF (currentRegion >= 0) AND
     NOT ((actorIdx = 0) AND (riding = RideSwan)) THEN
    terrCode := GetTerrainAt(actors[actorIdx].absX, actors[actorIdx].absY);
    actors[actorIdx].environ := UpdateEnviron(terrCode, actors[actorIdx].environ)
  END;
  RETURN TRUE
END MoveActor;

BEGIN
  InitDirTables
END Movement.
