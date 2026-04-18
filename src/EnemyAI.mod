IMPLEMENTATION MODULE EnemyAI;

(* Enemy AI matching original FTA.
   Two separate concerns:
   1. Tactic/direction selection (occasional, ~1/8 or 1/4 frames)
   2. Movement execution (every frame, tiny steps in current facing)
   These are NOT the same thing. *)

FROM Actor IMPORT actors, actorCount,
                  TypeEnemy, TypeSetfig, TypeCarrier, TypeDragon,
                  StWalking, StStill, StDead, StDying,
                  StFighting, StShoot1, StShoot3,
                  GoalAttack1, GoalAttack2, GoalArcher1, GoalArcher2,
                  GoalFlee, GoalStand, GoalDeath, GoalWait,
                  GoalFollow, GoalConfused,
                  TacPursue, TacFollow, TacBumble, TacRandom,
                  TacBackup, TacEvade, TacShoot, TacFrust;
FROM Movement IMPORT MoveActor;
FROM Missile IMPORT FireMissile;
FROM WorldObj IMPORT AddObj;
FROM Carrier IMPORT turtleEggs;

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
VAR r: BOOLEAN;
    xd, yd: INTEGER;
BEGIN
  (* Original do_tactic: r = !(rand()&7) — 1/8 chance gate on set_course.
     For ATTACK2 goal: r = !(rand()&3) — 1/4 chance instead. *)
  IF actors[i].goal = GoalAttack2 THEN
    r := (Rand(4) = 0)
  ELSE
    r := (Rand(8) = 0)
  END;

  actors[i].tactic := tactic;

  IF tactic = TacPursue THEN
    IF r THEN SetCourse(i, actors[0].absX, actors[0].absY) END

  ELSIF tactic = TacShoot THEN
    (* Original: 50% chance AND alignment check before firing.
       Must be within 8px on one axis OR on diagonal arc. *)
    CalcDist(actors[i].absX, actors[i].absY,
             actors[0].absX, actors[0].absY, xd, yd);
    IF (Rand(2) = 0) AND
       ((xd < 8) OR (yd < 8) OR
        ((xd > yd - 5) AND (xd < yd + 7))) AND
       (actors[i].state < StShoot1) THEN
      SetCourse(i, actors[0].absX, actors[0].absY);
      actors[i].state := StShoot1
    ELSE
      SetCourse(i, actors[0].absX, actors[0].absY)
    END

  ELSIF tactic = TacRandom THEN
    IF r THEN actors[i].facing := Rand(8) END;
    actors[i].state := StWalking

  ELSIF tactic = TacBumble THEN
    IF r THEN SetCourse(i, actors[0].absX, actors[0].absY) END

  ELSIF tactic = TacBackup THEN
    IF r THEN SetCourseAway(i, actors[0].absX, actors[0].absY) END

  ELSIF tactic = TacFollow THEN
    IF r THEN
      IF actorCount > 2 THEN
        IF i > 1 THEN
          SetCourse(i, actors[i-1].absX, actors[i-1].absY + 20)
        ELSE
          SetCourse(i, actors[2].absX, actors[2].absY + 20)
        END
      END
    END

  ELSIF tactic = TacEvade THEN
    IF r THEN
      actors[i].facing := (actors[i].facing + 2) MOD 8;
      actors[i].state := StWalking
    END

  ELSIF tactic = TacFrust THEN
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
        ELSIF (actors[i].race = 9) AND (actors[i].actorType = TypeEnemy) THEN
          (* Necromancer: transform + drop Talisman (objId 139) *)
          AddObj(actors[i].absX, actors[i].absY, 139, 1, -1);
          actors[i].race := 10;
          actors[i].vitality := 4;
          actors[i].weapon := 0;
          actors[i].state := StStill;
          actors[i].goal := GoalStand
        ELSIF (actors[i].race = 9) AND (actors[i].actorType = TypeSetfig) THEN
          (* Witch: drop Golden Lasso (objId 27) *)
          AddObj(actors[i].absX, actors[i].absY, 27, 1, -1);
          actors[i].state := StDead
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
  IF actors[i].actorType = TypeDragon THEN RETURN END;
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

  (* Override goals — but egg-guarding snakes never flee *)
  IF actors[0].state = StDead THEN mode := GoalFlee END;
  IF (actors[i].vitality < 2) AND
     (NOT (turtleEggs AND (actors[i].race = 4))) THEN
    mode := GoalFlee
  END;

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
    (* Original: r = !bitrand(15) — 1/16 chance to SELECT NEW tactic *)
    r := (Rand(16) = 0);

    (* Snakes with turtle eggs: force EGG_SEEK — walk to eggs *)
    IF turtleEggs AND (actors[i].race = 4) THEN
      SetCourse(i, 23087, 5667);
      actors[i].state := StWalking
    (* Select NEW tactic — only when r is TRUE *)
    ELSIF r THEN
      IF actors[i].weapon < 1 THEN
        mode := GoalConfused;
        actors[i].tactic := TacRandom
      ELSIF (actors[i].vitality < 6) AND (Rand(2) = 0) THEN
        actors[i].tactic := TacEvade
      ELSIF mode >= GoalArcher1 THEN
        IF (xd < 40) AND (yd < 30) THEN
          actors[i].tactic := TacBackup
        ELSIF (xd < 70) AND (yd < 70) THEN
          actors[i].tactic := TacShoot
        ELSE
          actors[i].tactic := TacPursue
        END
      ELSE
        actors[i].tactic := TacPursue
      END
    END;

    (* Execute current tactic EVERY FRAME — key fix matching original
       do_tactic(i, tactic) at fmain.c line 2170 *)
    SelectTactic(i, actors[i].tactic);

    (* Movement execution — every frame if WALKING *)
    IF actors[i].state = StWalking THEN
      IF NOT StepMove(i) THEN
        actors[i].state := StStill
      END
    END;

    (* Melee engagement check — matching original lines 2162-2167 *)
    thresh := 14 - mode;
    IF thresh < 8 THEN thresh := 8 END;
    IF xd > yd THEN maxDist := xd ELSE maxDist := yd END;
    IF actors[i].state = StFighting THEN
      IF maxDist >= thresh + 6 THEN
        actors[i].state := StStill
      END
    ELSIF (BAND(CARDINAL(actors[i].weapon), 4) = 0) AND
          (maxDist < thresh) THEN
      (* Original: set_course + if state >= WALKING then state = FIGHTING *)
      SetCourse(i, actors[0].absX, actors[0].absY);
      actors[i].state := StFighting
    END

  (* === NON-HOSTILE MODES === *)
  ELSIF mode = GoalFlee THEN
    (* Execute BACKUP every frame, but if blocked try random direction *)
    IF actors[i].tactic = TacFrust THEN
      (* Stuck — pick random direction to escape *)
      actors[i].facing := Rand(8);
      actors[i].state := StWalking;
      actors[i].tactic := TacBackup
    ELSE
      SelectTactic(i, TacBackup)
    END;
    IF actors[i].state = StWalking THEN
      IF NOT StepMove(i) THEN
        actors[i].facing := Rand(8);
        actors[i].state := StWalking
      END
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
  rng := 77777  (* will be mixed by first Rand calls *)
END EnemyAI.
