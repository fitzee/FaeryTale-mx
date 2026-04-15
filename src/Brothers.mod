IMPLEMENTATION MODULE Brothers;

FROM Strings IMPORT Assign;
FROM Actor IMPORT actors;
FROM World IMPORT TileSize;

PROCEDURE ClearWeaponInv(VAR b: BrotherData);
VAR i: INTEGER;
BEGIN
  FOR i := 0 TO 5 DO b.weaponInv[i] := 0 END
END ClearWeaponInv;

PROCEDURE InitBrothers;
BEGIN
  activeBrother := Julian;

  Assign("Julian", brothers[Julian].name);
  brothers[Julian].vitality := 100;
  brothers[Julian].weapon := 1;
  brothers[Julian].brave := 35;
  brothers[Julian].luck := 20;
  brothers[Julian].kind := 15;
  ClearWeaponInv(brothers[Julian]);
  brothers[Julian].weaponInv[1] := 1;  (* starts with dirk *)
  brothers[Julian].startX := 19036;
  brothers[Julian].startY := 15755;
  brothers[Julian].alive := TRUE;

  Assign("Philip", brothers[Philip].name);
  brothers[Philip].vitality := 80;
  brothers[Philip].weapon := 0;
  brothers[Philip].brave := 20;
  brothers[Philip].luck := 35;
  brothers[Philip].kind := 15;
  ClearWeaponInv(brothers[Philip]);
  brothers[Philip].startX := 19036;
  brothers[Philip].startY := 15755;
  brothers[Philip].alive := TRUE;

  Assign("Kevin", brothers[Kevin].name);
  brothers[Kevin].vitality := 60;
  brothers[Kevin].weapon := 0;
  brothers[Kevin].brave := 15;
  brothers[Kevin].luck := 20;
  ClearWeaponInv(brothers[Kevin]);
  brothers[Kevin].kind := 35;
  brothers[Kevin].startX := 19036;
  brothers[Kevin].startY := 15755;
  brothers[Kevin].alive := TRUE
END InitBrothers;

PROCEDURE SaveBrotherState;
BEGIN
  brothers[activeBrother].vitality := actors[0].vitality;
  brothers[activeBrother].weapon := actors[0].weapon
END SaveBrotherState;

PROCEDURE RestoreBrotherState;
BEGIN
  actors[0].absX := brothers[activeBrother].startX;
  actors[0].absY := brothers[activeBrother].startY;
  actors[0].vitality := brothers[activeBrother].vitality;
  actors[0].weapon := brothers[activeBrother].weapon;
  actors[0].state := 13; (* StStill *)
  actors[0].facing := 4  (* south *)
END RestoreBrotherState;

PROCEDURE SwitchToNext(): BOOLEAN;
VAR i, next: INTEGER;
BEGIN
  brothers[activeBrother].alive := FALSE;

  (* Find next living brother *)
  FOR i := 1 TO NumBrothers DO
    next := (activeBrother + i) MOD NumBrothers;
    IF brothers[next].alive THEN
      activeBrother := next;
      RestoreBrotherState;
      RETURN TRUE
    END
  END;
  (* All brothers dead *)
  RETURN FALSE
END SwitchToNext;

PROCEDURE ActiveName(VAR name: ARRAY OF CHAR);
BEGIN
  Assign(brothers[activeBrother].name, name)
END ActiveName;

END Brothers.
