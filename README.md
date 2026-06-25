# Instrument

A Godot 4.6 2D project that displays interactive musical instruments as resizable tiles. Instruments can emit and receive note names (pitch or pitch+octave), and are wired together so playing one highlights matching positions on another.

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
| `BasicInstrument` | `basic_instrument.gd` | Note I/O: octave parsing, matching, `connect_to()` / `connect_bidirectional()` |
| `PianoInstrument` | `piano_instrument.gd` | 64-key piano keyboard (A1–C7) |
| `GuitarInstrument` | `guitar_instrument.gd` | 12-fret horizontal guitar neck |
| `TileManager` | `tile_manager.gd` | Spawns, lays out, and rearranges tiles |

Each concrete instrument has a matching `.tscn` scene file with the script attached.

### File map

```
Instrument/
├── project.godot          # Project config (name, window, main scene)
├── main.tscn / main.gd    # Entry point; bidirectional piano ↔ guitar wiring
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

func play_note(note: String) -> bool           # User click → emit_note
func emit_note(note: String) -> bool           # Validate, store, redraw, emit signal
func receive_note(note: String) -> bool        # Validate, store, redraw; does NOT re-emit
func connect_to(other: BasicInstrument)        # note_emitted → other.receive_note
func connect_bidirectional(other: BasicInstrument)  # Two-way connect_to; no feedback loop
func normalize_note(note: String) -> String
func is_valid_note(note: String) -> bool       # Pitch or pitch+octave
```

`current_note` holds the most recent note (emit or receive).

`receive_note` updates state and emits `note_received` only — it never calls `note_emitted`, so bidirectional wiring does not loop.

### Pitch and octave parsing

The base class accepts both pitch-only and pitch+octave names via `_normalize_pitch()`:

| Input | Stored as | Example |
|-------|-----------|---------|
| Pitch only | Chromatic name | `"C"`, `"F#"` |
| Pitch + octave | Pitch + digit(s) | `"C4"`, `"A0"` |

Helpers (protected, used by subclasses): `_split_pitch()`, `_name_to_midi()`, `_midi_to_name()`, `_note_matches()`.

### Matching (`_note_matches`)

| `current_note` | Key/cell note | Matches when |
|----------------|---------------|--------------|
| `"C4"` | `"C4"` | Exact string |
| `"C4"` | `"C5"` | Same MIDI pitch |
| `"C"` | `"C4"`, `"C5"`, … | Same pitch class |
| `"C4"` | `"C"` (pitch only) | No — octave required on key side |

Piano and guitar call `_note_matches()` for highlights. `PianoInstrument` additionally constrains playable range in `emit_note` via `_is_valid_piano_note()`.

## Current runtime wiring (`main.gd`)

On `_ready()`:

1. `TileManager` has already spawned 2 piano tiles.
2. `main.gd` renames tile 0 to `"Piano"`.
3. Removes tile 1 and replaces it with `GuitarInstrument` via `add_tile_from_scene`.
4. Calls `piano.connect_bidirectional(guitar)`.

Result: click either instrument → the other highlights the matching key/fret/open position.

## PianoInstrument

- **Range**: 64 keys, MIDI 33–96 (`A1`–`C7`) — full 88-key span with one octave removed from each end.
- **Layout**: White keys span full tile width. Key **depth** uses ratio `WHITE_KEY_DEPTH_RATIO = 7.0` (realistic width:height). Extra vertical space becomes top/bottom **stretchers** (wood frame).
- **Input**: Left-click key → `play_note("C4")` etc.
- **Highlight**: Active keys use `active_key_color` via `_note_matches()`. Non-`C` white keys and black keys also get a **circle marker** with the pitch letter (`_draw_active_markers()`). `C` white keys show a small octave label at the bottom of the key (e.g. `C4`).
- **Drawing**: Overrides `_draw()` completely (does not use `BasicInstrument`’s large centered note text).

## GuitarInstrument

- **Neck**: Left → right (open zone and nut on the left, frets and bridge on the right). Tab-style view: horizontal strings, vertical frets.
- **Strings**: Standard tuning. Top to bottom on screen: high E → B → G → D → A → low E (array index 5 → 0). Line width tapers from bass to treble (`STRING_WIDTHS`).
- **Open-string zone**: Clickable strip left of the nut. Open-string note labels (e.g. `E2`, `A2`) centered above each string; active open notes show circle markers in the zone.
- **Fret markers**: Dots at frets 3, 5, 7, 9 (single, numbered), 12 (double dots with centered `12` label).
- **Note markers**: Circle markers with bold note text on any matching cell (open or fretted), whether clicked locally or received from another instrument.
- **Tuning**: `OPEN_STRING_NOTES` + `OPEN_STRING_OCTAVES` → E2, A2, D3, G3, B3, E4 at fret 0.

## Drawing and input patterns

Instruments use the same patterns:

1. **`_update_layout()`** — compute geometry from `tile_size` into cached rects/arrays.
2. **`_draw()`** — call layout, draw chrome, draw instrument.
3. **`_input(event)`** — on left click inside tile global rect, map to local pos, hit-test, `play_note()`.

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
4. Handle input in `_input()` or `_unhandled_input()`; call `play_note()` on click.
5. Register in scene: `tile_manager.add_tile_from_scene(preload("res://my_instrument.tscn"), "Title")`.
6. Godot will generate `.uid` files and `.godot/` cache on import (gitignored).

Do **not** modify `BasicInstrument` for one-off behavior — derive a new class (see `PianoInstrument`, `GuitarInstrument`).

## Git history (logical progression)

1. Godot project scaffold + `.gitignore`
2. `InstTile` base class
3. `TileManager` horizontal layout
4. `BasicInstrument` note emit/receive
5. `PianoInstrument` keyboard
6. Piano upgraded to full keyboard span + stretchers (later trimmed to 64 keys, A1–C7)
7. `GuitarInstrument` + piano/guitar mixed layout
8. Guitar marker UX (circles, open-string-on-receive-only)
9. Octave-aware note parsing, bidirectional wiring, piano circle markers
10. Guitar visual polish (nut, bridge, string thickness, labels) and unified open-string markers

## Out of scope / not yet implemented

- Audio playback (no `AudioStreamPlayer` yet)
- MIDI input
- Guitar body outline (removed per design)
- Persistence, menus, or multiple scenes

## Conventions for contributors and AI

- **Minimize scope**: Extend via new subclasses; avoid unrelated edits.
- **Match style**: `class_name`, typed arrays (`Array[InstTile]`), `##` doc comments on exports, `_private` helpers, `_draw_*` decomposition.
- **Commits**: User prefers logical, separate commits (scaffold → base → feature → wiring).
- **Verification**: Always run the project when finished with a change (see **Running the project** above). Leave the app open; do not use `--quit-after` when launching for review.
- **TileManager children**: Instruments are children of `TileManager`, not directly of `Main`.
