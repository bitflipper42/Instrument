class_name PianoInstrument
extends BasicInstrument

## 64-key piano (A1–C7): full 88-key range with one octave removed from each end.

const MIDI_LOW := 33   # A1
const MIDI_HIGH := 96  # C7
const WHITE_PITCH_CLASSES: PackedInt32Array = [0, 2, 4, 5, 7, 9, 11]
## Pitch-class index within an octave -> 1 if a black key sits to its right.
const BLACK_OFFSET_BY_PC: PackedInt32Array = [1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0]

@export var white_key_color: Color = Color(0.94, 0.94, 0.90)
@export var black_key_color: Color = Color(0.12, 0.12, 0.14)
@export var key_border_color: Color = Color(0.55, 0.55, 0.58)
@export var active_key_color: Color = Color(0.22, 0.50, 0.78)
@export var marker_fill_color: Color = Color(0.92, 0.90, 0.84)
@export var neighbor_marker_fill_color: Color = Color(0.82, 0.80, 0.74)
@export var marker_text_color: Color = Color(0.22, 0.18, 0.14)
@export var neighbor_marker_text_color: Color = Color(0.45, 0.42, 0.38)
@export var stretcher_color: Color = Color(0.30, 0.22, 0.15)
@export var stretcher_border_color: Color = Color(0.18, 0.12, 0.08)

## White-key depth / width ratio on a real piano (~165 mm / 23.5 mm).
const WHITE_KEY_DEPTH_RATIO := 7.0
const BLACK_KEY_HEIGHT_RATIO := 0.62

const TITLE_HEIGHT := 28.0
const KEYBOARD_PADDING := Vector2(8.0, 6.0)

var _white_keys: Array[Dictionary] = []
var _black_keys: Array[Dictionary] = []
var _top_stretcher_rect := Rect2()
var _bottom_stretcher_rect := Rect2()
var _keyboard_area := Rect2()
var _bold_marker_font: FontVariation


func _ready() -> void:
	super._ready()
	if title == "Instrument":
		title = "Piano"
	_bold_marker_font = FontVariation.new()
	_bold_marker_font.base_font = ThemeDB.fallback_font
	_bold_marker_font.variation_embolden = 1.2


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
		play_note(note)


func emit_note(note: String) -> bool:
	var n := _normalize_pitch(note)
	if n == "" or not _is_valid_piano_note(n):
		push_warning("PianoInstrument: invalid note '%s'" % note)
		return false
	return super.emit_note(note)


func receive_note(note: String) -> bool:
	return super.receive_note(note)


func _draw() -> void:
	_update_layout()
	_draw_tile_chrome()
	_draw_stretchers()
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


func _body_rect() -> Rect2:
	var origin := KEYBOARD_PADDING + Vector2(0.0, TITLE_HEIGHT)
	var size := tile_size - origin - KEYBOARD_PADDING
	size.x = maxf(size.x, 0.0)
	size.y = maxf(size.y, 0.0)
	return Rect2(origin, size)


func _update_layout() -> void:
	_white_keys.clear()
	_black_keys.clear()

	var body := _body_rect()
	if body.size.x <= 0.0 or body.size.y <= 0.0:
		_top_stretcher_rect = Rect2()
		_bottom_stretcher_rect = Rect2()
		_keyboard_area = Rect2()
		return

	var white_count := _white_key_count()
	if white_count == 0:
		return

	var white_width := body.size.x / float(white_count)
	var ideal_keyboard_height := white_width * WHITE_KEY_DEPTH_RATIO
	var keyboard_height := minf(ideal_keyboard_height, body.size.y)
	var leftover := body.size.y - keyboard_height
	var top_stretcher_height := leftover * 0.5
	var bottom_stretcher_height := leftover - top_stretcher_height

	_top_stretcher_rect = Rect2(body.position, Vector2(body.size.x, top_stretcher_height))
	_keyboard_area = Rect2(
		body.position + Vector2(0.0, top_stretcher_height),
		Vector2(body.size.x, keyboard_height))
	_bottom_stretcher_rect = Rect2(
		_keyboard_area.position + Vector2(0.0, keyboard_height),
		Vector2(body.size.x, bottom_stretcher_height))

	_build_keys_in_area(_keyboard_area)


func _draw_stretchers() -> void:
	_draw_stretcher(_top_stretcher_rect)
	_draw_stretcher(_bottom_stretcher_rect)


func _draw_stretcher(rect: Rect2) -> void:
	if rect.size.y <= 0.0:
		return
	draw_rect(rect, stretcher_color, true)
	draw_rect(rect, stretcher_border_color, false, 1.0)
	var inset := Rect2(rect.position + Vector2(2.0, 2.0), rect.size - Vector2(4.0, 4.0))
	if inset.size.x > 0.0 and inset.size.y > 0.0:
		draw_rect(inset, stretcher_color.lightened(0.06), false, 1.0)


func _build_keys_in_area(area: Rect2) -> void:
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return

	var white_midis: Array[int] = []
	for midi in range(MIDI_LOW, MIDI_HIGH + 1):
		if _is_white_key(midi):
			white_midis.append(midi)

	var white_count := white_midis.size()
	var white_width := area.size.x / float(white_count)
	var white_height := area.size.y
	var black_width := white_width * 0.62
	var black_height := white_height * BLACK_KEY_HEIGHT_RATIO

	for i in white_count:
		var midi: int = white_midis[i]
		var key_rect := Rect2(
			area.position + Vector2(white_width * i, 0.0),
			Vector2(white_width, white_height))
		var note := _midi_to_name(midi)
		_white_keys.append({"note": note, "midi": midi, "rect": key_rect})

		var pc := midi % 12
		if BLACK_OFFSET_BY_PC[pc] == 1:
			var black_midi := midi + 1
			if black_midi <= MIDI_HIGH:
				var black_rect := Rect2(
					Vector2(key_rect.position.x + white_width - black_width * 0.5, area.position.y),
					Vector2(black_width, black_height))
				_black_keys.append({
					"note": _midi_to_name(black_midi),
					"midi": black_midi,
					"rect": black_rect,
				})


func _draw_keyboard() -> void:
	for key in _white_keys:
		_draw_key(key["rect"], key["note"], false)
	for key in _black_keys:
		_draw_key(key["rect"], key["note"], true)
	_draw_active_markers()


func _draw_key(rect: Rect2, note: String, is_black: bool) -> void:
	var fill := black_key_color if is_black else white_key_color
	if _note_matches(note):
		fill = active_key_color
	draw_rect(rect, fill, true)
	draw_rect(rect, key_border_color, false, 1.0)

	if not is_black and note.begins_with("C"):
		var font := ThemeDB.fallback_font
		var font_size := clampi(int(rect.size.x * 0.55), 6, 11)
		var label_y := rect.position.y + rect.size.y - 4.0
		draw_string(
			font, Vector2(rect.position.x + 2.0, label_y), note,
			HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 4.0, font_size,
			Color(0.35, 0.35, 0.38))


func _draw_active_markers() -> void:
	if current_note == "":
		return
	var pitch_label := _current_note_letter()
	for key in _white_keys:
		var note: String = key["note"]
		if _note_matches(note) and not note.begins_with("C"):
			_draw_key_marker(key["rect"], false, pitch_label, true)
		elif _note_matches_octave_neighbors(note):
			_draw_key_marker(key["rect"], false, note, false)
	for key in _black_keys:
		var note: String = key["note"]
		if _note_matches(note):
			_draw_key_marker(key["rect"], true, pitch_label, true)
		elif _note_matches_octave_neighbors(note):
			_draw_key_marker(key["rect"], true, note, false)


func _current_note_letter() -> String:
	var parsed := _split_pitch(current_note)
	if not parsed.is_empty():
		return parsed["pitch"]
	return normalize_note(current_note)


func _draw_key_marker(rect: Rect2, is_black: bool, label: String, is_primary: bool) -> void:
	var scale := 0.44 if is_black else 0.32
	var radius := minf(rect.size.x, rect.size.y) * scale
	var padding := 4.0
	var center := Vector2(
		rect.position.x + rect.size.x * 0.5,
		rect.position.y + rect.size.y - radius - padding)
	var fill := marker_fill_color if is_primary else neighbor_marker_fill_color
	var text_color := marker_text_color if is_primary else neighbor_marker_text_color
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 24, key_border_color, 1.0)

	var font := _bold_marker_font
	var font_size := clampi(int(radius * (1.05 if is_black else 0.9)), 6, 14 if is_black else 12)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline_y := center.y + (ascent - descent) * 0.5
	draw_string(
		font, Vector2(center.x - radius, baseline_y), label,
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, text_color)


func _note_at(local_pos: Vector2) -> String:
	_update_layout()
	for key in _black_keys:
		if (key["rect"] as Rect2).has_point(local_pos):
			return key["note"]
	for key in _white_keys:
		if (key["rect"] as Rect2).has_point(local_pos):
			return key["note"]
	return ""


func _is_white_key(midi: int) -> bool:
	return WHITE_PITCH_CLASSES.has(midi % 12)


func _white_key_count() -> int:
	var count := 0
	for midi in range(MIDI_LOW, MIDI_HIGH + 1):
		if _is_white_key(midi):
			count += 1
	return count


func _is_valid_piano_note(note: String) -> bool:
	var parsed := _split_pitch(note)
	if parsed.is_empty():
		return CHROMATIC.has(normalize_note(note))
	var midi := _name_to_midi(note)
	return midi >= MIDI_LOW and midi <= MIDI_HIGH
