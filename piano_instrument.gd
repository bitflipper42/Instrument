class_name PianoInstrument
extends BasicInstrument

## Full 88-key piano (A0–C8) derived from BasicInstrument. Draws all white and
## black keys across the tile and emits octave-qualified note names on click.

const MIDI_LOW := 21   # A0
const MIDI_HIGH := 108 # C8
const WHITE_PITCH_CLASSES: PackedInt32Array = [0, 2, 4, 5, 7, 9, 11]
## Pitch-class index within an octave -> 1 if a black key sits to its right.
const BLACK_OFFSET_BY_PC: PackedInt32Array = [1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0]

@export var white_key_color: Color = Color(0.94, 0.94, 0.90)
@export var black_key_color: Color = Color(0.12, 0.12, 0.14)
@export var key_border_color: Color = Color(0.55, 0.55, 0.58)
@export var active_key_color: Color = Color(0.35, 0.70, 0.95)
@export var stretcher_color: Color = Color(0.30, 0.22, 0.15)
@export var stretcher_border_color: Color = Color(0.18, 0.12, 0.08)

## White-key depth / width ratio on a real piano (~165 mm / 23.5 mm).
const WHITE_KEY_DEPTH_RATIO := 7.0
const BLACK_KEY_HEIGHT_RATIO := 0.62
const WHITE_KEY_COUNT := 52

const TITLE_HEIGHT := 28.0
const KEYBOARD_PADDING := Vector2(8.0, 6.0)

var _white_keys: Array[Dictionary] = []
var _black_keys: Array[Dictionary] = []
var _top_stretcher_rect := Rect2()
var _bottom_stretcher_rect := Rect2()
var _keyboard_area := Rect2()


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


## Accepts octave-qualified names ("C4", "A0") and plain chromatic names ("C").
func emit_note(note: String) -> bool:
	var n := _normalize_pitch(note)
	if n == "" or not _is_valid_piano_note(n):
		push_warning("PianoInstrument: invalid note '%s'" % note)
		return false
	current_note = n
	queue_redraw()
	note_emitted.emit(n)
	return true


func receive_note(note: String) -> bool:
	var n := _normalize_pitch(note)
	if n == "":
		push_warning("PianoInstrument: invalid note '%s'" % note)
		return false
	current_note = n
	queue_redraw()
	note_received.emit(n)
	return true


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

	var white_width := body.size.x / float(WHITE_KEY_COUNT)
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


func _midi_to_name(midi: int) -> String:
	var octave := int(midi / 12) - 1
	return CHROMATIC[midi % 12] + str(octave)


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


func _is_valid_piano_note(note: String) -> bool:
	var parsed := _split_pitch(note)
	if parsed.is_empty():
		return CHROMATIC.has(normalize_note(note))
	var midi := _name_to_midi(note)
	return midi >= MIDI_LOW and midi <= MIDI_HIGH


func _note_matches(key_note: String) -> bool:
	if current_note == "":
		return false
	if key_note == current_note:
		return true
	var current_parsed := _split_pitch(current_note)
	if current_parsed.is_empty():
		return normalize_note(current_note) == normalize_note(_split_pitch(key_note).get("pitch", key_note))
	return false
