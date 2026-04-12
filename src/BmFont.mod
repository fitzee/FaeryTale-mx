IMPLEMENTATION MODULE BmFont;

FROM SYSTEM IMPORT ADDRESS;
FROM Gfx IMPORT Renderer;
FROM Texture IMPORT LoadBMPKeyed, DrawRegion AS TexDrawRegion, Tex,
                    SetBlendMode, SetColorMod;
FROM Canvas IMPORT BLEND_ALPHA;

VAR
  fontTex: Tex;

PROCEDURE LoadFont(ren: Renderer; path: ARRAY OF CHAR): BOOLEAN;
BEGIN
  (* Load with black as transparent color key *)
  fontTex := LoadBMPKeyed(ren, path, 0, 0, 0);
  IF fontTex = NIL THEN RETURN FALSE END;
  SetBlendMode(fontTex, BLEND_ALPHA);
  RETURN TRUE
END LoadFont;

PROCEDURE SetFontColor(r, g, b: INTEGER);
BEGIN
  IF fontTex # NIL THEN
    SetColorMod(fontTex, r, g, b)
  END
END SetFontColor;

PROCEDURE DrawChar(ren: Renderer; ch: CHAR; x, y, scale: INTEGER);
VAR sx: INTEGER;
BEGIN
  IF fontTex = NIL THEN RETURN END;
  IF (ORD(ch) < LoChar) OR (ORD(ch) >= LoChar + NumGlyphs) THEN RETURN END;
  sx := (ORD(ch) - LoChar) * GlyphW;
  TexDrawRegion(ren, fontTex,
                sx, 0, GlyphW, GlyphH,
                x, y, GlyphW * scale, GlyphH * scale)
END DrawChar;

PROCEDURE DrawStr(ren: Renderer; s: ARRAY OF CHAR; x, y, scale: INTEGER);
VAR i, cx: INTEGER;
BEGIN
  cx := x;
  i := 0;
  WHILE (i <= HIGH(s)) AND (s[i] # 0C) DO
    DrawChar(ren, s[i], cx, y, scale);
    INC(cx, GlyphW * scale);
    INC(i)
  END
END DrawStr;

PROCEDURE DrawStrSized(ren: Renderer; s: ARRAY OF CHAR;
                       x, y, cw, ch: INTEGER);
VAR i, cx, sx: INTEGER;
BEGIN
  IF fontTex = NIL THEN RETURN END;
  cx := x;
  i := 0;
  WHILE (i <= HIGH(s)) AND (s[i] # 0C) DO
    IF (ORD(s[i]) >= LoChar) AND (ORD(s[i]) < LoChar + NumGlyphs) THEN
      sx := (ORD(s[i]) - LoChar) * GlyphW;
      TexDrawRegion(ren, fontTex,
                    sx, 0, GlyphW, GlyphH,
                    cx, y, cw, ch)
    END;
    INC(cx, cw);
    INC(i)
  END
END DrawStrSized;

END BmFont.
