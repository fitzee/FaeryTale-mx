# Faery Tale Adventure — Modula-2 (mx) Port

Back in 1988 or so, I read about *The Faery Tale Adventure* for the Amiga in a computer magazine. The screenshots and the sheer scale of the game (something like ~17,000 screens) completely blew me away. I didn’t even own an Amiga at the time, but suddenly I really wanted one just to play this. I actually remember asking my Nan in the UK to buy me the game before I even had the machine. I still have the original sleeve, map, and the 3.5" floppy it came on.

Since then, I’ve played it on and off on real Amigas and via UAE. By modern standards it’s obviously dated, but I still enjoy it, mostly for the nostalgia, though the fantasy setting has always kept it appealing. I did finish it back in the day, and I’ve always thought it deserved a sequel.

Years later, Talin (David Joiner), the original “jack of all trades” behind the game, released the source code on GitHub. It’s a mix of 68k assembler and C, not the easiest to follow, and full of Amiga-specific hardware tricks, but it’s also a bit of a masterclass in algorithms and data structures.

So with the source available, the obvious question was: now what? Some people have started porting it using modern abstractions like SDL, but I figured I’d take a different angle, why not try to port or recreate as much of it as possible using my own Modula-2 compiler, *mx*? It seemed like a solid way to stress test the compiler while scratching that long-standing nostalgic itch.

*mx* had already handled a few projects, but this pulled a lot of threads together. It pushed the compiler further and gave me a deeper appreciation for the original codebase. It wasn’t straightforward, but I hope the result does justice to the original, and maybe proves useful or interesting to others.

I’m immensely grateful to Talin for building the original game and then releasing the code all these years later.

---

## Modula-2 Port vs Original (C / 68k ASM)

### What translates well

- Strong typing and explicit record structures make the data model clearer than the original’s loosely-typed C structs. Types like `Actor`, `WorldObject`, and `MissileRec` are self-describing where the original used `char` for everything from weapon codes to animation states.
- The module system (DEF/MOD separation) enforces cleaner boundaries than the original’s spread across large C files. Each concern lives in its own module with an explicit interface.
- PIM4 `CASE` statements map cleanly to the original’s switch/case tables (encounter charts, statelists, direction tables, menus).

### What fights you

- No array constant initializers, simple tables become procedural setup code:
  ```modula-2
  diroffs[0] := 16; diroffs[1] := 16; ...
  ```
- No 2D open array parameters, attempting `ARRAY OF ARRAY OF CHAR` as a parameter caused runtime faults in `mx`. Workarounds involve direct indexing or accessors instead of passing tables.
- Exported record array `VAR`s are unreliable across module boundaries, writes may not persist. Resolved by keeping data module-local and exposing via procedures.
- No unsigned types in PIM4, bitwise operations require explicit casting:
  ```modula-2
  inum := BOR(INTEGER(CARDINAL(inum)), 1);
  ```
- No `break` or `goto`, the original’s heavy use of `goto` for movement and collision fallback chains requires restructuring into nested conditionals or helper procedures.

---

## What the original does that’s genuinely clever

- Even and odd sprite interleaving, packs two subtypes into one sprite sheet with a single bit toggle. Halves asset count.
- Combat state machine (`trans_list`), 9 states with random transitions (4 exits each). About 36 bytes drives varied melee animation.
- Copper mode split, HUD rendered at higher horizontal resolution than the playfield via mid-frame mode switching. Replicated here via coordinate mapping.
- Environment ramp system, water depth and terrain effects modeled as gradual integer transitions instead of binary states.

---

## Architecture comparison

The original is a monolithic frame loop, movement, AI, rendering, collision, sound, and narrative all interleaved, sharing globals and local state inside large functions.

The Modula-2 port separates these into about 25 modules with explicit interfaces. This improves readability and isolation, but introduces friction where the original relied on direct global access. Systems that were tightly coupled now require explicit state passing.

The original’s structure is arguably more honest about how intertwined these systems are:
- AI directly influences rendering state  
- Movement triggers world transitions  
- Collision doubles as terrain detection  

Decoupling these requires additional plumbing that didn’t exist before.

---

## Selected implementation details

The port preserves many of the original’s underlying techniques:

- Copper-style dual-resolution rendering (HUD vs playfield)
- Tile masking for sprite occlusion
- Sector-based world layout with region wrapping
- Finite-state AI with goal and tactic separation
- Proximity-based encounter spawning
- Day and night palette modulation
- 8-direction quantized movement with collision fallback
- Projectile system reusing actor movement logic
- Trigger-based narration system
- Actor slot recycling
- Menu system mapped into HUD coordinate space

(Full list in project notes)

---

## Bottom line

Modula-2 produces more maintainable, structured code at the cost of verbosity and friction around low-level constructs.

The original C and 68k code is compact and direct, but difficult to reason about or modify safely.

The port is roughly 3× the line count for equivalent functionality, largely due to:
- procedural table initialization
- explicit type conversions
- stricter module boundaries

---

## Repository

If you want to try *mx* or explore the port:

https://github.com/fitzee/mx
