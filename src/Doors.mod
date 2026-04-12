IMPLEMENTATION MODULE Doors;

FROM InOut IMPORT WriteString, WriteInt, WriteLn;

CONST
  CAVE  = 18;
  STAIR = 15;

TYPE
  DoorRec = RECORD
    xc1, yc1: INTEGER;
    xc2, yc2: INTEGER;
    dtype:    INTEGER;
    secs:     INTEGER
  END;

VAR
  doors: ARRAY [0..85] OF DoorRec;

PROCEDURE SetDoor(i, x1, y1, x2, y2, dt, sc: INTEGER);
BEGIN
  doors[i].xc1 := x1;  doors[i].yc1 := y1;
  doors[i].xc2 := x2;  doors[i].yc2 := y2;
  doors[i].dtype := dt; doors[i].secs := sc
END SetDoor;

PROCEDURE InitDoors;
BEGIN
  SetDoor( 0,  4464, 20576, 10352, 35680,  1, 1);
  SetDoor( 1,  4464, 20576, 10352, 35680,  1, 1);
  SetDoor( 2,  4464, 20576, 10352, 35680,  1, 1);
  SetDoor( 3,  4464, 20576, 10352, 35680,  1, 1);
  SetDoor( 4,  5008,  7008,  6528, 35936, 18, 2);
  SetDoor( 5,  6000, 27296,  8816, 38560,  9, 1);
  SetDoor( 6,  6512, 25248,  8048, 38560,  9, 1);
  SetDoor( 7,  6816, 19360,  5024, 38304, 17, 1);
  SetDoor( 8,  6816, 19552,  5024, 38752, 17, 1);
  SetDoor( 9,  6944, 19296,  5920, 38240, 17, 1);
  SetDoor(10,  7040, 19328,  5504, 38272, 17, 1);
  SetDoor(11,  7040, 19520,  5504, 38720, 17, 1);
  SetDoor(12,  7792, 15200, 10368, 40032,  3, 1);
  SetDoor(13,  9344, 13216, 11904, 36256,  1, 1);
  SetDoor(14, 10592, 34656, 11008, 37568, 15, 1);
  SetDoor(15, 11008, 37568, 10592, 34688, 15, 2);
  SetDoor(16, 11264, 29024, 10992, 37728,  9, 1);
  SetDoor(17, 12144, 11872, 12672, 39520,  3, 1);
  SetDoor(18, 12144, 25504,  7280, 38560,  9, 1);
  SetDoor(19, 12672, 14528, 10112, 39104,  1, 1);
  SetDoor(20, 13424, 19296,  1136, 36576, 15, 2);
  SetDoor(21, 15840,  7104, 12000, 37824,  7, 1);
  SetDoor(22, 15872,  7104, 12032, 37824,  7, 1);
  SetDoor(23, 17008,  9568, 11904, 39520,  3, 1);
  SetDoor(24, 17024, 15296, 10624, 39104,  1, 1);
  SetDoor(25, 17888, 21376,  9680, 38528, 10, 1);
  SetDoor(26, 18304, 12224,  9600, 39104,  1, 1);
  SetDoor(27, 18528, 26176,  7264, 39488, 18, 1);
  SetDoor(28, 18576, 26272,  7312, 39584, 11, 1);
  SetDoor(29, 18784, 23360,  8800, 39488, 18, 1);
  SetDoor(30, 18832, 23456,  8848, 39584, 11, 1);
  SetDoor(31, 18848, 15552,  2976, 33472,  2, 1);
  SetDoor(32, 18896, 15808,  3024, 33984,  2, 1);
  SetDoor(33, 18896, 15872,  3024, 34048,  2, 1);
  SetDoor(34, 18960, 15488,  3344, 33408,  1, 1);
  SetDoor(35, 18960, 15680,  3856, 33600,  1, 1);
  SetDoor(36, 18992, 15808,  3632, 34240,  1, 1);
  SetDoor(37, 19040, 16000,  4192, 34176,  1, 1);
  SetDoor(38, 19056, 15488,  4976, 33408,  1, 1);
  SetDoor(39, 19072, 15680,  4496, 33600,  1, 1);
  SetDoor(40, 19568, 12896,  9600, 40032,  3, 1);
  SetDoor(41, 19808, 21568,  8032, 40000, 18, 1);
  SetDoor(42, 19856, 17280, 12416, 36224, 13, 1);
  SetDoor(43, 19856, 21664,  8080, 40096, 11, 1);
  SetDoor(44, 19936, 27520, 10704, 38528, 10, 1);
  SetDoor(45, 21344, 22592,  8800, 38976, 18, 1);
  SetDoor(46, 21392, 22688,  8848, 39072, 11, 1);
  SetDoor(47, 21600, 17728,  7264, 38976, 18, 1);
  SetDoor(48, 21616, 25728, 11392, 36224,  3, 1);
  SetDoor(49, 21648, 17824,  7312, 39072, 11, 1);
  SetDoor(50, 22000, 21216,  5856, 33760, 10, 1);
  SetDoor(51, 22208, 21440,  7104, 33984, 13, 1);
  SetDoor(52, 22208, 21568,  6592, 34112, 13, 1);
  SetDoor(53, 22256, 20896,  6640, 33440, 13, 1);
  SetDoor(54, 22272, 21056,  7664, 33600, 14, 1);
  SetDoor(55, 22288, 21568,  7184, 34368, 13, 1);
  SetDoor(56, 22320, 21248,  6736, 33792, 13, 1);
  SetDoor(57, 22320, 21376,  7216, 33920, 14, 1);
  SetDoor(58, 22352, 20896,  7264, 33440, 13, 1);
  SetDoor(59, 22352, 21088,  8272, 33632, 13, 1);
  SetDoor(60, 22368, 21440,  8288, 33984, 13, 1);
  SetDoor(61, 22368, 21568,  7776, 34112, 13, 1);
  SetDoor(62, 22624, 23872,  7264, 39488, 18, 1);
  SetDoor(63, 22672, 23968,  7312, 40096, 11, 1);
  SetDoor(64, 22720, 11872,  2752, 34912, 18, 2);
  SetDoor(65, 22880, 28480,  8800, 39488, 18, 1);
  SetDoor(66, 22928, 28576,  8848, 40096, 11, 1);
  SetDoor(67, 22944, 26464, 10912, 35680, 15, 1);
  SetDoor(68, 23008, 22656, 10192, 38528, 10, 1);
  SetDoor(69, 24176,  6752,  9600, 39520,  3, 1);
  SetDoor(70, 24256, 10592,  4544, 35680, 18, 2);
  SetDoor(71, 24672, 29248,  6496, 40000, 18, 1);
  SetDoor(72, 24720, 29344,  6544, 40096, 11, 1);
  SetDoor(73, 24816, 12992,  9712, 35776,  3, 1);
  SetDoor(74, 25792,  6240,   960, 34400, 18, 2);
  SetDoor(75, 25952, 23872,  8032, 39488, 18, 1);
  SetDoor(76, 26000, 23968,  8080, 39072, 11, 1);
  SetDoor(77, 26048,  6688,  1200, 34880,  9, 2);
  SetDoor(78, 26224, 10848, 11136, 39520,  3, 1);
  SetDoor(79, 26624,  7008, 10992, 36960,  9, 1);
  SetDoor(80, 27472, 17280, 10320, 36224, 13, 1);
  SetDoor(81, 27616, 31872, 11216, 38528, 10, 1);
  SetDoor(82, 27760, 11872, 10368, 39520,  3, 1);
  SetDoor(83, 28000, 26688,  8032, 39488, 18, 1);
  SetDoor(84, 28048, 26784,  8080, 39584, 11, 1);
  SetDoor(85, 28384, 21120, 12752, 38528, 10, 1)
END InitDoors;

PROCEDURE CheckDoor(heroX, heroY, regionNum: INTEGER;
                    VAR newX, newY, newRegion: INTEGER): BOOLEAN;
VAR i, k, j, xtest, ytest, dt: INTEGER;
    d: DoorRec;
BEGIN
  xtest := (heroX DIV 16) * 16;
  ytest := (heroY DIV 32) * 32;

  IF regionNum < 8 THEN
    (* Outdoor to Indoor: binary search by xc1 *)
    i := 0;
    k := DoorCount - 1;
    WHILE k >= i DO
      j := (k + i) DIV 2;
      d := doors[j];
      IF d.xc1 > xtest THEN
        k := j - 1
      ELSIF d.xc1 + 16 < xtest THEN
        i := j + 1
      ELSIF (d.xc1 < xtest) AND ((d.dtype MOD 2) = 0) THEN
        i := j + 1
      ELSIF d.yc1 > ytest THEN
        k := j - 1
      ELSIF d.yc1 < ytest THEN
        i := j + 1
      ELSE
        dt := d.dtype;
        IF dt = CAVE THEN
          newX := d.xc2 + 24;
          newY := d.yc2 + 16
        ELSIF (dt MOD 2) = 1 THEN
          newX := d.xc2 + 16;
          newY := d.yc2
        ELSE
          newX := d.xc2 - 1;
          newY := d.yc2 + 16
        END;
        IF d.secs = 1 THEN
          newRegion := 8
        ELSE
          newRegion := 9
        END;
        WriteString("Door: entering region ");
        WriteInt(newRegion, 1); WriteLn;
        RETURN TRUE
      END;
      IF (i >= DoorCount) OR (k < 0) THEN
        RETURN FALSE
      END
    END
  ELSE
    (* Indoor to Outdoor: linear search by xc2/yc2 *)
    FOR j := 0 TO DoorCount - 1 DO
      d := doors[j];
      IF (d.yc2 = ytest) AND
         ((d.xc2 = xtest) OR
          ((d.xc2 = xtest - 16) AND ((d.dtype MOD 2) = 1))) THEN
        dt := d.dtype;
        IF dt = CAVE THEN
          newX := d.xc1 - 4;
          newY := d.yc1 + 16
        ELSIF (dt MOD 2) = 1 THEN
          newX := d.xc1 + 16;
          newY := d.yc1 + 34
        ELSE
          newX := d.xc1 + 20;
          newY := d.yc1 + 16
        END;
        newRegion := -1;
        WriteString("Door: exiting to outdoor"); WriteLn;
        RETURN TRUE
      END
    END
  END;

  RETURN FALSE
END CheckDoor;

END Doors.
