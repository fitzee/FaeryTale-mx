IMPLEMENTATION MODULE Compass;

FROM Gfx IMPORT Renderer;
FROM Texture IMPORT Tex, Create AS TexCreate, DrawRegion AS TexDrawRegion,
                    SetTarget, ResetTarget, SetBlendMode, SetAlpha;
FROM Canvas IMPORT SetColor, FillRect, Clear, BLEND_ALPHA;
FROM Platform IMPORT PlayH, Scale;

CONST
  CompW = 48;  (* compass bitmap width in pixels — 48 used of 64 *)
  CompH = 25;  (* compass bitmap height *)
  BytesPerRow = 8;  (* 64 bits = 8 bytes per row *)

  (* Compass position in HUD — screen pixel coordinates.
     Original: (567, 15) in 640x57. Scale: 960/640 = 1.5x *)
  CompScrX = 851;
  CompScrY = 23;  (* relative to HUD top *)

  (* Scaled size *)
  CompScrW = 72;  (* 48 * 1.5 *)
  CompScrH = 38;  (* 25 * 1.5 *)

  (* Direction comptable: maps original dir to rect in compass.
     Original dirs: S=0,SW=1,W=2,NW=3,N=4,NE=5,E=6,SE=7 *)

VAR
  (* nhinor: base compass bitmap — 8 bytes per row, 25 rows *)
  nhinor: ARRAY [0..199] OF INTEGER;
  (* nhivar: direction highlight bitmap *)
  nhivar: ARRAY [0..199] OF INTEGER;
  (* Pre-rendered overlay texture for the direction highlight *)
  dirTex: ARRAY [0..8] OF Tex;  (* 0-7 = dirs, 8 = neutral *)

PROCEDURE InitBitmapData;
BEGIN
  (* nhinor — base compass *)
  nhinor[0]:=1;   nhinor[1]:=255; nhinor[2]:=248; nhinor[3]:=255;
  nhinor[4]:=252; nhinor[5]:=3;   nhinor[6]:=128; nhinor[7]:=0;
  nhinor[8]:=1;   nhinor[9]:=255; nhinor[10]:=0;  nhinor[11]:=7;
  nhinor[12]:=252; nhinor[13]:=3; nhinor[14]:=128; nhinor[15]:=0;
  nhinor[16]:=7;  nhinor[17]:=224; nhinor[18]:=240; nhinor[19]:=120;
  nhinor[20]:=63; nhinor[21]:=3;  nhinor[22]:=128; nhinor[23]:=0;
  nhinor[24]:=25; nhinor[25]:=15; nhinor[26]:=224; nhinor[27]:=63;
  nhinor[28]:=196; nhinor[29]:=195; nhinor[30]:=128; nhinor[31]:=0;
  nhinor[32]:=252; nhinor[33]:=127; nhinor[34]:=192; nhinor[35]:=31;
  nhinor[36]:=241; nhinor[37]:=255; nhinor[38]:=128; nhinor[39]:=0;
  nhinor[40]:=241; nhinor[41]:=159; nhinor[42]:=128; nhinor[43]:=15;
  nhinor[44]:=204; nhinor[45]:=127; nhinor[46]:=128; nhinor[47]:=0;
  nhinor[48]:=231; nhinor[49]:=231; nhinor[50]:=0;   nhinor[51]:=7;
  nhinor[52]:=63;  nhinor[53]:=63;  nhinor[54]:=128; nhinor[55]:=0;
  nhinor[56]:=207; nhinor[57]:=249; nhinor[58]:=128; nhinor[59]:=12;
  nhinor[60]:=255; nhinor[61]:=159; nhinor[62]:=128; nhinor[63]:=0;
  nhinor[64]:=159; nhinor[65]:=254; nhinor[66]:=96;  nhinor[67]:=51;
  nhinor[68]:=255; nhinor[69]:=207; nhinor[70]:=128; nhinor[71]:=0;
  nhinor[72]:=63;  nhinor[73]:=7;   nhinor[74]:=152; nhinor[75]:=207;
  nhinor[76]:=195; nhinor[77]:=231; nhinor[78]:=128; nhinor[79]:=0;
  nhinor[80]:=112; nhinor[81]:=1;   nhinor[82]:=231; nhinor[83]:=159;
  nhinor[84]:=0;   nhinor[85]:=51;  nhinor[86]:=128; nhinor[87]:=0;
  nhinor[88]:=0;   nhinor[89]:=0;   nhinor[90]:=120; nhinor[91]:=60;
  nhinor[92]:=0;   nhinor[93]:=3;   nhinor[94]:=128; nhinor[95]:=0;
  nhinor[96]:=0;   nhinor[97]:=0;   nhinor[98]:=25;  nhinor[99]:=48;
  nhinor[100]:=0;  nhinor[101]:=0;  nhinor[102]:=0;  nhinor[103]:=0;
  nhinor[104]:=0;  nhinor[105]:=0;  nhinor[106]:=120; nhinor[107]:=12;
  nhinor[108]:=0;  nhinor[109]:=3;  nhinor[110]:=128; nhinor[111]:=0;
  nhinor[112]:=120; nhinor[113]:=1; nhinor[114]:=199; nhinor[115]:=243;
  nhinor[116]:=0;  nhinor[117]:=51; nhinor[118]:=128; nhinor[119]:=0;
  nhinor[120]:=63; nhinor[121]:=135; nhinor[122]:=56; nhinor[123]:=60;
  nhinor[124]:=195; nhinor[125]:=231; nhinor[126]:=128; nhinor[127]:=0;
  nhinor[128]:=159; nhinor[129]:=252; nhinor[130]:=240; nhinor[131]:=31;
  nhinor[132]:=63;  nhinor[133]:=207; nhinor[134]:=128; nhinor[135]:=0;
  nhinor[136]:=207; nhinor[137]:=243; nhinor[138]:=192; nhinor[139]:=15;
  nhinor[140]:=207; nhinor[141]:=159; nhinor[142]:=128; nhinor[143]:=0;
  nhinor[144]:=231; nhinor[145]:=207; nhinor[146]:=128; nhinor[147]:=7;
  nhinor[148]:=243; nhinor[149]:=63;  nhinor[150]:=128; nhinor[151]:=0;
  nhinor[152]:=241; nhinor[153]:=63;  nhinor[154]:=128; nhinor[155]:=15;
  nhinor[156]:=252; nhinor[157]:=127; nhinor[158]:=128; nhinor[159]:=0;
  nhinor[160]:=252; nhinor[161]:=127; nhinor[162]:=192; nhinor[163]:=31;
  nhinor[164]:=241; nhinor[165]:=48;  nhinor[166]:=128; nhinor[167]:=0;
  nhinor[168]:=51;  nhinor[169]:=31;  nhinor[170]:=224; nhinor[171]:=63;
  nhinor[172]:=199; nhinor[173]:=192; nhinor[174]:=128; nhinor[175]:=0;
  nhinor[176]:=15;  nhinor[177]:=224; nhinor[178]:=240; nhinor[179]:=120;
  nhinor[180]:=63;  nhinor[181]:=0;   nhinor[182]:=128; nhinor[183]:=0;
  nhinor[184]:=3;   nhinor[185]:=255; nhinor[186]:=0;   nhinor[187]:=7;
  nhinor[188]:=255; nhinor[189]:=0;   nhinor[190]:=128; nhinor[191]:=0;
  nhinor[192]:=3;   nhinor[193]:=255; nhinor[194]:=248; nhinor[195]:=255;
  nhinor[196]:=255; nhinor[197]:=255; nhinor[198]:=0;   nhinor[199]:=0;

  (* nhivar — direction highlight *)
  nhivar[0]:=1;   nhivar[1]:=255; nhivar[2]:=248; nhivar[3]:=255;
  nhivar[4]:=252; nhivar[5]:=3;   nhivar[6]:=128; nhivar[7]:=0;
  nhivar[8]:=121; nhivar[9]:=255; nhivar[10]:=2;  nhivar[11]:=7;
  nhivar[12]:=252; nhivar[13]:=243; nhivar[14]:=128; nhivar[15]:=0;
  nhivar[16]:=103; nhivar[17]:=224; nhivar[18]:=242; nhivar[19]:=120;
  nhivar[20]:=63;  nhivar[21]:=51;  nhivar[22]:=128; nhivar[23]:=0;
  nhivar[24]:=25;  nhivar[25]:=15;  nhivar[26]:=231; nhivar[27]:=63;
  nhivar[28]:=196; nhivar[29]:=195; nhivar[30]:=128; nhivar[31]:=0;
  nhivar[32]:=252; nhivar[33]:=127; nhivar[34]:=207; nhivar[35]:=159;
  nhivar[36]:=241; nhivar[37]:=255; nhivar[38]:=128; nhivar[39]:=0;
  nhivar[40]:=241; nhivar[41]:=159; nhivar[42]:=159; nhivar[43]:=207;
  nhivar[44]:=204; nhivar[45]:=127; nhivar[46]:=128; nhivar[47]:=0;
  nhivar[48]:=231; nhivar[49]:=231; nhivar[50]:=63;  nhivar[51]:=231;
  nhivar[52]:=63;  nhivar[53]:=63;  nhivar[54]:=128; nhivar[55]:=0;
  nhivar[56]:=207; nhivar[57]:=249; nhivar[58]:=159; nhivar[59]:=204;
  nhivar[60]:=255; nhivar[61]:=159; nhivar[62]:=128; nhivar[63]:=0;
  nhivar[64]:=159; nhivar[65]:=254; nhivar[66]:=103; nhivar[67]:=51;
  nhivar[68]:=255; nhivar[69]:=207; nhivar[70]:=128; nhivar[71]:=0;
  nhivar[72]:=63;  nhivar[73]:=7;   nhivar[74]:=152; nhivar[75]:=207;
  nhivar[76]:=195; nhivar[77]:=231; nhivar[78]:=128; nhivar[79]:=0;
  nhivar[80]:=112; nhivar[81]:=249; nhivar[82]:=231; nhivar[83]:=159;
  nhivar[84]:=60;  nhivar[85]:=51;  nhivar[86]:=128; nhivar[87]:=0;
  nhivar[88]:=15;  nhivar[89]:=254; nhivar[90]:=120; nhivar[91]:=60;
  nhivar[92]:=255; nhivar[93]:=195; nhivar[94]:=128; nhivar[95]:=0;
  nhivar[96]:=255; nhivar[97]:=255; nhivar[98]:=153; nhivar[99]:=51;
  nhivar[100]:=255; nhivar[101]:=248; nhivar[102]:=0; nhivar[103]:=0;
  nhivar[104]:=7;  nhivar[105]:=254; nhivar[106]:=120; nhivar[107]:=12;
  nhivar[108]:=255; nhivar[109]:=195; nhivar[110]:=128; nhivar[111]:=0;
  nhivar[112]:=120; nhivar[113]:=121; nhivar[114]:=199; nhivar[115]:=243;
  nhivar[116]:=60;  nhivar[117]:=51;  nhivar[118]:=128; nhivar[119]:=0;
  nhivar[120]:=63;  nhivar[121]:=135; nhivar[122]:=56;  nhivar[123]:=60;
  nhivar[124]:=195; nhivar[125]:=231; nhivar[126]:=128; nhivar[127]:=0;
  nhivar[128]:=159; nhivar[129]:=252; nhivar[130]:=243; nhivar[131]:=159;
  nhivar[132]:=63;  nhivar[133]:=207; nhivar[134]:=128; nhivar[135]:=0;
  nhivar[136]:=207; nhivar[137]:=243; nhivar[138]:=207; nhivar[139]:=207;
  nhivar[140]:=207; nhivar[141]:=159; nhivar[142]:=128; nhivar[143]:=0;
  nhivar[144]:=231; nhivar[145]:=207; nhivar[146]:=159; nhivar[147]:=231;
  nhivar[148]:=243; nhivar[149]:=63;  nhivar[150]:=128; nhivar[151]:=0;
  nhivar[152]:=241; nhivar[153]:=63;  nhivar[154]:=159; nhivar[155]:=207;
  nhivar[156]:=252; nhivar[157]:=127; nhivar[158]:=128; nhivar[159]:=0;
  nhivar[160]:=252; nhivar[161]:=127; nhivar[162]:=207; nhivar[163]:=159;
  nhivar[164]:=241; nhivar[165]:=48;  nhivar[166]:=128; nhivar[167]:=0;
  nhivar[168]:=51;  nhivar[169]:=31;  nhivar[170]:=231; nhivar[171]:=63;
  nhivar[172]:=199; nhivar[173]:=204; nhivar[174]:=128; nhivar[175]:=0;
  nhivar[176]:=207; nhivar[177]:=224; nhivar[178]:=242; nhivar[179]:=120;
  nhivar[180]:=63;  nhivar[181]:=60;  nhivar[182]:=128; nhivar[183]:=0;
  nhivar[184]:=243; nhivar[185]:=255; nhivar[186]:=2;   nhivar[187]:=7;
  nhivar[188]:=255; nhivar[189]:=0;   nhivar[190]:=128; nhivar[191]:=0;
  nhivar[192]:=3;   nhivar[193]:=255; nhivar[194]:=248; nhivar[195]:=255;
  nhivar[196]:=255; nhivar[197]:=255; nhivar[198]:=0;   nhivar[199]:=0
END InitBitmapData;

PROCEDURE GetBit(VAR bm: ARRAY OF INTEGER; x, y: INTEGER): BOOLEAN;
VAR byteIdx, bitIdx: INTEGER;
BEGIN
  IF (x < 0) OR (x >= 64) OR (y < 0) OR (y >= 25) THEN RETURN FALSE END;
  byteIdx := y * BytesPerRow + x DIV 8;
  bitIdx := 7 - (x MOD 8);
  RETURN (bm[byteIdx] DIV (1 * (byteIdx - byteIdx + 1)) > 0) AND TRUE
END GetBit;

PROCEDURE BitSet(VAR bm: ARRAY OF INTEGER; x, y: INTEGER): BOOLEAN;
VAR byteVal, bitMask: INTEGER;
BEGIN
  IF (x < 0) OR (x >= 48) OR (y < 0) OR (y >= 25) THEN RETURN FALSE END;
  byteVal := bm[y * BytesPerRow + x DIV 8];
  bitMask := 128;
  bitMask := bitMask DIV (1);
  (* shift right by (x MOD 8) *)
  CASE x MOD 8 OF
    0: bitMask := 128 |
    1: bitMask := 64  |
    2: bitMask := 32  |
    3: bitMask := 16  |
    4: bitMask := 8   |
    5: bitMask := 4   |
    6: bitMask := 2   |
    7: bitMask := 1
  ELSE
    bitMask := 0
  END;
  RETURN (byteVal DIV bitMask) MOD 2 = 1
END BitSet;

PROCEDURE BuildDirTexture(ren: Renderer; dir: INTEGER);
VAR x, y, base, hilite: INTEGER;
    cx, cy, cw, ch: INTEGER;
    tex: Tex;
BEGIN
  tex := TexCreate(ren, CompW, CompH);
  IF tex = NIL THEN RETURN END;

  SetTarget(ren, tex);
  SetColor(ren, 0, 0, 0, 0);
  Clear(ren);

  (* Get comptable rect for this direction.
     Original dirs: S=0,SW=1,W=2,NW=3,N=4,NE=5,E=6,SE=7 *)
  CASE dir OF
    0: cx := 0;  cy := 0;  cw := 16; ch := 8  |  (* S *)
    1: cx := 16; cy := 0;  cw := 16; ch := 9  |  (* SW *)
    2: cx := 32; cy := 0;  cw := 16; ch := 8  |  (* W *)
    3: cx := 30; cy := 8;  cw := 18; ch := 8  |  (* NW *)
    4: cx := 32; cy := 16; cw := 16; ch := 8  |  (* N *)
    5: cx := 16; cy := 13; cw := 16; ch := 11 |  (* NE *)
    6: cx := 0;  cy := 16; cw := 16; ch := 8  |  (* E *)
    7: cx := 0;  cy := 8;  cw := 18; ch := 8     (* SE *)
  ELSE
    cx := 0; cy := 0; cw := 0; ch := 0
  END;

  FOR y := 0 TO CompH - 1 DO
    FOR x := 0 TO CompW - 1 DO
      base := 0;
      hilite := 0;
      IF BitSet(nhinor, x, y) THEN base := 1 END;
      IF BitSet(nhivar, x, y) THEN hilite := 1 END;

      IF (dir < 8) AND (x >= cx) AND (x < cx + cw) AND
         (y >= cy) AND (y < cy + ch) THEN
        (* Direction region: use nhivar *)
        IF hilite = 1 THEN
          (* Highlighted direction pixel — red/orange *)
          SetColor(ren, 255, 100, 30, 200);
          FillRect(ren, x, y, 1, 1)
        ELSIF base = 1 THEN
          (* Base pixel in direction region — darker *)
          SetColor(ren, 80, 40, 20, 160);
          FillRect(ren, x, y, 1, 1)
        END
      ELSE
        (* Outside direction region: use nhinor base *)
        IF base = 1 THEN
          SetColor(ren, 80, 40, 20, 160);
          FillRect(ren, x, y, 1, 1)
        END
      END
    END
  END;

  ResetTarget(ren);
  SetBlendMode(tex, BLEND_ALPHA);
  dirTex[dir] := tex
END BuildDirTexture;

PROCEDURE InitCompass(ren: Renderer);
VAR i: INTEGER;
BEGIN
  InitBitmapData;
  FOR i := 0 TO 8 DO
    dirTex[i] := NIL
  END;
  (* Build neutral (no direction) *)
  BuildDirTexture(ren, 8);
  (* Build all 8 directions *)
  FOR i := 0 TO 7 DO
    BuildDirTexture(ren, i)
  END
END InitCompass;

PROCEDURE DrawCompass(ren: Renderer; dir: INTEGER);
VAR origDir, hudY: INTEGER;
    tex: Tex;
BEGIN
  hudY := PlayH * Scale;

  (* Map our direction to original direction.
     Our: N=0,NE=1,E=2,SE=3,S=4,SW=5,W=6,NW=7
     Orig: S=0,SW=1,W=2,NW=3,N=4,NE=5,E=6,SE=7 *)
  IF (dir >= 0) AND (dir <= 7) THEN
    CASE dir OF
      0: origDir := 4 |  (* N *)
      1: origDir := 5 |  (* NE *)
      2: origDir := 6 |  (* E *)
      3: origDir := 7 |  (* SE *)
      4: origDir := 0 |  (* S *)
      5: origDir := 1 |  (* SW *)
      6: origDir := 2 |  (* W *)
      7: origDir := 3    (* NW *)
    ELSE
      origDir := 8
    END
  ELSE
    origDir := 8  (* neutral *)
  END;

  tex := dirTex[origDir];
  IF tex = NIL THEN RETURN END;

  TexDrawRegion(ren, tex,
                0, 0, CompW, CompH,
                CompScrX, hudY + CompScrY, CompScrW, CompScrH)
END DrawCompass;

END Compass.
