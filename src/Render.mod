IMPLEMENTATION MODULE Render;

FROM Platform IMPORT ren, ScreenW, ScreenH, PlayW, PlayH, Scale,
                    DrawTexRegion;
FROM Texture IMPORT Draw AS TexDraw, DrawRegion AS TexDrawRegion,
                    Width AS TexWidth, Height AS TexHeight;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;
FROM Canvas IMPORT SetColor, FillRect, DrawRect, SetClip, ClearClip;
FROM World IMPORT tiles, WorldW, WorldH, TileSize, camX, camY,
                  TerrGrass, TerrWater, TerrForest,
                  TerrMountain, TerrPath, TerrWall, TerrDoor,
                  TerrSand, TerrSwamp, TerrBridge, TerrFloor;
FROM Actor IMPORT actors, actorCount, StDead, StDying, StStill,
                  StWalking, StFighting;
FROM Items IMPORT items, itemCount, inventory,
                  ItemGold, ItemFood, ItemKey, ItemSword,
                  ItemShield, ItemPotion, ItemGem, ItemScroll;
FROM GameState IMPORT cycle, msgText, msgTimer, regionFade;
FROM DayNight IMPORT brightness, isNight, GetTint;
FROM Brothers IMPORT activeBrother, brothers, Julian, Philip, Kevin;
FROM Assets IMPORT tileTex, hudTex, brotherTex, shadowPB,
                   currentRegion, GetSectorByte, GetMaskType,
                   GetTilesBits, GetMapTag;
FROM PixBuf IMPORT PBuf, GetPix AS PBGetPix;
FROM Menu IMPORT cmode, menus, realOptions, optionCount, MaxOpts,
                 MItems, MMagic, MTalk, MBuy, MGame, MUse, MFile,
                 MSave, MKeys, MGive;
FROM BmFont IMPORT DrawStr, DrawStrSized, SetFontColor, GlyphW, GlyphH;

(* Tiles in PNG: 16px wide x 32px tall, 256 tiles stacked vertically.
   Sector byte: top 2 bits = image bank (0-3), bottom 6 bits = tile index.
   Tile Y in texture = tileIndex * 32. *)

CONST
  TilePixW = 16;
  TilePixH = 32;

PROCEDURE InitOverlay;
BEGIN
  (* Sprite masking uses shadow_mem PixBuf directly — no setup needed *)
END InitOverlay;

PROCEDURE S(v: INTEGER): INTEGER;
BEGIN
  RETURN v * Scale
END S;

(* ---- World drawing ---- *)

PROCEDURE DrawWorldTiled;
VAR imx, imy, sx, sy, secByte, imgIdx, tileY: INTEGER;
    startIX, startIY, endIX, endIY: INTEGER;
BEGIN
  SetClip(ren, 0, 0, S(PlayW), S(PlayH));

  startIX := camX DIV TilePixW - 1;
  startIY := camY DIV TilePixH - 1;
  endIX := (camX + PlayW) DIV TilePixW + 1;
  endIY := (camY + PlayH) DIV TilePixH + 1;
  IF startIX < 0 THEN startIX := 0 END;
  IF startIY < 0 THEN startIY := 0 END;

  FOR imy := startIY TO endIY DO
    FOR imx := startIX TO endIX DO
      secByte := GetSectorByte(imx * TilePixW, imy * TilePixH);
      imgIdx := secByte DIV 64;
      tileY := (secByte MOD 64) * TilePixH;
      sx := imx * TilePixW - camX;
      sy := imy * TilePixH - camY;

      IF (imgIdx >= 0) AND (imgIdx <= 3) AND (tileTex[imgIdx] # NIL) THEN
        DrawTexRegion(tileTex[imgIdx],
                      0, tileY, TilePixW, TilePixH,
                      S(sx), S(sy), S(TilePixW), S(TilePixH))
      END
    END
  END;

  ClearClip(ren)
END DrawWorldTiled;

PROCEDURE DrawWorldFallback;
VAR tx, ty, sx, sy, r, g, b: INTEGER;
    startTX, startTY, endTX, endTY: INTEGER;
BEGIN
  SetClip(ren, 0, 0, S(PlayW), S(PlayH));

  startTX := camX DIV TileSize;
  startTY := camY DIV TileSize;
  endTX := (camX + PlayW) DIV TileSize + 1;
  endTY := (camY + PlayH) DIV TileSize + 1;

  IF startTX < 0 THEN startTX := 0 END;
  IF startTY < 0 THEN startTY := 0 END;
  IF endTX > WorldW THEN endTX := WorldW END;
  IF endTY > WorldH THEN endTY := WorldH END;

  FOR tx := startTX TO endTX - 1 DO
    FOR ty := startTY TO endTY - 1 DO
      sx := (tx * TileSize - camX) * Scale;
      sy := (ty * TileSize - camY) * Scale;
      TerrainColor(tiles[tx][ty].terrain, r, g, b);
      SetColor(ren, r, g, b, 255);
      FillRect(ren, sx, sy, TileSize * Scale, TileSize * Scale)
    END
  END;

  ClearClip(ren)
END DrawWorldFallback;

PROCEDURE TerrainColor(terrain: INTEGER; VAR r, g, b: INTEGER);
BEGIN
  CASE terrain OF
    TerrGrass:    r := 34;  g := 139; b := 34  |
    TerrWater:    r := 30;  g := 90;  b := 200 |
    TerrForest:   r := 0;   g := 80;  b := 20  |
    TerrMountain: r := 100; g := 85;  b := 65  |
    TerrPath:     r := 180; g := 160; b := 100 |
    TerrWall:     r := 80;  g := 80;  b := 80  |
    TerrDoor:     r := 140; g := 100; b := 40  |
    TerrSand:     r := 220; g := 200; b := 140 |
    TerrSwamp:    r := 60;  g := 90;  b := 50  |
    TerrBridge:   r := 160; g := 120; b := 60  |
    TerrFloor:    r := 120; g := 110; b := 100
  ELSE
    r := 0; g := 0; b := 0
  END
END TerrainColor;

PROCEDURE DrawWorld;
BEGIN
  IF currentRegion >= 0 THEN
    DrawWorldTiled
  ELSE
    DrawWorldFallback
  END
END DrawWorld;

(* Build a composite sprite mask matching the original pipeline.
   bmask starts as all TRUE (draw everything).
   For each overlapping tile that passes the mask type check,
   set bmask to FALSE where shadow_mem has a 1 (tile covers sprite).
   Then DrawBrotherSprite uses bmask to skip blocked pixels. *)

VAR
  bmask: ARRAY [0..15] OF ARRAY [0..31] OF BOOLEAN;

PROCEDURE BuildSpriteMask;
VAR xm, ym, imx, imy, px, py, secByte, maskType: INTEGER;
    maskY, ystop, heroSec, ground: INTEGER;
    xbw, ym1, ym2, blitwide: INTEGER;
    sprWorldX, sprWorldY: INTEGER;
    tileWorldX, tileWorldY: INTEGER;
    localX, localY, shadowX, shadowY: INTEGER;
    doMask: BOOLEAN;
BEGIN
  (* Init: all pixels drawable *)
  FOR px := 0 TO 15 DO
    FOR py := 0 TO 31 DO
      bmask[px][py] := TRUE
    END
  END;

  IF currentRegion < 0 THEN RETURN END;
  IF shadowPB = NIL THEN RETURN END;

  (* Sprite world position (top-left) *)
  sprWorldX := actors[0].absX - 8;
  sprWorldY := actors[0].absY - 24;
  ground := actors[0].absY - camY;

  (* Tile range overlapping sprite *)
  xbw := sprWorldX DIV TilePixW;
  ym1 := sprWorldY DIV TilePixH;
  blitwide := ((sprWorldX + SprW - 1) DIV TilePixW) - xbw + 1;
  ym2 := ((sprWorldY + SprH - 1) DIV TilePixH) - ym1;

  heroSec := GetSectorByte(actors[0].absX, actors[0].absY);

  FOR xm := 0 TO blitwide - 1 DO
    FOR ym := 0 TO ym2 DO
      imx := xbw + xm;
      imy := ym1 + ym;
      ystop := ground - (imy * TilePixH - camY);

      secByte := GetSectorByte(imx * TilePixW, imy * TilePixH);
      maskType := GetMaskType(secByte);

      doMask := TRUE;
      CASE maskType OF
        0: doMask := FALSE |
        1: IF xm = 0 THEN doMask := FALSE END |
        2: IF ystop > 35 THEN doMask := FALSE END |
        3: (* always *) |
        4: IF (xm = 0) OR (ystop > 35) THEN doMask := FALSE END |
        5: IF (xm = 0) AND (ystop > 35) THEN doMask := FALSE END |
        6: (* always *) |
        7: IF ystop > 20 THEN doMask := FALSE END
      ELSE
        doMask := FALSE
      END;

      IF doMask THEN
        maskY := GetMapTag(secByte) * TilePixH;
        tileWorldX := imx * TilePixW;
        tileWorldY := imy * TilePixH;

        (* For each pixel in the overlap region, check shadow mask.
           If shadow pixel is set, block the sprite pixel. *)
        FOR py := 0 TO TilePixH - 1 DO
          FOR px := 0 TO TilePixW - 1 DO
            (* Position in sprite coordinates *)
            localX := (tileWorldX + px) - sprWorldX;
            localY := (tileWorldY + py) - sprWorldY;
            IF (localX >= 0) AND (localX < SprW) AND
               (localY >= 0) AND (localY < SprH) THEN
              (* Check shadow mask *)
              shadowX := px;
              shadowY := maskY + py;
              IF (shadowY >= 0) AND (shadowY < 6144) THEN
                IF PBGetPix(shadowPB, shadowX, shadowY) # 0 THEN
                  bmask[localX][localY] := FALSE
                END
              END
            END
          END
        END
      END
    END
  END
END BuildSpriteMask;

(* ---- Items ---- *)

PROCEDURE DrawItems;
VAR i, sx, sy, r, g, b: INTEGER;
BEGIN
  SetClip(ren, 0, 0, S(PlayW), S(PlayH));

  FOR i := 0 TO itemCount - 1 DO
    IF items[i].active THEN
      sx := (items[i].x - camX) * Scale;
      sy := (items[i].y - camY) * Scale;
      IF (sx > -S(16)) AND (sx < S(PlayW) + 16) AND
         (sy > -S(16)) AND (sy < S(PlayH) + 16) THEN
        ItemColor(items[i].itemId, r, g, b);
        IF (cycle DIV 8) MOD 2 = 0 THEN
          SetColor(ren, r, g, b, 255)
        ELSE
          SetColor(ren, r DIV 2, g DIV 2, b DIV 2, 255)
        END;
        FillRect(ren, sx - S(3), sy - S(3), S(6), S(6));
        SetColor(ren, 255, 255, 255, 255);
        DrawRect(ren, sx - S(3), sy - S(3), S(6), S(6))
      END
    END
  END;

  ClearClip(ren)
END DrawItems;

PROCEDURE ItemColor(id: INTEGER; VAR r, g, b: INTEGER);
BEGIN
  CASE id OF
    ItemGold:   r := 255; g := 215; b := 0   |
    ItemFood:   r := 180; g := 100; b := 40  |
    ItemKey:    r := 200; g := 200; b := 50  |
    ItemSword:  r := 180; g := 180; b := 200 |
    ItemShield: r := 100; g := 140; b := 200 |
    ItemPotion: r := 200; g := 50;  b := 200 |
    ItemGem:    r := 50;  g := 200; b := 220 |
    ItemScroll: r := 240; g := 230; b := 200
  ELSE
    r := 200; g := 200; b := 200
  END
END ItemColor;

(* ---- Actors ---- *)

CONST
  SprW = 16;   (* sprite frame width in source pixels *)
  SprH = 32;   (* sprite frame height in source pixels *)

(* Map our direction to original walk frame base.
   Our: N=0,NE=1,E=2,SE=3,S=4,SW=5,W=6,NW=7
   Original walk bases: S=0, W=8, N=16, E=24 *)
PROCEDURE WalkBase(facing: INTEGER): INTEGER;
BEGIN
  CASE facing OF
    0: RETURN 16 |  (* N *)
    1: RETURN 16 |  (* NE → N *)
    2: RETURN 24 |  (* E *)
    3: RETURN 0  |  (* SE → S *)
    4: RETURN 0  |  (* S *)
    5: RETURN 0  |  (* SW → S *)
    6: RETURN 8  |  (* W *)
    7: RETURN 16    (* NW → N *)
  ELSE
    RETURN 0
  END
END WalkBase;

PROCEDURE GetSpriteFrame(i: INTEGER): INTEGER;
VAR base: INTEGER;
BEGIN
  IF actors[i].state = StWalking THEN
    base := WalkBase(actors[i].facing);
    RETURN base + ((cycle + i) MOD 8)
  ELSIF actors[i].state = StStill THEN
    base := WalkBase(actors[i].facing);
    RETURN base + 1  (* standing frame *)
  ELSE
    (* Fighting, dying etc — use still frame for now *)
    base := WalkBase(actors[i].facing);
    RETURN base + 1
  END
END GetSpriteFrame;

PROCEDURE DrawBrotherSprite(brotherIdx, frame, sx, sy, env: INTEGER);
VAR tex: ADDRESS;
    srcY, srcH, dstY, dstH, clipBot, px, py: INTEGER;
BEGIN
  IF (brotherIdx < 0) OR (brotherIdx > 2) THEN RETURN END;
  tex := brotherTex[brotherIdx];
  IF tex = NIL THEN RETURN END;
  IF (frame < 0) OR (frame > 66) THEN frame := 0 END;

  srcY := frame * SprH;
  srcH := SprH;
  dstY := sy - S(16);
  dstH := S(SprH);
  clipBot := 0;

  IF env = 2 THEN
    (* Forest/brush: clip bottom 10 pixels of sprite — hide legs *)
    clipBot := 10
  ELSIF env > 2 THEN
    (* Water: clip bottom by environ pixels — character sinks down *)
    clipBot := env;
    IF clipBot > SprH - 4 THEN clipBot := SprH - 4 END
  END;

  IF clipBot > 0 THEN
    DEC(srcH, clipBot);
    DEC(dstH, S(clipBot))
  END;

  IF srcH <= 0 THEN RETURN END;

  (* Build sprite mask from overlapping tiles *)
  BuildSpriteMask;

  (* Draw sprite pixel-by-pixel, skipping where bmask is FALSE.
     Each source pixel becomes Scale x Scale screen pixels. *)
  FOR py := 0 TO srcH - 1 DO
    FOR px := 0 TO SprW - 1 DO
      IF bmask[px][py] THEN
        DrawTexRegion(tex, px, srcY + py, 1, 1,
                      sx - S(8) + px * Scale, dstY + py * Scale,
                      Scale, Scale)
      END
    END
  END
END DrawBrotherSprite;

PROCEDURE DrawActorBody(i, sx, sy: INTEGER);
VAR r, g, b, frame: INTEGER;
BEGIN
  IF (i = 0) AND (brotherTex[activeBrother] # NIL) THEN
    frame := GetSpriteFrame(i);
    DrawBrotherSprite(activeBrother, frame, sx, sy, actors[i].environ);
    RETURN
  END;

  (* Fallback: colored rectangles for non-player actors *)
  IF actors[i].actorType = 2 THEN
    r := 60; g := 160; b := 220
  ELSE
    IF actors[i].state = StFighting THEN
      r := 255; g := 80; b := 80
    ELSE
      r := 200; g := 40; b := 40
    END
  END;

  SetColor(ren, r, g, b, 255);
  FillRect(ren, sx - S(4), sy - S(6), S(8), S(12));
  SetColor(ren, 0, 0, 0, 255);
  DrawRect(ren, sx - S(4), sy - S(6), S(8), S(12))
END DrawActorBody;

PROCEDURE DrawActors;
VAR i, sx, sy: INTEGER;
BEGIN
  SetClip(ren, 0, 0, S(PlayW), S(PlayH));

  FOR i := 0 TO actorCount - 1 DO
    IF (actors[i].state # StDead) AND (actors[i].state # StDying) THEN
      sx := (actors[i].absX - camX) * Scale;
      sy := (actors[i].absY - camY) * Scale;
      IF (sx > -S(20)) AND (sx < S(PlayW) + 20) AND
         (sy > -S(20)) AND (sy < S(PlayH) + 20) THEN
        DrawActorBody(i, sx, sy)
      END
    END
  END;

  ClearClip(ren)
END DrawActors;

(* ---- HUD ---- *)

PROCEDURE DrawHUD;
BEGIN
  IF hudTex # NIL THEN
    (* SDL has issues with source rects on paletted textures.
       Use Texture.Draw at native size, then let SDL scale via
       logical renderer size. For now, just draw at 1:1. *)
    TexDraw(ren, hudTex, 0, S(PlayH))
  ELSE
    SetColor(ren, 30, 25, 20, 255);
    FillRect(ren, 0, S(PlayH), S(ScreenW), S(TextH))
  END
END DrawHUD;

PROCEDURE DrawCompass;
CONST
  (* Compass center in screen pixels.
     HUD compass is at ~(591, 27) in 640x57 space.
     Screen: 591*960/640=886, PlayH*3 + 27*171/57=429+81=510 *)
  CX = 886;
  CY = 510;
  R  = 16;  (* radius to direction pip *)
VAR dir, px, py: INTEGER;
BEGIN
  IF actors[0].state = StStill THEN RETURN END;
  dir := actors[0].facing;
  IF (dir < 0) OR (dir > 7) THEN RETURN END;

  (* Calculate pip position from compass center.
     Our dirs: N=0,NE=1,E=2,SE=3,S=4,SW=5,W=6,NW=7 *)
  CASE dir OF
    0: px := CX;     py := CY - R |     (* N *)
    1: px := CX + R + 13; py := CY - R - 14 |  (* NE *)
    2: px := CX + R;      py := CY |           (* E *)
    3: px := CX + R + 13; py := CY + R + 13 |  (* SE *)
    4: px := CX;           py := CY + R |       (* S *)
    5: px := CX - R - 15; py := CY + R + 15 |  (* SW *)
    6: px := CX - R;      py := CY |           (* W *)
    7: px := CX - R - 14; py := CY - R - 14    (* NW *)
  ELSE
    RETURN
  END;

  (* Draw a bright red diamond pip *)
  SetColor(ren, 255, 50, 0, 255);
  FillRect(ren, px - 3, py - 3, 7, 7);
  SetColor(ren, 255, 200, 50, 255);
  FillRect(ren, px - 1, py - 1, 3, 3)
END DrawCompass;

(* ---- Menu ---- *)

PROCEDURE PalColor(idx: INTEGER; VAR r, g, b: INTEGER);
BEGIN
  (* HUD text area palette from textcolors[] — NOT pagecolors *)
  CASE idx OF
     0: r :=   0; g :=   0; b :=   0 |  (* 0x000 black *)
     1: r := 255; g := 255; b := 255 |  (* 0xFFF white *)
     2: r := 204; g :=   0; b :=   0 |  (* 0xC00 red *)
     3: r := 255; g := 102; b :=   0 |  (* 0xF60 orange *)
     4: r :=   0; g :=   0; b := 255 |  (* 0x00F blue *)
     5: r := 204; g :=   0; b := 255 |  (* 0xC0F magenta *)
     6: r :=   0; g := 153; b :=   0 |  (* 0x090 green *)
     7: r := 255; g := 255; b :=   0 |  (* 0xFF0 yellow *)
     8: r := 255; g := 153; b :=   0 |  (* 0xF90 orange-gold *)
     9: r := 255; g :=   0; b := 204 |  (* 0xF0C pink *)
    10: r := 170; g :=  85; b :=   0 |  (* 0xA50 brown *)
    11: r := 255; g := 221; b := 187 |  (* 0xFDB light peach *)
    12: r := 238; g := 187; b := 119 |  (* 0xEB7 tan *)
    13: r := 204; g := 204; b := 204 |  (* 0xCCC light gray *)
    14: r := 136; g := 136; b := 136 |  (* 0x888 medium gray *)
    15: r :=  68; g :=  68; b :=  68    (* 0x444 dark gray *)
  ELSE
    r := 0; g := 0; b := 0
  END
END PalColor;

PROCEDURE GetOptionLabel(optIdx: INTEGER; VAR buf: ARRAY OF CHAR);
VAR i, base: INTEGER;
    tabLabels: ARRAY [0..24] OF CHAR;
BEGIN
  (* Tab labels for slots 0-4 *)
  tabLabels[0]  := 'I'; tabLabels[1]  := 't'; tabLabels[2]  := 'e';
  tabLabels[3]  := 'm'; tabLabels[4]  := 's';
  tabLabels[5]  := 'M'; tabLabels[6]  := 'a'; tabLabels[7]  := 'g';
  tabLabels[8]  := 'i'; tabLabels[9]  := 'c';
  tabLabels[10] := 'T'; tabLabels[11] := 'a'; tabLabels[12] := 'l';
  tabLabels[13] := 'k'; tabLabels[14] := ' ';
  tabLabels[15] := 'B'; tabLabels[16] := 'u'; tabLabels[17] := 'y';
  tabLabels[18] := ' '; tabLabels[19] := ' ';
  tabLabels[20] := 'G'; tabLabels[21] := 'a'; tabLabels[22] := 'm';
  tabLabels[23] := 'e'; tabLabels[24] := ' ';

  IF optIdx < 5 THEN
    base := optIdx * 5;
    FOR i := 0 TO 4 DO
      buf[i] := tabLabels[base + i]
    END
  ELSE
    base := (optIdx - 5) * 5;
    FOR i := 0 TO 4 DO
      IF base + i <= HIGH(menus[cmode].labels) THEN
        buf[i] := menus[cmode].labels[base + i]
      ELSE
        buf[i] := ' '
      END
    END
  END;
  buf[5] := 0C
END GetOptionLabel;

PROCEDURE DrawMenu;
CONST
  (* 3x pre-scaled font (24px source) rendered at 12px (clean 2:1 downsample).
     6 chars per column = 72px. *)
  CharSz = 12;
  ColW   = 72;   (* 6 chars at 12px *)
  RowH   = 14;   (* 12px char + 2px gap *)
  Col0   = 645;
  Col1   = 723;
  YOff   = 12;
VAR j, optIdx, col, row, px, py, penb: INTEGER;
    bgR, bgG, bgB, fgR, fgG, fgB: INTEGER;
    selected: BOOLEAN;
    label: ARRAY [0..5] OF CHAR;
    hudY: INTEGER;
BEGIN
  hudY := S(PlayH);

  FOR j := 0 TO optionCount - 1 DO
    optIdx := realOptions[j];
    IF optIdx < 0 THEN (* skip *)
    ELSE
      selected := (menus[cmode].enabled[optIdx] AND 1) # 0;

      col := j MOD 2;
      row := j DIV 2;
      IF col = 0 THEN px := Col0 ELSE px := Col1 END;
      py := hudY + YOff + row * RowH;

      (* Background pen — matches original propt() logic *)
      IF optIdx < 5 THEN
        penb := 4  (* tabs always dark brown *)
      ELSE
        penb := menus[cmode].color
      END;
      PalColor(penb, bgR, bgG, bgB);

      (* Foreground: pena=1 (white) if selected, pena=0 (black) if not *)
      IF selected THEN
        fgR := 255; fgG := 255; fgB := 255
      ELSE
        fgR := 0; fgG := 0; fgB := 0
      END;

      (* Draw background rect *)
      SetColor(ren, bgR, bgG, bgB, 255);
      FillRect(ren, px, py, ColW, CharSz);

      (* Draw 5-char label centered in the rect *)
      GetOptionLabel(optIdx, label);
      SetFontColor(fgR, fgG, fgB);
      DrawStrSized(ren, label, px + 8, py, CharSz, CharSz)
    END
  END
END DrawMenu;

(* ---- Minimap ---- *)

PROCEDURE DrawMinimap;
VAR x, y, mx, my, r, g, b, px, py: INTEGER;
BEGIN
  IF hudTex # NIL THEN RETURN END; (* HUD covers minimap area *)
  mx := S(ScreenW - 66);
  my := S(PlayH + 2);

  SetColor(ren, 10, 10, 20, 180);
  FillRect(ren, mx - S(1), my - S(1), S(66), S(TextH - 2));

  FOR x := 0 TO WorldW - 1 DO
    FOR y := 0 TO WorldH - 1 DO
      TerrainColor(tiles[x][y].terrain, r, g, b);
      SetColor(ren, r, g, b, 255);
      FillRect(ren, mx + x * Scale, my + y * Scale, Scale, Scale)
    END
  END;

  px := actors[0].absX DIV TileSize;
  py := actors[0].absY DIV TileSize;
  IF (cycle DIV 10) MOD 2 = 0 THEN
    SetColor(ren, 255, 255, 255, 255)
  ELSE
    SetColor(ren, 255, 255, 0, 255)
  END;
  FillRect(ren, mx + px * Scale, my + py * Scale, Scale, Scale);

  SetColor(ren, 255, 40, 40, 255);
  FOR x := 1 TO actorCount - 1 DO
    IF actors[x].state # StDead THEN
      px := actors[x].absX DIV TileSize;
      py := actors[x].absY DIV TileSize;
      FillRect(ren, mx + px * Scale, my + py * Scale, Scale, Scale)
    END
  END
END DrawMinimap;

(* ---- Message ---- *)

PROCEDURE DrawRegionFade;
VAR alpha: INTEGER;
BEGIN
  IF regionFade <= 0 THEN RETURN END;
  alpha := regionFade * 25;
  IF alpha > 255 THEN alpha := 255 END;
  SetColor(ren, 0, 0, 0, alpha);
  FillRect(ren, 0, 0, S(PlayW), S(PlayH))
END DrawRegionFade;

PROCEDURE DrawMessage;
VAR i: INTEGER;
BEGIN
  IF msgTimer <= 0 THEN RETURN END;
  SetColor(ren, 40, 30, 20, 255);
  i := 0;
  WHILE (i <= 63) AND (msgText[i] # 0C) DO
    FillRect(ren, S(10 + i * 3), S(PlayH + 22), S(2), S(5));
    INC(i)
  END
END DrawMessage;

END Render.
