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
- Original binary assets loaded successfully
- Assets module: loads sector, map, terrain .bin files
- Tile image BMPs loaded via SDL textures
- All 10 region definitions with image/terrain/sector mappings
- Sector byte lookup with xReg/yReg offset matching original px_to_im
- Sub-tile terrain collision using 8-region bitmask from original asm
- Terrain attribute lookup from binary terrain data
- Nearest-neighbor scaling on all textures for crisp pixel art

## Phase 6 - COMPLETE
- **HUD system**: bitmap font (topaz_8, pre-scaled 12px), menu panel
- 10 menu modes matching original (Items/Magic/Talk/Buy/Game/Save/Keys/Give/Use/File)
- HUD text palette (textcolors) distinct from game palette (pagecolors)
- Keyboard shortcuts for menu navigation
- Inventory-dependent menu options via SetOptions
- Compass direction indicator with per-direction pip rendering
- HUD scaled from 640x57 original to 960x171 screen

## Phase 7 - COMPLETE
- **Animated brother sprites**: Julian/Phillip/Kevin from original 16x32 sprite sheets
- 8-direction walking with frame cycling from diroffs table
- Terrain-aware sprite rendering: forest clips legs (environ=2), water submerges gradually
- Shadow baked into sprite frames

## Phase 8 - COMPLETE
- **Building door system**: 86 doors from original doorlist
- Indoor/outdoor coordinate mapping with region transitions (regions 8-9)
- Door direction enforcement (horizontal/vertical approach checks)
- Door entry gated by terrain type 15 (door tiles)
- Interior regions fully working with correct tile rendering
- Day/night disabled indoors, door cooldown prevents bounce

## Phase 9 - COMPLETE
- **Tile overlay masking via sprite mask pipeline**
- m2blitter library: pure M2 Amiga Blitter emulation with BAND/BOR/BNOT builtins
- Minterm engine: EvalMinterm for general boolean blitter operations
- Shadow mask (shadow_mem.png) loaded as PixBuf for per-pixel tile occlusion
- BuildSpriteMask: composite mask from overlapping tiles using original mask type rules
- Mask types 0-7 matching original fmain.c:3599-3631 (case 0: never, 1: xm check, 2: ystop>35, 3: always, etc.)
- Sprite drawn pixel-by-pixel through composite mask
- Ground offset corrected: absY-camY+16 matching original ystart+32
- Tile PNGs loaded with Amiga palette via LoadPNGPal for correct overlay colors
- SetPalAlpha added to m2gfx for transparent palette entries

## Phase 10 - COMPLETE
- **Seamless region boundaries**
- Per-tile region detection with GetSectorByteForRegion
- xReg/yReg sector lookup offset matching original px_to_im from fsubs.asm
- Region switching uses camera position (camX/camY) matching original map_x/map_y
- No region fade — instant invisible transitions
- Region boundary tiles render correctly with proper map/sector data per tile

## Phase 11 - COMPLETE
- **Movement and collision matching original**
- ProxCheck: two-point collision at (x+4,y+2) and (x-4,y+2) matching original prox()
- Terrain-based environ system: forest clips legs, water gradually submerges, roads speed up
- UpdateEnviron with gradual ramping for water entry/exit
- Wall sub-tile collision verified against original terrain data

## Phase 12 - IN PROGRESS
- **SMUS tracker music engine**
- Pure M2 4-voice tracker playing original FTA music data
- Loads waveforms (wavmem.bin), volume envelopes (volmem.bin), track data (songs.bin)
- 28 tracks across 7 moods: day, battle, night, special, indoor, death
- Period table and note duration table from original gdriver.asm
- SDL2 audio output via m2audio Playback module at 22050Hz mono
- Mood changes with day/night cycle and indoor/outdoor transitions
- Pitch and instrument mapping correct; tempo tuning still needed

## Architecture

### Libraries
- **m2gfx**: SDL2 graphics (with LoadBMPKeyed, SetPalAlpha, LoadPNGPal extensions)
- **m2blitter**: Pure M2 Amiga Blitter emulation (minterm engine, BlitMask, ShadowBlitRGBA)
- **m2audio**: SDL2 audio playback (Playback module for queued PCM output)
- **m2sys**: File I/O, system utilities

### Key Modules
- Platform.mod — SDL2 boundary (window, input, rendering, asset loading)
- Assets.mod — Binary asset loading, region management, sector/terrain lookup
- Render.mod — Tile rendering, sprite masking, HUD, compass, menu
- Movement.mod — Collision detection, terrain-based movement speed
- GameState.mod — Game loop, input handling, door system, mood selection
- Music.mod — SMUS tracker engine with SDL2 audio output
- Doors.mod — 86-door building entry/exit system
- BmFont.mod — Bitmap font rendering from topaz spritesheet
- Menu.mod — 10-mode menu system with keyboard shortcuts
- Blitter.mod — Minterm engine, masked blitting operations
- BlitMask.mod — 1-bit mask creation and boolean operations
- Compass.mod — Direction indicator overlay (unused, replaced by pip approach)

### GitHub
- Repository: https://github.com/fitzee/FaeryTale-mx
