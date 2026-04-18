IMPLEMENTATION MODULE Render;

FROM SYSTEM IMPORT ADDRESS;
FROM Platform IMPORT ren, ScreenW, ScreenH, PlayW, PlayH, Scale, TextH,
                    DrawTexRegion, LoadBMPKeyedTexture;
FROM Texture IMPORT Draw AS TexDraw, DrawRegion AS TexDrawRegion,
                    Width AS TexWidth, Height AS TexHeight,
                    SetColorMod;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;
FROM Canvas IMPORT SetColor, FillRect, DrawRect, SetClip, ClearClip;
FROM World IMPORT tiles, WorldW, WorldH, TileSize, camX, camY,
                  TerrGrass, TerrWater, TerrForest,
                  TerrMountain, TerrPath, TerrWall, TerrDoor,
                  TerrSand, TerrSwamp, TerrBridge, TerrFloor;
FROM Actor IMPORT actors, actorCount, StDead, StDying, StStill,
                  StWalking, StFighting, StSleep,
                  TypeEnemy, TypeSetfig, TypeRaft, TypeCarrier;
FROM Items IMPORT items, itemCount, inventory,
                  ItemGold, ItemFood, ItemKey, ItemSword,
                  ItemShield, ItemPotion, ItemGem, ItemScroll;
FROM GameState IMPORT cycle, msgText, msgTimer, regionFade,
                     fairyActive, fairyX;
FROM DayNight IMPORT brightness, isNight, lightlevel, GetFadeRGB,
                     PaletteTickDue;
FROM Brothers IMPORT activeBrother, brothers, Julian, Philip, Kevin;
FROM Assets IMPORT tileTex, hudTex, brotherTex, enemyTex, npcTex, shadowPB,
                   currentRegion, GetSectorByte, GetSectorByteForRegion,
                   GetMaskType, GetTilesBits, GetMapTag, DetectRegion,
                   regions, NumRegions, LoadImgCached, AssetPath;
FROM PixBuf IMPORT PBuf, GetPix AS PBGetPix;
FROM Menu IMPORT cmode, menus, realOptions, optionCount, MaxOpts,
                 MItems, MMagic, MTalk, MBuy, MGame, MUse, MFile,
                 MSave, MKeys, MGive,
                 PanelX, PanelY, BtnW, BtnH;
FROM HudFont IMPORT DrawHudStr, DrawMenuStr;
FROM WorldObj IMPORT objTex;
FROM NPC IMPORT GetSetfigSprite;
FROM Carrier IMPORT riding;
FROM HudLog IMPORT GetLine, GetStatBrv, GetStatLck, GetStatKnd,
                   GetStatWlth, GetStatVit, logDirty, statDirty;

(* Tiles in PNG: 16px wide x 32px tall, 256 tiles stacked vertically.
   Sector byte: top 2 bits = image bank (0-3), bottom 6 bits = tile index.
   Tile Y in texture = tileIndex * 32. *)

CONST
  TilePixW = 16;
  TilePixH = 32;

PROCEDURE InitOverlay;
BEGIN
  fadeR := 255; fadeG := 255; fadeB := 255;
  wpnInited := FALSE;
  bowInited := FALSE;
  compassBase := NIL;
  compassHi := NIL;
  UpdateFade
END InitOverlay;

PROCEDURE LoadCompass;
VAR p: ARRAY [0..127] OF CHAR;
BEGIN
  AssetPath("compass_base.bmp", p);
  compassBase := LoadBMPKeyedTexture(p, 255, 0, 255);
  AssetPath("compass_highlight.bmp", p);
  compassHi := LoadBMPKeyedTexture(p, 255, 0, 255);
  IF compassBase = NIL THEN
    WriteString("Compass: base load failed"); WriteLn
  END;
  IF compassHi = NIL THEN
    WriteString("Compass: highlight load failed"); WriteLn
  END;
  (* Load carrier sprites *)
  AssetPath("shape_4_Raft_32x32_x2.bmp", p);
  raftTex := LoadBMPKeyedTexture(p, 255, 0, 255);
  AssetPath("shape_5_Turtle_32x32_x16.bmp", p);
  turtleTex := LoadBMPKeyedTexture(p, 255, 0, 255);
  AssetPath("shape_11_Bird_64x64_x8.bmp", p);
  birdTex := LoadBMPKeyedTexture(p, 255, 0, 255)
END LoadCompass;

PROCEDURE S(v: INTEGER): INTEGER;
BEGIN
  RETURN v * Scale
END S;

(* ---- World drawing ---- *)

VAR
  fadeR, fadeG, fadeB: INTEGER;  (* cached palette fade values 0..100 *)
  compassBase, compassHi: ADDRESS;  (* compass textures *)
  raftTex, turtleTex, birdTex: ADDRESS;  (* carrier textures *)

PROCEDURE UpdateFade;
VAR r, g, b: INTEGER;
BEGIN
  GetFadeRGB(r, g, b);
  fadeR := r * 255 DIV 100;
  fadeG := g * 255 DIV 100;
  fadeB := b * 255 DIV 100;
  IF fadeR > 255 THEN fadeR := 255 END;
  IF fadeG > 255 THEN fadeG := 255 END;
  IF fadeB > 255 THEN fadeB := 255 END
END UpdateFade;

PROCEDURE DrawWorldTiled;
VAR imx, imy, sx, sy, secByte, imgIdx, tileY, tileReg: INTEGER;
    startIX, startIY, endIX, endIY: INTEGER;
    tex: ADDRESS;
BEGIN
  (* Update palette fade — indoor regions are always full bright,
     outdoor regions update on palette tick.
     Force immediate update when transitioning outdoor to avoid flash. *)
  IF currentRegion >= 8 THEN
    fadeR := 255; fadeG := 255; fadeB := 255
  ELSE
    IF (fadeR = 255) AND (fadeG = 255) AND (fadeB = 255) THEN
      (* Just came from indoor — force immediate palette update *)
      UpdateFade
    ELSIF PaletteTickDue() THEN
      UpdateFade
    END
  END;

  SetClip(ren, 0, 0, S(PlayW), S(PlayH));

  startIX := camX DIV TilePixW - 1;
  startIY := camY DIV TilePixH - 1;
  endIX := (camX + PlayW) DIV TilePixW + 1;
  endIY := (camY + PlayH) DIV TilePixH + 1;
  IF startIX < 0 THEN startIX := 0 END;
  IF startIY < 0 THEN startIY := 0 END;

  FOR imy := startIY TO endIY DO
    FOR imx := startIX TO endIX DO
      (* Use current region's sector data for all tiles.
         The original uses one region for the entire screen —
         the map/sector data wraps correctly at boundaries. *)
      secByte := GetSectorByte(imx * TilePixW, imy * TilePixH);
      imgIdx := secByte DIV 64;
      tileY := (secByte MOD 64) * TilePixH;
      sx := imx * TilePixW - camX;
      sy := imy * TilePixH - camY;
      tex := tileTex[imgIdx];

      IF tex # NIL THEN
        (* Apply day/night fade via SetColorMod matching original palette math *)
        SetColorMod(tex, fadeR, fadeG, fadeB);
        DrawTexRegion(tex,
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

PROCEDURE BuildSpriteMaskAt(worldX, worldY, groundY: INTEGER);
VAR xm, ym, imx, imy, px, py, secByte, maskType: INTEGER;
    maskY, ystop, heroSec, ground: INTEGER;
    xbw, ym1, ym2, blitwide: INTEGER;
    sprWorldX, sprWorldY: INTEGER;
    tileWorldX, tileWorldY: INTEGER;
    localX, localY, shadowX, shadowY: INTEGER;
    doMask: BOOLEAN;
BEGIN
  FOR px := 0 TO 15 DO
    FOR py := 0 TO 31 DO
      bmask[px][py] := TRUE
    END
  END;

  IF currentRegion < 0 THEN RETURN END;
  IF shadowPB = NIL THEN RETURN END;

  sprWorldX := worldX;
  sprWorldY := worldY;
  ground := groundY;

  xbw := sprWorldX DIV TilePixW;
  ym1 := sprWorldY DIV TilePixH;
  blitwide := ((sprWorldX + SprW - 1) DIV TilePixW) - xbw + 1;
  ym2 := ((sprWorldY + SprH - 1) DIV TilePixH) - ym1;

  heroSec := GetSectorByte(sprWorldX + 8, sprWorldY + 16);

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
        3: (* Original: case 3: break; — always mask.
              But also has goto nomask for specific cases. *)  |
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
END BuildSpriteMaskAt;

PROCEDURE BuildSpriteMaskFor(actorIdx: INTEGER);
BEGIN
  BuildSpriteMaskAt(
    actors[actorIdx].absX - 8,
    actors[actorIdx].absY - 16,
    actors[actorIdx].absY - camY + 16)
END BuildSpriteMaskFor;

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

PROCEDURE FightBase(facing: INTEGER): INTEGER;
BEGIN
  CASE facing OF
    0: RETURN 56 |  1: RETURN 56 |  2: RETURN 68 |  3: RETURN 32 |
    4: RETURN 32 |  5: RETURN 32 |  6: RETURN 44 |  7: RETURN 56
  ELSE RETURN 32
  END
END FightBase;

(* For brothers (player): frames are sequential 0-66.
   For enemies: frames are interleaved — even race uses even frames,
   odd race uses odd frames. Original: inum |= 1 for odd race. *)

PROCEDURE GetPlayerFrame(i: INTEGER): INTEGER;
VAR base, inum, frame: INTEGER;
BEGIN
  IF NOT wpnInited THEN InitWpnState END;

  (* When riding, show static standing pose *)
  IF (riding # 0) AND (i = 0) THEN
    RETURN WalkBase(actors[i].facing) + 1
  END;

  IF actors[i].state = StWalking THEN
    RETURN WalkBase(actors[i].facing) + ((cycle + i) MOD 8)
  ELSIF actors[i].state = StFighting THEN
    (* Use statelist: base is the statelist index, figure gives the actual sprite frame *)
    base := FightBase(actors[i].facing);
    inum := base + ((cycle + i) DIV 2) MOD 12;
    IF inum > 86 THEN inum := 86 END;
    RETURN wpnState[inum].figure
  ELSIF actors[i].state = StSleep THEN
    RETURN wpnState[86].figure  (* sleeping frame *)
  ELSIF (actors[i].state = StDying) OR (actors[i].state = StDead) THEN
    inum := 80;
    frame := ((cycle + i) DIV 4) MOD 3;
    IF actors[i].state = StDead THEN frame := 2 END;
    RETURN wpnState[inum + frame].figure
  ELSE
    RETURN WalkBase(actors[i].facing) + 1
  END
END GetPlayerFrame;

PROCEDURE GetEnemyFrame(i: INTEGER): INTEGER;
VAR base, frame, inum: INTEGER;
    odd: BOOLEAN;
BEGIN
  IF NOT wpnInited THEN InitWpnState END;
  odd := BAND(CARDINAL(actors[i].race), 1) # 0;

  (* Enemy sheets: 64 frames interleaved even/odd for race pairs.
     Walk: 0-31 (4 dirs × 8 frames). Fight: 32-63 (same layout).
     Use statelist figure lookup — validated against actual sprite sheets. *)
  (* Original fight animation: inum = diroffs[d+8] + fight_state.
     diroffs[d+8]: S=32, W=44, N=56, E=68.
     Fight state 0-8 transitions via trans_list randomly.
     We approximate with a slower cycle through states 0-7.
     Then statelist[dex].figure gives the actual sprite frame.
     Dying: dex=80 or 81. Dead: dex=82. *)
  IF actors[i].state = StWalking THEN
    base := WalkBase(actors[i].facing);
    inum := base + ((cycle + i) MOD 8)
  ELSIF (actors[i].state = StFighting) AND (actors[i].state < StWalking) OR
        (actors[i].state = StFighting) THEN
    (* Enemy fight: use original statelist lookup.
       dex = diroffs[d+8] + fight_state.
       diroffs[d+8]: S=32, W=44, N=56, E=68.
       fight_state cycles 0-7, statelist[dex].figure gives frame. *)
    CASE actors[i].facing OF
      0, 1, 7: base := 56 |  (* N: diroffs[8] *)
      2:       base := 68 |  (* E: diroffs[10] *)
      3, 4, 5: base := 32 |  (* S: diroffs[12] *)
      6:       base := 44    (* W: diroffs[14] *)
    ELSE base := 32
    END;
    frame := ((cycle + i) DIV 4) MOD 6;
    IF frame > 5 THEN frame := 5 END;
    inum := base + frame;
    IF inum > 86 THEN inum := base END;
    inum := wpnState[inum].figure
  ELSIF actors[i].state = StDying THEN
    IF actors[i].tactic > 15 THEN
      IF (actors[i].facing = 0) OR (actors[i].facing > 4) THEN
        inum := wpnState[80].figure
      ELSE
        inum := wpnState[81].figure
      END
    ELSIF actors[i].tactic > 0 THEN
      IF (actors[i].facing = 0) OR (actors[i].facing > 4) THEN
        inum := wpnState[81].figure
      ELSE
        inum := wpnState[80].figure
      END
    ELSE
      inum := wpnState[82].figure
    END
  ELSIF actors[i].state = StDead THEN
    inum := wpnState[82].figure
  ELSE
    inum := WalkBase(actors[i].facing) + 1
  END;

  (* Snake (race 4): dedicated frame lookup.
     4 directions, 2 walk frames each, dead frame at +3 from base.
     Sheet layout: S=36,37 dead=39 / W=44,45 dead=47 /
                   N=52,53 dead=55 / E=60,61 dead=63 *)
  IF actors[i].race = 4 THEN
    CASE actors[i].facing OF
      0, 1, 7: base := 52 |  (* N *)
      2, 3:    base := 60 |  (* E *)
      4, 5:    base := 36 |  (* S *)
      6:       base := 44    (* W *)
    ELSE base := 36
    END;
    IF (actors[i].state = StDying) OR (actors[i].state = StDead) THEN
      RETURN base + 3  (* dead snake: 39, 47, 55, 63 *)
    ELSE
      RETURN base + (cycle DIV 4) MOD 2  (* alternate 0/1 *)
    END
  END;

  (* Even/odd interleave for all frames *)
  IF odd THEN
    inum := BOR(INTEGER(CARDINAL(inum)), 1)
  ELSE
    inum := BAND(CARDINAL(inum), 65534)
  END;
  RETURN inum
END GetEnemyFrame;

(* --- Weapon overlay rendering ---
   Weapons are drawn from the objects sprite sheet (16x16 frames).
   statelist maps animation frame → weapon frame base + x,y offset.
   Weapon type determines an additional frame offset. *)

CONST
  WpnSprW = 16;
  WpnSprH = 16;

TYPE
  StateEntry = RECORD
    figure: INTEGER;  (* actual sprite frame for body *)
    wpnNo:  INTEGER;  (* base weapon frame in objects sheet *)
    wpnX:   INTEGER;  (* x offset from actor position *)
    wpnY:   INTEGER   (* y offset from actor position *)
  END;

VAR
  wpnState: ARRAY [0..86] OF StateEntry;
  wpnInited: BOOLEAN;

PROCEDURE InitWpnState;
  PROCEDURE W(i, fig, wn, wx, wy: INTEGER);
  BEGIN
    wpnState[i].figure := fig;
    wpnState[i].wpnNo := wn;
    wpnState[i].wpnX := wx;
    wpnState[i].wpnY := wy
  END W;
BEGIN
  (* South walk 0-7: figure, wpnNo, wpnX, wpnY *)
  W( 0, 0,11,-2,11); W( 1, 1,11,-3,11); W( 2, 2,11,-3,10); W( 3, 3,11,-3, 9);
  W( 4, 4,11,-3,10); W( 5, 5,11,-3,11); W( 6, 6,11,-2,11); W( 7, 7,11,-1,11);
  (* West walk 8-15 *)
  W( 8, 8, 9,-12,11); W( 9, 9, 9,-11,12); W(10,10, 9,-8,13); W(11,11, 9,-4,13);
  W(12,12, 9,  0,13); W(13,13, 9,-4,13); W(14,14, 9,-8,13); W(15,15, 9,-11,12);
  (* North walk 16-23 *)
  W(16,16,14,-1, 1); W(17,17,14,-1, 2); W(18,18,14,-1, 3); W(19,19,14,-1, 4);
  W(20,20,14,-1, 3); W(21,21,14,-1, 2); W(22,22,14,-1, 1); W(23,23,14,-1, 1);
  (* East walk 24-31 *)
  W(24,24,10, 5,12); W(25,25,10, 3,12); W(26,26,10, 2,12); W(27,27,10, 3,12);
  W(28,28,10, 5,12); W(29,29,10, 6,12); W(30,30,10, 6,11); W(31,31,10, 6,12);
  (* South fight 32-43 *)
  W(32,32,11,-2,12); W(33,32,10, 0,12); W(34,33, 0, 2,10); W(35,34, 1, 4, 6);
  W(36,34, 2, 1, 4); W(37,34, 3, 0, 4); W(38,36, 4,-5, 0); W(39,36, 5,-10,1);
  W(40,35,12,-5, 5); W(41,36, 0, 0, 6); W(42,38,85,-6, 5); W(43,37,81,-6, 5);
  (* West fight 44-55 *)
  W(44,40, 9,-7,12); W(45,40, 8,-9, 9); W(46,41, 7,-10,5); W(47,42, 7,-12,4);
  W(48,42, 6,-12,3); W(49,42, 5,-12,3); W(50,44, 5,-8, 3); W(51,44,14,-7, 6);
  W(52,43,13,-7, 8); W(53,42, 5,-12,3); W(54,46,86,-3, 0); W(55,45,82,-3, 0);
  (* North fight 56-67 *)
  W(56,48,14,-3, 0); W(57,48, 6,-3,-1); W(58,49, 5,-2,-3); W(59,50, 5,-3,-4);
  W(60,50, 4, 0, 0); W(61,50, 3, 3, 0); W(62,52, 4, 6, 1); W(63,52,15, 7, 3);
  W(64,51,14, 1, 6); W(65,50, 4, 0, 0); W(66,54,87, 3, 0); W(67,53,83, 3, 0);
  (* East fight 68-79 *)
  W(68,56,10, 5,11); W(69,56, 0, 6, 9); W(70,57, 1,10, 6); W(71,58, 1,10, 5);
  W(72,58, 2, 7, 3); W(73,58, 3, 6, 3); W(74,60, 4, 1, 0); W(75,60, 3, 3, 2);
  W(76,59,15, 4, 1); W(77,58, 4, 5, 1); W(78,62,84, 3, 0); W(79,61,80, 3, 0);
  (* Death 80-82 *)
  W(80,47, 0, 5,11); W(81,63, 0, 6, 9); W(82,39, 0, 6, 9);
  (* Sink/special 83-86 *)
  W(83,55,10, 5,11); W(84,64,10, 5,11); W(85,65,10, 5,11); W(86,66,10, 5,11);
  wpnInited := TRUE
END InitWpnState;

VAR
  bowX: ARRAY [0..31] OF INTEGER;
  bowY: ARRAY [0..31] OF INTEGER;
  bowInited: BOOLEAN;

PROCEDURE InitBowOffsets;
BEGIN
  (* South walk 0-7 *)
  bowX[0]:=1; bowX[1]:=2; bowX[2]:=3; bowX[3]:=4;
  bowX[4]:=3; bowX[5]:=2; bowX[6]:=1; bowX[7]:=0;
  (* West walk 8-15 *)
  bowX[8]:=3; bowX[9]:=2; bowX[10]:=0; bowX[11]:=-2;
  bowX[12]:=-3; bowX[13]:=-2; bowX[14]:=0; bowX[15]:=2;
  (* North walk 16-23 *)
  bowX[16]:=-3; bowX[17]:=-3; bowX[18]:=-3; bowX[19]:=-3;
  bowX[20]:=-3; bowX[21]:=-3; bowX[22]:=-3; bowX[23]:=-2;
  (* East walk 24-31 *)
  bowX[24]:=0; bowX[25]:=1; bowX[26]:=1; bowX[27]:=1;
  bowX[28]:=0; bowX[29]:=-2; bowX[30]:=-3; bowX[31]:=-2;

  bowY[0]:=8; bowY[1]:=8; bowY[2]:=8; bowY[3]:=7;
  bowY[4]:=8; bowY[5]:=8; bowY[6]:=8; bowY[7]:=8;
  bowY[8]:=11; bowY[9]:=12; bowY[10]:=13; bowY[11]:=13;
  bowY[12]:=13; bowY[13]:=13; bowY[14]:=13; bowY[15]:=12;
  bowY[16]:=8; bowY[17]:=7; bowY[18]:=6; bowY[19]:=5;
  bowY[20]:=6; bowY[21]:=7; bowY[22]:=8; bowY[23]:=9;
  bowY[24]:=12; bowY[25]:=12; bowY[26]:=12; bowY[27]:=12;
  bowY[28]:=12; bowY[29]:=12; bowY[30]:=11; bowY[31]:=12;
  bowInited := TRUE
END InitBowOffsets;

PROCEDURE DrawWeaponOverlay(i, sx, sy, frame: INTEGER);
VAR weapon, wpnFrame, objFrame, ox, oy, f, dirGroup: INTEGER;
    srcY, px, py, dx, dy, bx, by: INTEGER;
BEGIN
  IF objTex = NIL THEN RETURN END;
  weapon := actors[i].weapon;
  IF (weapon <= 0) OR (weapon > 5) THEN RETURN END;
  IF (actors[i].state = StDead) OR (actors[i].state = StDying) THEN RETURN END;
  IF actors[i].environ > 4 THEN RETURN END;
  IF NOT wpnInited THEN InitWpnState END;
  IF NOT bowInited THEN InitBowOffsets END;
  IF (frame < 0) OR (frame > 86) THEN RETURN END;

  (* Hide weapon when facing north — weapon is behind actor body *)
  f := actors[i].facing;
  IF (f = 0) OR (f = 1) OR (f = 7) THEN RETURN END;

  (* Bow: special handling for walk frames (0-31) *)
  IF (weapon = 4) AND (frame < 32) THEN
    ox := bowX[frame];
    oy := bowY[frame];
    (* Bow frame: direction group determines which bow sprite.
       Original: group 0(S)→81, 1(W)→30, 2(N)→83, 3(E)→30 *)
    dirGroup := frame DIV 8;
    IF BAND(CARDINAL(dirGroup), 1) # 0 THEN
      objFrame := 30     (* W or E *)
    ELSIF BAND(CARDINAL(dirGroup), 2) # 0 THEN
      objFrame := 83     (* N *)
    ELSE
      objFrame := 81     (* S *)
    END
  ELSIF weapon = 5 THEN
    (* Wand *)
    ox := wpnState[frame].wpnX;
    oy := wpnState[frame].wpnY;
    objFrame := actors[i].facing + 103;
    IF actors[i].facing = 2 THEN DEC(oy, 6) END
  ELSIF weapon = 4 THEN
    (* Bow in fight/shoot frames (>=32): hide overlay —
       the shoot animation is in the character body sprite *)
    RETURN
  ELSE
    (* Hand weapons: dagger/mace/sword *)
    ox := wpnState[frame].wpnX;
    oy := wpnState[frame].wpnY;
    wpnFrame := wpnState[frame].wpnNo;
    CASE weapon OF
      1: objFrame := wpnFrame + 64 |
      2: objFrame := wpnFrame + 32 |
      3: objFrame := wpnFrame + 48
    ELSE
      objFrame := wpnFrame
    END
  END;

  IF (objFrame < 0) OR (objFrame >= 116) THEN RETURN END;

  srcY := objFrame * WpnSprH;
  SetColorMod(objTex, fadeR, fadeG, fadeB);

  (* For player (i=0): draw pixel-by-pixel through bmask so buildings clip weapon.
     For enemies: draw directly since they don't use tile masking yet. *)
  dx := sx - S(8) + S(ox);
  dy := sy - S(16) + S(oy);

  IF i = 0 THEN
    (* Build a fresh bmask at the WEAPON's world position.
       Original: weapon goes through same masking pipeline as character.
       Weapon top-left in world = actor position + weapon offset - sprite center. *)
    BuildSpriteMaskAt(
      actors[0].absX - 8 + ox,
      actors[0].absY - 16 + oy,
      actors[0].absY - camY + 16);
    (* Draw weapon through bmask — pixel coords are now relative to weapon origin *)
    FOR py := 0 TO WpnSprH - 1 DO
      FOR px := 0 TO WpnSprW - 1 DO
        IF (px < SprW) AND (py < SprH) THEN
          IF bmask[px][py] THEN
            DrawTexRegion(objTex, px, srcY + py, 1, 1,
                          dx + px * Scale, dy + py * Scale,
                          Scale, Scale)
          END
        ELSE
          DrawTexRegion(objTex, px, srcY + py, 1, 1,
                        dx + px * Scale, dy + py * Scale,
                        Scale, Scale)
        END
      END
    END
  ELSE
    (* Enemies: also build bmask at weapon position for building clipping *)
    BuildSpriteMaskAt(
      actors[i].absX - 8 + ox,
      actors[i].absY - 16 + oy,
      actors[i].absY - camY + 16);
    FOR py := 0 TO WpnSprH - 1 DO
      FOR px := 0 TO WpnSprW - 1 DO
        IF (px < SprW) AND (py < SprH) THEN
          IF bmask[px][py] THEN
            DrawTexRegion(objTex, px, srcY + py, 1, 1,
                          dx + px * Scale, dy + py * Scale,
                          Scale, Scale)
          END
        ELSE
          DrawTexRegion(objTex, px, srcY + py, 1, 1,
                        dx + px * Scale, dy + py * Scale,
                        Scale, Scale)
        END
      END
    END
  END
END DrawWeaponOverlay;

PROCEDURE DrawBrotherSprite(actorIdx, brotherIdx, frame, sx, sy, env: INTEGER);
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

  (* Apply same day/night fade to sprite *)
  SetColorMod(tex, fadeR, fadeG, fadeB);

  (* Build sprite mask from overlapping tiles *)
  BuildSpriteMaskFor(actorIdx);

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

PROCEDURE RaceToTexIdx(race: INTEGER): INTEGER;
BEGIN
  (* Maps enemy race to enemyTex[] index.
     Original file_id: 0,1→6  2,3,5→7  4,6,7→8  8,9,10→9 *)
  CASE race OF
    0, 1:     RETURN 0 |  (* Ogre/Orc → shape_6 *)
    2, 3, 5:  RETURN 1 |  (* Wraith/Skeleton/Salamander → shape_7 *)
    4, 6, 7:  RETURN 2 |  (* Snake/Spider/DKnight → shape_8 *)
    8, 9, 10: RETURN 3    (* Loraii/Necromancer/Woodcutter → shape_9 *)
  ELSE
    RETURN 0
  END
END RaceToTexIdx;

PROCEDURE DrawEnemySprite(actorIdx, texIdx, frame, sx, sy: INTEGER);
VAR tex: ADDRESS;
    srcY, srcH, px, py, dstY, dstH, clipBot, env: INTEGER;
BEGIN
  IF (texIdx < 0) OR (texIdx > 4) THEN RETURN END;
  tex := enemyTex[texIdx];
  IF tex = NIL THEN RETURN END;
  srcY := frame * SprH;
  srcH := SprH;
  dstY := sy - S(16);
  dstH := S(SprH);

  SetColorMod(tex, fadeR, fadeG, fadeB);

  (* Wraiths (race=2) float over everything — no environ clip, no tile mask *)
  IF actors[actorIdx].race = 2 THEN
    DrawTexRegion(tex, 0, srcY, SprW, SprH,
                  sx - S(8), dstY, S(SprW), S(SprH));
    RETURN
  END;

  (* Environ-based clipping for non-wraith enemies *)
  env := actors[actorIdx].environ;
  clipBot := 0;
  IF env = 2 THEN
    clipBot := 10
  ELSIF env > 2 THEN
    clipBot := env;
    IF clipBot > SprH - 4 THEN clipBot := SprH - 4 END
  END;
  IF clipBot > 0 THEN
    DEC(srcH, clipBot);
    DEC(dstH, S(clipBot))
  END;
  IF srcH <= 0 THEN RETURN END;

  (* All other enemies get tile masking like the player *)
  BuildSpriteMaskFor(actorIdx);
  FOR py := 0 TO srcH - 1 DO
    FOR px := 0 TO SprW - 1 DO
      IF bmask[px][py] THEN
        DrawTexRegion(tex, px, srcY + py, 1, 1,
                      sx - S(8) + px * Scale, dstY + py * Scale,
                      Scale, Scale)
      END
    END
  END
END DrawEnemySprite;

(* Get the statelist index for weapon overlay positioning *)
PROCEDURE GetStateIdx(i: INTEGER): INTEGER;
VAR base: INTEGER;
BEGIN
  IF actors[i].state = StWalking THEN
    RETURN WalkBase(actors[i].facing) + ((cycle + i) MOD 8)
  ELSIF actors[i].state = StFighting THEN
    base := FightBase(actors[i].facing);
    RETURN base + ((cycle + i) DIV 2) MOD 12
  ELSIF (actors[i].state = StDying) OR (actors[i].state = StDead) THEN
    RETURN 80
  ELSE
    RETURN WalkBase(actors[i].facing) + 1
  END
END GetStateIdx;

PROCEDURE DrawActorBody(i, sx, sy: INTEGER);
VAR frame, texIdx, stateIdx, mx, my, npcBank, npcFrame: INTEGER;
BEGIN
  IF (i = 0) AND (brotherTex[activeBrother] # NIL) THEN
    frame := GetPlayerFrame(i);
    stateIdx := GetStateIdx(i);
    (* When riding, offset player UP to appear on top of carrier *)
    IF riding # 0 THEN
      DrawBrotherSprite(i, activeBrother, frame, sx, sy - S(10), actors[i].environ)
    ELSE
      DrawBrotherSprite(i, activeBrother, frame, sx, sy, actors[i].environ)
    END;
    IF riding = 0 THEN
      DrawWeaponOverlay(i, sx, sy, stateIdx)
    END;
    RETURN
  END;

  (* Enemy sprites *)
  IF actors[i].actorType = TypeEnemy THEN
    texIdx := RaceToTexIdx(actors[i].race);
    IF enemyTex[texIdx] # NIL THEN
      frame := GetEnemyFrame(i);
      stateIdx := GetStateIdx(i);
      DrawEnemySprite(i, texIdx, frame, sx, sy);
      DrawWeaponOverlay(i, sx, sy, stateIdx);
      RETURN
    END
  END;

  (* NPC / SETFIG sprites — with tile masking like player/enemies.
     Original: king (race 5) and sorceress (race 7) skip masking entirely
     (fmain.c:3578 — goto nomask for race 0x85, 0x87). *)
  IF actors[i].actorType = TypeSetfig THEN
    GetSetfigSprite(actors[i].race, npcBank, npcFrame);
    IF (npcBank >= 0) AND (npcBank <= 4) AND (npcTex[npcBank] # NIL) THEN
      SetColorMod(npcTex[npcBank], fadeR, fadeG, fadeB);
      IF (actors[i].race = 5) OR (actors[i].race = 7) THEN
        (* King/sorceress: no masking — clear mask to all visible *)
        FOR my := 0 TO SprH - 1 DO
          FOR mx := 0 TO SprW - 1 DO bmask[mx][my] := TRUE END
        END
      ELSE
        BuildSpriteMaskFor(i)
      END;
      FOR my := 0 TO SprH - 1 DO
        FOR mx := 0 TO SprW - 1 DO
          IF bmask[mx][my] THEN
            DrawTexRegion(npcTex[npcBank],
                          mx, npcFrame * SprH + my, 1, 1,
                          sx - S(8) + mx * Scale,
                          sy - S(16) + my * Scale,
                          Scale, Scale)
          END
        END
      END;
      RETURN
    END
  END;

  (* Raft — 32x32 sprite, 2 frames *)
  IF actors[i].actorType = TypeRaft THEN
    IF raftTex # NIL THEN
      SetColorMod(raftTex, fadeR, fadeG, fadeB);
      DrawTexRegion(raftTex, 0, 0, 32, 32,
                    sx - S(16), sy - S(16), S(32), S(32))
    END;
    RETURN
  END;

  (* Carrier — turtle (32x32, 16 frames) or swan (64x64, 8 frames) *)
  IF actors[i].actorType = TypeCarrier THEN
    IF actors[i].race = 5 THEN
      (* Turtle: 16 frames, 2 per direction.
         Sheet order (top→bottom): NW,N,NE,E,SE,S,SW,W
         Our facing: N=0,NE=1,E=2,SE=3,S=4,SW=5,W=6,NW=7
         Remap: (facing + 1) MOD 8 *)
      IF turtleTex # NIL THEN
        frame := ((actors[i].facing + 1) MOD 8) * 2 + (cycle DIV 4 MOD 2);
        SetColorMod(turtleTex, fadeR, fadeG, fadeB);
        DrawTexRegion(turtleTex, 0, frame * 32, 32, 32,
                      sx - S(16), sy - S(16), S(32), S(32))
      END
    ELSIF actors[i].race = 11 THEN
      (* Swan/Bird: frame based on facing, 64x64 *)
      IF birdTex # NIL THEN
        frame := actors[i].facing MOD 8;
        SetColorMod(birdTex, fadeR, fadeG, fadeB);
        DrawTexRegion(birdTex, 0, frame * 64, 64, 64,
                      sx - S(32), sy - S(32), S(64), S(64))
      END
    END;
    RETURN
  END;

  (* Fallback: colored rectangles *)
  IF actors[i].actorType = TypeEnemy THEN
    SetColor(ren, 200, 40, 40, 255)
  ELSE
    SetColor(ren, 60, 160, 220, 255)
  END;
  FillRect(ren, sx - S(4), sy - S(6), S(8), S(12));
  SetColor(ren, 0, 0, 0, 255);
  DrawRect(ren, sx - S(4), sy - S(6), S(8), S(12))
END DrawActorBody;

PROCEDURE DrawActors;
VAR i, j, sx, sy, n, tmp: INTEGER;
    order: ARRAY [0..19] OF INTEGER;  (* actor indices sorted by Y *)
BEGIN
  SetClip(ren, 0, 0, S(PlayW), S(PlayH));

  (* Build sorted draw order by absY — actors further back draw first.
     Simple insertion sort on small array.
     When riding, player sorts slightly ahead of carrier so player
     draws on top (closer to camera). *)
  n := 0;
  FOR i := 0 TO actorCount - 1 DO
    order[n] := i;
    j := n;
    sy := actors[i].absY;
    IF (i = 0) AND (riding # 0) THEN INC(sy) END;
    WHILE (j > 0) DO
      tmp := actors[order[j-1]].absY;
      IF (order[j-1] = 0) AND (riding # 0) THEN INC(tmp) END;
      IF tmp <= sy THEN EXIT END;  (* use <= so equal Y preserves order *)
      order[j] := order[j-1];
      DEC(j)
    END;
    order[j] := i;
    INC(n)
  END;

  FOR j := 0 TO n - 1 DO
    i := order[j];
    sx := (actors[i].absX - camX) * Scale;
    sy := (actors[i].absY - camY) * Scale;
    IF (sx > -S(20)) AND (sx < S(PlayW) + 20) AND
       (sy > -S(20)) AND (sy < S(PlayH) + 20) THEN
      DrawActorBody(i, sx, sy)
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
VAR dir, cx, cy, dx, dy, sz: INTEGER;
    (* Compass direction offsets: dx,dy from center for each direction.
       Our dirs: 0=N,1=NE,2=E,3=SE,4=S,5=SW,6=W,7=NW *)
    ox, oy: ARRAY [0..7] OF INTEGER;
BEGIN
  dir := actors[0].facing;
  IF (dir < 0) OR (dir > 7) THEN RETURN END;

  (* Compass center in screen coords.
     HUD compass center is at ~(591, 27) in 640x57 space *)
  cx := 591 * ScreenW * Scale DIV 640;
  cy := PlayH * Scale + 27 * TextH * Scale DIV 57;
  sz := 5 * ScreenW * Scale DIV 640;  (* pip size *)
  IF sz < 3 THEN sz := 3 END;

  (* Direction offsets from center in screen pixels *)
  dx := 11 * ScreenW * Scale DIV 640;
  dy := 11 * TextH * Scale DIV 57;

  ox[0] :=  0; oy[0] := -dy;   (* N *)
  ox[1] :=  dx; oy[1] := -dy;  (* NE *)
  ox[2] :=  dx; oy[2] :=  0;   (* E *)
  ox[3] :=  dx; oy[3] :=  dy;  (* SE *)
  ox[4] :=  0; oy[4] :=  dy;   (* S *)
  ox[5] := -dx; oy[5] :=  dy;  (* SW *)
  ox[6] := -dx; oy[6] :=  0;   (* W *)
  ox[7] := -dx; oy[7] := -dy;  (* NW *)

  (* Draw filled green diamond at active direction *)
  SetColor(ren, 0, 176, 0, 255);
  FillRect(ren, cx + ox[dir] - sz, cy + oy[dir] - sz DIV 2, sz * 2, sz);
  SetColor(ren, 0, 220, 0, 255);
  FillRect(ren, cx + ox[dir] - sz + 1, cy + oy[dir] - sz DIV 2 + 1, sz * 2 - 2, sz - 2)
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
  LabelOff = 4;    (* label inset from button left *)
  LabelChars = 6;  (* chars per label *)
VAR j, optIdx, col, penb, bx, by: INTEGER;
    bgR, bgG, bgB, fgR, fgG, fgB: INTEGER;
    selected: BOOLEAN;
    label: ARRAY [0..5] OF CHAR;
BEGIN
  FOR j := 0 TO optionCount - 1 DO
    optIdx := realOptions[j];
    IF optIdx < 0 THEN (* skip *)
    ELSE
      selected := BAND(CARDINAL(menus[cmode].enabled[optIdx]), 1) # 0;

      col := j MOD 2;
      bx := PanelX + col * BtnW;
      by := PanelY + (j DIV 2) * BtnH;

      IF optIdx < 5 THEN
        penb := 4
      ELSE
        penb := menus[cmode].color
      END;
      PalColor(penb, bgR, bgG, bgB);

      IF selected THEN
        fgR := 255; fgG := 255; fgB := 255
      ELSE
        fgR := 0; fgG := 0; fgB := 0
      END;

      GetOptionLabel(optIdx, label);
      DrawMenuStr(ren, label, bx, by, LabelChars, LabelOff,
                  fgR, fgG, fgB, bgR, bgG, bgB)
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

PROCEDURE AppendInt(VAR buf: ARRAY OF CHAR; VAR pos: INTEGER; n: INTEGER);
VAR i, len: INTEGER;
    tmp: ARRAY [0..7] OF CHAR;
BEGIN
  IF n < 0 THEN n := 0 END;
  len := 0;
  IF n = 0 THEN
    tmp[0] := '0'; len := 1
  ELSE
    WHILE n > 0 DO
      tmp[len] := CHR(ORD('0') + (n MOD 10));
      n := n DIV 10;
      INC(len)
    END
  END;
  FOR i := len - 1 TO 0 BY -1 DO
    IF pos <= HIGH(buf) THEN
      buf[pos] := tmp[i]; INC(pos)
    END
  END;
  IF pos <= HIGH(buf) THEN buf[pos] := 0C END
END AppendInt;

PROCEDURE BuildStat(label: ARRAY OF CHAR; val: INTEGER;
                    VAR buf: ARRAY OF CHAR);
VAR i, p: INTEGER;
BEGIN
  p := 0;
  i := 0;
  WHILE (i <= HIGH(label)) AND (label[i] # 0C) DO
    IF p <= HIGH(buf) THEN buf[p] := label[i]; INC(p) END;
    INC(i)
  END;
  AppendInt(buf, p, val)
END BuildStat;

PROCEDURE DrawMessage;
CONST
  (* All coordinates in original 640x57 HUD space.
     HudFont maps to screen internally. *)
  TXMIN = 16;   (* left edge of text area *)
  TYMIN = 5;    (* top of text area *)
  RowH  = 10;   (* pixels per row *)
  StatY = 45;   (* stat strip baseline *)
VAR row: INTEGER;
    line: ARRAY [0..39] OF CHAR;
    statBuf: ARRAY [0..15] OF CHAR;
BEGIN
  (* Draw 4-line message log *)
  FOR row := 0 TO 3 DO
    GetLine(row, line);
    IF line[0] # 0C THEN
      DrawHudStr(ren, line, TXMIN, TYMIN + row * RowH)
    END
  END;

  (* Draw stat strip — original coordinates from ppick() case 7 and 4 *)
  BuildStat("Brv:", GetStatBrv(), statBuf);
  DrawHudStr(ren, statBuf, 14, StatY);

  BuildStat("Lck:", GetStatLck(), statBuf);
  DrawHudStr(ren, statBuf, 90, StatY);

  BuildStat("Knd:", GetStatKnd(), statBuf);
  DrawHudStr(ren, statBuf, 168, StatY);

  BuildStat("Vit:", GetStatVit(), statBuf);
  DrawHudStr(ren, statBuf, 245, StatY);

  BuildStat("Wlth:", GetStatWlth(), statBuf);
  DrawHudStr(ren, statBuf, 321, StatY);

  logDirty := FALSE;
  statDirty := FALSE
END DrawMessage;

(* --- Graphical inventory screen (viewstatus=4) ---
   Original: clears play area to black, draws item sprites from objects sheet.
   inv_list: image_number*80+img_off = source Y in objects bitplane data.
   But our objTex is 16px wide with 16px tall frames stacked vertically.
   Original objects are 16px wide, variable height (img_height).
   image_number selects the 16x16 frame, img_off selects a sub-region. *)

PROCEDURE DrawInventory;

  PROCEDURE DrawInvSlot(imgNum, xoff, yoff, ydelta, imgOff, imgH,
                        maxShow, count: INTEGER);
  VAR i, srcY, dx, dy: INTEGER;
  BEGIN
    IF objTex = NIL THEN RETURN END;
    SetColorMod(objTex, 255, 255, 255);  (* full brightness for inventory *)
    IF count <= 0 THEN RETURN END;
    IF count > maxShow THEN count := maxShow END;
    (* Source: frame imgNum in the 16x16 objects sheet, sub-region imgOff..imgOff+imgH *)
    srcY := imgNum * 16 + imgOff;
    (* Dest: play area coordinates at Scale *)
    dx := S(xoff + 20);
    dy := S(yoff);
    FOR i := 0 TO count - 1 DO
      DrawTexRegion(objTex,
                    0, srcY, 16, imgH,
                    dx, dy, S(16), S(imgH));
      INC(dy, S(ydelta))
    END
  END DrawInvSlot;

VAR b, i: INTEGER;
    (* stuff array: maps inv_list indices to our inventory.
       0-4=weapons, 5-7=special, 8=arrows, 9-14=magic, 15-21=keys,
       22-30=quest items. We map what we track. *)
    stuff: ARRAY [0..34] OF INTEGER;
BEGIN
  b := activeBrother;

  (* Read directly from brothers[].stuff[] — the authoritative inventory.
     stuff[0..4] are weapons (Dirk,Mace,Sword,Bow,Wand). *)
  FOR i := 0 TO 34 DO stuff[i] := brothers[b].stuff[i] END;

  (* Clear play area to black *)
  SetColor(ren, 0, 0, 0, 255);
  FillRect(ren, 0, 0, S(PlayW), S(PlayH));

  (* Draw each item from inv_list at its original position.
     inv_list data: {image_number, xoff, yoff, ydelta, img_off, img_height, maxshown} *)
  DrawInvSlot(12, 10,  0,  0, 0, 8,  1, stuff[0]);   (* Dirk *)
  DrawInvSlot( 9, 10, 10,  0, 0, 8,  1, stuff[1]);   (* Mace *)
  DrawInvSlot( 8, 10, 20,  0, 0, 8,  1, stuff[2]);   (* Sword *)
  DrawInvSlot(10, 10, 30,  0, 0, 8,  1, stuff[3]);   (* Bow *)
  DrawInvSlot(17, 10, 40,  0, 8, 8,  1, stuff[4]);   (* Wand *)
  DrawInvSlot(27, 10, 50,  0, 0, 8,  1, stuff[5]);   (* Lasso *)
  DrawInvSlot(23, 10, 60,  0, 8, 8,  1, stuff[6]);   (* Shell *)
  DrawInvSlot(27, 10, 70,  0, 8, 8,  1, stuff[7]);   (* Sun Stone *)
  DrawInvSlot( 3, 30,  0,  3, 7, 1, 45, stuff[8]);   (* Arrows *)
  DrawInvSlot(18, 50,  0,  9, 0, 8, 15, stuff[9]);   (* Blue Stone *)
  DrawInvSlot(19, 65,  0,  6, 0, 5, 23, stuff[10]);  (* Green Jewel *)
  DrawInvSlot(22, 80,  0,  8, 0, 7, 17, stuff[11]);  (* Glass Vial *)
  DrawInvSlot(21, 95,  0,  7, 0, 6, 20, stuff[12]);  (* Crystal Orb *)
  DrawInvSlot(23,110,  0, 10, 0, 9, 14, stuff[13]);  (* Bird Totem *)
  DrawInvSlot(17,125,  0,  6, 0, 5, 23, stuff[14]);  (* Gold Ring *)
  DrawInvSlot(24,140,  0, 10, 0, 9, 14, stuff[15]);  (* Jade Skull *)
  DrawInvSlot(25,160,  0,  5, 0, 5, 25, stuff[16]);  (* Gold Key *)
  DrawInvSlot(25,172,  0,  5, 8, 5, 25, stuff[17]);  (* Green Key *)
  DrawInvSlot(114,184, 0,  5, 0, 5, 25, stuff[18]);  (* Blue Key *)
  DrawInvSlot(114,196, 0,  5, 8, 5, 25, stuff[19]);  (* Red Key *)
  DrawInvSlot(26,208,  0,  5, 0, 5, 25, stuff[20]);  (* Grey Key *)
  DrawInvSlot(26,220,  0,  5, 8, 5, 25, stuff[21]);  (* White Key *)
  DrawInvSlot(11,  0, 80,  0, 8, 8,  1, stuff[22]);  (* Talisman *)
  DrawInvSlot(19,  0, 90,  0, 8, 8,  1, stuff[23]);  (* Rose *)
  DrawInvSlot(20,  0,100,  0, 8, 8,  1, stuff[24]);  (* Fruit *)
  DrawInvSlot(21,232,  0, 10, 8, 8,  5, stuff[25]);  (* Gold Statue *)
  DrawInvSlot(22,  0,110,  0, 8, 8,  1, stuff[26]);  (* Book *)
  DrawInvSlot( 8, 14, 80,  0, 8, 8,  1, stuff[27]);  (* Herb *)
  DrawInvSlot( 9, 14, 90,  0, 8, 8,  1, stuff[28]);  (* Writ *)
  DrawInvSlot(10, 14,100,  0, 8, 8,  1, stuff[29]);  (* Bone *)
  DrawInvSlot(12, 14,110,  0, 8, 8,  1, stuff[30])   (* Shard *)
END DrawInventory;

PROCEDURE DrawFairy;
VAR sx, sy, sprY: INTEGER;
BEGIN
  IF objTex = NIL THEN RETURN END;
  IF NOT fairyActive THEN RETURN END;
  SetColorMod(objTex, 255, 255, 255);
  sx := (fairyX - camX) * Scale;
  sy := (actors[0].absY - camY) * Scale;
  sprY := (100 + (cycle MOD 2)) * 16;  (* frames 100-101 alternate *)
  DrawTexRegion(objTex, 0, sprY, 16, 16,
                sx - S(8), sy - S(8), S(16), S(16))
END DrawFairy;

END Render.

