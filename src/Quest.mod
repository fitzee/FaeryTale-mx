IMPLEMENTATION MODULE Quest;

(* Quest progression matching original FTA. *)

FROM SYSTEM IMPORT ADR;
FROM Strings IMPORT Assign, Concat;
FROM Actor IMPORT actors, actorCount;
FROM Brothers IMPORT brothers, activeBrother, AddWealth;
FROM Assets IMPORT currentRegion;
FROM WorldObj IMPORT objects, objCount;
FROM HudLog IMPORT AddLogLine;
FROM BinaryIO IMPORT OpenRead, OpenWrite, Close, ReadBytes, WriteBytes, Done;
FROM InOut IMPORT WriteString, WriteInt, WriteLn;

VAR
  princessRescued: BOOLEAN;
  gameWon: BOOLEAN;

(* --- Princess Rescue --- *)

PROCEDURE CheckRescue(heroX, heroY: INTEGER);
VAR i: INTEGER;
BEGIN
  IF princessRescued THEN RETURN END;
  IF currentRegion # 8 THEN RETURN END;

  IF (heroX > 10820) AND (heroX < 10877) AND
     (heroY > 35646) AND (heroY < 35670) THEN
    princessRescued := TRUE;
    brothers[activeBrother].stuff[28] := 1;  (* Writ *)
    AddWealth(100);
    FOR i := 16 TO 21 DO
      INC(brothers[activeBrother].stuff[i], 3)
    END;
    AddLogLine("You have rescued the princess!");
    AddLogLine("The king gave you a writ and 100 gold.");
    WriteString("Quest: princess rescued!"); WriteLn
  END
END CheckRescue;

(* --- Win Condition --- *)

PROCEDURE CheckWinCondition(): BOOLEAN;
BEGIN
  IF brothers[activeBrother].stuff[22] > 0 THEN
    IF NOT gameWon THEN
      gameWon := TRUE;
      AddLogLine("You have recovered the Talisman!");
      AddLogLine("The quest is complete!");
      WriteString("Quest: TALISMAN RECOVERED — YOU WIN!"); WriteLn
    END;
    RETURN TRUE
  END;
  RETURN FALSE
END CheckWinCondition;

(* --- Save/Load Game --- *)

PROCEDURE MakePath(slot: INTEGER; VAR path: ARRAY OF CHAR);
BEGIN
  Assign("saves/save_", path);
  CASE slot OF
    0: Concat(path, "A.dat", path) |
    1: Concat(path, "B.dat", path) |
    2: Concat(path, "C.dat", path) |
    3: Concat(path, "D.dat", path) |
    4: Concat(path, "E.dat", path) |
    5: Concat(path, "F.dat", path) |
    6: Concat(path, "G.dat", path) |
    7: Concat(path, "H.dat", path)
  ELSE
    Concat(path, "X.dat", path)
  END
END MakePath;

PROCEDURE SaveGame(slot: INTEGER): BOOLEAN;
VAR path: ARRAY [0..63] OF CHAR;
    fd, n, i, v: INTEGER;
    buf: ARRAY [0..3] OF CHAR;
BEGIN
  MakePath(slot, path);
  OpenWrite(path, fd);
  IF fd = 0 THEN
    WriteString("Save: cannot open "); WriteString(path); WriteLn;
    RETURN FALSE
  END;

  (* Header *)
  buf[0] := 'F'; buf[1] := 'T'; buf[2] := 'A'; buf[3] := '1';
  WriteBytes(fd, ADR(buf), 4, n);

  (* Active brother *)
  v := activeBrother;
  WriteBytes(fd, ADR(v), 4, n);

  (* All 3 brothers' stats and inventory *)
  FOR i := 0 TO 2 DO
    WriteBytes(fd, ADR(brothers[i].vitality), 4, n);
    WriteBytes(fd, ADR(brothers[i].weapon), 4, n);
    WriteBytes(fd, ADR(brothers[i].brave), 4, n);
    WriteBytes(fd, ADR(brothers[i].luck), 4, n);
    WriteBytes(fd, ADR(brothers[i].kind), 4, n);
    WriteBytes(fd, ADR(brothers[i].wealth), 4, n);
    WriteBytes(fd, ADR(brothers[i].stuff[0]), 140, n);
    v := 0; IF brothers[i].alive THEN v := 1 END;
    WriteBytes(fd, ADR(v), 4, n)
  END;

  (* Player position and state *)
  WriteBytes(fd, ADR(actors[0].absX), 4, n);
  WriteBytes(fd, ADR(actors[0].absY), 4, n);
  WriteBytes(fd, ADR(actors[0].weapon), 4, n);
  WriteBytes(fd, ADR(actors[0].facing), 4, n);

  (* Princess state *)
  v := 0; IF princessRescued THEN v := 1 END;
  WriteBytes(fd, ADR(v), 4, n);

  Close(fd);
  AddLogLine("Game saved.");
  WriteString("Quest: saved to "); WriteString(path); WriteLn;
  RETURN TRUE
END SaveGame;

PROCEDURE LoadGame(slot: INTEGER): BOOLEAN;
VAR path: ARRAY [0..63] OF CHAR;
    fd, n, i, v: INTEGER;
    buf: ARRAY [0..3] OF CHAR;
BEGIN
  MakePath(slot, path);
  OpenRead(path, fd);
  IF fd = 0 THEN
    AddLogLine("No save file found.");
    RETURN FALSE
  END;

  (* Verify header *)
  ReadBytes(fd, ADR(buf), 4, n);
  IF (n < 4) OR (buf[0] # 'F') OR (buf[1] # 'T') OR
     (buf[2] # 'A') OR (buf[3] # '1') THEN
    AddLogLine("Invalid save file.");
    Close(fd);
    RETURN FALSE
  END;

  (* Active brother *)
  ReadBytes(fd, ADR(v), 4, n);
  activeBrother := v;
  IF activeBrother > 2 THEN activeBrother := 0 END;

  (* All 3 brothers *)
  FOR i := 0 TO 2 DO
    ReadBytes(fd, ADR(brothers[i].vitality), 4, n);
    ReadBytes(fd, ADR(brothers[i].weapon), 4, n);
    ReadBytes(fd, ADR(brothers[i].brave), 4, n);
    ReadBytes(fd, ADR(brothers[i].luck), 4, n);
    ReadBytes(fd, ADR(brothers[i].kind), 4, n);
    ReadBytes(fd, ADR(brothers[i].wealth), 4, n);
    ReadBytes(fd, ADR(brothers[i].stuff[0]), 140, n);
    ReadBytes(fd, ADR(v), 4, n);
    brothers[i].alive := (v # 0)
  END;

  (* Player position *)
  ReadBytes(fd, ADR(actors[0].absX), 4, n);
  ReadBytes(fd, ADR(actors[0].absY), 4, n);
  ReadBytes(fd, ADR(actors[0].weapon), 4, n);
  ReadBytes(fd, ADR(actors[0].facing), 4, n);

  (* Princess state *)
  ReadBytes(fd, ADR(v), 4, n);
  princessRescued := (v # 0);

  Close(fd);

  actors[0].state := 13;  (* StStill *)
  actors[0].vitality := brothers[activeBrother].vitality;
  actors[0].environ := 0;
  actorCount := 1;

  AddLogLine("Game loaded.");
  WriteString("Quest: loaded from "); WriteString(path); WriteLn;
  RETURN TRUE
END LoadGame;

BEGIN
  princessRescued := FALSE;
  gameWon := FALSE
END Quest.
