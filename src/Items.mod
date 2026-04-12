IMPLEMENTATION MODULE Items;

FROM Actor IMPORT actors, StDead;

PROCEDURE InitItems;
VAR i: INTEGER;
BEGIN
  itemCount := 0;
  FOR i := 0 TO MaxItems - 1 DO
    items[i].active := FALSE;
    items[i].x := 0;
    items[i].y := 0;
    items[i].itemId := ItemNone
  END;
  FOR i := 0 TO MaxInv - 1 DO
    inventory[i] := 0
  END;

  (* Scatter some items around the world *)
  SpawnItem(28 * 16, 28 * 16, ItemGold);
  SpawnItem(33 * 16, 28 * 16, ItemGold);
  SpawnItem(30 * 16, 34 * 16, ItemFood);
  SpawnItem(24 * 16, 24 * 16, ItemPotion);
  SpawnItem(38 * 16, 24 * 16, ItemSword);
  SpawnItem(42 * 16, 10 * 16, ItemGem);
  SpawnItem(10 * 16, 9 * 16, ItemKey);
  SpawnItem(51 * 16, 50 * 16, ItemScroll);
  SpawnItem(7 * 16, 45 * 16, ItemShield);
  SpawnItem(30 * 16, 15 * 16, ItemFood);
  SpawnItem(45 * 16, 30 * 16, ItemGold);
  SpawnItem(25 * 16, 40 * 16, ItemPotion)
END InitItems;

PROCEDURE SpawnItem(wx, wy, id: INTEGER);
BEGIN
  IF itemCount >= MaxItems THEN RETURN END;
  items[itemCount].x := wx;
  items[itemCount].y := wy;
  items[itemCount].itemId := id;
  items[itemCount].active := TRUE;
  INC(itemCount)
END SpawnItem;

PROCEDURE CheckPickup(playerX, playerY: INTEGER): INTEGER;
VAR i, dx, dy: INTEGER;
BEGIN
  FOR i := 0 TO itemCount - 1 DO
    IF items[i].active THEN
      dx := playerX - items[i].x;
      dy := playerY - items[i].y;
      IF (dx < 12) AND (dx > -12) AND (dy < 12) AND (dy > -12) THEN
        items[i].active := FALSE;
        AddToInventory(items[i].itemId);
        RETURN items[i].itemId
      END
    END
  END;
  RETURN ItemNone
END CheckPickup;

PROCEDURE AddToInventory(id: INTEGER);
BEGIN
  IF (id > 0) AND (id < MaxInv) THEN
    INC(inventory[id])
  END
END AddToInventory;

PROCEDURE UseItem(id: INTEGER): BOOLEAN;
BEGIN
  IF (id > 0) AND (id < MaxInv) AND (inventory[id] > 0) THEN
    DEC(inventory[id]);
    RETURN TRUE
  END;
  RETURN FALSE
END UseItem;

PROCEDURE InventoryCount(id: INTEGER): INTEGER;
BEGIN
  IF (id > 0) AND (id < MaxInv) THEN
    RETURN inventory[id]
  END;
  RETURN 0
END InventoryCount;

END Items.
