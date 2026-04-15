IMPLEMENTATION MODULE Narration;

(* Place-triggered message system from the original FTA.
   Tables and messages transcribed from narr.c. *)

FROM Strings IMPORT Assign;
FROM Brothers IMPORT ActiveName;
FROM Assets IMPORT GetMapSector;
FROM HudLog IMPORT AddLogLine;

CONST
  OutTblSize = 29;
  InTblSize  = 36;

VAR
  heroPlace: INTEGER;  (* current place ID, for change detection *)

  (* Trigger tables stored as flat arrays: [min, max, msgId] triples *)
  outTab: ARRAY [0..86] OF INTEGER;   (* 29 * 3 *)
  inTab:  ARRAY [0..107] OF INTEGER;  (* 36 * 3 *)

  (* Message tables — indexed arrays of pre-written strings *)
  placeMsg:  ARRAY [0..26] OF ARRAY [0..63] OF CHAR;
  insideMsg: ARRAY [0..22] OF ARRAY [0..63] OF CHAR;
  eventMsg:  ARRAY [0..38] OF ARRAY [0..63] OF CHAR;

(* --- Initialization --- *)

PROCEDURE SetTrigger(VAR tab: ARRAY OF INTEGER;
                     idx, mn, mx, id: INTEGER);
BEGIN
  tab[idx * 3]     := mn;
  tab[idx * 3 + 1] := mx;
  tab[idx * 3 + 2] := id
END SetTrigger;

PROCEDURE InitOutdoorTriggers;
BEGIN
  SetTrigger(outTab,  0,  51,  51, 19);
  SetTrigger(outTab,  1,  64,  69,  2);
  SetTrigger(outTab,  2,  70,  73,  3);
  SetTrigger(outTab,  3,  80,  95,  6);
  SetTrigger(outTab,  4,  96,  99,  7);
  SetTrigger(outTab,  5, 138, 139,  8);
  SetTrigger(outTab,  6, 144, 144,  9);
  SetTrigger(outTab,  7, 147, 147, 10);
  SetTrigger(outTab,  8, 148, 148, 20);
  SetTrigger(outTab,  9, 159, 162, 17);
  SetTrigger(outTab, 10, 163, 163, 18);
  SetTrigger(outTab, 11, 164, 167, 12);
  SetTrigger(outTab, 12, 168, 168, 21);
  SetTrigger(outTab, 13, 170, 170, 22);
  SetTrigger(outTab, 14, 171, 174, 14);
  SetTrigger(outTab, 15, 176, 176, 13);
  SetTrigger(outTab, 16, 178, 178, 23);
  SetTrigger(outTab, 17, 179, 179, 24);
  SetTrigger(outTab, 18, 180, 180, 25);
  SetTrigger(outTab, 19, 175, 180,  0);
  SetTrigger(outTab, 20, 208, 221, 11);
  SetTrigger(outTab, 21, 243, 243, 16);
  SetTrigger(outTab, 22, 250, 252,  0);
  SetTrigger(outTab, 23, 255, 255, 26);
  SetTrigger(outTab, 24,  78,  78,  4);
  SetTrigger(outTab, 25, 187, 239,  4);
  SetTrigger(outTab, 26,   0,  79,  0);
  SetTrigger(outTab, 27, 185, 254, 15);
  SetTrigger(outTab, 28,   0, 255,  0)
END InitOutdoorTriggers;

PROCEDURE InitIndoorTriggers;
BEGIN
  SetTrigger(inTab,  0,   2,   2,  2);
  SetTrigger(inTab,  1,   7,   7,  3);
  SetTrigger(inTab,  2,   4,   4,  4);
  SetTrigger(inTab,  3,   5,   6,  5);
  SetTrigger(inTab,  4,   9,  10,  6);
  SetTrigger(inTab,  5,  30,  30,  7);
  SetTrigger(inTab,  6,  19,  33, 14);
  SetTrigger(inTab,  7, 101, 101, 14);
  SetTrigger(inTab,  8, 130, 134, 14);
  SetTrigger(inTab,  9,  36,  36, 13);
  SetTrigger(inTab, 10,  37,  42, 12);
  SetTrigger(inTab, 11,  46,  46,  0);
  SetTrigger(inTab, 12,  43,  59, 11);
  SetTrigger(inTab, 13, 100, 100, 11);
  SetTrigger(inTab, 14, 143, 149, 11);
  SetTrigger(inTab, 15,  62,  62, 16);
  SetTrigger(inTab, 16,  65,  66, 18);
  SetTrigger(inTab, 17,  60,  78, 17);
  SetTrigger(inTab, 18,  82,  82, 17);
  SetTrigger(inTab, 19,  86,  87, 17);
  SetTrigger(inTab, 20,  92,  92, 17);
  SetTrigger(inTab, 21,  94,  95, 17);
  SetTrigger(inTab, 22,  97,  99, 17);
  SetTrigger(inTab, 23, 120, 120, 17);
  SetTrigger(inTab, 24, 116, 119, 17);
  SetTrigger(inTab, 25, 139, 141, 17);
  SetTrigger(inTab, 26,  79,  96,  9);
  SetTrigger(inTab, 27, 104, 104, 19);
  SetTrigger(inTab, 28, 114, 114, 20);
  SetTrigger(inTab, 29, 105, 115,  8);
  SetTrigger(inTab, 30, 135, 138,  8);
  SetTrigger(inTab, 31, 125, 125, 21);
  SetTrigger(inTab, 32, 127, 127, 10);
  SetTrigger(inTab, 33, 142, 142, 22);
  SetTrigger(inTab, 34, 121, 129, 22);
  SetTrigger(inTab, 35, 150, 161, 15)
END InitIndoorTriggers;

PROCEDURE InitPlaceMessages;
BEGIN
  placeMsg[0][0] := 0C;
  placeMsg[1][0] := 0C;
  Assign("% returned to the village of Tambry.", placeMsg[2]);
  Assign("% came to Vermillion Manor.", placeMsg[3]);
  Assign("% reached the Mountains of Frost.", placeMsg[4]);
  Assign("% reached the Plain of Grief.", placeMsg[5]);
  Assign("% came to the city of Marheim.", placeMsg[6]);
  Assign("% came to the Witch's castle.", placeMsg[7]);
  Assign("% came to the Graveyard.", placeMsg[8]);
  Assign("% came to a great stone ring.", placeMsg[9]);
  Assign("% came to a watchtower.", placeMsg[10]);
  Assign("% traveled to the great Bog.", placeMsg[11]);
  Assign("% came to the Crystal Palace.", placeMsg[12]);
  Assign("% came to mysterious Pixle Grove.", placeMsg[13]);
  Assign("% entered the Citadel of Doom.", placeMsg[14]);
  Assign("% entered the Burning Waste.", placeMsg[15]);
  Assign("% found an oasis.", placeMsg[16]);
  Assign("% came to the hidden city of Azal.", placeMsg[17]);
  Assign("% discovered an outlying fort.", placeMsg[18]);
  Assign("% came to a small keep.", placeMsg[19]);
  Assign("% came to an old castle.", placeMsg[20]);
  Assign("% came to a log cabin.", placeMsg[21]);
  Assign("% came to a dark stone tower.", placeMsg[22]);
  Assign("% came to an isolated cabin.", placeMsg[23]);
  Assign("% came to the Tombs of Hemsath.", placeMsg[24]);
  Assign("% reached the Forbidden Keep.", placeMsg[25]);
  Assign("% found a cave in the hillside.", placeMsg[26])
END InitPlaceMessages;

PROCEDURE InitInsideMessages;
BEGIN
  insideMsg[0][0] := 0C;
  insideMsg[1][0] := 0C;
  Assign("% came to a small chamber.", insideMsg[2]);
  Assign("% came to a large chamber.", insideMsg[3]);
  Assign("% came to a long passageway.", insideMsg[4]);
  Assign("% came to a twisting tunnel.", insideMsg[5]);
  Assign("% came to a forked intersection.", insideMsg[6]);
  Assign("He entered the keep.", insideMsg[7]);
  Assign("He entered the castle.", insideMsg[8]);
  Assign("He entered the castle of King Mar.", insideMsg[9]);
  Assign("He entered the sanctuary of the temple.", insideMsg[10]);
  Assign("% entered the Spirit Plane.", insideMsg[11]);
  Assign("% came to a large room.", insideMsg[12]);
  Assign("% came to an octagonal room.", insideMsg[13]);
  Assign("% traveled along a stone corridor.", insideMsg[14]);
  Assign("% came to a stone maze.", insideMsg[15]);
  Assign("He entered a small building.", insideMsg[16]);
  Assign("He entered the building.", insideMsg[17]);
  Assign("He entered the tavern.", insideMsg[18]);
  Assign("He went inside the inn.", insideMsg[19]);
  Assign("He entered the crypt.", insideMsg[20]);
  Assign("He walked into the cabin.", insideMsg[21]);
  Assign("He unlocked the door and entered.", insideMsg[22])
END InitInsideMessages;

PROCEDURE InitEventMessages;
BEGIN
  (* Exact transcription from original narr.c event_msg[].
     Index 0 = first string after the null-terminated blob. *)
  Assign("% was getting rather hungry.", eventMsg[0]);
  Assign("% was getting very hungry.", eventMsg[1]);
  Assign("% was starving!", eventMsg[2]);
  Assign("% was getting tired.", eventMsg[3]);
  Assign("% was getting sleepy.", eventMsg[4]);
  (* 5 *)
  Assign("% was hit and killed!", eventMsg[5]);
  Assign("% was drowned in the water!", eventMsg[6]);
  Assign("% was burned in the lava.", eventMsg[7]);
  Assign("% was turned to stone by the witch.", eventMsg[8]);
  Assign("% started the journey in his home village of Tambry", eventMsg[9]);
  (* 10 *)
  Assign("as had his brother before him.", eventMsg[10]);
  Assign("as had his brothers before him.", eventMsg[11]);
  Assign("% just couldn't stay awake any longer!", eventMsg[12]);
  Assign("% was feeling quite full.", eventMsg[13]);
  Assign("% was feeling quite rested.", eventMsg[14]);
  (* 15 *)
  Assign("Even % would not draw weapon in here.", eventMsg[15]);
  Assign("A calming influence prevents % from drawing.", eventMsg[16]);
  Assign("% picked up a scrap of paper.", eventMsg[17]);
  Assign("It read: Find the turtle!", eventMsg[18]);
  Assign("It read: Meet me at midnight at the Crypt.", eventMsg[19]);
  (* 20 *)
  Assign("% looked around but discovered nothing.", eventMsg[20]);
  Assign("% does not have that item.", eventMsg[21]);
  Assign("% bought some food and ate it.", eventMsg[22]);
  Assign("% bought some arrows.", eventMsg[23]);
  Assign("% passed out from hunger!", eventMsg[24]);
  (* 25 *)
  Assign("% is not sleepy.", eventMsg[25]);
  Assign("% decided to lie down and sleep.", eventMsg[26]);
  Assign("% perished in the hot lava!", eventMsg[27]);
  Assign("It was midnight.", eventMsg[28]);
  Assign("It was morning.", eventMsg[29]);
  (* 30 *)
  Assign("It was midday.", eventMsg[30]);
  Assign("Evening was drawing near.", eventMsg[31]);
  Assign("Ground is too hot for swan to land.", eventMsg[32]);
  Assign("Flying too fast to dismount.", eventMsg[33]);
  Assign("They're all dead! he cried.", eventMsg[34]);
  (* 35 *)
  Assign("No time for that now!", eventMsg[35]);
  Assign("% put an apple away for later.", eventMsg[36]);
  Assign("% ate one of his apples.", eventMsg[37]);
  Assign("% discovered a hidden object.", eventMsg[38])
END InitEventMessages;

(* --- Format: expand '%' to brother name --- *)

PROCEDURE FormatMsg(src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR);
VAR si, di, ni: INTEGER;
    name: ARRAY [0..15] OF CHAR;
BEGIN
  ActiveName(name);
  si := 0; di := 0;
  WHILE (si <= HIGH(src)) AND (src[si] # 0C) AND (di < HIGH(dst)) DO
    IF src[si] = '%' THEN
      ni := 0;
      WHILE (ni <= HIGH(name)) AND (name[ni] # 0C) AND (di < HIGH(dst)) DO
        dst[di] := name[ni];
        INC(di); INC(ni)
      END;
      INC(si)
    ELSE
      dst[di] := src[si];
      INC(di); INC(si)
    END
  END;
  IF di <= HIGH(dst) THEN dst[di] := 0C END
END FormatMsg;

(* --- Dispatch: format and send to HUD log --- *)

PROCEDURE DispatchPlace(id: INTEGER);
VAR buf: ARRAY [0..79] OF CHAR;
BEGIN
  IF (id < 0) OR (id > 26) THEN RETURN END;
  IF placeMsg[id][0] = 0C THEN RETURN END;
  FormatMsg(placeMsg[id], buf);
  AddLogLine(buf)
END DispatchPlace;

PROCEDURE DispatchInside(id: INTEGER);
VAR buf: ARRAY [0..79] OF CHAR;
BEGIN
  IF (id < 0) OR (id > 22) THEN RETURN END;
  IF insideMsg[id][0] = 0C THEN RETURN END;
  FormatMsg(insideMsg[id], buf);
  AddLogLine(buf)
END DispatchInside;

PROCEDURE DispatchEvent(id: INTEGER);
VAR buf: ARRAY [0..79] OF CHAR;
BEGIN
  IF (id < 0) OR (id > 38) THEN RETURN END;
  IF eventMsg[id][0] = 0C THEN RETURN END;
  FormatMsg(eventMsg[id], buf);
  AddLogLine(buf)
END DispatchEvent;

(* --- Trigger lookup --- *)

PROCEDURE LookupPlace(sector: INTEGER;
                      VAR tab: ARRAY OF INTEGER;
                      count: INTEGER): INTEGER;
VAR i, base: INTEGER;
BEGIN
  FOR i := 0 TO count - 1 DO
    base := i * 3;
    IF (sector >= tab[base]) AND (sector <= tab[base + 1]) THEN
      RETURN tab[base + 2]
    END
  END;
  RETURN 0
END LookupPlace;

(* --- Public API --- *)

PROCEDURE InitPlace(heroX, heroY, region: INTEGER);
VAR sector, placeId: INTEGER;
BEGIN
  IF region < 0 THEN RETURN END;
  sector := BAND(CARDINAL(GetMapSector(heroX, heroY)), 255);
  IF region > 7 THEN
    placeId := LookupPlace(sector, inTab, InTblSize);
    IF placeId > 0 THEN INC(placeId, 256) END
  ELSE
    placeId := LookupPlace(sector, outTab, OutTblSize)
  END;
  heroPlace := placeId
END InitPlace;

PROCEDURE UpdatePlace(heroX, heroY, region: INTEGER);
VAR sector, placeId: INTEGER;
BEGIN
  IF region < 0 THEN RETURN END;
  sector := BAND(CARDINAL(GetMapSector(heroX, heroY)), 255);

  IF region > 7 THEN
    placeId := LookupPlace(sector, inTab, InTblSize);
    (* Indoor place IDs offset by 256 to distinguish from outdoor *)
    IF placeId > 0 THEN INC(placeId, 256) END
  ELSE
    placeId := LookupPlace(sector, outTab, OutTblSize);
    (* Mountain special case: depends on region parity *)
    IF placeId = 4 THEN
      IF (region > 7) THEN
        (* skip *)
      ELSIF BAND(CARDINAL(region), 1) # 0 THEN
        placeId := 0
      ELSIF region > 3 THEN
        placeId := 5  (* Plain of Grief *)
      END
    END
  END;

  (* Only emit on place change *)
  IF (placeId # 0) AND (placeId # heroPlace) THEN
    heroPlace := placeId;
    IF placeId > 256 THEN
      DispatchInside(placeId - 256)
    ELSE
      DispatchPlace(placeId)
    END
  END
END UpdatePlace;

PROCEDURE Event(n: INTEGER);
BEGIN
  DispatchEvent(n)
END Event;

(* --- Module init --- *)

BEGIN
  heroPlace := 0;
  InitOutdoorTriggers;
  InitIndoorTriggers;
  InitPlaceMessages;
  InitInsideMessages;
  InitEventMessages
END Narration.
