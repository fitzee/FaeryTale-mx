IMPLEMENTATION MODULE Intro;

(* Opening credits: book cover zoom-in, three page spreads with
   page-flip animation, then zoom-out. Matching original FTA intro. *)

FROM SYSTEM IMPORT ADDRESS;
FROM Platform IMPORT ren, ScreenW, ScreenH, PlayW, PlayH, Scale,
                    GetTicks, DelayMs, BeginFrame, EndFrame,
                    LoadBMPTexture, PollInput, InputState, DirNone;
FROM Texture IMPORT Tex, Draw AS TexDraw, DrawRegion AS TexDrawRegion;
FROM Canvas IMPORT SetColor, Clear;
FROM Assets IMPORT AssetPath;
FROM Music IMPORT SetMood;
FROM GameState IMPORT FrameTime;
FROM InOut IMPORT WriteString, WriteLn;

CONST
  MoodIntro = 16;
  PageW = 320;
  PageH = 200;

VAR
  cover, spread1, spread2, spread3: Tex;
  skipped: BOOLEAN;
  introTick: INTEGER;

PROCEDURE LoadPage(name: ARRAY OF CHAR): Tex;
VAR p: ARRAY [0..127] OF CHAR;
BEGIN
  AssetPath(name, p);
  RETURN LoadBMPTexture(p)
END LoadPage;

PROCEDURE PumpAndCheck(): BOOLEAN;
VAR inp: InputState;
    result: BOOLEAN;
BEGIN
  inp.attack := FALSE; inp.quit := FALSE; inp.mouseClick := FALSE;
  inp.dirKey := DirNone; inp.menuKey := 0C;
  PollInput(inp);
  IF introTick < 60 THEN RETURN FALSE END;
  result := inp.attack OR (inp.menuKey # 0C) OR
            (inp.dirKey # DirNone) OR inp.quit OR
            inp.mouseClick;
  RETURN result
END PumpAndCheck;

PROCEDURE DrawTex(tex: Tex);
VAR sw, sh: INTEGER;
BEGIN
  IF tex = NIL THEN RETURN END;
  sw := ScreenW * Scale;
  sh := PlayH * Scale;
  BeginFrame;
  SetColor(ren, 0, 0, 0, 255);
  Clear(ren);
  TexDrawRegion(ren, tex, 0, 0, PageW, PageH, 0, 0, sw, sh);
  EndFrame
END DrawTex;

PROCEDURE Wait(n: INTEGER);
VAR i: INTEGER;
BEGIN
  FOR i := 1 TO n DO
    IF skipped THEN RETURN END;
    IF PumpAndCheck() THEN skipped := TRUE; RETURN END;
    INC(introTick);
    DelayMs(FrameTime)
  END
END Wait;

(* Zoom in: scale from center point outward *)
PROCEDURE ZoomIn(tex: Tex);
VAR i, x, y, w, h, sw, sh: INTEGER;
BEGIN
  IF tex = NIL THEN RETURN END;
  sw := ScreenW * Scale;
  sh := PlayH * Scale;
  i := 0;
  WHILE (i <= 160) AND (NOT skipped) DO
    IF PumpAndCheck() THEN skipped := TRUE; RETURN END;
    INC(introTick);
    w := sw * i DIV 160;
    h := sh * i DIV 160;
    x := (sw - w) DIV 2;
    y := (sh - h) DIV 2;
    BeginFrame;
    SetColor(ren, 0, 0, 0, 255);
    Clear(ren);
    IF (w > 0) AND (h > 0) THEN
      TexDrawRegion(ren, tex, 0, 0, PageW, PageH, x, y, w, h)
    END;
    EndFrame;
    DelayMs(FrameTime);
    INC(i, 4)
  END
END ZoomIn;

(* Zoom out *)
PROCEDURE ZoomOut(tex: Tex);
VAR i, x, y, w, h, sw, sh: INTEGER;
BEGIN
  IF tex = NIL THEN RETURN END;
  sw := ScreenW * Scale;
  sh := PlayH * Scale;
  i := 156;
  WHILE (i >= 0) AND (NOT skipped) DO
    IF PumpAndCheck() THEN skipped := TRUE; RETURN END;
    INC(introTick);
    w := sw * i DIV 160;
    h := sh * i DIV 160;
    x := (sw - w) DIV 2;
    y := (sh - h) DIV 2;
    BeginFrame;
    SetColor(ren, 0, 0, 0, 255);
    Clear(ren);
    IF (w > 0) AND (h > 0) THEN
      TexDrawRegion(ren, tex, 0, 0, PageW, PageH, x, y, w, h)
    END;
    EndFrame;
    DelayMs(FrameTime);
    DEC(i, 4)
  END
END ZoomOut;

(* Page curve function matching original page_det().
   Returns vertical offset (page curl) for column position. *)
PROCEDURE PageDet(v: INTEGER): INTEGER;
BEGIN
  IF v < 0 THEN RETURN 10
  ELSIF v = 0 THEN RETURN 9
  ELSIF v = 1 THEN RETURN 9
  ELSIF v = 2 THEN RETURN 8
  ELSIF v = 3 THEN RETURN 7
  ELSIF v = 4 THEN RETURN 6
  ELSIF v = 5 THEN RETURN 5
  ELSIF v = 6 THEN RETURN 5
  ELSIF v = 7 THEN RETURN 5
  ELSIF v = 8 THEN RETURN 4
  ELSIF v = 9 THEN RETURN 4
  ELSIF v = 10 THEN RETURN 4
  ELSIF v > 135 THEN RETURN 10
  ELSIF v > 123 THEN RETURN 6
  ELSIF v > 98 THEN RETURN 5
  ELSIF v > 71 THEN RETURN 4
  ELSE RETURN 3
  END
END PageDet;

(* Animated page flip from oldTex to newTex.
   Matching original flipscan():
   - Frames 0-10: reveal new RIGHT page by shrinking old right strips
   - Frames 11-21: reveal new LEFT page by growing new left strips *)
PROCEDURE FlipScan(oldTex, newTex: Tex);
VAR i, sw, sh, scol, dcol, h, rate, wide: INTEGER;
    sx, sy, sw2, sh2, dx, dy: INTEGER;
    flip1, flip2, flip3: ARRAY [0..21] OF INTEGER;
BEGIN
  IF (oldTex = NIL) OR (newTex = NIL) THEN RETURN END;
  sw := ScreenW * Scale;
  sh := PlayH * Scale;

  (* Original flip tables *)
  flip1[0]:=8; flip1[1]:=6; flip1[2]:=5; flip1[3]:=4; flip1[4]:=3;
  flip1[5]:=2; flip1[6]:=3; flip1[7]:=5; flip1[8]:=13; flip1[9]:=0;
  flip1[10]:=0; flip1[11]:=13; flip1[12]:=5; flip1[13]:=3; flip1[14]:=2;
  flip1[15]:=3; flip1[16]:=4; flip1[17]:=5; flip1[18]:=6; flip1[19]:=8;
  flip1[20]:=0; flip1[21]:=0;

  flip2[0]:=7; flip2[1]:=5; flip2[2]:=4; flip2[3]:=3; flip2[4]:=2;
  flip2[5]:=1; flip2[6]:=1; flip2[7]:=1; flip2[8]:=1; flip2[9]:=0;
  flip2[10]:=0; flip2[11]:=1; flip2[12]:=1; flip2[13]:=1; flip2[14]:=1;
  flip2[15]:=2; flip2[16]:=3; flip2[17]:=4; flip2[18]:=5; flip2[19]:=7;
  flip2[20]:=0; flip2[21]:=0;

  flip3[0]:=12; flip3[1]:=9; flip3[2]:=6; flip3[3]:=3; flip3[4]:=0;
  flip3[5]:=0; flip3[6]:=0; flip3[7]:=0; flip3[8]:=0; flip3[9]:=0;
  flip3[10]:=0; flip3[11]:=0; flip3[12]:=0; flip3[13]:=0; flip3[14]:=0;
  flip3[15]:=0; flip3[16]:=3; flip3[17]:=6; flip3[18]:=9; flip3[19]:=0;
  flip3[20]:=0; flip3[21]:=0;

  FOR i := 0 TO 21 DO
    IF skipped THEN RETURN END;
    IF PumpAndCheck() THEN skipped := TRUE; RETURN END;
    INC(introTick);

    rate := flip1[i];
    wide := flip2[i];

    BeginFrame;
    SetColor(ren, 0, 0, 0, 255);
    Clear(ren);

    IF i < 11 THEN
      (* RIGHT page turn: draw new right, overlay shrinking old right strips *)
      (* Start with new page as base for right half *)
      TexDrawRegion(ren, newTex,
                    PageW DIV 2, 0, PageW DIV 2, PageH,
                    sw DIV 2, 0, sw DIV 2, sh);
      (* Keep old left half *)
      TexDrawRegion(ren, oldTex,
                    0, 0, PageW DIV 2, PageH,
                    0, 0, sw DIV 2, sh);

      (* Overlay old right page strips (shrinking) *)
      IF rate > 0 THEN
        dcol := 0;
        scol := wide;
        WHILE scol < 136 DO
          h := PageDet(scol);
          (* Draw strip from old page onto right side *)
          TexDrawRegion(ren, oldTex,
                        PageW DIV 2 + scol, h,
                        wide, PageH - h - h,
                        sw DIV 2 + dcol * sw DIV PageW, h * sh DIV PageH,
                        wide * sw DIV PageW, (PageH - h - h) * sh DIV PageH);
          INC(dcol, wide);
          INC(scol, rate)
        END
      END

    ELSE
      (* LEFT page turn: draw old left, overlay growing new left strips *)
      (* Full new right half *)
      TexDrawRegion(ren, newTex,
                    PageW DIV 2, 0, PageW DIV 2, PageH,
                    sw DIV 2, 0, sw DIV 2, sh);

      IF rate > 0 THEN
        (* Start with old left half *)
        TexDrawRegion(ren, oldTex,
                      24, 0, 135, PageH,
                      24 * sw DIV PageW, 0, 135 * sw DIV PageW, sh);
        (* Overlay new left strips from spine outward *)
        dcol := 0;
        scol := wide;
        WHILE scol < 136 DO
          h := PageDet(scol);
          TexDrawRegion(ren, newTex,
                        PageW DIV 2 - scol - wide, h,
                        wide, PageH - h - h,
                        (PageW DIV 2 - dcol - wide) * sw DIV PageW,
                        h * sh DIV PageH,
                        wide * sw DIV PageW,
                        (PageH - h - h) * sh DIV PageH);
          INC(dcol, wide);
          INC(scol, rate)
        END
      ELSE
        (* rate=0: show full new left page *)
        TexDrawRegion(ren, newTex,
                      0, 0, PageW DIV 2, PageH,
                      0, 0, sw DIV 2, sh)
      END
    END;

    EndFrame;

    IF flip3[i] > 0 THEN
      DelayMs(flip3[i] * FrameTime DIV 3)
    ELSE
      DelayMs(FrameTime)
    END
  END
END FlipScan;

PROCEDURE RunIntro;
BEGIN
  skipped := FALSE;
  introTick := 0;

  cover := LoadPage("page0.bmp");
  spread1 := LoadPage("spread_1.bmp");
  spread2 := LoadPage("spread_2.bmp");
  spread3 := LoadPage("spread_3.bmp");

  IF cover = NIL THEN RETURN END;

  WriteString("Intro: starting"); WriteLn;
  DelayMs(500);

  SetMood(MoodIntro);

  (* 1. Black screen *)
  BeginFrame; SetColor(ren, 0, 0, 0, 255); Clear(ren); EndFrame;
  Wait(30);
  IF skipped THEN RETURN END;

  (* 2. Zoom in on cover *)
  ZoomIn(cover);
  IF skipped THEN RETURN END;
  DrawTex(cover);
  Wait(60);
  IF skipped THEN RETURN END;

  (* 3. Flip to spread 1 *)
  FlipScan(cover, spread1);
  IF skipped THEN RETURN END;
  DrawTex(spread1);
  Wait(200);
  IF skipped THEN RETURN END;

  (* 4. Flip to spread 2 *)
  FlipScan(spread1, spread2);
  IF skipped THEN RETURN END;
  DrawTex(spread2);
  Wait(200);
  IF skipped THEN RETURN END;

  (* 5. Flip to spread 3 *)
  FlipScan(spread2, spread3);
  IF skipped THEN RETURN END;
  DrawTex(spread3);
  Wait(200);
  IF skipped THEN RETURN END;

  (* 6. Zoom out *)
  ZoomOut(spread3);

  (* Clean up *)
  BeginFrame; SetColor(ren, 0, 0, 0, 255); Clear(ren); EndFrame
END RunIntro;

END Intro.
