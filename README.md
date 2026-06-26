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
| Default layout | Row 0: Piano + square Source; Row 1: Guitar; Row 2: Viola |

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
    ├── PianoInstrument          (row 0, left)
    ├── SourceInstrument         (row 0, right, square)
    ├── GuitarInstrument         (row 1)
    └── ViolaInstrument          (row 2)
```

`TileManager` owns all instrument tiles as child nodes. It positions them as **full-width horizontal bars stacked vertically**, reflowing on window resize.

### Class hierarchy

All instruments are `Node2D` nodes that draw via `_draw()` (no Control/UI nodes).

```
InstTile
└── BasicInstrument
    ├── PianoInstrument
    ├── GuitarInstrument
    ├── ViolaInstrument
    └── SourceInstrument
```

| Class | File | Role |
|-------|------|------|
| `InstTile` | `inst_tile.gd` | Base tile: rect layout, border, title, `set_rect()` |
| `BasicInstrument` | `basic_instrument.gd` | MIDI note I/O: `active_notes` set, octave parsing, matching, `release_all()`, `connect_to()` / `connect_bidirectional()`, shared input |
| `MidiMessage` | `midi_message.gd` | Note-on/note-off message value object |
| `PianoInstrument` | `piano_instrument.gd` | 64-key piano keyboard (A1–C7) |
| `GuitarInstrument` | `guitar_instrument.gd` | 13-fret horizontal guitar neck (fret 13 extension zone) |
| `ViolaInstrument` | `viola_instrument.gd` | 4-string fretted viola fingerboard (C3–A4) |
| `SourceInstrument` | `source_instrument.gd` | Control tile: note + scale dropdowns and a Clear button (UI via Control nodes) |
| `TileManager` | `tile_manager.gd` | Spawns, lays out, and rearranges tiles (rows model) |

Each concrete instrument has a matching `.tscn` scene file with the script attached.

### File map

```
Instrument/
├── project.godot          # Project config (name, window, main scene)
├── main.tscn / main.gd    # Entry point; bidirectional piano ↔ guitar ↔ viola wiring
├── tile_manager.gd        # Tile layout manager (no .tscn; script on node in main.tscn)
├── inst_tile.gd/.tscn     # Base tile
├── basic_instrument.gd/.tscn
├── midi_message.gd        # MidiMessage value object (note-on/note-off)
├── piano_instrument.gd/.tscn
├── guitar_instrument.gd/.tscn
├── viola_instrument.gd/.tscn
├── source_instrument.gd/.tscn  # Control tile (note + scale dropdowns, Clear button)
├── icon.svg
├── .gitignore             # Ignores .godot/, .import/, etc.
└── README.md
```

## Tile system (`TileManager`)

- **Layout**: A grid of **rows**. Rows stack vertically and split the viewport height equally; within a row, tiles are placed left to right. A tile marked **square** takes a fixed width equal to the row height; the remaining width is split equally among the non-square tiles in that row.
- **Data model**: `rows: Array` — each row is an `Array` of `{ "tile": InstTile, "square": bool }`.
- **Default spawn**: `default_tile_count = 0` (the layout is built explicitly from `main.gd`).
- **API**:
  - `add_row()` — appends an empty row, returns its index
  - `add_tile_to_row(row, scene, title, square := false)` — spawns a tile into a row
  - `add_tile_from_scene(scene, title, square := false)` — new single-tile row
  - `add_tile(title)` — new single-tile row using default `tile_scene`
  - `remove_tile(tile)` — removes by reference; drops the row if it empties
  - `all_tiles()` — flattened list of every tile (row-major)
  - `arrange_tiles()` — called on resize and after the row list changes
- **Exported knobs**: `spacing`, `margin`, `tile_scene`, `default_tile_count`

Tiles receive their screen rect via `InstTile.set_rect(top_left, size)`, which sets `position` and `tile_size` and triggers `queue_redraw()`. Tiles that host UI (e.g. `SourceInstrument`) override `set_rect` to reflow their controls.

## Note system (`BasicInstrument`)

Notes are exchanged as **MIDI-style messages** and several can sound at once.
Each instrument keeps a set of active notes; **note-on** adds a note, **note-off**
removes it. There is no single "current note".

### Chromatic names

Canonical pitch names (sharps only):

`C, C#, D, D#, E, F, F#, G, G#, A, A#, B`

Flats are normalized to sharps via `FLAT_ALIASES` (e.g. `Bb` → `A#`).

### MIDI messages (`MidiMessage`, `midi_message.gd`)

A lightweight `RefCounted` value object passed over the signals:

```gdscript
const NOTE_OFF := 0x80
const NOTE_ON  := 0x90

var type: int       # NOTE_ON / NOTE_OFF
var channel: int    # 0-15
var note: int       # MIDI note number 0-127
var velocity: int   # 0-127

static func note_on(note, velocity := 100, channel := 0) -> MidiMessage
static func note_off(note, velocity := 0, channel := 0) -> MidiMessage
func status() -> int        # (type & 0xF0) | (channel & 0x0F)
func is_note_on() -> bool    # NOTE_ON with velocity > 0
func is_note_off() -> bool   # NOTE_OFF, or NOTE_ON with velocity 0
```

### Signals and methods

```gdscript
signal midi_out(message: MidiMessage)       # Local note-on/off, sent to listeners
signal midi_received(message: MidiMessage)  # Incoming message applied (no re-emit)

func note_on(note: String, velocity := default_velocity) -> bool  # Add note, emit midi_out
func note_off(note: String) -> bool                               # Remove note, emit midi_out
func toggle_note(note: String) -> bool                            # Latch: off if active, else on
func play_note(note: String) -> bool                              # Convenience alias for note_on
func receive_midi(message: MidiMessage) -> void                   # Apply on/off; does NOT re-emit
func is_note_active(note: String) -> bool
func connect_to(other: BasicInstrument)        # midi_out → other.receive_midi
func connect_bidirectional(other: BasicInstrument)  # Two-way connect_to; no feedback loop
func normalize_note(note: String) -> String
func is_valid_note(note: String) -> bool       # Pitch or pitch+octave
func _can_play(note: String) -> bool           # Overridable range/validity gate
```

State lives in `active_notes: Dictionary` (MIDI note number → velocity). Exports:
`default_velocity` (click velocity), `midi_channel`, `octave_neighbor_radius`.

`receive_midi` updates state and emits `midi_received` only — it never emits `midi_out`, so bidirectional wiring does not loop.

### Pitch and octave parsing

The base class accepts both pitch-only and pitch+octave names via `_normalize_pitch()`:

| Input | Stored as | Example |
|-------|-----------|---------|
| Pitch only | Chromatic name | `"C"`, `"F#"` |
| Pitch + octave | Pitch + digit(s) | `"C4"`, `"A0"` |

Helpers (protected, used by subclasses): `_split_pitch()`, `_name_to_midi()`, `_midi_to_name()`, `_note_matches()`, `_note_matches_octave_neighbors()`.

### Matching (`_note_matches`)

Matching is against the **set of active notes** (by MIDI number):

| Active notes | Key/cell note | Matches when |
|--------------|---------------|--------------|
| `{C4}` | `"C4"` | Same MIDI number |
| `{C4}` | `"C5"` | No (different MIDI number) |
| `{C4, E4, G4}` | `"E4"` | Member of the active set |
| `{C4}` | `"C"` (pitch only) | Same pitch class as some active note |

Piano, guitar, and viola call `_note_matches()` for the **primary** highlight (key fill on piano, active marker color on the necks). `PianoInstrument` constrains playable range by overriding `_can_play()` with `_is_valid_piano_note()`.

### Octave neighbor markers (`_note_matches_octave_neighbors`)

Each active octaved note also marks the same pitch class at ±1 and ±2 octaves — e.g. while `C4` is sounding, secondary markers appear on `C2`, `C3`, `C5`, and `C6` wherever those keys/cells exist.

- **Logic** (in `BasicInstrument`): shares a pitch class with some active note, within `octave_neighbor_radius * 12` semitones, and is not itself a primary match.
- **Knob**: `@export var octave_neighbor_radius: int = 2` on `BasicInstrument` (set to `0` to disable).
- **Drawing** (per instrument): piano uses `neighbor_marker_fill_color` / `neighbor_marker_text_color` and labels neighbors with the full note name (`C2`, `C5`, …); the necks use `active_marker_color` for primary and `marker_color` for neighbors via `_draw_note_marker(..., is_primary)`.

## Current runtime wiring (`main.gd`)

On `_ready()` (`default_tile_count = 0`, so nothing is auto-spawned):

1. Row 0: adds `PianoInstrument` (flexible width) and a square `SourceInstrument` via `add_tile_to_row`.
2. Row 1: adds `GuitarInstrument`; Row 2: adds `ViolaInstrument` (each `add_tile_from_scene`).
3. Bidirectionally wires the playable three: piano ↔ guitar, piano ↔ viola, guitar ↔ viola.
4. Connects `source.clear_pressed` to `_release_all_notes()`, which calls `release_all()` on every `BasicInstrument`.

Result: play notes on any instrument → the others highlight the matching key/fret/position. Because notes are note-on/note-off, multiple held notes light up everywhere at once. Source's **Clear** releases all of them.

### Input gestures

- **Left-click** a key/cell: toggles that note on/off (latched). Click several to build a chord.
- **Right-press** a key/cell: note-on while held; **right-release**: note-off (momentary).

Both gestures are handled by `BasicInstrument._input()`, which hit-tests via the overridable `_note_at(local_pos)`.

## PianoInstrument

- **Range**: 64 keys, MIDI 33–96 (`A1`–`C7`) — full 88-key span with one octave removed from each end.
- **Layout**: White keys span full tile width. Key **depth** uses ratio `WHITE_KEY_DEPTH_RATIO = 7.0` (realistic width:height). Extra vertical space becomes top/bottom **stretchers** (wood frame).
- **Input**: Inherits `BasicInstrument._input()` (left-click toggles, right-hold is momentary); supplies `_note_at()` for hit-testing.
- **Highlight**: Active keys use `active_key_color` via `_note_matches()`. Non-`C` white keys and black keys also get a **circle marker** with the pitch letter (`_draw_active_markers()`). `C` white keys show a small octave label at the bottom of the key (e.g. `C4`). **Octave neighbors** (±2 octaves) get softer circle markers labeled with the full note name.
- **Drawing**: Overrides `_draw()` completely (does not use `BasicInstrument`’s large centered note text).

## GuitarInstrument

- **Neck**: Left → right (open zone and nut on the left, frets and bridge on the right). Tab-style view: horizontal strings, vertical frets. Ivory **nut** block and wooden **bridge** saddle at each end; frets use `2^(-n/12)` spacing.
- **Strings**: Standard tuning. Top to bottom on screen: high E → B → G → D → A → low E (array index 5 → 0). Line width tapers from bass to treble (`STRING_WIDTHS`).
- **Open-string zone**: Clickable strip left of the nut, same width as the **fret 13 zone** on the right. Open-string note labels (e.g. `E2`, `A2`) centered above each string; active open notes show circle markers in the zone.
- **Fret 13 zone**: Fixed-width strip (matches open zone) between fret 12 and the bridge. Note labels above each string (e.g. `F2`, `F3`) via shared `_draw_zone_note_labels()`; clickable like other frets.
- **Fret markers**: Dots at frets 3, 5, 7, 9 (single, numbered), 12 (double dots with centered `12` label). Fret numbers use subtle off-white `fret_marker_text_color`.
- **Hit-testing**: Each fretted cell spans from the previous wire (or nut) to the current fret wire — e.g. fret 1 is nut → fret 1, not fret 1 → fret 2.
- **Note markers**: Circle markers with bold note text on any matching cell (open or fretted), whether clicked locally or received from another instrument. Primary match uses `active_marker_color`; **octave neighbors** (±2) use the default `marker_color`.
- **Tuning**: `OPEN_STRING_NOTES` + `OPEN_STRING_OCTAVES` → E2, A2, D3, G3, B3, E4 at fret 0.

## ViolaInstrument

- **Fingerboard**: Same left → right neck model as the guitar (nut, bridge, open zone, extension zone), with semitone fret lines drawn across the board.
- **Strings**: 4 strings in fifths, standard viola tuning — top to bottom on screen: A4 → D4 → G3 → C3 (array index 3 → 0). Width tapers from low C to high A (`STRING_WIDTHS`).
- **Position markers**: Dots at positions 3, 5, 7 (numbered), viola-style.
- **Shares** the base `_note_at()`/marker logic; primary and ±2 octave neighbor markers behave as on the other instruments.

## SourceInstrument

A control tile (square, in the piano's row) built from **Control nodes**, not `_draw`:

- **UI**: a `VBoxContainer` holding a row (`HBoxContainer`) of two `OptionButton` dropdowns, an expanding spacer, and a bottom-centered Clear `Button`. The container is repositioned in an overridden `set_rect`.
- **Dropdowns**: root note (12 chromatic names) and scale type (`Major`, `Minor`, `Major Pentatonic`, `Minor Pentatonic`). Both use `clip_text` so the long labels never overflow the square tile; the note dropdown is fixed-narrow, the scale dropdown expands.
- **Signals/accessors**: `clear_pressed`, `scale_selection_changed(root_note, scale)`, `selected_root_note()`, `selected_scale()`.
- **Clear**: emits `clear_pressed`; `main.gd` releases all notes on every instrument. The dropdown selection has no functional effect yet (placeholder for future note generation).

## Drawing and input patterns

Instruments use the same patterns:

1. **`_update_layout()`** — compute geometry from `tile_size` into cached rects/arrays.
2. **`_draw()`** — call layout, draw chrome, draw instrument.
3. **`_note_at(local_pos)`** — hit-test a local position to a note name. Input itself (left-click toggle, right-hold momentary) is handled once in `BasicInstrument._input()`.

Hit-testing uses precomputed cell dicts: `{ "note", "rect", "fret", "string", ... }`.

### Godot drawing gotchas (learned in this project)

- **Integer division**: Use `int(midi / 12)`, not `//` (invalid in GDScript 4).
- **Bold font**: `FontVariation.variation_embolden` (not `variation_embold`).
- **Centered `draw_string`**: `HORIZONTAL_ALIGNMENT_CENTER` requires an explicit `width`; with `-1` text is left-aligned at `pos.x`. Use `draw_string(font, Vector2(center.x - radius, y), text, CENTER, radius * 2, ...)`.
- **Vertical centering**: `baseline_y = center.y + (ascent - descent) * 0.5`.

## Adding a new instrument

1. Create `my_instrument.gd` extending `BasicInstrument` (or `InstTile` if no note I/O).
2. Add `class_name MyInstrument` and a `.tscn` with script attached.
3. Override `_draw()` for custom visuals; override `_can_play()` to constrain the playable range.
4. Override `_note_at(local_pos)` to hit-test clicks; the base `_input()` already handles left-click toggle and right-hold momentary gestures.
5. Register in scene: `tile_manager.add_tile_from_scene(preload("res://my_instrument.tscn"), "Title")`.
6. Godot will generate `.uid` files and `.godot/` cache on import (gitignored).

Do **not** modify `BasicInstrument` for one-off behavior — derive a new class (see `PianoInstrument`, `GuitarInstrument`, `ViolaInstrument`).

## Git history (logical progression)

1. Godot project scaffold + `.gitignore`
2. `InstTile` base class
3. `TileManager` horizontal layout
4. `BasicInstrument` note emit/receive
5. `PianoInstrument` keyboard
6. Piano upgraded to full keyboard span + stretchers (later trimmed to 64 keys, A1–C7)
7. `GuitarInstrument` + piano/guitar mixed layout
8. Guitar marker UX (circles on fretted cells; open-string markers unified with `_draw_active_cells`)
9. Octave-aware note parsing, bidirectional wiring, piano circle markers
10. Guitar visual polish (nut, bridge, string thickness, labels, high-E-on-top layout)
11. Guitar fret hit-test fix, fret numbers on position dots, subtle fret label color
12. Octave neighbor markers (±2 octaves) via `_note_matches_octave_neighbors()`; guitar fret 13 extension zone
13. `ViolaInstrument` (four-string fretted fingerboard, C3–A4) added to the layout
14. Multi-note MIDI model: `MidiMessage`, note-on/note-off, `active_notes` set, latch + momentary input gestures
15. `TileManager` rows model (multiple tiles per row, square sizing); `SourceInstrument` control tile with note/scale dropdowns and a Clear-all button

## Out of scope / not yet implemented

- Audio playback (no `AudioStreamPlayer` yet)
- Hardware MIDI input (`InputEventMIDI`); the message model is internal only
- Velocity-driven visuals, per-note timing/scheduling
- Guitar body outline (removed per design)
- Persistence, menus, or multiple scenes

## Conventions for contributors and AI

- **Minimize scope**: Extend via new subclasses; avoid unrelated edits.
- **Match style**: `class_name`, typed arrays (`Array[InstTile]`), `##` doc comments on exports, `_private` helpers, `_draw_*` decomposition.
- **Commits**: User prefers logical, separate commits (scaffold → base → feature → wiring).
- **Verification**: Always run the project when finished with a change (see **Running the project** above). Leave the app open; do not use `--quit-after` when launching for review.
- **TileManager children**: Instruments are children of `TileManager`, not directly of `Main`.
