IMPLEMENTATION MODULE EnemyAI;

FROM Actor IMPORT actors, actorCount, StWalking, StStill, StDead,
                  StFighting, StDying, GoalAttack1, GoalStand, GoalDeath;
FROM Movement IMPORT MoveActor;

PROCEDURE CalcDist(ax, ay, bx, by: INTEGER): INTEGER;
VAR dx, dy: INTEGER;
BEGIN
  dx := ax - bx;
  dy := ay - by;
  IF dx < 0 THEN dx := -dx END;
  IF dy < 0 THEN dy := -dy END;
  RETURN dx + dy
END CalcDist;

PROCEDURE SetCourse(actorIdx, targetX, targetY: INTEGER);
VAR dx, dy: INTEGER;
BEGIN
  dx := targetX - actors[actorIdx].absX;
  dy := targetY - actors[actorIdx].absY;

  (* Pick best 8-way direction toward target *)
  IF (dx > 3) AND (dy < -3) THEN
    actors[actorIdx].facing := 1  (* NE *)
  ELSIF (dx > 3) AND (dy > 3) THEN
    actors[actorIdx].facing := 3  (* SE *)
  ELSIF (dx < -3) AND (dy > 3) THEN
    actors[actorIdx].facing := 5  (* SW *)
  ELSIF (dx < -3) AND (dy < -3) THEN
    actors[actorIdx].facing := 7  (* NW *)
  ELSIF dx > 3 THEN
    actors[actorIdx].facing := 2  (* E *)
  ELSIF dx < -3 THEN
    actors[actorIdx].facing := 6  (* W *)
  ELSIF dy < -3 THEN
    actors[actorIdx].facing := 0  (* N *)
  ELSIF dy > 3 THEN
    actors[actorIdx].facing := 4  (* S *)
  END
END SetCourse;

PROCEDURE UpdateOne(i: INTEGER);
VAR dist: INTEGER;
BEGIN
  IF actors[i].state = StDead THEN RETURN END;
  IF actors[i].state = StDying THEN
    actors[i].state := StDead;
    RETURN
  END;

  dist := CalcDist(actors[i].absX, actors[i].absY,
                   actors[0].absX, actors[0].absY);

  IF actors[i].goal = GoalAttack1 THEN
    IF dist < 14 THEN
      (* Close enough to fight *)
      actors[i].state := StFighting
    ELSIF dist < 200 THEN
      (* Pursue player *)
      SetCourse(i, actors[0].absX, actors[0].absY);
      IF MoveActor(i, actors[i].facing, 1) THEN
        actors[i].state := StWalking
      ELSE
        (* Try deviating like original checkdev1/checkdev2 *)
        actors[i].facing := (actors[i].facing + 1) MOD 8;
        IF NOT MoveActor(i, actors[i].facing, 1) THEN
          actors[i].facing := (actors[i].facing + 6) MOD 8;
          IF NOT MoveActor(i, actors[i].facing, 1) THEN
            actors[i].state := StStill
          END
        END
      END
    ELSE
      actors[i].state := StStill
    END
  ELSIF actors[i].goal = GoalStand THEN
    IF dist < 14 THEN
      SetCourse(i, actors[0].absX, actors[0].absY)
    END;
    actors[i].state := StStill
  END
END UpdateOne;

PROCEDURE UpdateEnemies;
VAR i: INTEGER;
BEGIN
  FOR i := 1 TO actorCount - 1 DO
    UpdateOne(i)
  END
END UpdateEnemies;

END EnemyAI.
