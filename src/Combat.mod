IMPLEMENTATION MODULE Combat;

FROM Actor IMPORT actors, actorCount, StFighting, StDying, StDead, StStill;

PROCEDURE DoHit(attacker, defender: INTEGER);
VAR damage: INTEGER;
BEGIN
  (* Simple damage: weapon-based like original *)
  damage := 2 + actors[attacker].weapon;
  DEC(actors[defender].vitality, damage);
  IF actors[defender].vitality <= 0 THEN
    actors[defender].state := StDying
  END
END DoHit;

PROCEDURE CalcDist(a, b: INTEGER): INTEGER;
VAR dx, dy: INTEGER;
BEGIN
  dx := actors[a].absX - actors[b].absX;
  dy := actors[a].absY - actors[b].absY;
  IF dx < 0 THEN dx := -dx END;
  IF dy < 0 THEN dy := -dy END;
  RETURN dx + dy
END CalcDist;

PROCEDURE UpdateCombat;
VAR i, dist: INTEGER;
BEGIN
  FOR i := 1 TO actorCount - 1 DO
    IF actors[i].state = StFighting THEN
      dist := CalcDist(i, 0);
      IF dist < 14 THEN
        DoHit(i, 0)
      ELSE
        actors[i].state := StStill
      END
    END
  END;

  (* Player attacking nearby enemies *)
  IF actors[0].state = StFighting THEN
    FOR i := 1 TO actorCount - 1 DO
      IF actors[i].state # StDead THEN
        dist := CalcDist(0, i);
        IF dist < 18 THEN
          DoHit(0, i)
        END
      END
    END
  END
END UpdateCombat;

END Combat.
