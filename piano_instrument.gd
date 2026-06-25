class_name PianoInstrument
extends BasicInstrument

## Full-width piano keyboard derived from BasicInstrument. Draws white and black
## keys across the tile and emits note names on click.

const WHITE_NOTES: PackedStringArray = ["C", "D", "E", "F", "G", "A", "B"]
const BLACK_NOTES: PackedStringArray = ["C#", "D#", "F#", "G#", "A#"]
## White-key index within an octave that has a black key to its right.
const BLACK_AFTER_WHITE: PackedInt32Array = [0, 1, 3, 4, 5]

@export var start_octave: int = 3
@export var octave_count: int = 2

@export var white_key_color: Color = Color(0.94, 0.94, 0.90)
@export var black_key_color: Color = Color(0.12, 0.12, 0.14)
@export var key_border_color: Color = Color(0.55, 0.55, 0.58)
@export var active_key_color: Color = Color(0.35, 0.70, 0.95)

const TITLE_HEIGHT := 28.0
const KEYBOARD_PADDING := Vector2(8.0, 6.0)

var _white_keys: Array[Dictionary] = []
var _black_keys: Array[Dictionary] = []


func _ready() -> void:
	super._ready()
	if title == "Instrument":
		title = "Piano"


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var tile_rect := Rect2(global_position, tile_size)
	if not tile_rect.has_point(click.global_position):
		return
	var local_pos := click.global_position - global_position
	var note := _note_at(local_pos)
	if note != "":
		emit_note(note)


func _draw() -> void:
	_draw_tile_chrome()
	_rebuild_key_layout()
	_draw_keyboard()


func _draw_tile_chrome() -> void:
	var rect := Rect2(Vector2.ZERO, tile_size)
	draw_rect(rect, tile_color, true)
	draw_rect(rect, border_color, false, border_width)
	if title != "":
		var font := ThemeDB.fallback_font
		var font_size := 18
		draw_string(
			font, Vector2(10.0, 10.0 + font_size), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_color)


func _keyboard_rect() -> Rect2:
	var origin := KEYBOARD_PADDING + Vector2(0.0, TITLE_HEIGHT)
	var size := tile_size - origin - KEYBOARD_PADDING
	size.x = maxf(size.x, 0.0)
	size.y = maxf(size.y, 0.0)
	return Rect2(origin, size)


func _rebuild_key_layout() -> void:
	_white_keys.clear()
	_black_keys.clear()
	var area := _keyboard_rect()
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return

	var white_count := octave_count * WHITE_NOTES.size()
	var white_width := area.size.x / float(white_count)
	var white_height := area.size.y
	var black_width := white_width * 0.62
	var black_height := white_height * 0.62

	for octave in octave_count:
		for white_index in WHITE_NOTES.size():
			var global_white := octave * WHITE_NOTES.size() + white_index
			var note := WHITE_NOTES[white_index]
			var key_rect := Rect2(
				area.position + Vector2(white_width * global_white, 0.0),
				Vector2(white_width, white_height))
			_white_keys.append({"note": note, "rect": key_rect})

			if BLACK_AFTER_WHITE.has(white_index):
				var black_note := BLACK_NOTES[BLACK_AFTER_WHITE.find(white_index)]
				var black_rect := Rect2(
					Vector2(key_rect.position.x + white_width - black_width * 0.5, area.position.y),
					Vector2(black_width, black_height))
				_black_keys.append({"note": black_note, "rect": black_rect})


func _draw_keyboard() -> void:
	for key in _white_keys:
		_draw_key(key["rect"], key["note"], false)
	for key in _black_keys:
		_draw_key(key["rect"], key["note"], true)


func _draw_key(rect: Rect2, note: String, is_black: bool) -> void:
	var fill := black_key_color if is_black else white_key_color
	if note == current_note:
		fill = active_key_color
	draw_rect(rect, fill, true)
	draw_rect(rect, key_border_color, false, 1.0)

	if not is_black:
		var font := ThemeDB.fallback_font
		var font_size := clampi(int(rect.size.x * 0.22), 10, 16)
		var label_y := rect.position.y + rect.size.y - 8.0
		draw_string(
			font, Vector2(rect.position.x + 4.0, label_y), note,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8.0, font_size,
			Color(0.35, 0.35, 0.38))


func _note_at(local_pos: Vector2) -> String:
	_rebuild_key_layout()
	for key in _black_keys:
		if (key["rect"] as Rect2).has_point(local_pos):
			return key["note"]
	for key in _white_keys:
		if (key["rect"] as Rect2).has_point(local_pos):
			return key["note"]
	return ""
