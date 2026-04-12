IMPLEMENTATION MODULE DayNight;

PROCEDURE InitDayNight;
BEGIN
  timeOfDay := 0;
  brightness := 100;
  isNight := FALSE
END InitDayNight;

PROCEDURE UpdateDayNight;
VAR phase, half: INTEGER;
BEGIN
  INC(timeOfDay);
  IF timeOfDay >= DayLength THEN timeOfDay := 0 END;

  half := DayLength DIV 2;

  IF timeOfDay < half THEN
    (* Day phase: ramp up then down *)
    phase := timeOfDay;
    IF phase < half DIV 4 THEN
      (* Dawn *)
      brightness := 40 + (phase * 60) DIV (half DIV 4)
    ELSIF phase < half * 3 DIV 4 THEN
      (* Full day *)
      brightness := 100
    ELSE
      (* Dusk *)
      brightness := 100 - ((phase - half * 3 DIV 4) * 60) DIV (half DIV 4)
    END
  ELSE
    (* Night phase *)
    phase := timeOfDay - half;
    IF phase < half DIV 4 THEN
      (* Early night *)
      brightness := 40 - (phase * 15) DIV (half DIV 4)
    ELSIF phase < half * 3 DIV 4 THEN
      (* Deep night *)
      brightness := 25
    ELSE
      (* Pre-dawn *)
      brightness := 25 + ((phase - half * 3 DIV 4) * 15) DIV (half DIV 4)
    END
  END;

  IF brightness < 25 THEN brightness := 25 END;
  IF brightness > 100 THEN brightness := 100 END;
  isNight := brightness < 50
END UpdateDayNight;

PROCEDURE GetTint(VAR r, g, b: INTEGER);
BEGIN
  (* Original uses different fade curves for R, G, B
     Night has blue shift like original nighttime palette *)
  r := brightness;
  g := brightness;
  b := brightness;
  IF isNight THEN
    (* Blue shift at night, matching original's limit behavior *)
    IF r < 30 THEN r := 30 END;
    IF g < 40 THEN g := 40 END;
    IF b < 70 THEN b := 70 END
  END
END GetTint;

END DayNight.
