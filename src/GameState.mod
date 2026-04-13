IMPLEMENTATION MODULE GameState;

FROM Strings IMPORT Assign, Concat;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;
FROM Platform IMPORT PollInput, InputState, DirNone,
                    ScreenW, TextH, Scale;
FROM Actor IMPORT actors, actorCount, InitAll,
                  StWalking, StStill, StFighting, StDead, StDying,
                  GoalAttack1, GoalStand;
FROM World IMPORT InitWorld, TileSize, WorldW, WorldH, UpdateCamera,
                  GetTerrain, TerrSwamp, TerrWater, camX, camY;
FROM Movement IMPORT MoveActor;
FROM EnemyAI IMPORT UpdateEnemies;
FROM Combat IMPORT UpdateCombat;
FROM Items IMPORT InitItems, CheckPickup, UseItem, InventoryCount,
                  SpawnItem,
                  ItemNone, ItemGold, ItemFood, ItemPotion,
                  ItemSword, ItemKey, ItemGem, ItemShield, ItemScroll;
FROM DayNight IMPORT InitDayNight, UpdateDayNight, brightness, isNight;
FROM Brothers IMPORT InitBrothers, SwitchToNext, ActiveName,
                     SaveBrotherState, RestoreBrotherState, brothers,
                     activeBrother;
FROM NPC IMPORT InitNPCs, CheckNPCInteract, GetSpeech;
FROM Assets IMPORT InitAssets, PreloadAll, LoadHUD, currentRegion,
                   CheckRegionSwitch, SwitchRegion, DetectRegion;
FROM Menu IMPORT HandleMenuKey, SetOptions;
FROM Doors IMPORT InitDoors, CheckDoor;

VAR
  input: InputState;
  potionCooldown: INTEGER;
  hungerTimer: INTEGER;
  prevRegion: INTEGER;
  deathTimer: INTEGER;
  doorCooldown: INTEGER;
  nameBuf: ARRAY [0..31] OF CHAR;
  msgBuf: ARRAY [0..63] OF CHAR;

PROCEDURE InitGame;
BEGIN
  running := TRUE;
  cycle := 0;
  dayNight := 0;
  msgTimer := 0;
  msgText[0] := 0C;
  potionCooldown := 0;
  hungerTimer := 0;
  deathTimer := 0;
  doorCooldown := 0;

  InitWorld;
  InitAll;
  InitItems;
  InitDayNight;
  InitBrothers;
  InitDoors;

  (* Place player from active brother data *)
  RestoreBrotherState;

  actorCount := 1; (* just the player for now *);

  (* Preload all game assets at startup — no loading during gameplay *)
  InitAssets;
  IF PreloadAll() THEN
    IF NOT LoadHUD(ScreenW * Scale, TextH * Scale) THEN
      WriteString("*** HUD LOAD FAILED ***"); WriteLn
    END;
    (* Start at Tambry village — original starting position *)
    SwitchRegion(3);
    actors[0].absX := 19036;
    actors[0].absY := 15755;
    ShowMessage("Welcome to the Faery Tale!")
  ELSE
    ShowMessage("Welcome! (placeholder mode)")
  END
END InitGame;

PROCEDURE ShowMessage(msg: ARRAY OF CHAR);
BEGIN
  Assign(msg, msgText);
  msgTimer := 180
END ShowMessage;

PROCEDURE HandlePickup;
VAR picked: INTEGER;
BEGIN
  picked := CheckPickup(actors[0].absX, actors[0].absY);
  IF picked # ItemNone THEN
    CASE picked OF
      ItemGold:   ShowMessage("Found gold!") |
      ItemFood:   ShowMessage("Found food!") |
      ItemKey:    ShowMessage("Found a key!") |
      ItemSword:
        ShowMessage("Found a sword!");
        actors[0].weapon := 3 |
      ItemShield: ShowMessage("Found a shield!") |
      ItemPotion: ShowMessage("Found a potion!") |
      ItemGem:    ShowMessage("Found a gem!") |
      ItemScroll: ShowMessage("Found a scroll!")
    ELSE
      ShowMessage("Found something!")
    END;
    SetOptions
  END
END HandlePickup;

PROCEDURE HandleTalk;
VAR npcIdx: INTEGER;
    speech: ARRAY [0..63] OF CHAR;
BEGIN
  npcIdx := CheckNPCInteract(actors[0].absX, actors[0].absY);
  IF npcIdx >= 0 THEN
    GetSpeech(npcIdx, speech);
    ShowMessage(speech)
  ELSE
    ShowMessage("Nobody to talk to here.")
  END
END HandleTalk;

PROCEDURE CheckEnvironment;
VAR terrain: INTEGER;
BEGIN
  IF currentRegion >= 0 THEN RETURN END; (* skip for asset-based world *)
  terrain := GetTerrain(actors[0].absX, actors[0].absY);

  (* Swamp damage like original fiery_death zones *)
  IF terrain = TerrSwamp THEN
    IF (cycle MOD 30) = 0 THEN
      DEC(actors[0].vitality, 1);
      IF actors[0].vitality <= 0 THEN
        actors[0].state := StDying;
        ShowMessage("The swamp claims you...")
      ELSIF (cycle MOD 90) = 0 THEN
        ShowMessage("The swamp drains your strength...")
      END
    END
  END
END CheckEnvironment;

PROCEDURE CheckEnemyDrops;
VAR i: INTEGER;
BEGIN
  (* When enemies die, sometimes drop loot *)
  FOR i := 1 TO actorCount - 1 DO
    IF actors[i].state = StDying THEN
      (* Drop gold on death *)
      SpawnItem(actors[i].absX, actors[i].absY, ItemGold);
      (* Some enemies drop extra loot *)
      IF actors[i].race = 0 THEN
        SpawnItem(actors[i].absX + 8, actors[i].absY, ItemFood)
      ELSIF actors[i].race = 2 THEN
        SpawnItem(actors[i].absX - 8, actors[i].absY, ItemPotion)
      END
    END
  END
END CheckEnemyDrops;

PROCEDURE UpdatePlayer;
BEGIN
  IF input.quit THEN
    running := FALSE;
    RETURN
  END;

  IF actors[0].state = StDead THEN
    IF deathTimer = 0 THEN
      ActiveName(nameBuf);
      Assign(nameBuf, msgBuf);
      Concat(msgBuf, " has fallen!", msgBuf);
      ShowMessage(msgBuf);
      deathTimer := 120
    ELSIF deathTimer = 1 THEN
      IF SwitchToNext() THEN
        ActiveName(nameBuf);
        Assign(nameBuf, msgBuf);
        Concat(msgBuf, " takes up the quest!", msgBuf);
        ShowMessage(msgBuf);
        deathTimer := 0
      ELSE
        ShowMessage("All brothers have fallen... Game Over.");
        deathTimer := -1
      END
    END;
    IF deathTimer > 0 THEN DEC(deathTimer) END;
    RETURN
  END;

  IF potionCooldown > 0 THEN DEC(potionCooldown) END;

  (* Use potion with P key *)
  IF input.usePotion AND (potionCooldown = 0) THEN
    IF UseItem(ItemPotion) THEN
      INC(actors[0].vitality, 30);
      IF actors[0].vitality > 100 THEN actors[0].vitality := 100 END;
      ShowMessage("Potion restores your health!");
      potionCooldown := 30
    ELSE
      ShowMessage("No potions!");
      potionCooldown := 30
    END
  END;

  (* Use food with F key *)
  IF input.useFood AND (potionCooldown = 0) THEN
    IF UseItem(ItemFood) THEN
      INC(actors[0].vitality, 10);
      IF actors[0].vitality > 100 THEN actors[0].vitality := 100 END;
      ShowMessage("You eat some food.");
      potionCooldown := 30
    ELSE
      ShowMessage("No food!");
      potionCooldown := 30
    END
  END;

  (* Talk to NPCs *)
  IF input.talk AND (potionCooldown = 0) THEN
    HandleTalk;
    potionCooldown := 30
  END;

  IF input.attack THEN
    actors[0].state := StFighting
  ELSIF input.dirKey # DirNone THEN
    actors[0].facing := input.dirKey;
    IF MoveActor(0, input.dirKey, 2) THEN
      actors[0].state := StWalking
    ELSE
      actors[0].state := StStill
    END
  ELSE
    actors[0].state := StStill;
    actors[0].velX := 0;
    actors[0].velY := 0
  END
END UpdatePlayer;

PROCEDURE CheckDoors;
VAR newX, newY, newReg: INTEGER;
BEGIN
  IF doorCooldown > 0 THEN
    DEC(doorCooldown);
    RETURN
  END;
  IF CheckDoor(actors[0].absX, actors[0].absY, currentRegion,
               newX, newY, newReg) THEN
    actors[0].absX := newX;
    actors[0].absY := newY;
    IF newReg >= 0 THEN
      SwitchRegion(newReg)
    ELSE
      (* Exiting indoor — force detect outdoor region *)
      SwitchRegion(DetectRegion(newX, newY))
    END;
    doorCooldown := 60;  (* ~1 second cooldown *)
    ShowMessage("You enter...")
  END
END CheckDoors;

PROCEDURE UpdateGame;
BEGIN
  input.quit := FALSE;
  input.dirKey := DirNone;
  input.attack := FALSE;
  input.usePotion := FALSE;
  input.useFood := FALSE;
  input.talk := FALSE;
  input.toggleMap := FALSE;

  PollInput(input);
  mapToggled := input.toggleMap;
  IF input.menuKey # 0C THEN
    HandleMenuKey(input.menuKey)
  END;
  UpdatePlayer;
  HandlePickup;
  CheckEnvironment;
  CheckEnemyDrops;
  UpdateEnemies;
  UpdateCombat;
  (* Check for door entry/exit *)
  CheckDoors;

  UpdateCamera(actors[0].absX, actors[0].absY);
  (* Region switch with fade *)
  prevRegion := currentRegion;
  (* Original uses camera position (map_x/map_y) for region detection *)
  CheckRegionSwitch(camX, camY);
  UpdateDayNight;
  IF currentRegion >= 8 THEN
    (* Interiors are always fully lit *)
    brightness := 100;
    isNight := FALSE
  END;
  SaveBrotherState;

  IF msgTimer > 0 THEN DEC(msgTimer) END;

  INC(cycle);
  INC(dayNight)
END UpdateGame;

END GameState.
