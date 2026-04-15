IMPLEMENTATION MODULE Combat;

(* Combat system matching original FTA dohit/checkdead.
   TEMPORARY: player takes no damage (defender=0 suppressed). *)

FROM Actor IMPORT actors, actorCount,
                  TypeEnemy, TypeSetfig,
                  StFighting, StDying, StDead, StStill, StShoot1,
                  GoalDeath;
FROM Brothers IMPORT brothers, activeBrother;
FROM SFX IMPORT PlayEffect, SfxEnemyHit, SfxPlayerHit;

VAR
  hitCooldown: ARRAY [0..19] OF INTEGER;  (* per-actor attack timer *)
  rng: INTEGER;

PROCEDURE Rand(limit: INTEGER): INTEGER;
BEGIN
  rng := rng * 1103515245 + 12345;
  IF rng < 0 THEN rng := -rng END;
  IF limit <= 0 THEN RETURN 0 END;
  RETURN (rng DIV 65536) MOD limit
END Rand;

(* --- Central hit function matching original dohit --- *)

PROCEDURE DoHit(attacker, defender: INTEGER);
VAR damage, wt: INTEGER;
BEGIN
  (* TEMPORARY: player invulnerability — remove this to enable enemy damage *)
  IF defender = 0 THEN RETURN END;

  (* Damage: weapon value + small random bonus *)
  wt := actors[attacker].weapon;
  IF wt >= 8 THEN wt := 5 END;
  IF wt < 1 THEN wt := 1 END;
  damage := wt + 1;

  DEC(actors[defender].vitality, damage);

  IF defender = 0 THEN
    PlayEffect(SfxPlayerHit)
  ELSE
    PlayEffect(SfxEnemyHit)
  END;

  (* Check death — matches original checkdead() *)
  IF actors[defender].vitality <= 0 THEN
    actors[defender].vitality := 0;
    actors[defender].state := StDying;
    actors[defender].goal := GoalDeath;
    actors[defender].tactic := 7;  (* death countdown init *)

    IF defender > 0 THEN
      (* Enemy killed: brave++ *)
      INC(brothers[activeBrother].brave)
    ELSE
      (* Player killed: luck -= 5 *)
      DEC(brothers[activeBrother].luck, 5);
      IF brothers[activeBrother].luck < 0 THEN
        brothers[activeBrother].luck := 0
      END
    END;

    (* Killing a person (SETFIG): kind -= 3 *)
    IF actors[defender].actorType = TypeSetfig THEN
      DEC(brothers[activeBrother].kind, 3);
      IF brothers[activeBrother].kind < 0 THEN
        brothers[activeBrother].kind := 0
      END
    END
  END
END DoHit;

(* --- Distance check --- *)

PROCEDURE Dist(a, b: INTEGER; VAR xd, yd: INTEGER);
BEGIN
  xd := actors[a].absX - actors[b].absX;
  yd := actors[a].absY - actors[b].absY;
  IF xd < 0 THEN xd := -xd END;
  IF yd < 0 THEN yd := -yd END
END Dist;

(* --- Facing check --- *)

PROCEDURE IsFacing(attacker, target: INTEGER): BOOLEAN;
VAR dx, dy, f: INTEGER;
BEGIN
  (* Generous facing check — target must be in the forward 180 degrees *)
  dx := actors[target].absX - actors[attacker].absX;
  dy := actors[target].absY - actors[attacker].absY;
  f := actors[attacker].facing;
  CASE f OF
    0: RETURN dy <= 0 |          (* N: anything north *)
    1: RETURN (dx >= 0) OR (dy <= 0) |  (* NE: north or east half *)
    2: RETURN dx >= 0 |          (* E *)
    3: RETURN (dx >= 0) OR (dy >= 0) |  (* SE *)
    4: RETURN dy >= 0 |          (* S *)
    5: RETURN (dx <= 0) OR (dy >= 0) |  (* SW *)
    6: RETURN dx <= 0 |          (* W *)
    7: RETURN (dx <= 0) OR (dy <= 0)    (* NW *)
  ELSE
    RETURN TRUE
  END
END IsFacing;

(* --- Search dead enemy for weapon loot --- *)

PROCEDURE SearchBody(enemyIdx: INTEGER): INTEGER;
VAR w: INTEGER;
BEGIN
  IF (enemyIdx < 1) OR (enemyIdx >= actorCount) THEN RETURN -1 END;
  IF actors[enemyIdx].state # StDead THEN RETURN -1 END;
  w := actors[enemyIdx].weapon;
  IF w <= 0 THEN RETURN -1 END;
  actors[enemyIdx].weapon := -1;
  RETURN w
END SearchBody;

(* --- Main combat update --- *)

PROCEDURE UpdateCombat;
VAR i, xd, yd, bv: INTEGER;
BEGIN
  (* Decrement all cooldowns *)
  FOR i := 0 TO actorCount - 1 DO
    IF hitCooldown[i] > 0 THEN DEC(hitCooldown[i]) END
  END;

  (* Enemy → Player attacks — only deal damage, don't change state.
     State management is handled by EnemyAI. *)
  FOR i := 1 TO actorCount - 1 DO
    IF (actors[i].state = StFighting) AND (hitCooldown[i] = 0) THEN
      Dist(i, 0, xd, yd);
      IF (xd < 14) AND (yd < 14) THEN
        DoHit(i, 0);
        hitCooldown[i] := 12
      END
    END
  END;

  (* Player → Enemy melee attacks *)
  IF (actors[0].state = StFighting) AND (hitCooldown[0] = 0) THEN
    FOR i := 1 TO actorCount - 1 DO
      IF (actors[i].state # StDead) AND (actors[i].state # StDying) THEN
        Dist(0, i, xd, yd);
        IF (xd < 20) AND (yd < 20) AND IsFacing(0, i) THEN
          DoHit(0, i);
          hitCooldown[0] := 8;
          i := actorCount  (* break *)
        END
      END
    END
  END
END UpdateCombat;

BEGIN
  rng := 77777;
  FOR rng := 0 TO 19 DO hitCooldown[rng] := 0 END;
  rng := 77777
END Combat.
