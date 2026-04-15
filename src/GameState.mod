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
                  AddToInventory, SpawnItem,
                  ItemNone, ItemGold, ItemFood, ItemPotion,
                  ItemSword, ItemKey, ItemGem, ItemShield, ItemScroll;
FROM DayNight IMPORT InitDayNight, UpdateDayNight, brightness, isNight,
                     lightlevel, MusicTickDue;
FROM Brothers IMPORT InitBrothers, SwitchToNext, ActiveName,
                     SaveBrotherState, RestoreBrotherState, brothers,
                     activeBrother;
FROM NPC IMPORT InitNPCs, MaterializeNPCs, TalkToNPC, LookAtNPC;
FROM Assets IMPORT InitAssets, PreloadAll, LoadHUD, currentRegion,
                   CheckRegionSwitch, SwitchRegion, DetectRegion,
                   GetTerrainAt;
FROM Menu IMPORT HandleMenuKey, SetOptions, cmode, menus, realOptions,
                 optionCount, MItems, MGame, GoMenu,
                 PanelX, PanelY, BtnW, BtnH;
FROM Music IMPORT SetMood, StopMusic, MoodDay, MoodNight, MoodIndoor,
                  MoodBattle;
FROM Platform IMPORT PlayH, Scale, ScreenW;
FROM Doors IMPORT InitDoors, CheckDoor;
FROM WorldObj IMPORT CheckObjectPickup, objects, objCount;
FROM HudLog IMPORT AddLogLine, SetStats, InitHudLog;
FROM Encounter IMPORT InitEncounters, UpdateEncounters, EnemiesNearby;
FROM Combat IMPORT SearchBody;
FROM Missile IMPORT InitMissiles, UpdateMissiles, FireMissile;
FROM Narration IMPORT InitPlace, UpdatePlace, Event;

VAR
  input: InputState;
  potionCooldown: INTEGER;
  hungerTimer: INTEGER;
  prevRegion: INTEGER;
  deathTimer: INTEGER;
  doorCooldown: INTEGER;
  battleFlag: BOOLEAN;
  prevBattle: BOOLEAN;
  nameBuf: ARRAY [0..31] OF CHAR;
  msgBuf: ARRAY [0..63] OF CHAR;

PROCEDURE InitGame;
BEGIN
  running := TRUE;
  cycle := 0;
  dayNight := 6000;  (* midday — full bright, matching DayNight.InitDayNight *)
  msgTimer := 0;
  msgText[0] := 0C;
  potionCooldown := 0;
  hungerTimer := 0;
  deathTimer := 0;
  doorCooldown := 0;
  battleFlag := FALSE;
  prevBattle := FALSE;
  viewStatus := 0;

  InitWorld;
  InitAll;
  InitItems;
  InitDayNight;
  InitBrothers;
  InitDoors;
  InitHudLog;
  InitNPCs;
  InitEncounters;
  InitMissiles;

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
    InitPlace(actors[0].absX, actors[0].absY, 3);
    Event(9);   (* "Julian started the journey in his home village of Tambry" *)
    Event(30)   (* "It was midday." *)
  ELSE
    ShowMessage("Welcome! (placeholder mode)")
  END
END InitGame;

PROCEDURE ShowMessage(msg: ARRAY OF CHAR);
VAR buf: ARRAY [0..79] OF CHAR;
    si, di, ni: INTEGER;
    name: ARRAY [0..15] OF CHAR;
BEGIN
  (* Expand '%' to current brother name *)
  ActiveName(name);
  si := 0; di := 0;
  WHILE (si <= HIGH(msg)) AND (msg[si] # 0C) AND (di < 79) DO
    IF msg[si] = '%' THEN
      ni := 0;
      WHILE (ni <= HIGH(name)) AND (name[ni] # 0C) AND (di < 79) DO
        buf[di] := name[ni];
        INC(di); INC(ni)
      END;
      INC(si)
    ELSE
      buf[di] := msg[si];
      INC(di); INC(si)
    END
  END;
  buf[di] := 0C;
  Assign(buf, msgText);
  msgTimer := 180;
  AddLogLine(buf)
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

PROCEDURE ShowInventory;
BEGIN
  viewStatus := 4
END ShowInventory;

PROCEDURE HandleLook;
VAR i, dx, dy, found: INTEGER;
BEGIN
  (* Original: search for hidden objects (status=0 or status=5) within
     distance 40 and reveal them (set status=1 = visible/pickupable).
     status=5 = "look-only" items hidden in fireplaces, cabinets etc. *)
  found := 0;
  FOR i := 0 TO objCount - 1 DO
    IF ((objects[i].status = 0) OR (objects[i].status = 5)) AND
       ((objects[i].region = currentRegion) OR
        (objects[i].region = -1)) THEN
      dx := actors[0].absX - objects[i].x;
      dy := actors[0].absY - objects[i].y;
      IF (dx > -40) AND (dx < 40) AND (dy > -40) AND (dy < 40) THEN
        objects[i].status := 1;
        found := 1
      END
    END
  END;
  IF found > 0 THEN
    Event(38)  (* "% discovered a hidden object." *)
  ELSE
    (* No hidden objects — describe nearest NPC if any *)
    IF LookAtNPC(actors[0].absX, actors[0].absY, nameBuf) THEN
      Assign("% sees ", msgBuf);
      Concat(msgBuf, nameBuf, msgBuf);
      Concat(msgBuf, ".", msgBuf);
      ShowMessage(msgBuf)
    ELSE
      Event(20)  (* "% looked around but discovered nothing." *)
    END
  END
END HandleLook;

PROCEDURE TogglePause;
BEGIN
  (* Toggle bit 0 of menus[GAME].enabled[5], matching original XOR toggle *)
  IF BAND(CARDINAL(menus[MGame].enabled[5]), 1) = 0 THEN
    menus[MGame].enabled[5] := BOR(INTEGER(CARDINAL(menus[MGame].enabled[5])), 1);
    ShowMessage("Game paused.")
  ELSE
    menus[MGame].enabled[5] := BAND(CARDINAL(menus[MGame].enabled[5]), 14);
    ShowMessage("Game resumed.")
  END
END TogglePause;

PROCEDURE ToggleMusic;
BEGIN
  (* Toggle bit 0 of menus[GAME].enabled[6], then setmood *)
  IF BAND(CARDINAL(menus[MGame].enabled[6]), 1) = 0 THEN
    menus[MGame].enabled[6] := BOR(INTEGER(CARDINAL(menus[MGame].enabled[6])), 1);
    SetMood(MoodDay)
  ELSE
    menus[MGame].enabled[6] := BAND(CARDINAL(menus[MGame].enabled[6]), 14);
    StopMusic
  END
END ToggleMusic;

PROCEDURE HandleMenuClick(mx, my: INTEGER);
CONST
  (* Original propt() layout in 640x57 HUD space:
     Col0=430, Col1=482, each 48px wide (6*8), row = (j/2)*9 + 8. *)
  HudW = 640;
VAR hx, hy, col, row, itemIdx, optIdx: INTEGER;
BEGIN
  (* Convert screen mouse coords to 640x57 HUD space *)
  hx := mx * HudW DIV (ScreenW * Scale);
  hy := (my - PlayH * Scale) DIV Scale;

  (* Check if click is in menu panel *)
  IF hy < PanelY THEN RETURN END;
  IF hx < PanelX THEN RETURN END;
  IF hx >= PanelX + BtnW * 2 THEN RETURN END;

  (* Determine column and row relative to panel *)
  col := (hx - PanelX) DIV BtnW;
  row := (hy - PanelY) DIV BtnH;
  IF row < 0 THEN RETURN END;
  IF row > 5 THEN RETURN END;

  (* Map to menu item index *)
  itemIdx := row * 2 + col;
  IF itemIdx >= optionCount THEN RETURN END;

  optIdx := realOptions[itemIdx];
  IF optIdx < 0 THEN RETURN END;

  (* Tab items (0-4) switch menu mode *)
  IF optIdx < 5 THEN
    GoMenu(optIdx);
    RETURN
  END;

  (* Sub-items: execute the action based on current menu mode *)
  CASE cmode OF
    0: (* Items menu *)
      CASE optIdx OF
        5: ShowInventory |               (* List *)
        6: HandleWorldPickup |           (* Take *)
        7: HandleLook |                  (* Look *)
        8: GoMenu(8) |                   (* Use → USE menu *)
        9: GoMenu(7)                     (* Give → GIVE menu *)
      ELSE
      END |
    2: (* Talk menu *)
      CASE optIdx OF
        5: ShowMessage("You yell loudly!") |   (* Yell *)
        6: HandleTalk |                         (* Say *)
        7: ShowMessage("You ask around...")     (* Ask *)
      ELSE
      END |
    4: (* Game menu *)
      CASE optIdx OF
        5: TogglePause |     (* Pause *)
        6: ToggleMusic |     (* Music *)
        7: (* Sound toggle — not yet *) |
        8: running := FALSE | (* Quit *)
        9: ShowMessage("Load not implemented")  (* Load *)
      ELSE
      END |
    8: (* Use menu — weapon equipping.
          Original: hit < 5 → weapon = hit+1 if owned *)
      IF optIdx < 10 THEN
        (* optIdx 5-9 maps to USE menu items 0-4 = weapon codes 1-5 *)
        IF (optIdx >= 5) AND (optIdx <= 9) THEN
          IF brothers[activeBrother].weaponInv[optIdx - 4] > 0 THEN
            actors[0].weapon := optIdx - 4;
            WeaponName(optIdx - 4, nameBuf);
            Assign("Equipped ", msgBuf);
            Concat(msgBuf, nameBuf, msgBuf);
            Concat(msgBuf, ".", msgBuf);
            ShowMessage(msgBuf)
          ELSE
            ShowMessage("You don't have one.")
          END;
          GoMenu(0)  (* return to Items menu *)
        END
      END
  ELSE
  END
END HandleMenuClick;

PROCEDURE WeaponName(w: INTEGER; VAR name: ARRAY OF CHAR);
BEGIN
  CASE w OF
    1: Assign("a dagger", name) |
    2: Assign("a mace", name) |
    3: Assign("a sword", name) |
    4: Assign("a bow", name) |
    5: Assign("a wand", name)
  ELSE
    Assign("a weapon", name)
  END
END WeaponName;

PROCEDURE SearchNearbyCorpses;
VAR i, dx, dy, w: INTEGER;
    wname: ARRAY [0..15] OF CHAR;
BEGIN
  FOR i := 1 TO actorCount - 1 DO
    IF actors[i].state = StDead THEN
      dx := actors[0].absX - actors[i].absX;
      dy := actors[0].absY - actors[i].absY;
      IF dx < 0 THEN dx := -dx END;
      IF dy < 0 THEN dy := -dy END;
      IF (dx < 20) AND (dy < 20) THEN
        w := SearchBody(i);
        IF w > 0 THEN
          IF (w >= 1) AND (w <= 5) THEN
            INC(brothers[activeBrother].weaponInv[w]);
            WeaponName(w, wname);
            Assign("Found ", msgBuf);
            Concat(msgBuf, wname, msgBuf);
            Concat(msgBuf, "!", msgBuf);
            ShowMessage(msgBuf);
            IF w > actors[0].weapon THEN
              actors[0].weapon := w;
              Assign("Equipped ", msgBuf);
              Concat(msgBuf, wname, msgBuf);
              Concat(msgBuf, ".", msgBuf);
              ShowMessage(msgBuf)
            END
          END;
          SetOptions;
          RETURN
        ELSE
          ShowMessage("The body was empty.")
        END;
        RETURN
      END
    END
  END;
  ShowMessage("Nothing to take.")
END SearchNearbyCorpses;

PROCEDURE ContainerLoot;
(* Original: rand4() for 0-3 items from containers.
   Matching original container interaction. *)
VAR roll, item: INTEGER;
BEGIN
  roll := (cycle * 1103515245 + 12345) DIV 65536;
  IF roll < 0 THEN roll := -roll END;
  roll := roll MOD 4;
  IF roll = 0 THEN
    ShowMessage("It was empty.")
  ELSE
    (* Give gold + random item *)
    AddToInventory(ItemGold);
    ShowMessage("Found some gold!");
    IF roll >= 2 THEN
      AddToInventory(ItemFood);
      ShowMessage("Found some food!")
    END;
    IF roll >= 3 THEN
      item := (cycle MOD 4) + 3;  (* key, sword, shield, or potion *)
      AddToInventory(item);
      CASE item OF
        3: ShowMessage("Found a key!") |
        4: ShowMessage("Found a sword!") |
        5: ShowMessage("Found a shield!") |
        6: ShowMessage("Found a potion!")
      ELSE
        ShowMessage("Found something!")
      END
    END
  END
END ContainerLoot;

PROCEDURE HandleWorldPickup;
VAR id: INTEGER;
BEGIN
  id := CheckObjectPickup(actors[0].absX, actors[0].absY);
  IF id >= 0 THEN
    CASE id OF
      13:
        ShowMessage("Found 50 gold pieces!");
        AddToInventory(ItemGold);
        AddToInventory(ItemGold) |
      14: (* urn — container *)
        ShowMessage("Opened a brass urn.");
        ContainerLoot |
      15: (* chest — container *)
        ShowMessage("Opened a chest.");
        ContainerLoot |
      16: (* sacks — container *)
        ShowMessage("Opened some sacks.");
        ContainerLoot |
      17: ShowMessage("Found a gold ring!");
          AddToInventory(ItemShield) |     (* reuse Shield slot for ring *)
      18: ShowMessage("Found a blue stone!");
          AddToInventory(ItemGem) |
      19: ShowMessage("Found a gold jewel!");
          AddToInventory(ItemGem) |
      20: ShowMessage("Found a scrap of paper!");
          AddToInventory(ItemScroll) |
      22: ShowMessage("Found a vial!");
          AddToInventory(ItemPotion) |
      23: ShowMessage("Found a totem!");
          AddToInventory(ItemScroll) |
      24: ShowMessage("Found a skull!");
          AddToInventory(ItemScroll) |
      25: ShowMessage("Found a gold key!");
          AddToInventory(ItemKey) |
      26: ShowMessage("Found a grey key!");
          AddToInventory(ItemKey) |
     102: ShowMessage("Found a turtle!") |
     114: ShowMessage("Found a blue key!");
          AddToInventory(ItemKey) |
     145: ShowMessage("Found a magic wand!");
          brothers[activeBrother].weaponInv[5] := 1 |
     148: ShowMessage("Found some fruit!");
          AddToInventory(ItemFood) |
     149: ShowMessage("Found a gold statue!");
          AddToInventory(ItemGold);
          AddToInventory(ItemGold);
          AddToInventory(ItemGold) |
     151: ShowMessage("Found a shell!");
          AddToInventory(ItemShield) |
     153: ShowMessage("Found a green key!");
          AddToInventory(ItemKey) |
     154: ShowMessage("Found a white key!");
          AddToInventory(ItemKey) |
     242: ShowMessage("Found a red key!");
          AddToInventory(ItemKey)
    ELSE
      ShowMessage("Found something!")
    END;
    SetOptions
  ELSE
    (* No world object found — try searching dead enemy corpses *)
    SearchNearbyCorpses
  END
END HandleWorldPickup;

PROCEDURE HandleTalk;
VAR speech: ARRAY [0..127] OF CHAR;
BEGIN
  IF TalkToNPC(actors[0].absX, actors[0].absY, speech) THEN
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
    (* Ranged weapons (bow=4, wand=5) fire projectiles *)
    IF (actors[0].weapon >= 4) AND (actors[0].state # StShoot1) THEN
      actors[0].state := StShoot1;
      FireMissile(0);
      actors[0].velX := 0;
      actors[0].velY := 0
    ELSIF actors[0].weapon >= 4 THEN
      (* Already shooting — hold state *)
      actors[0].velX := 0;
      actors[0].velY := 0
    ELSE
      (* Melee weapons *)
      actors[0].state := StFighting;
      actors[0].velX := 0;
      actors[0].velY := 0
    END
  ELSIF (actors[0].state = StFighting) OR (actors[0].state = StShoot1) THEN
    actors[0].state := StStill;
    actors[0].velX := 0;
    actors[0].velY := 0
  ELSIF input.dirKey # DirNone THEN
    actors[0].facing := input.dirKey;
    IF MoveActor(0, input.dirKey, 1) THEN
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
  (* Only check outdoor doors when near a door tile (terrain 15).
     Check hero position and adjacent points to catch nearby doors. *)
  IF currentRegion < 8 THEN
    IF (GetTerrainAt(actors[0].absX, actors[0].absY) # 15) AND
       (GetTerrainAt(actors[0].absX + 4, actors[0].absY) # 15) AND
       (GetTerrainAt(actors[0].absX - 4, actors[0].absY) # 15) AND
       (GetTerrainAt(actors[0].absX, actors[0].absY + 4) # 15) AND
       (GetTerrainAt(actors[0].absX, actors[0].absY - 4) # 15) THEN
      RETURN
    END
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
    doorCooldown := 60  (* ~1 second cooldown *)
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

  (* Inventory display: any key/click dismisses *)
  IF viewStatus = 4 THEN
    IF input.quit THEN running := FALSE; RETURN END;
    IF input.attack OR (input.menuKey # 0C) OR
       input.mouseClick OR (input.dirKey # DirNone) THEN
      viewStatus := 0
    END;
    RETURN
  END;

  mapToggled := input.toggleMap;
  IF input.menuKey # 0C THEN
    HandleMenuKey(input.menuKey)
  END;
  IF input.mouseClick THEN
    HandleMenuClick(input.mouseX, input.mouseY)
  END;
  IF input.quit THEN running := FALSE; RETURN END;

  (* Pause: original checks menus[GAME].enabled[5] & 1, skips all updates *)
  IF BAND(CARDINAL(menus[MGame].enabled[5]), 1) # 0 THEN
    IF msgTimer > 0 THEN DEC(msgTimer) END;
    RETURN
  END;

  UpdatePlayer;
  CheckEnvironment;
  UpdateEnemies;
  UpdateCombat;
  UpdateEncounters(actors[0].absX, actors[0].absY, currentRegion);
  UpdateMissiles;
  (* Check for door entry/exit *)
  CheckDoors;

  UpdateCamera(actors[0].absX, actors[0].absY);
  (* Region switch with fade *)
  prevRegion := currentRegion;
  (* Original uses camera position (map_x/map_y) for region detection *)
  CheckRegionSwitch(camX, camY);

  (* Place narration — sector-triggered arrival messages *)
  UpdatePlace(actors[0].absX, actors[0].absY, currentRegion);
  MaterializeNPCs(actors[0].absX, actors[0].absY, currentRegion);

  UpdateDayNight;

  (* Battle flag: set per-frame when living enemies nearby.
     battle2 holds previous tick's value — music persists one cycle.
     Original: battleflag set in AI loop, battle2 = previous frame,
     music only switches when both are FALSE. *)
  battleFlag := EnemiesNearby(actors[0].absX, actors[0].absY);
  IF MusicTickDue() THEN
    IF battleFlag OR prevBattle THEN
      SetMood(MoodBattle)
    ELSIF currentRegion >= 8 THEN
      SetMood(MoodIndoor)
    ELSIF lightlevel > 120 THEN
      SetMood(MoodDay)
    ELSE
      SetMood(MoodNight)
    END;
    prevBattle := battleFlag
  END;

  IF currentRegion >= 8 THEN
    (* Interiors are always fully lit *)
    brightness := 100;
    isNight := FALSE
  END;
  SaveBrotherState;

  (* Update HUD stats from brother data *)
  SetStats(brothers[activeBrother].brave,
           brothers[activeBrother].luck,
           brothers[activeBrother].kind,
           InventoryCount(ItemGold),
           actors[0].vitality);

  IF msgTimer > 0 THEN DEC(msgTimer) END;

  INC(cycle);
  INC(dayNight)
END UpdateGame;

END GameState.
