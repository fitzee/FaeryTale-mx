IMPLEMENTATION MODULE Missile;

(* Projectile system from original FTA.
   Arrows use object sprite frames 0-7 (8 directions).
   Wand bolts use frames 89-96. Spent = frame 88. *)

FROM Actor IMPORT actors, actorCount,
                  StDead, StDying, StShoot1, StShoot3, StStill;
FROM Movement IMPORT NewX, NewY;
FROM Combat IMPORT DoHit;
FROM Platform IMPORT ren, Scale, PlayW, PlayH, DrawTexRegion;
FROM World IMPORT camX, camY;
FROM WorldObj IMPORT objTex;
FROM DayNight IMPORT brightness;
FROM SFX IMPORT PlayEffect, SfxBowFire, SfxWandFire, SfxArrowHit;

CONST
  MaxFlight  = 40;  (* max frames before missile dies *)
  ArrowSpeed = 3;
  WandSpeed  = 5;
  ArrowHitR  = 6;   (* hit radius *)
  WandHitR   = 9;
  ObjSprH    = 16;  (* object sprite frame height *)
  ObjSprW    = 16;

VAR
  (* Spawn offsets from original bowshotx/bowshoty *)
  bowShotX: ARRAY [0..7] OF INTEGER;
  bowShotY: ARRAY [0..7] OF INTEGER;

PROCEDURE InitMissiles;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO MaxMissiles - 1 DO
    missiles[i].mtype := 0;
    missiles[i].speed := 0
  END;
  nextSlot := 0;

  bowShotX[0] :=  0; bowShotY[0] := -6;
  bowShotX[1] :=  0; bowShotY[1] := -6;
  bowShotX[2] :=  3; bowShotY[2] := -1;
  bowShotX[3] :=  6; bowShotY[3] :=  0;
  bowShotX[4] := -3; bowShotY[4] :=  6;
  bowShotX[5] := -3; bowShotY[5] :=  8;
  bowShotX[6] := -3; bowShotY[6] :=  0;
  bowShotX[7] := -6; bowShotY[7] := -1
END InitMissiles;

PROCEDURE FireMissile(actorIdx: INTEGER);
VAR weapon, d: INTEGER;
BEGIN
  weapon := actors[actorIdx].weapon;
  IF (weapon < 4) OR (weapon > 5) THEN RETURN END;

  d := actors[actorIdx].facing;
  IF d > 7 THEN d := 0 END;

  missiles[nextSlot].absX := actors[actorIdx].absX + bowShotX[d];
  missiles[nextSlot].absY := actors[actorIdx].absY + bowShotY[d];
  missiles[nextSlot].direction := d;
  missiles[nextSlot].archer := actorIdx;
  missiles[nextSlot].timeOfFlight := 0;

  IF weapon = 4 THEN
    missiles[nextSlot].mtype := 1;  (* arrow *)
    missiles[nextSlot].speed := ArrowSpeed;
    PlayEffect(SfxBowFire)
  ELSE
    missiles[nextSlot].mtype := 2;  (* wand bolt *)
    missiles[nextSlot].speed := WandSpeed;
    PlayEffect(SfxWandFire)
  END;

  nextSlot := (nextSlot + 1) MOD MaxMissiles
END FireMissile;

PROCEDURE UpdateMissiles;
VAR i, j, s, dx, dy, dist, hitR: INTEGER;
BEGIN
  FOR i := 0 TO MaxMissiles - 1 DO
    IF (missiles[i].mtype = 0) OR (missiles[i].mtype = 3) OR
       (missiles[i].speed = 0) THEN
      missiles[i].mtype := 0
    ELSE
      INC(missiles[i].timeOfFlight);
      IF missiles[i].timeOfFlight > MaxFlight THEN
        missiles[i].mtype := 0
      ELSE
        (* Move missile *)
        s := missiles[i].speed * 2;
        missiles[i].absX := NewX(missiles[i].absX, missiles[i].direction, s);
        missiles[i].absY := NewY(missiles[i].absY, missiles[i].direction, s);

        (* Hit radius *)
        IF missiles[i].mtype = 2 THEN
          hitR := WandHitR
        ELSE
          hitR := ArrowHitR
        END;

        (* Check collision with actors *)
        FOR j := 0 TO actorCount - 1 DO
          IF (j # missiles[i].archer) AND
             (actors[j].state # StDead) AND
             (actors[j].state # StDying) THEN
            dx := actors[j].absX - missiles[i].absX;
            dy := actors[j].absY - missiles[i].absY;
            IF dx < 0 THEN dx := -dx END;
            IF dy < 0 THEN dy := -dy END;
            (* Chebyshev distance *)
            IF dx > dy THEN dist := dx ELSE dist := dy END;
            IF dist < hitR THEN
              DoHit(missiles[i].archer, j);
              PlayEffect(SfxArrowHit);
              missiles[i].speed := 0;
              missiles[i].mtype := 3;  (* spent *)
              j := actorCount  (* break *)
            END
          END
        END
      END
    END
  END
END UpdateMissiles;

PROCEDURE S(v: INTEGER): INTEGER;
BEGIN RETURN v * Scale END S;

PROCEDURE DrawMissiles;
VAR i, sx, sy, frame, srcY: INTEGER;
BEGIN
  IF objTex = NIL THEN RETURN END;

  FOR i := 0 TO MaxMissiles - 1 DO
    IF missiles[i].mtype > 0 THEN
      sx := (missiles[i].absX - camX) * Scale;
      sy := (missiles[i].absY - camY) * Scale;
      IF (sx > -S(20)) AND (sx < S(PlayW) + 20) AND
         (sy > -S(20)) AND (sy < S(PlayH) + 20) THEN

        IF missiles[i].mtype = 3 THEN
          frame := 88  (* spent/stuck *)
        ELSIF missiles[i].mtype = 2 THEN
          (* Wand bolt: remap our dir (N=0..NW=7) to original frame order *)
          frame := (missiles[i].direction + 1) MOD 8 + 89
        ELSE
          (* Arrow: remap direction to match original sprite frame order.
             Objects sheet: frame 0=NW, 1=N, 2=NE, 3=E, 4=SE, 5=S, 6=SW, 7=W.
             Our dirs: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW. *)
          frame := (missiles[i].direction + 1) MOD 8
        END;

        srcY := frame * ObjSprH;
        DrawTexRegion(objTex,
                      0, srcY, ObjSprW, ObjSprH,
                      sx - S(8), sy - S(8),
                      S(ObjSprW), S(ObjSprH))
      END
    END
  END
END DrawMissiles;

END Missile.
