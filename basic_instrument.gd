class_name BasicInstrument
extends InstTile

## A tile that can receive and emit musical note names ("C", "C#", "C4", ...).
## Connect one instrument's `note_emitted` to another's `receive_note` (or use
## `connect_to`) to pass notes along a chain.

signal note_emitted(note: String)
signal note_received(note: String)

## The twelve chromatic note names used as the canonical form.
const CHROMATIC: PackedStringArray = [
	"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
]

## Flat spellings normalized to their canonical sharp equivalents.
const FLAT_ALIASES: Dictionary = {
	"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#",
}

## How many octaves above/below the selected note get secondary markers.
@export var octave_neighbor_radius: int = 2

## The most recent note this instrument received or emitted.
var current_note: String = ""


func _ready() -> void:
	if title == "":
		title = "Instrument"

## Normalizes user-supplied names (trims, fixes case, converts flats to sharps).
func normalize_note(note: String) -> String:
	var n := note.strip_edges()
	if n.is_empty():
		return ""
	n = n.substr(0, 1).to_upper() + n.substr(1)
	if FLAT_ALIASES.has(n):
		return FLAT_ALIASES[n]
	return n

## True if `note` is a recognized pitch or pitch+octave name.
func is_valid_note(note: String) -> bool:
	return _normalize_pitch(note) != ""

## User-initiated note (e.g. click). Updates state and emits `note_emitted`.
func play_note(note: String) -> bool:
	return emit_note(note)

## Sends a note out to any listeners. Returns false if the note is invalid.
func emit_note(note: String) -> bool:
	var n := _normalize_pitch(note)
	if n == "":
		push_warning("BasicInstrument: invalid note '%s'" % note)
		return false
	current_note = n
	queue_redraw()
	note_emitted.emit(n)
	return true

## Handles an incoming note from another instrument. Updates state only;
## does not emit `note_emitted` (avoids feedback loops when bidirectionally connected).
func receive_note(note: String) -> bool:
	var n := _normalize_pitch(note)
	if n == "":
		push_warning("BasicInstrument: invalid note '%s'" % note)
		return false
	current_note = n
	queue_redraw()
	note_received.emit(n)
	return true

## Routes this instrument's output into another instrument's input.
func connect_to(other: BasicInstrument) -> void:
	if not note_emitted.is_connected(other.receive_note):
		note_emitted.connect(other.receive_note)


## Two-way routing: each instrument's clicks reach the other, but
## `receive_note` never re-emits, so there is no feedback loop.
func connect_bidirectional(other: BasicInstrument) -> void:
	connect_to(other)
	other.connect_to(self)


func _split_pitch(note: String) -> Dictionary:
	var n := note.strip_edges()
	if n.is_empty():
		return {}
	var octave_start := -1
	for i in n.length():
		if n[i].is_valid_int():
			octave_start = i
			break
	if octave_start < 0:
		return {}
	var pitch_part := normalize_note(n.substr(0, octave_start))
	if not CHROMATIC.has(pitch_part):
		return {}
	var octave_str := n.substr(octave_start)
	if not octave_str.is_valid_int():
		return {}
	return {"pitch": pitch_part, "octave": int(octave_str)}


func _normalize_pitch(note: String) -> String:
	var parsed := _split_pitch(note)
	if not parsed.is_empty():
		return parsed["pitch"] + str(parsed["octave"])
	var pitch := normalize_note(note)
	if CHROMATIC.has(pitch):
		return pitch
	return ""


func _name_to_midi(note: String) -> int:
	var parsed := _split_pitch(note)
	if parsed.is_empty():
		return -1
	var pitch: String = parsed["pitch"]
	var octave: int = parsed["octave"]
	var pc := CHROMATIC.find(pitch)
	if pc < 0:
		return -1
	return (octave + 1) * 12 + pc


func _midi_to_name(midi: int) -> String:
	var octave := int(midi / 12) - 1
	return CHROMATIC[midi % 12] + str(octave)


## True when `key_note` should highlight for the current stored note.
func _note_matches(key_note: String) -> bool:
	if current_note == "":
		return false
	if key_note == current_note:
		return true
	var current_parsed := _split_pitch(current_note)
	var key_parsed := _split_pitch(key_note)
	if current_parsed.is_empty() and key_parsed.is_empty():
		return normalize_note(current_note) == normalize_note(key_note)
	if current_parsed.is_empty():
		return normalize_note(current_note) == key_parsed["pitch"]
	if key_parsed.is_empty():
		return false
	return _name_to_midi(current_note) == _name_to_midi(key_note)


## True when `key_note` is the same pitch class within ±`octave_neighbor_radius`
## octaves of `current_note`, but not the primary match from `_note_matches`.
func _note_matches_octave_neighbors(key_note: String) -> bool:
	if current_note == "" or octave_neighbor_radius <= 0:
		return false
	if _note_matches(key_note):
		return false
	var current_midi := _name_to_midi(current_note)
	var key_midi := _name_to_midi(key_note)
	if current_midi < 0 or key_midi < 0:
		return false
	var diff := absi(key_midi - current_midi)
	return diff % 12 == 0 and diff <= octave_neighbor_radius * 12


func _draw() -> void:
	super._draw()
	if current_note != "":
		var font := ThemeDB.fallback_font
		var font_size := 48
		var text_size := font.get_string_size(
			current_note, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2(
			(tile_size.x - text_size.x) * 0.5,
			(tile_size.y + text_size.y) * 0.5)
		draw_string(font, pos, current_note,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_color)
