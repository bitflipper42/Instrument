class_name BasicInstrument
extends InstTile

## A tile that can receive and emit musical note names ("C", "C#", "D", ...).
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

## True if `note` is a recognized chromatic note name.
func is_valid_note(note: String) -> bool:
	return CHROMATIC.has(normalize_note(note))

## Sends a note out to any listeners. Returns false if the note is invalid.
func emit_note(note: String) -> bool:
	var n := normalize_note(note)
	if not CHROMATIC.has(n):
		push_warning("BasicInstrument: invalid note '%s'" % note)
		return false
	current_note = n
	queue_redraw()
	note_emitted.emit(n)
	return true

## Handles an incoming note. Returns false if the note is invalid.
func receive_note(note: String) -> bool:
	var n := normalize_note(note)
	if not CHROMATIC.has(n):
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
