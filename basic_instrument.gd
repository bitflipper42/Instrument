class_name BasicInstrument
extends InstTile

## A tile that can emit and receive musical notes as MIDI-style messages.
## Several notes can sound at once: note-on adds a note, note-off removes it.
## Connect one instrument's `midi_out` to another's `receive_midi` (or use
## `connect_to`) to pass notes along a chain.

signal midi_out(message: MidiMessage)
signal midi_received(message: MidiMessage)

## The twelve chromatic note names used as the canonical form.
const CHROMATIC: PackedStringArray = [
	"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B",
]

## Flat spellings normalized to their canonical sharp equivalents.
const FLAT_ALIASES: Dictionary = {
	"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#",
}

## How many octaves above/below an active note get secondary markers.
@export var octave_neighbor_radius: int = 2
## Velocity used for notes started by a local click (0-127).
@export var default_velocity: int = 100
## MIDI channel used for emitted messages (0-15).
@export var midi_channel: int = 0

## Currently sounding notes: MIDI note number -> velocity.
var active_notes: Dictionary = {}

## MIDI note held by a momentary (right-button) press, or -1 when none.
var _held_note: int = -1


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

## True when `note` is currently sounding on this instrument.
func is_note_active(note: String) -> bool:
	var midi := _name_to_midi(note)
	return midi >= 0 and active_notes.has(midi)


## Starts a note (note-on). Updates state and emits `midi_out`.
func note_on(note: String, velocity: int = default_velocity) -> bool:
	var midi := _name_to_midi(note)
	if midi < 0:
		push_warning("BasicInstrument: invalid note '%s'" % note)
		return false
	if not _can_play(note):
		return false
	active_notes[midi] = velocity
	queue_redraw()
	midi_out.emit(MidiMessage.note_on(midi, velocity, midi_channel))
	return true


## Stops a note (note-off). Updates state and emits `midi_out`.
func note_off(note: String) -> bool:
	var midi := _name_to_midi(note)
	if midi < 0:
		return false
	active_notes.erase(midi)
	queue_redraw()
	midi_out.emit(MidiMessage.note_off(midi, 0, midi_channel))
	return true


## Latching helper for clicks: stops the note if active, otherwise starts it.
func toggle_note(note: String) -> bool:
	if is_note_active(note):
		return note_off(note)
	return note_on(note)


## User-initiated note start (kept for convenience). Alias for `note_on`.
func play_note(note: String) -> bool:
	return note_on(note)


## Applies an incoming MIDI message. Updates state only; never re-emits
## `midi_out` (so bidirectional wiring does not feed back).
func receive_midi(message: MidiMessage) -> void:
	if message.is_note_on():
		active_notes[message.note] = message.velocity
	else:
		active_notes.erase(message.note)
	queue_redraw()
	midi_received.emit(message)


## Overridable gate for playable notes (e.g. an instrument's range).
func _can_play(_note: String) -> bool:
	return true


## Routes this instrument's output into another instrument's input.
func connect_to(other: BasicInstrument) -> void:
	if not midi_out.is_connected(other.receive_midi):
		midi_out.connect(other.receive_midi)


## Two-way routing: each instrument's notes reach the other, but
## `receive_midi` never re-emits, so there is no feedback loop.
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


## True when `key_note` is one of the currently active notes.
func _note_matches(key_note: String) -> bool:
	if active_notes.is_empty():
		return false
	var key_midi := _name_to_midi(key_note)
	if key_midi >= 0:
		return active_notes.has(key_midi)
	# Pitch-only key (no octave): match any active note of that pitch class.
	var pc := CHROMATIC.find(normalize_note(key_note))
	if pc < 0:
		return false
	for midi in active_notes:
		if midi % 12 == pc:
			return true
	return false


## True when `key_note` shares a pitch class with some active note within
## ±`octave_neighbor_radius` octaves, but is not itself a primary match.
func _note_matches_octave_neighbors(key_note: String) -> bool:
	if active_notes.is_empty() or octave_neighbor_radius <= 0:
		return false
	if _note_matches(key_note):
		return false
	var key_midi := _name_to_midi(key_note)
	if key_midi < 0:
		return false
	for midi in active_notes:
		var diff := absi(key_midi - int(midi))
		if diff != 0 and diff % 12 == 0 and diff <= octave_neighbor_radius * 12:
			return true
	return false


## Maps a global click position to a local note name. Overridden by instruments.
func _note_at(_local_pos: Vector2) -> String:
	return ""


func _note_at_global(global_pos: Vector2) -> String:
	var tile_rect := Rect2(global_position, tile_size)
	if not tile_rect.has_point(global_pos):
		return ""
	return _note_at(global_pos - global_position)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		var note := _note_at_global(click.global_position)
		if note != "":
			toggle_note(note)
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		if click.pressed:
			var note := _note_at_global(click.global_position)
			if note != "":
				_held_note = _name_to_midi(note)
				note_on(note)
		elif _held_note >= 0:
			note_off(_midi_to_name(_held_note))
			_held_note = -1


func _draw() -> void:
	super._draw()
	if active_notes.is_empty():
		return
	var names: Array[String] = []
	for midi in active_notes:
		names.append(_midi_to_name(int(midi)))
	names.sort()
	var text := ", ".join(names)
	var font := ThemeDB.fallback_font
	var font_size := 48
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2(
		(tile_size.x - text_size.x) * 0.5,
		(tile_size.y + text_size.y) * 0.5)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_color)
