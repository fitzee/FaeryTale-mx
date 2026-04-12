# Porting Notes

## Architecture

### Module Map
```
Main.mod          Entry point, game loop (pure M2)
Platform.def/mod  SDL2 boundary via m2gfx (ONLY non-pure module)
Actor.def/mod     Entity types and states (pure M2)
World.def/mod     Tile world, terrain, camera (pure M2)
Movement.def/mod  8-way movement, collision (pure M2)
EnemyAI.def/mod   Goal/tactic AI system (pure M2)
Combat.def/mod    Hit detection, damage (pure M2)
Items.def/mod     World items, inventory (pure M2)
Brothers.def/mod  Three-brother mechanic (pure M2)
NPC.def/mod       NPC dialogue system (pure M2)
DayNight.def/mod  Day/night cycle (pure M2)
Render.def/mod    Drawing (uses Platform - thin bridge)
GameState.def/mod Game state orchestration (pure M2)
```

### Purity Summary
- 11 of 13 modules are pure Modula-2
- Platform.mod is the ONLY module that imports from m2gfx (SDL2)
- Render.mod imports from Platform but contains no direct SDL2 calls

## Key Design Decisions

### Movement System
Original `newx/newy` direction tables reimplemented in pure M2:
- 8-directional with speed multiplier
- Terrain speed modifiers: swamp/forest=1, normal=2, path=3
- Entity collision: 11x9 pixel bounding box (matches original)

### Collision Model
Original `proxcheck` = terrain + entity collision.
- Terrain: tile lookup, walls/water/mountains block
- Swamp and forest are passable but slow
- Entity: bounding box proximity check

### World Representation
Original: 128x128 sectors, 256 total, with terrain types.
Current: 64x64 tile grid with handcrafted world.
Multiple biomes: lake, forest, swamp, mountains, town, castle.

### Three Brothers
Original: Julian dies -> Philip takes over -> Kevin.
Implemented: each brother has name, vitality, weapon, start position.
Death triggers 2-second delay then brother switch with message.
All dead = game over.

### Enemy AI
Original goal/tactic system simplified:
- ATTACK1: pursue player within 200px, fight within 14px
- STAND: face player but don't move
- Deviation pathfinding: try +1 dir, then -2 dir (matches original)

### Day/Night Cycle
Original fades palette RGB values per `daynight` counter.
Implemented: brightness 25-100% with blue shift at night.
Full cycle = ~2 minutes. Applied as tint to terrain colors.

### Amiga-Specific Replacements
| Amiga | Replacement |
|-------|-------------|
| Blitter | Canvas FillRect/DrawRect |
| Copper | DayNight brightness tint |
| Custom sprite | Actor rectangle rendering |
| CIA timer | SDL2 Gfx.Ticks() |
| Keyboard handler | Events.IsKeyPressed (polled) |
| Amiga palette (12-bit) | 24-bit RGB via Canvas |
| Disk I/O | Not yet needed (hardcoded world) |
