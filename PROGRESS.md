# Progress Log

## Phase 1 - COMPLETE
- Project skeleton with m2.toml (edition=m2plus, m2gfx + m2sys deps)
- Platform module: thin SDL2 boundary (window, input, timing, rendering)
- Actor module: pure M2 actor/entity types
- World module: pure M2 tile grid
- Movement module: pure M2 8-directional movement + collision
- Main module: fixed-step game loop

## Phase 2 - COMPLETE
- 8-directional collision, health bars, HUD, fixed timestep

## Phase 3 - COMPLETE
- EnemyAI, Combat, Items, NPC dialogue, enemy drops
- 5 enemies, 12 items, 3 NPCs across the world

## Phase 4 - COMPLETE
- Scrolling camera, day/night cycle, minimap
- Three-brothers mechanic (Julian, Philip, Kevin)
- Terrain speed modifiers, swamp damage
- Brother/inventory/day-night HUD indicators

## Phase 5 - COMPLETE
- **Original binary assets loaded successfully**
- Assets module: loads sector, map, terrain .bin files via m2sys (pure M2 parsing)
- Tile image PNGs loaded via PixBuf.LoadPNG (through platform boundary)
- All 10 region definitions from original need table
- Region 5 (Bay/City/Farms) loads: sector_032, map_176, terrain_05/06, image_320/280/240/200
- PixBuf screen buffer for indexed-color tile rendering
- BlitTile: pixel-by-pixel tile copy from image PixBuf to screen PixBuf
- Sector byte lookup: world coords -> map -> sector -> tile index
- Terrain attribute lookup from binary terrain data
- Fallback to colored rectangles when assets not loaded
