MODULE Main;

FROM InOut IMPORT WriteString, WriteLn;
FROM Platform IMPORT Init, Shutdown, BeginFrame, EndFrame,
                    GetTicks, DelayMs, ren;
FROM GameState IMPORT InitGame, UpdateGame, running, FrameTime,
                      mapToggled;
FROM Render IMPORT InitOverlay, DrawWorld, DrawItems, DrawActors,
                   DrawHUD, DrawCompass, DrawMenu, DrawRegionFade,
                   DrawMessage;
FROM DebugMap IMPORT InitDebugMap, ToggleDebugMap, UpdateDebugMap;
FROM Menu IMPORT InitMenus;
FROM BmFont IMPORT LoadFont;
FROM Compass IMPORT InitCompass;

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
  InitDebugMap;

  WHILE running DO
    frameStart := GetTicks();

    UpdateGame;

    IF mapToggled THEN ToggleDebugMap END;

    BeginFrame;
    DrawWorld;
    DrawItems;
    DrawActors;
    DrawRegionFade;
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

  Shutdown
END Main.
