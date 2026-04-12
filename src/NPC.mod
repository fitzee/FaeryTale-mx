IMPLEMENTATION MODULE NPC;

FROM Strings IMPORT Assign;
FROM Actor IMPORT actors, actorCount, StStill, GoalWait;
FROM World IMPORT TileSize;

PROCEDURE InitNPCs;
VAR idx: INTEGER;
BEGIN
  npcCount := 0;

  (* NPC 0: Old wizard in the tavern *)
  idx := actorCount;
  actors[idx].absX := 24 * TileSize;
  actors[idx].absY := 24 * TileSize;
  actors[idx].actorType := 2;
  actors[idx].state := StStill;
  actors[idx].goal := 8; (* GoalWait *)
  actors[idx].vitality := 999;
  actors[idx].race := 10;
  actors[idx].facing := 4;
  INC(actorCount);
  npcs[0].actorIdx := idx;
  npcs[0].speechIdx := 0;
  npcs[0].hasSpoken := FALSE;
  INC(npcCount);

  (* NPC 1: Ranger near the forest *)
  idx := actorCount;
  actors[idx].absX := 34 * TileSize;
  actors[idx].absY := 10 * TileSize;
  actors[idx].actorType := 2;
  actors[idx].state := StStill;
  actors[idx].goal := 8;
  actors[idx].vitality := 999;
  actors[idx].race := 12;
  actors[idx].facing := 6;
  INC(actorCount);
  npcs[1].actorIdx := idx;
  npcs[1].speechIdx := 1;
  npcs[1].hasSpoken := FALSE;
  INC(npcCount);

  (* NPC 2: King in the castle *)
  idx := actorCount;
  actors[idx].absX := 41 * TileSize;
  actors[idx].absY := 39 * TileSize;
  actors[idx].actorType := 2;
  actors[idx].state := StStill;
  actors[idx].goal := 8;
  actors[idx].vitality := 999;
  actors[idx].race := 5;
  actors[idx].facing := 4;
  INC(actorCount);
  npcs[2].actorIdx := idx;
  npcs[2].speechIdx := 2;
  npcs[2].hasSpoken := FALSE;
  INC(npcCount)
END InitNPCs;

PROCEDURE CheckNPCInteract(playerX, playerY: INTEGER): INTEGER;
VAR i, dx, dy, idx: INTEGER;
BEGIN
  FOR i := 0 TO npcCount - 1 DO
    idx := npcs[i].actorIdx;
    dx := playerX - actors[idx].absX;
    dy := playerY - actors[idx].absY;
    IF (dx < 20) AND (dx > -20) AND (dy < 16) AND (dy > -16) THEN
      (* Face the player *)
      IF dx > 5 THEN actors[idx].facing := 2
      ELSIF dx < -5 THEN actors[idx].facing := 6
      ELSIF dy > 5 THEN actors[idx].facing := 4
      ELSIF dy < -5 THEN actors[idx].facing := 0
      END;
      RETURN i
    END
  END;
  RETURN -1
END CheckNPCInteract;

PROCEDURE GetSpeech(speechIdx: INTEGER; VAR text: ARRAY OF CHAR);
BEGIN
  CASE speechIdx OF
    0: Assign("Beware the swamp! Its waters drain life.", text) |
    1: Assign("The forest hides a skeleton guardian.", text) |
    2: Assign("Brave hero! Seek the gem beyond the mountains.", text)
  ELSE
    Assign("...", text)
  END
END GetSpeech;

END NPC.
