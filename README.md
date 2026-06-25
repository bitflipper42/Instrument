# Instrument

A Godot 4.6 2D project that displays interactive musical instruments as resizable tiles. Instruments can emit and receive note names, and are wired together so playing one highlights matching positions on another.

This document is written for humans and for AI assistants continuing work on the codebase.

## Quick reference

| Item | Value |
|------|-------|
| Engine | Godot 4.6 (Forward+) |
| Language | GDScript |
| Main scene | `res://main.tscn` |
| Root node | `Main` (Node2D) |
| Window | Maximized (`window/size/mode=2`), canvas_items stretch |
| Default layout | 2 horizontal tiles: Piano (top), Guitar (bottom) |

## Running the project

```bash
# Example path — adjust to your Godot install
~/Downloads/Godot.app/Contents/MacOS/Godot --path /path/to/Instrument
```

Open `project.godot` in the Godot editor, or run the command above. Press **F5** to play.

**Always run the project when done with a change.** Launch Godot after implementing or modifying code so the result can be verified in the running app. Leave the window open — do not auto-close with flags like `--quit-after`.

## Architecture

### Scene tree

```
Main (Node2D)                    main.gd
└── TileManager (Node2D)         tile_manager.gd
    ├── PianoInstrument          (top tile, spawned by TileManager)
    └── GuitarInstrument         (bottom tile, swapped in by main.gd)
```

`TileManager` owns all instrument tiles as child nodes. It positions them as **full-width horizontal bars stacked vertically**, reflowing on window resize.

### Class hierarchy

All instruments are `Node2D` nodes that draw via `_draw()` (no Control/UI nodes).

```
InstTile
└── BasicInstrument
    ├── PianoInstrument
    └── GuitarInstrument
```

| Class | File | Role |
|-------|------|------|
| `InstTile` | `inst_tile.gd` | Base tile: rect layout, border, title, `set_rect()` |
| `BasicInstrument` | `basic_instrument.gd` | Note I/O: signals, validation, `connect_to()` |
| `PianoInstrument` | `piano_instrument.gd` | 88-key piano keyboard |
| `GuitarInstrument` | `guitar_instrument.gd` | 12-fret horizontal guitar neck |
| `TileManager` | `tile_manager.gd` | Spawns, lays out, and rearranges tiles |

Each concrete instrument has a matching `.tscn` scene file with the script attached.

### File map

```
Instrument/
├── project.godot          # Project config (name, window, main scene)
├── main.tscn / main.gd    # Entry point; wires piano → guitar
├── tile_manager.gd        # Tile layout manager (no .tscn; script on node in main.tscn)
├── inst_tile.gd/.tscn     # Base tile
├── basic_instrument.gd/.tscn
├── piano_instrument.gd/.tscn
├── guitar_instrument.gd/.tscn
├── icon.svg
├── .gitignore             # Ignores .godot/, .import/, etc.
└── README.md
```

## Tile system (`TileManager`)

- **Layout**: Tiles are horizontal strips (full viewport width, equal height split).
- **Default spawn**: `default_tile_count = 2`, `tile_scene = piano_instrument.tscn`.
- **API**:
  - `add_tile(title)` — spawns using default `tile_scene`
  - `add_tile_from_scene(scene, title)` — spawns a specific instrument scene
  - `remove_tile(index)`, `swap_tiles(a, b)`, `move_tile(from, to)`
  - `arrange_tiles()` — called on resize and after tile list changes
- **Exported knobs**: `spacing`, `margin`, `tile_scene`, `default_tile_count`

Tiles receive their screen rect via `InstTile.set_rect(top_left, size)`, which sets `position` and `tile_size` and triggers `queue_redraw()`.

## Note system (`BasicInstrument`)

### Chromatic names

Canonical pitch names (sharps only):

`C, C#, D, D#, E, F, F#, G, G#, A, A#, B`

Flats are normalized to sharps via `FLAT_ALIASES` (e.g. `Bb` → `A#`).

### Signals and methods

```gdscript
signal note_emitted(note: String)
signal note_received(note: String)

func emit_note(note: String) -> bool      # Validate, store, redraw, emit signal
func receive_note(note: String) -> bool    # Validate, store, redraw, emit signal
func connect_to(other: BasicInstrument)    # note_emitted → other.receive_note
func normalize_note(note: String) -> String
func is_valid_note(note: String) -> bool
```

`current_note` holds the most recent note (emit or receive).

### Note format conventions

| Instrument | Format | Example |
|------------|--------|---------|
| `BasicInstrument` | Pitch only | `"C"`, `"F#"` |
| `PianoInstrument` | Pitch + octave | `"C4"`, `"A0"` |
| `GuitarInstrument` | Pitch + octave | `"E2"`, `"G3"` |

Piano and guitar **override** `emit_note` / `receive_note` to accept octave-qualified names. They also accept plain chromatic names (no octave); matching then highlights all keys/strings with that pitch class.

**Cross-instrument caveat**: Piano emits `"C4"` but `BasicInstrument.receive_note` only accepts chromatic names without octave. Piano→guitar works because `GuitarInstrument` overrides `receive_note`. Piano→plain `BasicInstrument` would fail on octave-qualified input.

## Current runtime wiring (`main.gd`)

On `_ready()`:

1. `TileManager` has already spawned 2 piano tiles.
2. `main.gd` renames tile 0 to `"Piano"`.
3. Removes tile 1 and replaces it with `GuitarInstrument` via `add_tile_from_scene`.
4. Connects piano `note_emitted` → guitar `receive_note`.

Result: click a piano key → guitar highlights matching fret/open position.

## PianoInstrument

- **Range**: 88 keys, MIDI 21–108 (`A0`–`C8`).
- **Layout**: White keys span full tile width (52 whites). Key **depth** uses ratio `WHITE_KEY_DEPTH_RATIO = 7.0` (realistic width:height). Extra vertical space becomes top/bottom **stretchers** (wood frame).
- **Input**: Left-click key → `emit_note("C4")` etc.
- **Highlight**: Exact octave match, or all keys matching pitch class if no octave in `current_note`.
- **Drawing**: Overrides `_draw()` completely (does not use `BasicInstrument`’s large centered note text).

## GuitarInstrument

- **Neck**: Horizontal, left-to-right. Nut on the left (double vertical line), 12 frets as vertical lines with proper spacing (`1 - 2^(-n/12)` scaled so fret 12 is at the right edge).
- **Strings**: 6 strings horizontal (standard tuning E A D G B E, low to high in array index 0–5).
- **Open-string zone**: Narrow strip left of nut, width = `2 * marker_radius + padding`. Clickable for open notes.
- **Fret markers**: Dots at frets 3, 5, 7, 9 (single), 12 (double).
- **Note markers**: Circles with bold centered text (`FontVariation.variation_embolden = 1.2`). Label format: single line e.g. `E2`.
- **Open-string marker visibility**: Hidden by default. Shown only when `_show_open_markers` is true (set in `receive_note`, cleared in `emit_note`). Only matching open string(s) are drawn.
- **Fretted highlight**: Active fretted cells show circle markers via `_draw_active_cells()`.
- **Tuning**: `OPEN_STRING_NOTES` + `OPEN_STRING_OCTAVES` → E2, A2, D3, G3, B3, E4 at fret 0.

## Drawing and input patterns

Instruments use the same patterns:

1. **`_update_layout()`** — compute geometry from `tile_size` into cached rects/arrays.
2. **`_draw()`** — call layout, draw chrome, draw instrument.
3. **`_input(event)`** — on left click inside tile global rect, map to local pos, hit-test, `emit_note()`.

Hit-testing uses precomputed cell dicts: `{ "note", "rect", "fret", "string", ... }`.

### Godot drawing gotchas (learned in this project)

- **Integer division**: Use `int(midi / 12)`, not `//` (invalid in GDScript 4).
- **Bold font**: `FontVariation.variation_embolden` (not `variation_embold`).
- **Centered `draw_string`**: `HORIZONTAL_ALIGNMENT_CENTER` requires an explicit `width`; with `-1` text is left-aligned at `pos.x`. Use `draw_string(font, Vector2(center.x - radius, y), text, CENTER, radius * 2, ...)`.
- **Vertical centering**: `baseline_y = center.y + (ascent - descent) * 0.5`.

## Adding a new instrument

1. Create `my_instrument.gd` extending `BasicInstrument` (or `InstTile` if no note I/O).
2. Add `class_name MyInstrument` and a `.tscn` with script attached.
3. Override `_draw()` for custom visuals; override `emit_note`/`receive_note` if using octaves or custom validation.
4. Handle input in `_input()` or `_unhandled_input()`.
5. Register in scene: `tile_manager.add_tile_from_scene(preload("res://my_instrument.tscn"), "Title")`.
6. Godot will generate `.uid` files and `.godot/` cache on import (gitignored).

Do **not** modify `BasicInstrument` for one-off behavior — derive a new class (see `PianoInstrument`, `GuitarInstrument`).

## Git history (logical progression)

1. Godot project scaffold + `.gitignore`
2. `InstTile` base class
3. `TileManager` horizontal layout
4. `BasicInstrument` note emit/receive
5. `PianoInstrument` keyboard
6. Piano upgraded to 88 keys + stretchers
7. `GuitarInstrument` + piano/guitar mixed layout
8. Guitar marker UX (circles, open-string-on-receive-only)

## Out of scope / not yet implemented

- Audio playback (no `AudioStreamPlayer` yet)
- MIDI input
- Octave-aware matching in `BasicInstrument` base class
- Guitar body outline (removed per design)
- Persistence, menus, or multiple scenes

## Conventions for contributors and AI

- **Minimize scope**: Extend via new subclasses; avoid unrelated edits.
- **Match style**: `class_name`, typed arrays (`Array[InstTile]`), `##` doc comments on exports, `_private` helpers, `_draw_*` decomposition.
- **Commits**: User prefers logical, separate commits (scaffold → base → feature → wiring).
- **Verification**: Always run the project when finished with a change (see **Running the project** above). Leave the app open; do not use `--quit-after` when launching for review.
- **TileManager children**: Instruments are children of `TileManager`, not directly of `Main`.
