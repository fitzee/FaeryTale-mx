IMPLEMENTATION MODULE WorldObj;

FROM SYSTEM IMPORT ADDRESS;
FROM Platform IMPORT ren, Scale, PlayW, PlayH, DrawTexRegion,
                    LoadBMPKeyedTexture;
FROM Canvas IMPORT SetClip, ClearClip;
FROM World IMPORT camX, camY;
FROM Assets IMPORT currentRegion, AssetPath;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;

CONST
  ObjSprW = 16;
  ObjSprH = 16;

PROCEDURE S(v: INTEGER): INTEGER;
BEGIN RETURN v * Scale END S;

PROCEDURE AddObj(x, y, id, stat, reg: INTEGER);
BEGIN
  IF objCount >= MaxWorldObjs THEN RETURN END;
  objects[objCount].x := x;
  objects[objCount].y := y;
  objects[objCount].objId := id;
  objects[objCount].status := stat;
  objects[objCount].region := reg;
  INC(objCount)
END AddObj;

PROCEDURE InitWorldObjects;
BEGIN
  objCount := 0;
  objTex := NIL;

  (* === Global objects (region -1) === *)
  AddObj(19316, 15747, 11, 0, -1);   (* ghost brother 1 *)
  AddObj(18196, 15735, 11, 0, -1);   (* ghost brother 2 *)
  AddObj(12439, 36202, 10, 3, -1);   (* spectre *)
  AddObj(11092, 38526, 149, 1, -1);  (* gold statue *)
  AddObj(25737, 10662, 149, 1, -1);  (* gold statue *)
  AddObj( 2910, 39023, 149, 1, -1);  (* gold statue *)
  AddObj(12025, 37639, 149, 0, -1);  (* gold statue *)
  AddObj( 6700, 33766, 149, 0, -1);  (* gold statue *)

  (* === Region 0 — Snow Land === *)
  AddObj( 3340,  6735, 12, 3, 0);
  AddObj( 9678,  7035, 12, 3, 0);
  AddObj( 4981,  6306, 12, 3, 0);

  (* === Region 1 — Maze Forest North === *)
  AddObj(23087,  5667, 102, 5, 1);   (* turtle eggs — not pickable *)

  (* === Region 2 — Swamp Land === *)
  AddObj(13668, 15000,  0, 3, 2);
  AddObj(10627, 13154,  0, 3, 2);
  AddObj( 4981, 10056, 12, 3, 2);
  AddObj(13950, 11087, 16, 1, 2);    (* sacks *)
  AddObj(10344, 36171, 151, 1, 2);   (* shell *)

  (* === Region 3 — Tambry / Manor / Maze South === *)
  AddObj(19298, 16128, 15, 1, 3);    (* chest *)
  AddObj(18310, 15969, 13, 3, 3);    (* beggar *)
  AddObj(20033, 14401,  0, 3, 3);    (* wizard *)
  AddObj(24794, 13102, 13, 3, 3);    (* beggar *)
  AddObj(21626, 15446, 18, 1, 3);    (* blue stone *)
  AddObj(21616, 15456, 13, 1, 3);    (* money *)
  AddObj(21636, 15456, 17, 1, 3);    (* gold ring *)
  AddObj(20117, 14222, 19, 1, 3);    (* green jewel *)
  AddObj(24185,  9840, 16, 1, 3);    (* sacks *)
  AddObj(25769, 10617, 13, 1, 3);    (* money *)
  AddObj(25678, 10703, 18, 1, 3);    (* blue stone *)
  AddObj(17177, 10599, 20, 1, 3);    (* scrap *)

  (* === Region 4 — Desert === *)
  AddObj( 6817, 19693, 13, 3, 4);    (* beggar *)

  (* === Region 5 — Farm and City === *)
  AddObj(22184, 21156, 13, 3, 5);    (* beggar *)
  AddObj(18734, 17595, 17, 1, 5);    (* gold ring *)
  AddObj(21294, 22648, 15, 1, 5);    (* chest *)
  AddObj(22956, 19955,  0, 3, 5);    (* wizard *)
  AddObj(28342, 22613,  0, 3, 5);    (* wizard *)

  (* === Region 6 — Lava Plain === *)
  AddObj(24794, 13102, 13, 3, 6);

  (* === Region 7 — Southern Mountain === *)
  AddObj(23297,  5797, 102, 5, 7);   (* turtle eggs — not pickable *)

  (* === Region 8 — Building Interiors (key items only) === *)
  (* NPCs *)
  AddObj( 6700, 33756,  1, 3, 8);    (* priest *)
  AddObj( 5491, 33780,  5, 3, 8);    (* king *)
  AddObj( 5592, 33764,  6, 3, 8);    (* noble *)
  AddObj( 8878, 38995,  0, 3, 8);    (* wizard *)
  AddObj( 7776, 34084,  0, 3, 8);    (* wizard *)
  AddObj(10853, 35656,  4, 3, 8);    (* princess *)
  AddObj(12037, 37614,  7, 3, 8);    (* sorceress *)
  AddObj(11013, 36804,  9, 3, 8);    (* witch *)
  AddObj( 9631, 38953,  8, 3, 8);    (* bartender *)
  AddObj(10191, 38953,  8, 3, 8);    (* bartender *)
  AddObj(10649, 38953,  8, 3, 8);    (* bartender *)
  AddObj( 2966, 33964,  8, 3, 8);    (* bartender *)
  (* Collectible items *)
  AddObj(11410, 36169, 155, 1, 8);   (* sunstone *)
  AddObj( 9575, 39459, 14, 1, 8);    (* urn *)
  AddObj( 9590, 39459, 14, 1, 8);    (* urn *)
  AddObj( 9605, 39459, 14, 1, 8);    (* urn *)
  AddObj( 9680, 39453, 22, 1, 8);    (* vial *)
  AddObj( 9682, 39453, 22, 1, 8);    (* vial *)
  AddObj( 9784, 39453, 22, 1, 8);    (* vial *)
  AddObj( 9668, 39554, 15, 1, 8);    (* chest *)
  AddObj(11090, 39462, 13, 1, 8);    (* money *)
  AddObj(11909, 36198, 15, 1, 8);    (* chest *)
  AddObj(12212, 38481, 15, 1, 8);    (* chest *)
  AddObj(11652, 38481, 242, 1, 8);   (* red key *)
  AddObj(10059, 38472, 16, 1, 8);    (* sacks *)
  AddObj(10344, 36171, 151, 1, 8);   (* shell *)
  AddObj(11936, 36207, 20, 1, 8);    (* scrap/note *)
  AddObj( 9674, 35687, 14, 1, 8);    (* urn *)

  (* === Region 8 — Hidden 'look' items (ob_stat=5) === *)
  AddObj( 3872, 33546, 25, 5, 8);    (* gold key *)
  AddObj( 3887, 33510, 23, 5, 8);    (* totem *)
  AddObj( 4495, 33510, 22, 5, 8);    (* vial *)
  AddObj( 3327, 33383, 24, 5, 8);    (* jade skull *)
  AddObj( 4221, 34119, 11, 5, 8);    (* quiver *)
  AddObj( 7610, 33604, 22, 5, 8);    (* vial *)
  AddObj( 7616, 33522, 13, 5, 8);    (* money *)
  AddObj( 9570, 35768, 18, 5, 8);    (* blue stone *)
  AddObj( 9668, 35769, 11, 5, 8);    (* quiver *)
  AddObj( 9553, 38951, 17, 5, 8);    (* gold ring *)
  AddObj(10062, 39005, 24, 5, 8);    (* jade skull *)
  AddObj(10577, 38951, 22, 5, 8);    (* vial *)
  AddObj(11062, 39514, 13, 5, 8);    (* money *)
  AddObj( 8845, 39494,154, 5, 8);    (* white key *)

  (* === Region 9 — Underground === *)
  AddObj( 7540, 38528, 145, 1, 9);   (* magic wand *)
  AddObj( 9624, 36559, 145, 1, 9);   (* magic wand *)
  AddObj( 9624, 37459, 145, 1, 9);   (* magic wand *)
  AddObj( 8337, 36719, 145, 1, 9);   (* magic wand *)
  AddObj( 8154, 34890, 15, 1, 9);    (* chest *)
  AddObj( 7826, 35741, 15, 1, 9);    (* chest *)
  AddObj( 3460, 37260,  0, 3, 9);    (* wizard *)
  AddObj( 8485, 35725, 13, 1, 9);    (* money *)
  AddObj( 3723, 39340, 138, 1, 9);   (* king's bone *)

  WriteString("World: "); WriteInt(objCount, 1);
  WriteString(" objects placed"); WriteLn
END InitWorldObjects;

PROCEDURE LoadObjectSprites;
VAR p: ARRAY [0..127] OF CHAR;
BEGIN
  AssetPath("objects.bmp", p);
  objTex := LoadBMPKeyedTexture(p, 255, 0, 255);
  IF objTex = NIL THEN
    WriteString("World: object sprites failed"); WriteLn
  ELSE
    WriteString("World: object sprites loaded"); WriteLn
  END
END LoadObjectSprites;

PROCEDURE DrawWorldObjects;
VAR i, sx, sy, sprY, ht, id: INTEGER;
BEGIN
  IF objTex = NIL THEN RETURN END;

  SetClip(ren, 0, 0, S(PlayW), S(PlayH));

  FOR i := 0 TO objCount - 1 DO
    IF ((objects[i].status = 1) OR
        (revealHidden AND (objects[i].status = 5))) AND
       ((objects[i].region = currentRegion) OR
        (objects[i].region = -1)) THEN
      sx := (objects[i].x - camX) * Scale;
      sy := (objects[i].y - camY) * Scale;
      IF (sx > -S(20)) AND (sx < S(PlayW) + 20) AND
         (sy > -S(20)) AND (sy < S(PlayH) + 20) THEN
        sprY := objects[i].objId * ObjSprH;
        (* Original: certain objects render at half height (8px).
           if inum==27 || (inum>=8 && inum<=12) || inum==25 || inum==26 ||
              (inum>16 && inum<24) || (inum & 128)  → ysize=8 *)
        ht := ObjSprH;
        id := objects[i].objId;
        IF (id = 27) OR ((id >= 8) AND (id <= 12)) OR
           (id = 25) OR (id = 26) OR
           ((id > 16) AND (id < 24)) OR
           (BAND(CARDINAL(id), 128) # 0) THEN
          ht := 8
        END;
        IF sprY + ht <= 1856 THEN
          DrawTexRegion(objTex,
                        0, sprY, ObjSprW, ht,
                        sx - S(8), sy - S(ht DIV 2),
                        S(ObjSprW), S(ht))
        END
      END
    END
  END;

  ClearClip(ren)
END DrawWorldObjects;

PROCEDURE CheckObjectPickup(heroX, heroY: INTEGER): INTEGER;
VAR i, dx, dy, id: INTEGER;
BEGIN
  FOR i := 0 TO objCount - 1 DO
    IF ((objects[i].status = 1) OR
        (revealHidden AND (objects[i].status = 5))) AND
       ((objects[i].region = currentRegion) OR
        (objects[i].region = -1)) THEN
      dx := heroX - objects[i].x;
      dy := heroY - objects[i].y;
      IF (dx < 16) AND (dx > -16) AND (dy < 16) AND (dy > -16) THEN
        id := objects[i].objId;
        objects[i].status := 2;  (* picked up *)
        RETURN id
      END
    END
  END;
  RETURN -1
END CheckObjectPickup;

END WorldObj.
