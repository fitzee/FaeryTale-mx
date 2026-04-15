IMPLEMENTATION MODULE EnemyAI;

(* Enemy AI matching original FTA.
   Two separate concerns:
   1. Tactic/direction selection (occasional, ~1/8 or 1/4 frames)
   2. Movement execution (every frame, tiny steps in current facing)
   These are NOT the same thing. *)

FROM Actor IMPORT actors, actorCount,
                  TypeEnemy, TypeSetfig, TypeCarrier,
                  StWalking, StStill, StDead, StDying,
                  StFighting, StShoot1, StShoot3,
                  GoalAttack1, GoalAttack2, GoalArcher1, GoalArcher2,
                  GoalFlee, GoalStand, GoalDeath, GoalWait,
                  GoalFollow, GoalConfused,
                  TacPursue, TacFollow, TacBumble, TacRandom,
                  TacBackup, TacEvade, TacShoot, TacFrust;
FROM Movement IMPORT MoveActor;
FROM Missile IMPORT FireMissile;

VAR
  rng: INTEGER;

PROCEDURE Rand(limit: INTEGER): INTEGER;
BEGIN
  rng := rng * 1103515245 + 12345;
  IF rng < 0 THEN rng := -rng END;
  IF limit <= 0 THEN RETURN 0 END;
  RETURN (rng DIV 65536) MOD limit
END Rand;

PROCEDURE CalcDist(ax, ay, bx, by: INTEGER; VAR xd, yd: INTEGER);
BEGIN
  xd := ax - bx; yd := ay - by;
  IF xd < 0 THEN xd := -xd END;
  IF yd < 0 THEN yd := -yd END
END CalcDist;

PROCEDURE SetCourse(actorIdx, targetX, targetY: INTEGER);
VAR dx, dy: INTEGER;
BEGIN
  dx := targetX - actors[actorIdx].absX;
  dy := targetY - actors[actorIdx].absY;
  IF (dx > 3) AND (dy < -3) THEN actors[actorIdx].facing := 1
  ELSIF (dx > 3) AND (dy > 3) THEN actors[actorIdx].facing := 3
  ELSIF (dx < -3) AND (dy > 3) THEN actors[actorIdx].facing := 5
  ELSIF (dx < -3) AND (dy < -3) THEN actors[actorIdx].facing := 7
  ELSIF dx > 3 THEN actors[actorIdx].facing := 2
  ELSIF dx < -3 THEN actors[actorIdx].facing := 6
  ELSIF dy < -3 THEN actors[actorIdx].facing := 0
  ELSIF dy > 3 THEN actors[actorIdx].facing := 4
  END;
  actors[actorIdx].state := StWalking
END SetCourse;

PROCEDURE SetCourseAway(actorIdx, targetX, targetY: INTEGER);
BEGIN
  SetCourse(actorIdx,
            actors[actorIdx].absX * 2 - targetX,
            actors[actorIdx].absY * 2 - targetY)
END SetCourseAway;

(* Try to move in current facing with left/right fallback.
   Returns TRUE if moved. Sets FRUST tactic if all 3 attempts fail. *)
PROCEDURE StepMove(i: INTEGER): BOOLEAN;
VAR orig: INTEGER;
BEGIN
  orig := actors[i].facing;
  IF MoveActor(i, orig, 1) THEN RETURN TRUE END;
  (* Try +1 *)
  actors[i].facing := (orig + 1) MOD 8;
  IF MoveActor(i, actors[i].facing, 1) THEN RETURN TRUE END;
  (* Try -1 *)
  actors[i].facing := (orig + 7) MOD 8;
  IF MoveActor(i, actors[i].facing, 1) THEN RETURN TRUE END;
  (* All blocked *)
  actors[i].facing := orig;
  actors[i].tactic := TacFrust;
  RETURN FALSE
END StepMove;

(* --- Tactic selection: picks a direction, does NOT move --- *)

PROCEDURE SelectTactic(i, tactic: INTEGER);
BEGIN
  actors[i].tactic := tactic;

  IF tactic = TacPursue THEN
    SetCourse(i, actors[0].absX, actors[0].absY)

  ELSIF tactic = TacShoot THEN
    SetCourse(i, actors[0].absX, actors[0].absY);
    IF (Rand(4) = 0) AND (actors[i].state < StShoot1) THEN
      actors[i].state := StShoot1
    END

  ELSIF tactic = TacRandom THEN
    actors[i].facing := Rand(8);
    actors[i].state := StWalking

  ELSIF tactic = TacBumble THEN
    SetCourse(i, actors[0].absX, actors[0].absY)

  ELSIF tactic = TacBackup THEN
    SetCourseAway(i, actors[0].absX, actors[0].absY)

  ELSIF tactic = TacFollow THEN
    IF actorCount > 2 THEN
      IF i > 1 THEN
        SetCourse(i, actors[i-1].absX, actors[i-1].absY + 20)
      ELSE
        SetCourse(i, actors[2].absX, actors[2].absY + 20)
      END
    END

  ELSIF tactic = TacEvade THEN
    actors[i].facing := (actors[i].facing + 2) MOD 8;
    actors[i].state := StWalking

  ELSIF tactic = TacFrust THEN
    (* Pick a new random tactic *)
    IF BAND(CARDINAL(actors[i].weapon), 4) # 0 THEN
      SelectTactic(i, Rand(4) + 2)
    ELSE
      SelectTactic(i, Rand(2) + 3)
    END
  END
END SelectTactic;

(* --- Per-actor AI update --- *)

PROCEDURE UpdateOne(i: INTEGER);
VAR xd, yd, mode, tactic, thresh, maxDist: INTEGER;
    r: BOOLEAN;
BEGIN
  IF actors[i].state = StDead THEN RETURN END;
  IF actors[i].state = StDying THEN
    IF actors[i].tactic <= 0 THEN
      actors[i].tactic := 30
    ELSE
      DEC(actors[i].tactic);
      IF actors[i].tactic <= 0 THEN
        (* Death resolved — handle special races *)
        IF actors[i].race = 8 THEN
          (* Loraii: vanish instead of leaving corpse *)
          actors[i].state := StDead;
          actors[i].absX := 0;
          actors[i].absY := 0;
          actors[i].visible := FALSE
        ELSIF actors[i].race = 9 THEN
          (* Necromancer: transform into woodcutter form *)
          actors[i].race := 10;
          actors[i].vitality := 4;
          actors[i].weapon := 0;
          actors[i].state := StStill;
          actors[i].goal := GoalStand
          (* TODO: drop talisman item at position *)
        ELSE
          (* Default: corpse remains on ground *)
          actors[i].state := StDead
        END
      END
    END;
    RETURN
  END;

  IF actors[i].actorType = TypeSetfig THEN RETURN END;
  IF actors[i].actorType = TypeCarrier THEN RETURN END;
  IF actors[i].vitality < 1 THEN RETURN END;

  mode := actors[i].goal;
  tactic := actors[i].tactic;
  CalcDist(actors[i].absX, actors[i].absY,
           actors[0].absX, actors[0].absY, xd, yd);

  (* Too far — idle *)
  IF (xd > 300) OR (yd > 300) THEN
    actors[i].state := StStill;
    RETURN
  END;

  (* Override goals *)
  IF actors[0].state = StDead THEN mode := GoalFlee END;
  IF actors[i].vitality < 2 THEN mode := GoalFlee END;

  (* Shoot state machine *)
  IF actors[i].state = StShoot1 THEN
    FireMissile(i);
    actors[i].state := StShoot3;
    actors[i].goal := mode;
    RETURN
  END;
  IF actors[i].state = StShoot3 THEN
    actors[i].state := StStill;
    actors[i].goal := mode;
    RETURN
  END;

  (* === HOSTILE MODES === *)
  IF mode <= GoalArcher2 THEN
    (* Direction re-evaluation cadence:
       ATTACK1/ARCHER1: ~1 in 8 frames.
       ATTACK2/ARCHER2: ~1 in 16 frames. *)
    IF BAND(CARDINAL(mode), 2) = 0 THEN
      r := (Rand(8) = 0)
    ELSE
      r := (Rand(16) = 0)
    END;

    (* Tactic selection — only when r is TRUE *)
    IF r THEN
      IF actors[i].weapon < 1 THEN
        mode := GoalConfused;
        SelectTactic(i, TacRandom)
      ELSIF (actors[i].vitality < 6) AND (Rand(2) = 0) THEN
        SelectTactic(i, TacEvade)
      ELSIF mode >= GoalArcher1 THEN
        IF (xd < 40) AND (yd < 30) THEN
          SelectTactic(i, TacBackup)
        ELSIF (xd < 70) AND (yd < 70) THEN
          SelectTactic(i, TacShoot)
        ELSE
          SelectTactic(i, TacPursue)
        END
      ELSE
        SelectTactic(i, TacPursue)
      END
    END;

    (* Movement execution — every frame if WALKING *)
    IF actors[i].state = StWalking THEN
      IF NOT StepMove(i) THEN
        actors[i].state := StStill
      END
    END;

    (* Melee engagement check *)
    thresh := 14 - mode;
    IF thresh < 8 THEN thresh := 8 END;
    IF xd > yd THEN maxDist := xd ELSE maxDist := yd END;
    IF actors[i].state = StFighting THEN
      IF maxDist >= thresh + 6 THEN
        actors[i].state := StStill
      END
    ELSIF (BAND(CARDINAL(actors[i].weapon), 4) = 0) AND
          (maxDist < thresh) THEN
      SetCourse(i, actors[0].absX, actors[0].absY);
      actors[i].state := StFighting
    END

  (* === NON-HOSTILE MODES === *)
  ELSIF mode = GoalFlee THEN
    IF Rand(8) = 0 THEN SelectTactic(i, TacBackup) END;
    IF actors[i].state = StWalking THEN
      IF NOT StepMove(i) THEN actors[i].state := StStill END
    END

  ELSIF mode = GoalFollow THEN
    IF Rand(8) = 0 THEN SelectTactic(i, TacFollow) END;
    IF actors[i].state = StWalking THEN
      IF NOT StepMove(i) THEN actors[i].state := StStill END
    END

  ELSIF mode = GoalStand THEN
    IF Rand(16) = 0 THEN
      SetCourse(i, actors[0].absX, actors[0].absY)
    END;
    actors[i].state := StStill

  ELSIF mode = GoalWait THEN
    actors[i].state := StStill

  ELSIF mode = GoalConfused THEN
    IF Rand(8) = 0 THEN SelectTactic(i, TacRandom) END;
    IF actors[i].state = StWalking THEN
      IF NOT StepMove(i) THEN actors[i].state := StStill END
    END

  ELSE
    actors[i].state := StStill
  END;

  actors[i].goal := mode
END UpdateOne;

PROCEDURE UpdateEnemies;
VAR i: INTEGER;
BEGIN
  FOR i := 1 TO actorCount - 1 DO
    UpdateOne(i)
  END
END UpdateEnemies;

BEGIN
  rng := 54321
END EnemyAI.
