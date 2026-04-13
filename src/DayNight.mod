IMPLEMENTATION MODULE DayNight;

(* Matches original FTA day/night exactly.
   Original runs at 50Hz. We run at 60fps.
   Use a fractional accumulator to advance daynight at 50Hz. *)

VAR
  tickAccum: INTEGER;  (* accumulates 50ths at 60fps *)

PROCEDURE InitDayNight;
BEGIN
  (* Start at midday: daynight=6000 gives lightlevel=150, full bright *)
  daynight := 6000;
  tickAccum := 0;
  UpdateLightLevel
END InitDayNight;

PROCEDURE UpdateLightLevel;
BEGIN
  lightlevel := daynight DIV 40;
  IF lightlevel >= 300 THEN
    lightlevel := 600 - lightlevel
  END;
  isNight := lightlevel <= 120;
  (* brightness for backward compat: scale lightlevel 0..300 to 0..100 *)
  brightness := lightlevel * 100 DIV 300;
  IF brightness > 100 THEN brightness := 100 END
END UpdateLightLevel;

PROCEDURE UpdateDayNight;
BEGIN
  (* Advance daynight at 50Hz from a 60fps game loop.
     50/60 = 5/6. Accumulate: add 5 per frame, tick when >= 6. *)
  INC(tickAccum, 5);
  WHILE tickAccum >= 6 DO
    DEC(tickAccum, 6);
    INC(daynight);
    IF daynight >= DayNightMax THEN daynight := 0 END
  END;
  UpdateLightLevel
END UpdateDayNight;

PROCEDURE GetFadeRGB(VAR r, g, b: INTEGER);
BEGIN
  (* Original: fade_page(lightlevel-80+ll, lightlevel-61, lightlevel-62, TRUE, pagecolors)
     where ll=0 normally (no light_timer).
     So r = lightlevel - 80, g = lightlevel - 61, b = lightlevel - 62.
     Clamped by fade_page: r min 10, g min 25, b min 60 (when limit=TRUE). *)
  r := lightlevel - 80;
  g := lightlevel - 61;
  b := lightlevel - 62;
  (* Night limits from fade_page *)
  IF r < 10 THEN r := 10 END;
  IF g < 25 THEN g := 25 END;
  IF b < 60 THEN b := 60 END;
  IF r > 100 THEN r := 100 END;
  IF g > 100 THEN g := 100 END;
  IF b > 100 THEN b := 100 END
END GetFadeRGB;

PROCEDURE PaletteTickDue(): BOOLEAN;
BEGIN
  RETURN BAND(CARDINAL(daynight), 3) = 0
END PaletteTickDue;

PROCEDURE MusicTickDue(): BOOLEAN;
BEGIN
  RETURN BAND(CARDINAL(daynight), 7) = 0
END MusicTickDue;

END DayNight.
