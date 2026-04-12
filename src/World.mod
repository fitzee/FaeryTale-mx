IMPLEMENTATION MODULE World;

FROM Platform IMPORT PlayW, PlayH;

PROCEDURE InitWorld;
VAR x, y: INTEGER;
BEGIN
  camX := 0;
  camY := 0;

  (* Fill with grass *)
  FOR x := 0 TO WorldW - 1 DO
    FOR y := 0 TO WorldH - 1 DO
      tiles[x][y].terrain := TerrGrass
    END
  END;

  (* World border walls *)
  FOR x := 0 TO WorldW - 1 DO
    tiles[x][0].terrain := TerrMountain;
    tiles[x][WorldH - 1].terrain := TerrMountain
  END;
  FOR y := 0 TO WorldH - 1 DO
    tiles[0][y].terrain := TerrMountain;
    tiles[WorldW - 1][y].terrain := TerrMountain
  END;

  (* ---- Large lake in NW quadrant ---- *)
  FOR x := 5 TO 15 DO
    FOR y := 5 TO 12 DO
      tiles[x][y].terrain := TerrWater
    END
  END;
  (* Shore sand *)
  FOR x := 4 TO 16 DO
    tiles[x][4].terrain := TerrSand;
    tiles[x][13].terrain := TerrSand
  END;
  FOR y := 4 TO 13 DO
    tiles[4][y].terrain := TerrSand;
    tiles[16][y].terrain := TerrSand
  END;
  (* Bridge across lake *)
  FOR x := 9 TO 11 DO
    tiles[x][8].terrain := TerrBridge;
    tiles[x][9].terrain := TerrBridge
  END;

  (* ---- Forest in NE quadrant ---- *)
  FOR x := 35 TO 50 DO
    FOR y := 4 TO 15 DO
      tiles[x][y].terrain := TerrForest
    END
  END;
  (* Clearing in forest *)
  FOR x := 40 TO 44 DO
    FOR y := 8 TO 11 DO
      tiles[x][y].terrain := TerrGrass
    END
  END;
  (* Path through forest *)
  FOR x := 35 TO 50 DO
    tiles[x][10].terrain := TerrPath
  END;

  (* ---- Main east-west road ---- *)
  FOR x := 2 TO WorldW - 3 DO
    tiles[x][30].terrain := TerrPath;
    tiles[x][31].terrain := TerrPath
  END;

  (* ---- Main north-south road ---- *)
  FOR y := 2 TO WorldH - 3 DO
    tiles[30][y].terrain := TerrPath;
    tiles[31][y].terrain := TerrPath
  END;

  (* ---- Town at crossroads (center) ---- *)
  (* Town square *)
  FOR x := 26 TO 35 DO
    FOR y := 26 TO 35 DO
      tiles[x][y].terrain := TerrPath
    END
  END;

  (* Building 1: tavern (NW of crossroads) *)
  BuildRoom(22, 22, 6, 5);
  tiles[24][26].terrain := TerrDoor;

  (* Building 2: armory (NE of crossroads) *)
  BuildRoom(36, 22, 6, 5);
  tiles[38][26].terrain := TerrDoor;

  (* Building 3: house (SW of crossroads) *)
  BuildRoom(22, 36, 5, 5);
  tiles[24][36].terrain := TerrDoor;

  (* Building 4: castle (SE of crossroads) *)
  BuildRoom(37, 36, 8, 7);
  tiles[40][36].terrain := TerrDoor;
  (* Castle interior floor *)
  FOR x := 38 TO 44 DO
    FOR y := 37 TO 42 DO
      tiles[x][y].terrain := TerrFloor
    END
  END;

  (* ---- Swamp in SW quadrant ---- *)
  FOR x := 5 TO 18 DO
    FOR y := 42 TO 55 DO
      tiles[x][y].terrain := TerrSwamp
    END
  END;
  (* Some water pools in swamp *)
  FOR x := 8 TO 10 DO
    FOR y := 46 TO 48 DO
      tiles[x][y].terrain := TerrWater
    END
  END;
  FOR x := 14 TO 16 DO
    FOR y := 50 TO 52 DO
      tiles[x][y].terrain := TerrWater
    END
  END;

  (* ---- Mountain range in SE ---- *)
  FOR x := 45 TO 58 DO
    FOR y := 45 TO 55 DO
      tiles[x][y].terrain := TerrMountain
    END
  END;
  (* Mountain pass *)
  FOR y := 48 TO 52 DO
    tiles[50][y].terrain := TerrPath;
    tiles[51][y].terrain := TerrPath
  END;

  (* ---- Scattered trees ---- *)
  tiles[20][15].terrain := TerrForest;
  tiles[21][16].terrain := TerrForest;
  tiles[19][17].terrain := TerrForest;
  tiles[25][12].terrain := TerrForest;
  tiles[26][13].terrain := TerrForest;
  tiles[50][30].terrain := TerrForest;
  tiles[51][29].terrain := TerrForest;
  tiles[52][30].terrain := TerrForest;
  tiles[15][35].terrain := TerrForest;
  tiles[16][36].terrain := TerrForest
END InitWorld;

PROCEDURE BuildRoom(rx, ry, rw, rh: INTEGER);
VAR x, y: INTEGER;
BEGIN
  (* Walls around perimeter *)
  FOR x := rx TO rx + rw - 1 DO
    tiles[x][ry].terrain := TerrWall;
    tiles[x][ry + rh - 1].terrain := TerrWall
  END;
  FOR y := ry TO ry + rh - 1 DO
    tiles[rx][y].terrain := TerrWall;
    tiles[rx + rw - 1][y].terrain := TerrWall
  END;
  (* Floor inside *)
  FOR x := rx + 1 TO rx + rw - 2 DO
    FOR y := ry + 1 TO ry + rh - 2 DO
      tiles[x][y].terrain := TerrFloor
    END
  END
END BuildRoom;

PROCEDURE IsPassable(terrain: INTEGER): BOOLEAN;
BEGIN
  RETURN (terrain = TerrGrass) OR (terrain = TerrPath) OR
         (terrain = TerrDoor) OR (terrain = TerrSand) OR
         (terrain = TerrBridge) OR (terrain = TerrFloor) OR
         (terrain = TerrSwamp) OR (terrain = TerrForest)
END IsPassable;

PROCEDURE TerrainSpeed(terrain: INTEGER): INTEGER;
BEGIN
  CASE terrain OF
    TerrSwamp:  RETURN 1 |
    TerrForest: RETURN 1 |
    TerrSand:   RETURN 1 |
    TerrPath:   RETURN 3
  ELSE
    RETURN 2
  END
END TerrainSpeed;

PROCEDURE GetTerrain(x, y: INTEGER): INTEGER;
VAR tx, ty: INTEGER;
BEGIN
  tx := x DIV TileSize;
  ty := y DIV TileSize;
  IF (tx < 0) OR (tx >= WorldW) OR (ty < 0) OR (ty >= WorldH) THEN
    RETURN TerrMountain
  END;
  RETURN tiles[tx][ty].terrain
END GetTerrain;

PROCEDURE WorldToTile(wx: INTEGER): INTEGER;
BEGIN
  RETURN wx DIV TileSize
END WorldToTile;

PROCEDURE UpdateCamera(playerX, playerY: INTEGER);
VAR halfW, halfH: INTEGER;
BEGIN
  halfW := PlayW DIV 2;
  halfH := PlayH DIV 2;
  camX := playerX - halfW;
  camY := playerY - halfH;
  IF camX < 0 THEN camX := 0 END;
  IF camY < 0 THEN camY := 0 END;
  (* MaxCoord is 32768 for the original world *)
  IF camX > MaxCoord - PlayW THEN
    camX := MaxCoord - PlayW
  END;
  IF camY > MaxCoord - PlayH THEN
    camY := MaxCoord - PlayH
  END
END UpdateCamera;

END World.
