IMPLEMENTATION MODULE Carrier;

(* Carrier/riding system matching original FTA.
   Raft: fixed at (13668,14470), slot 1, auto-mount when very close.
   Turtle: spawned via shell, slot 3, water-only navigation.
   Swan: spawned in extent 0, slot 3, needs lasso, flies anywhere. *)

FROM Actor IMPORT actors, actorCount,
                  TypeRaft, TypeCarrier,
                  StStill, StWalking;
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
    (* Not riding — check proximity for mount *)
    CheckProximity(CarrierSlot);
    IF raftProx = 2 THEN
      riding := RideTurtle;
      actors[CarrierSlot].absX := actors[0].absX;
      actors[CarrierSlot].absY := actors[0].absY
    END
  END
END UpdateTurtleCarrier;

(* Update swan carrier *)
PROCEDURE UpdateSwanCarrier;
BEGIN
  IF activeCarrier # 11 THEN RETURN END;

  IF riding = RideSwan THEN
    (* Riding swan — follows player exactly *)
    actors[CarrierSlot].absX := actors[0].absX;
    actors[CarrierSlot].absY := actors[0].absY;

    (* Dismount: player nearly stopped + has clear space *)
    (* For now, dismount when player presses a key or stops *)
    (* TODO: proper dismount with space check *)
  ELSE
    (* Not riding — check if player near swan with lasso *)
    IF HasStuff(StLasso) THEN
      CheckProximity(CarrierSlot);
      IF raftProx >= 1 THEN
        riding := RideSwan;
        actors[CarrierSlot].absX := actors[0].absX;
        actors[CarrierSlot].absY := actors[0].absY
      END
    END
  END
END UpdateSwanCarrier;

PROCEDURE SpawnTurtle;
VAR i, tx, ty, terrain: INTEGER;
BEGIN
  (* Find nearby water tile to spawn turtle — wider search *)
  FOR i := 0 TO 80 DO
    tx := actors[0].absX + (i MOD 9 - 4) * 32;
    ty := actors[0].absY + (i DIV 9 - 4) * 32;
    terrain := GetTerrainAt(tx, ty);
    IF (terrain = 4) OR (terrain = 5) THEN
      (* Found water — spawn turtle here *)
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
      WriteInt(tx, 1); WriteString(","); WriteInt(ty, 1);
      WriteString(" slot="); WriteInt(CarrierSlot, 1);
      WriteString(" actorCount="); WriteInt(actorCount, 1); WriteLn;
      RETURN
    END
  END;
  (* No water found — spawn right next to player *)
  actors[CarrierSlot].absX := actors[0].absX + 20;
  actors[CarrierSlot].absY := actors[0].absY;
  actors[CarrierSlot].actorType := TypeCarrier;
  actors[CarrierSlot].state := StStill;
  actors[CarrierSlot].vitality := 50;
  actors[CarrierSlot].weapon := 0;
  actors[CarrierSlot].environ := 0;
  actors[CarrierSlot].visible := TRUE;
  actors[CarrierSlot].race := 5;
  activeCarrier := 5;
  IF actorCount < 4 THEN actorCount := 4 END;
  WriteString("Carrier: turtle spawned (no water)"); WriteLn
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
  END;

  (* Prevent sinking while riding *)
  IF riding # RideNone THEN
    actors[0].environ := 0
  END
END UpdateCarriers;

END Carrier.
