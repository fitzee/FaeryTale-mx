IMPLEMENTATION MODULE Movement;

FROM Actor IMPORT actors, actorCount, StDead;
FROM World IMPORT GetTerrain, IsPassable, TerrainSpeed;
FROM Assets IMPORT currentRegion, IsBlocked, GetTerrainAt;

(* Direction tables from original: N, NE, E, SE, S, SW, W, NW, none, none *)
VAR
  xDir: ARRAY [0..9] OF INTEGER;
  yDir: ARRAY [0..9] OF INTEGER;

PROCEDURE InitDirTables;
BEGIN
  xDir[0] :=  0; yDir[0] := -3;  (* N *)
  xDir[1] :=  2; yDir[1] := -2;  (* NE *)
  xDir[2] :=  3; yDir[2] :=  0;  (* E *)
  xDir[3] :=  2; yDir[3] :=  2;  (* SE *)
  xDir[4] :=  0; yDir[4] :=  3;  (* S *)
  xDir[5] := -2; yDir[5] :=  2;  (* SW *)
  xDir[6] := -3; yDir[6] :=  0;  (* W *)
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
  (* Terrain collision — matches original prox() in fsubs.asm:
     Check 1: (x+4, y+2) — blocked if terrain=1 or terrain>=10
     Check 2: (x-4, y+2) — blocked if terrain=1 or terrain>=8
     Player (actorIdx=0) can walk through terrain 8,9 (swamp/palace) *)
  IF currentRegion >= 0 THEN
    t := GetTerrainAt(x + 4, y + 2);
    IF t = 1 THEN RETURN t END;
    IF t >= 10 THEN
      IF (actorIdx = 0) AND (t = 15) THEN (* door — passable for player *)
      ELSE RETURN t
      END
    END;
    t := GetTerrainAt(x - 4, y + 2);
    IF t = 1 THEN RETURN t END;
    IF t >= 8 THEN
      IF (actorIdx = 0) AND ((t = 8) OR (t = 9) OR (t = 15)) THEN
        (* player walks through swamp/palace/doors *)
      ELSE RETURN t
      END
    END
  ELSE
    (* Fallback handcrafted world *)
    terrain := GetTerrain(x, y);
    IF NOT IsPassable(terrain) THEN
      RETURN terrain
    END
  END;

  (* Entity collision: 11x9 bounding box from original *)
  FOR j := 0 TO actorCount - 1 DO
    IF (j # actorIdx) AND (actors[j].state # StDead) THEN
      dx := x - actors[j].absX;
      dy := y - actors[j].absY;
      IF (dx < 11) AND (dx > -11) AND (dy < 9) AND (dy > -9) THEN
        RETURN 16
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
  IF ProxCheck(xTest, yTest, actorIdx) # 0 THEN
    RETURN FALSE
  END;
  actors[actorIdx].absX := xTest;
  actors[actorIdx].absY := yTest;

  (* Update environ from terrain at new position *)
  IF currentRegion >= 0 THEN
    terrCode := GetTerrainAt(actors[actorIdx].absX, actors[actorIdx].absY);
    actors[actorIdx].environ := UpdateEnviron(terrCode, actors[actorIdx].environ)
  END;
  RETURN TRUE
END MoveActor;

BEGIN
  InitDirTables
END Movement.
