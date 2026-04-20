IMPLEMENTATION MODULE Carrier;

(* Carrier/riding system matching original FTA.
   Raft: fixed at (13668,14470), slot 1, auto-mount when very close.
   Turtle: spawned via shell, slot 3, water-only navigation.
   Swan: spawned in extent 0, slot 3, needs lasso, flies anywhere. *)

FROM Actor IMPORT actors, actorCount,
                  TypeRaft, TypeCarrier, TypeDragon,
                  StStill, StWalking, StDead, StDying;
FROM World IMPORT camX, camY;
FROM Brothers IMPORT brothers, activeBrother, HasStuff;
FROM Assets IMPORT GetTerrainAt, currentRegion;
FROM Strings IMPORT Assign;
FROM NPC IMPORT GetSpeech;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;

CONST
  RaftX = 13668;  (* fixed raft spawn position *)
  RaftY = 14470;
  RaftSlot = 1;   (* actor slot for raft *)
  CarrierSlot = 3; (* actor slot for turtle/swan *)

  (* Stuff indices *)
  StLasso = 5;
  StShell = 6;

VAR
  raftProx: INTEGER;  (* 0=far, 1=near, 2=very near *)
  turtleTick: INTEGER;
  swanCooldown: INTEGER;  (* frames before remount allowed after dismount *)

PROCEDURE Abs(x: INTEGER): INTEGER;
BEGIN IF x < 0 THEN RETURN -x ELSE RETURN x END
END Abs;

PROCEDURE TalkToCarrier(VAR speech: ARRAY OF CHAR): BOOLEAN;
VAR dx, dy: INTEGER;
BEGIN
  IF activeCarrier # 5 THEN RETURN FALSE END;
  dx := Abs(actors[0].absX - actors[CarrierSlot].absX);
  dy := Abs(actors[0].absY - actors[CarrierSlot].absY);
  IF (dx > 40) OR (dy > 40) THEN RETURN FALSE END;
  (* Turtle: give shell if not owned, otherwise just talk *)
  IF brothers[activeBrother].stuff[StShell] > 0 THEN
    GetSpeech(57, speech)  (* "Just hop on my back if you need a ride" *)
  ELSE
    brothers[activeBrother].stuff[StShell] := 1;
    GetSpeech(56, speech)  (* "Thank you for saving my eggs! Take this shell" *)
  END;
  RETURN TRUE
END TalkToCarrier;

PROCEDURE InitCarriers;
BEGIN
  riding := RideNone;
  activeCarrier := 0;
  raftProx := 0;
  turtleTick := 0;
  turtleEggs := FALSE;
  turtleEggsDone := FALSE;

  (* Set up raft at fixed location — slot 1 *)
  actors[RaftSlot].absX := RaftX;
  actors[RaftSlot].absY := RaftY;
  actors[RaftSlot].actorType := TypeRaft;
  actors[RaftSlot].state := StStill;
  actors[RaftSlot].vitality := 999;
  actors[RaftSlot].weapon := 0;
  actors[RaftSlot].environ := 0;
  actors[RaftSlot].visible := TRUE;
  actors[RaftSlot].race := 0;
  IF actorCount < 2 THEN actorCount := 2 END
END InitCarriers;

(* Check proximity to a carrier at given actor slot *)
PROCEDURE CheckProximity(slot: INTEGER);
VAR dx, dy: INTEGER;
BEGIN
  dx := actors[0].absX - actors[slot].absX;
  dy := actors[0].absY - actors[slot].absY;
  IF (Abs(dx) < 9) AND (Abs(dy) < 9) THEN
    raftProx := 2  (* very close — can mount *)
  ELSIF (Abs(dx) < 16) AND (Abs(dy) < 16) THEN
    raftProx := 1  (* near *)
  ELSE
    raftProx := 0  (* far *)
  END
END CheckProximity;

(* Update raft — follows player when very close *)
PROCEDURE UpdateRaft;
VAR terrain: INTEGER;
BEGIN
  IF riding = RideRaft THEN
    (* Riding raft — raft follows player exactly *)
    actors[RaftSlot].absX := actors[0].absX;
    actors[RaftSlot].absY := actors[0].absY;

    (* Check if player left water — dismount *)
    terrain := GetTerrainAt(actors[0].absX, actors[0].absY);
    IF (terrain # 4) AND (terrain # 5) AND (terrain # 3) THEN
      riding := RideNone
    END
  ELSE
    (* Not riding — check proximity for auto-mount *)
    CheckProximity(RaftSlot);
    IF raftProx = 2 THEN
      terrain := GetTerrainAt(actors[0].absX, actors[0].absY);
      IF (terrain = 4) OR (terrain = 5) OR (terrain = 3) THEN
        riding := RideRaft;
        actors[RaftSlot].absX := actors[0].absX;
        actors[RaftSlot].absY := actors[0].absY
      END
    END
  END
END UpdateRaft;

(* Update turtle carrier *)
PROCEDURE UpdateTurtleCarrier;
VAR terrain: INTEGER;
BEGIN
  IF activeCarrier # 5 THEN RETURN END;

  IF riding = RideTurtle THEN
    (* Riding turtle — follows player, faces same direction *)
    actors[CarrierSlot].absX := actors[0].absX;
    actors[CarrierSlot].absY := actors[0].absY;
    actors[CarrierSlot].facing := actors[0].facing;

    (* Check dismount — if player on land *)
    terrain := GetTerrainAt(actors[0].absX, actors[0].absY);
    IF (terrain # 4) AND (terrain # 5) AND (terrain # 3) THEN
      riding := RideNone
    END
  ELSE
    (* Not riding — swim toward player every 16 frames.
       Original: set_course(i, hero_x, hero_y, 5) when (daynight & 15)==0 *)
    CheckProximity(CarrierSlot);
    IF raftProx = 2 THEN
      riding := RideTurtle;
      actors[CarrierSlot].absX := actors[0].absX;
      actors[CarrierSlot].absY := actors[0].absY
    ELSIF raftProx = 0 THEN
      (* Swim toward player — but only while turtle is in water.
         If next step would leave water, stop. Turtle stays on coast. *)
      IF actors[0].absX > actors[CarrierSlot].absX + 3 THEN
        IF GetTerrainAt(actors[CarrierSlot].absX + 2, actors[CarrierSlot].absY) >= 3 THEN
          INC(actors[CarrierSlot].absX, 2);
          actors[CarrierSlot].facing := 2
        END
      ELSIF actors[0].absX < actors[CarrierSlot].absX - 3 THEN
        IF GetTerrainAt(actors[CarrierSlot].absX - 2, actors[CarrierSlot].absY) >= 3 THEN
          DEC(actors[CarrierSlot].absX, 2);
          actors[CarrierSlot].facing := 6
        END
      END;
      IF actors[0].absY > actors[CarrierSlot].absY + 3 THEN
        IF GetTerrainAt(actors[CarrierSlot].absX, actors[CarrierSlot].absY + 2) >= 3 THEN
          INC(actors[CarrierSlot].absY, 2);
          actors[CarrierSlot].facing := 4
        END
      ELSIF actors[0].absY < actors[CarrierSlot].absY - 3 THEN
        IF GetTerrainAt(actors[CarrierSlot].absX, actors[CarrierSlot].absY - 2) >= 3 THEN
          DEC(actors[CarrierSlot].absY, 2);
          actors[CarrierSlot].facing := 0
        END
      END;
      actors[CarrierSlot].state := StWalking
    END
  END
END UpdateTurtleCarrier;

(* Update swan carrier *)
PROCEDURE IsFireyDeath(): BOOLEAN;
(* Original: fiery_death = map_x > 8802 && map_x < 13562 &&
   map_y > 24744 && map_y < 29544.
   Plain of Grief / lava zone — swan can't land here. *)
BEGIN
  RETURN (camX > 8802) AND (camX < 13562) AND
         (camY > 24744) AND (camY < 29544)
END IsFireyDeath;

PROCEDURE UpdateSwanCarrier;
VAR terrain, yt: INTEGER;
BEGIN
  IF activeCarrier # 11 THEN RETURN END;

  IF riding = RideSwan THEN
    (* Riding swan — follows player, faces same direction *)
    actors[CarrierSlot].absX := actors[0].absX;
    actors[CarrierSlot].absY := actors[0].absY;
    actors[CarrierSlot].facing := actors[0].facing;

    (* Airborne — prevents sinking and enemy melee *)
    actors[0].environ := -2;

    (* Dismount: original triggers when player nearly stopped and
       presses button. We use swanDismount flag set by GameState
       on attack press. Only land on passable non-water terrain. *)
    IF swanDismount THEN
      swanDismount := FALSE;
      IF IsFireyDeath() THEN
        (* Event 32: can't land in lava *)
      ELSIF (Abs(actors[0].velX) >= 15) OR (Abs(actors[0].velY) >= 15) THEN
        (* Event 33: too fast — stop pressing direction first *)
      ELSE
        yt := actors[0].absY - 14;
        terrain := GetTerrainAt(actors[0].absX, yt);
        IF (terrain # 1) AND (terrain < 4) THEN
          riding := RideNone;
          actors[0].absY := yt;
          actors[0].environ := 0;
          actors[0].velX := 0;
          actors[0].velY := 0;
          actors[0].state := StStill;
          (* Swan stays at landing spot for remount *)
          actors[CarrierSlot].state := StStill;
          swanCooldown := 30  (* prevent instant remount *)
        END
      END
    END
  ELSE
    (* Not riding — check if player near swan with lasso *)
    IF swanCooldown > 0 THEN
      DEC(swanCooldown)
    ELSIF HasStuff(StLasso) THEN
      CheckProximity(CarrierSlot);
      IF raftProx >= 1 THEN
        riding := RideSwan;
        actors[CarrierSlot].absX := actors[0].absX;
        actors[CarrierSlot].absY := actors[0].absY;
        actors[0].velX := 0;
        actors[0].velY := 0
      END
    END
  END
END UpdateSwanCarrier;

PROCEDURE PlaceTurtle(tx, ty: INTEGER);
BEGIN
  actors[CarrierSlot].absX := tx;
  actors[CarrierSlot].absY := ty;
  actors[CarrierSlot].actorType := TypeCarrier;
  actors[CarrierSlot].state := StStill;
  actors[CarrierSlot].vitality := 50;
  actors[CarrierSlot].weapon := 0;
  actors[CarrierSlot].environ := 0;
  actors[CarrierSlot].visible := TRUE;
  actors[CarrierSlot].race := 5;
  activeCarrier := 5;
  IF actorCount < 4 THEN actorCount := 4 END;
  WriteString("Carrier: turtle spawned at ");
  WriteInt(tx, 1); WriteString(","); WriteInt(ty, 1); WriteLn
END PlaceTurtle;

PROCEDURE SpawnTurtle;
(* Original get_turtle: try 25 random positions 150-213px from player
   in a random direction, looking for deep water (terrain 5).
   xdir = {-2,0,2,3,2,0,-2,-3}, ydir = {-2,-3,-2,0,2,3,2,0} *)
VAR i, dir, dist, tx, ty, terrain, rng: INTEGER;
    xdir, ydir: ARRAY [0..7] OF INTEGER;
BEGIN
  xdir[0] := -2; xdir[1] :=  0; xdir[2] := 2; xdir[3] := 3;
  xdir[4] :=  2; xdir[5] :=  0; xdir[6] := -2; xdir[7] := -3;
  ydir[0] := -2; ydir[1] := -3; ydir[2] := -2; ydir[3] := 0;
  ydir[4] :=  2; ydir[5] :=  3; ydir[6] := 2; ydir[7] := 0;
  rng := actors[0].absX * 31 + actors[0].absY + dragonRng;
  FOR i := 0 TO 24 DO
    rng := rng * 1103515245 + 12345;
    IF rng < 0 THEN rng := -rng END;
    dir := (rng DIV 65536) MOD 8;
    rng := rng * 1103515245 + 12345;
    IF rng < 0 THEN rng := -rng END;
    dist := 150 + (rng DIV 65536) MOD 64;
    tx := actors[0].absX + (xdir[dir] * dist) DIV 2;
    ty := actors[0].absY + (ydir[dir] * dist) DIV 2;
    terrain := GetTerrainAt(tx, ty);
    IF terrain = 5 THEN
      PlaceTurtle(tx, ty);
      RETURN
    END
  END;
  WriteString("Carrier: no deep water found for turtle"); WriteLn
END SpawnTurtle;

(* Check if player entered swan extent (2118-2618, 27237-27637) with lasso *)
PROCEDURE CheckSwanExtent;
BEGIN
  IF activeCarrier = 11 THEN RETURN END;  (* already spawned *)
  IF NOT HasStuff(StLasso) THEN RETURN END;
  IF (actors[0].absX > 2118) AND (actors[0].absX < 2618) AND
     (actors[0].absY > 27237) AND (actors[0].absY < 27637) THEN
    actors[CarrierSlot].absX := 2368;  (* center of extent *)
    actors[CarrierSlot].absY := 27437;
    actors[CarrierSlot].actorType := TypeCarrier;
    actors[CarrierSlot].state := StStill;
    actors[CarrierSlot].vitality := 50;
    actors[CarrierSlot].weapon := 0;
    actors[CarrierSlot].environ := 0;
    actors[CarrierSlot].visible := TRUE;
    actors[CarrierSlot].race := 11;
    actors[CarrierSlot].facing := 4;
    activeCarrier := 11;
    IF actorCount < 4 THEN actorCount := 4 END;
    WriteString("Carrier: swan spawned"); WriteLn
  END
END CheckSwanExtent;

PROCEDURE UpdateCarriers;
BEGIN
  IF actors[0].state >= 14 THEN RETURN END;  (* dead/dying — skip *)

  UpdateRaft;
  CheckSwanExtent;
  IF activeCarrier = 5 THEN UpdateTurtleCarrier
  ELSIF activeCarrier = 11 THEN UpdateSwanCarrier
  ELSIF (riding = RideSwan) OR
        ((actors[CarrierSlot].actorType = TypeCarrier) AND
         (actors[CarrierSlot].race = 11) AND
         (actors[CarrierSlot].vitality > 0)) THEN
    (* Swan exists (riding or dismounted) — keep active for remount *)
    activeCarrier := 11;
    UpdateSwanCarrier
  ELSIF (actors[CarrierSlot].actorType = TypeCarrier) AND
        (actors[CarrierSlot].race = 5) AND
        (actors[CarrierSlot].vitality > 0) THEN
    (* Turtle exists but activeCarrier was cleared by extent reset. *)
    activeCarrier := 5;
    UpdateTurtleCarrier
  END;

  (* Prevent sinking while riding — but swan is airborne (environ=-2) *)
  IF (riding # RideNone) AND (riding # RideSwan) THEN
    actors[0].environ := 0
  END
END UpdateCarriers;

(* --- Dragon --- *)

VAR
  dragonSpawned: BOOLEAN;
  dragonRng: INTEGER;

PROCEDURE SpawnDragon;
BEGIN
  IF dragonSpawned THEN RETURN END;
  (* Original: spawns at extent center + offset (6999, 35151) *)
  actors[CarrierSlot].absX := 6999;
  actors[CarrierSlot].absY := 35151;
  actors[CarrierSlot].actorType := TypeDragon;
  actors[CarrierSlot].state := StStill;
  actors[CarrierSlot].vitality := 50;
  actors[CarrierSlot].weapon := 5;  (* wand-type = fire breath missile *)
  actors[CarrierSlot].environ := 0;
  actors[CarrierSlot].visible := TRUE;
  actors[CarrierSlot].race := 10;
  actors[CarrierSlot].facing := 5;
  IF actorCount < 4 THEN actorCount := 4 END;
  dragonSpawned := TRUE;
  WriteString("Dragon spawned"); WriteLn
END SpawnDragon;

PROCEDURE UpdateDragon;
VAR dx, dy: INTEGER;
BEGIN
  IF NOT dragonSpawned THEN RETURN END;
  IF actors[CarrierSlot].actorType # TypeDragon THEN RETURN END;
  IF actors[CarrierSlot].state = StDead THEN RETURN END;
  IF actors[CarrierSlot].state = StDying THEN
    DEC(actors[CarrierSlot].tactic);
    IF actors[CarrierSlot].tactic <= 0 THEN
      actors[CarrierSlot].state := StDead
    END;
    RETURN
  END;
  IF actors[CarrierSlot].vitality < 1 THEN
    actors[CarrierSlot].state := StDying;
    actors[CarrierSlot].tactic := 30;
    RETURN
  END;

  (* Face the player *)
  dx := actors[0].absX - actors[CarrierSlot].absX;
  dy := actors[0].absY - actors[CarrierSlot].absY;
  IF Abs(dx) > Abs(dy) THEN
    IF dx > 0 THEN actors[CarrierSlot].facing := 2
    ELSE actors[CarrierSlot].facing := 6 END
  ELSE
    IF dy > 0 THEN actors[CarrierSlot].facing := 4
    ELSE actors[CarrierSlot].facing := 0 END
  END;

  (* Fire breath: 25% chance per frame — original: rand4() == 0.
     Set flag for GameState to call FireMissile (avoids import cycle). *)
  dragonFire := FALSE;
  dragonRng := dragonRng * 1103515245 + 12345;
  IF dragonRng < 0 THEN dragonRng := -dragonRng END;
  IF (dragonRng DIV 65536) MOD 4 = 0 THEN
    IF (Abs(dx) < 200) AND (Abs(dy) < 200) THEN
      dragonFire := TRUE
    END
  END
END UpdateDragon;

BEGIN
  dragonSpawned := FALSE;
  dragonFire := FALSE;
  swanDismount := FALSE;
  swanCooldown := 0;
  dragonRng := 31337
END Carrier.
