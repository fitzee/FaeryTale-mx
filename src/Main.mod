MODULE Main;

FROM InOut IMPORT WriteString, WriteLn;
FROM Platform IMPORT Init, Shutdown, BeginFrame, EndFrame,
                    GetTicks, DelayMs, ren;
FROM GameState IMPORT InitGame, UpdateGame, running, FrameTime,
                      mapToggled;
FROM Render IMPORT InitOverlay, DrawWorld, DrawItems, DrawActors,
                   DrawHUD, DrawCompass, DrawMenu, DrawMessage;
FROM DebugMap IMPORT InitDebugMap, ToggleDebugMap, UpdateDebugMap;
FROM Menu IMPORT InitMenus;
FROM BmFont IMPORT LoadFont;
FROM Compass IMPORT InitCompass;
FROM Music IMPORT InitMusic, UpdateMusic, ShutdownMusic;
FROM WorldObj IMPORT InitWorldObjects, LoadObjectSprites, DrawWorldObjects;

VAR
  frameStart, elapsed: INTEGER;

BEGIN
  WriteString("Faery Tale Adventure - Modula-2 reimplementation"); WriteLn;
  WriteString("  WASD/Arrows=move  Space=attack  M=debug map"); WriteLn;

  IF NOT Init() THEN
    WriteString("Failed to initialize platform"); WriteLn;
    HALT
  END;

  IF NOT LoadFont(ren, "assets/topaz_12.bmp") THEN
    WriteString("Warning: font load failed"); WriteLn
  END;
  InitMenus;
  InitCompass(ren);
  InitOverlay;
  InitGame;
  InitWorldObjects;
  LoadObjectSprites;
  IF NOT InitMusic() THEN
    WriteString("Warning: music init failed"); WriteLn
  END;
  InitDebugMap;

  WHILE running DO
    frameStart := GetTicks();

    UpdateGame;
    UpdateMusic;

    IF mapToggled THEN ToggleDebugMap END;

    BeginFrame;
    DrawWorld;
    DrawWorldObjects;
    DrawItems;
    DrawActors;
    DrawHUD;
    DrawCompass;
    DrawMenu;
    DrawMessage;
    EndFrame;

    UpdateDebugMap;

    elapsed := GetTicks() - frameStart;
    IF elapsed < FrameTime THEN
      DelayMs(FrameTime - elapsed)
    END
  END;

  ShutdownMusic;
  Shutdown
END Main.
