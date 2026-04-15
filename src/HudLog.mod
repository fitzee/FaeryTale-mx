IMPLEMENTATION MODULE HudLog;

FROM Strings IMPORT Assign, Length, Concat;

VAR
  lines: ARRAY [0..3] OF ARRAY [0..39] OF CHAR;
  brv, lck, knd, wlth, vit: INTEGER;

PROCEDURE InitHudLog;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO NumLines - 1 DO
    lines[i][0] := 0C
  END;
  brv := 0; lck := 0; knd := 0; wlth := 0; vit := 0;
  logDirty := TRUE;
  statDirty := TRUE
END InitHudLog;

PROCEDURE ScrollUp;
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO NumLines - 2 DO
    Assign(lines[i + 1], lines[i])
  END;
  lines[NumLines - 1][0] := 0C
END ScrollUp;

PROCEDURE InsertLine(s: ARRAY OF CHAR);
BEGIN
  ScrollUp;
  Assign(s, lines[NumLines - 1]);
  logDirty := TRUE
END InsertLine;

PROCEDURE AddLogLine(msg: ARRAY OF CHAR);
CONST
  WrapCol = 37;
VAR
  src: INTEGER;       (* read position in msg *)
  buf: ARRAY [0..39] OF CHAR;
  bi:  INTEGER;       (* write position in buf *)
  lastSpace: INTEGER; (* last space position in buf *)
  ch:  CHAR;
  tail: ARRAY [0..39] OF CHAR;
  ti, i: INTEGER;
BEGIN
  src := 0;
  bi := 0;
  lastSpace := -1;

  WHILE (src <= HIGH(msg)) AND (msg[src] # 0C) DO
    ch := msg[src];
    INC(src);

    IF ch = ' ' THEN
      lastSpace := bi
    END;

    buf[bi] := ch;
    INC(bi);

    IF bi >= WrapCol THEN
      (* Need to wrap *)
      IF lastSpace > 0 THEN
        (* Break at last space *)
        buf[lastSpace] := 0C;
        InsertLine(buf);
        (* Copy remainder after space into start of buf *)
        ti := 0;
        FOR i := lastSpace + 1 TO bi - 1 DO
          buf[ti] := buf[i];
          INC(ti)
        END;
        bi := ti;
        lastSpace := -1
      ELSE
        (* No space found — hard wrap *)
        buf[bi] := 0C;
        InsertLine(buf);
        bi := 0;
        lastSpace := -1
      END
    END
  END;

  (* Flush remaining text *)
  IF bi > 0 THEN
    buf[bi] := 0C;
    InsertLine(buf)
  END
END AddLogLine;

PROCEDURE AppendToLine(msg: ARRAY OF CHAR);
VAR len: INTEGER;
BEGIN
  len := Length(lines[NumLines - 1]);
  IF len + Length(msg) < MaxLineLen THEN
    Concat(lines[NumLines - 1], msg, lines[NumLines - 1])
  END;
  logDirty := TRUE
END AppendToLine;

PROCEDURE SetStats(b, l, k, w, v: INTEGER);
BEGIN
  IF (b # brv) OR (l # lck) OR (k # knd) OR
     (w # wlth) OR (v # vit) THEN
    brv := b; lck := l; knd := k; wlth := w; vit := v;
    statDirty := TRUE
  END
END SetStats;

PROCEDURE GetLine(row: INTEGER; VAR buf: ARRAY OF CHAR);
BEGIN
  IF (row >= 0) AND (row < NumLines) THEN
    Assign(lines[row], buf)
  ELSE
    buf[0] := 0C
  END
END GetLine;

PROCEDURE GetStatBrv(): INTEGER;
BEGIN RETURN brv END GetStatBrv;

PROCEDURE GetStatLck(): INTEGER;
BEGIN RETURN lck END GetStatLck;

PROCEDURE GetStatKnd(): INTEGER;
BEGIN RETURN knd END GetStatKnd;

PROCEDURE GetStatWlth(): INTEGER;
BEGIN RETURN wlth END GetStatWlth;

PROCEDURE GetStatVit(): INTEGER;
BEGIN RETURN vit END GetStatVit;

END HudLog.
