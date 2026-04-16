IMPLEMENTATION MODULE Compass;

(* Compass direction indicator — uses pre-rendered BMP files
   with magenta color key, same approach as all other sprites. *)

FROM Gfx IMPORT Renderer;
FROM Texture IMPORT Tex;
FROM Platform IMPORT PlayH, Scale, LoadBMPKeyedTexture, DrawTexRegion;
FROM Assets IMPORT AssetPath;
FROM Strings IMPORT Assign;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;

CONST
  CompW = 48;
  CompH = 25;
  CompScrX = 850;
  CompScrY = 45;
  CompScrW = 72;
  CompScrH = 75;

VAR
  dirTex: ARRAY [0..8] OF Tex;

PROCEDURE InitCompass(ren: Renderer);
VAR i: INTEGER;
    p, num: ARRAY [0..127] OF CHAR;
BEGIN
  FOR i := 0 TO 8 DO
    CASE i OF
      0: Assign("compass_0.bmp", num) |
      1: Assign("compass_1.bmp", num) |
      2: Assign("compass_2.bmp", num) |
      3: Assign("compass_3.bmp", num) |
      4: Assign("compass_4.bmp", num) |
      5: Assign("compass_5.bmp", num) |
      6: Assign("compass_6.bmp", num) |
      7: Assign("compass_7.bmp", num) |
      8: Assign("compass_8.bmp", num)
    ELSE
      Assign("compass_8.bmp", num)
    END;
    AssetPath(num, p);
    dirTex[i] := LoadBMPKeyedTexture(p, 255, 0, 255);
    IF dirTex[i] = NIL THEN
      WriteString("Compass FAIL: "); WriteString(num); WriteLn
    ELSE
      WriteString("Compass OK: "); WriteString(num); WriteLn
    END
  END
END InitCompass;

PROCEDURE DrawCompass(ren: Renderer; dir: INTEGER);
VAR origDir, hudY: INTEGER;
    tex: Tex;
BEGIN
  hudY := PlayH * Scale;

  IF (dir >= 0) AND (dir <= 7) THEN
    CASE dir OF
      0: origDir := 1 |
      1: origDir := 2 |
      2: origDir := 3 |
      3: origDir := 4 |
      4: origDir := 5 |
      5: origDir := 6 |
      6: origDir := 7 |
      7: origDir := 0
    ELSE
      origDir := 8
    END
  ELSE
    origDir := 8
  END;

  tex := dirTex[origDir];
  IF tex = NIL THEN RETURN END;

  DrawTexRegion(tex, 0, 0, CompW, CompH,
                CompScrX, hudY + CompScrY, CompScrW, CompScrH)
END DrawCompass;

END Compass.
