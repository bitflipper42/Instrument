class_name ViolaInstrument
extends BasicInstrument

## Fingerboard runs left → right (nut at min X, bridge at max X). Four strings in
## fifths tuning; high A (index 3) at top, low C (index 0) at bottom.

const POSITION_COUNT := 12
const EXTENSION_POSITION := 13
const STRING_COUNT := 4
const OPEN_STRING_NOTES: PackedStringArray = ["C", "G", "D", "A"]
const OPEN_STRING_OCTAVES: PackedInt32Array = [3, 3, 4, 4]
const DOT_POSITIONS: PackedInt32Array = [3, 5, 7]

@export var fingerboard_color: Color = Color(0.14, 0.11, 0.10)
@export var open_zone_color: Color = Color(0.20, 0.14, 0.10)
@export var fret_color: Color = Color(0.72, 0.70, 0.68)
@export var string_color: Color = Color(0.82, 0.74, 0.58)
@export var marker_color: Color = Color(0.76, 0.72, 0.64)
@export var position_marker_color: Color = Color(0.55, 0.48, 0.40)
@export var marker_text_color: Color = Color(0.22, 0.18, 0.14)
@export var position_label_color: Color = Color(0.92, 0.90, 0.86, 0.72)
@export var active_marker_color: Color = Color(0.22, 0.50, 0.78)
@export var edge_line_color: Color = Color(0.88, 0.86, 0.82)
@export var nut_color: Color = Color(0.92, 0.90, 0.84)
@export var bridge_color: Color = Color(0.55, 0.38, 0.22)
@export var label_color: Color = Color(0.55, 0.52, 0.48)

const TITLE_HEIGHT := 28.0
const BOARD_PADDING := Vector2(10.0, 8.0)
const MARKER_ZONE_PADDING := 6.0
## Per-string line width (index 0 = low C … 3 = high A).
const STRING_WIDTHS: PackedFloat32Array = [2.0, 1.6, 1.3, 1.0]
const OPEN_STRING_WIDTH_MULTIPLIER := 3.0

var _board_rect := Rect2()
var _open_zone_rect := Rect2()
var _extension_zone_rect := Rect2()
var _nut_rect := Rect2()
var _bridge_rect := Rect2()
var _position_x: Array[float] = []
var _string_y: Array[float] = []
var _finger_cells: Array[Dictionary] = []
var _bold_marker_font: FontVariation


func _ready() -> void:
	super._ready()
	if title == "Instrument":
		title = "Viola"
	_bold_marker_font = FontVariation.new()
	_bold_marker_font.base_font = ThemeDB.fallback_font
	_bold_marker_font.variation_embolden = 1.2


func receive_midi(message: MidiMessage) -> void:
	super.receive_midi(message)
	queue_redraw()


func _draw() -> void:
	_update_layout()
	_draw_tile_chrome()
	_draw_fingerboard()


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
	var origin := BOARD_PADDING + Vector2(0.0, TITLE_HEIGHT)
	var size := tile_size - origin - BOARD_PADDING
	size.x = maxf(size.x, 0.0)
	size.y = maxf(size.y, 0.0)
	return Rect2(origin, size)


func _update_layout() -> void:
	_position_x.clear()
	_string_y.clear()
	_finger_cells.clear()

	var body := _body_rect()
	if body.size.x <= 0.0 or body.size.y <= 0.0:
		_board_rect = Rect2()
		_open_zone_rect = Rect2()
		_extension_zone_rect = Rect2()
		_nut_rect = Rect2()
		_bridge_rect = Rect2()
		return

	var neck_height := body.size.y * 0.82
	var neck_top := body.position.y + (body.size.y - neck_height) * 0.5
	_board_rect = Rect2(body.position.x, neck_top, body.size.x, neck_height)

	var string_top := _board_rect.position.y + _board_rect.size.y * 0.12
	var string_bottom := _board_rect.position.y + _board_rect.size.y * 0.88
	for string_idx in STRING_COUNT:
		var t := float(string_idx) / float(STRING_COUNT - 1)
		_string_y.append(lerpf(string_top, string_bottom, 1.0 - t))

	var open_width := _open_zone_width()
	_open_zone_rect = Rect2(_board_rect.position.x, _board_rect.position.y, open_width, _board_rect.size.y)

	var nut_x := _board_rect.position.x + open_width
	var bridge_width := maxf(4.0, _board_rect.size.y * 0.05)
	var bridge_x := _board_rect.position.x + _board_rect.size.x - bridge_width
	_bridge_rect = Rect2(bridge_x, _board_rect.position.y, bridge_width, _board_rect.size.y)

	var extension_width := open_width
	var extension_left := bridge_x - extension_width
	_extension_zone_rect = Rect2(extension_left, _board_rect.position.y, extension_width, _board_rect.size.y)

	var span := extension_left - nut_x
	var position_span := 1.0 - pow(2.0, -float(POSITION_COUNT) / 12.0)
	var nut_width := maxf(3.0, _board_rect.size.y * 0.04)
	_nut_rect = Rect2(nut_x - nut_width, _board_rect.position.y, nut_width, _board_rect.size.y)

	_position_x.append(nut_x)
	for pos in range(1, POSITION_COUNT + 1):
		var t := (1.0 - pow(2.0, -float(pos) / 12.0)) / position_span
		_position_x.append(nut_x + span * t)

	var string_gap := _string_spacing()
	for string_idx in STRING_COUNT:
		var cy := _string_y[string_idx]
		_finger_cells.append({
			"position": 0,
			"string": string_idx,
			"note": _note_for(string_idx, 0),
			"rect": Rect2(
				Vector2(_open_zone_rect.position.x, cy - string_gap * 0.5),
				Vector2(_open_zone_rect.size.x, string_gap)),
		})

	for pos in range(1, POSITION_COUNT + 1):
		var x0 := _position_x[pos - 1]
		var x1 := _position_x[pos]
		for string_idx in STRING_COUNT:
			var cy := _string_y[string_idx]
			_finger_cells.append({
				"position": pos,
				"string": string_idx,
				"note": _note_for(string_idx, pos),
				"rect": Rect2(
					Vector2(x0, cy - string_gap * 0.5),
					Vector2(x1 - x0, string_gap)),
			})

	var extension_x0 := _position_x[POSITION_COUNT]
	for string_idx in STRING_COUNT:
		var cy := _string_y[string_idx]
		_finger_cells.append({
			"position": EXTENSION_POSITION,
			"string": string_idx,
			"note": _note_for(string_idx, EXTENSION_POSITION),
			"rect": Rect2(
				Vector2(extension_x0, cy - string_gap * 0.5),
				Vector2(extension_width, string_gap)),
		})


func _string_spacing() -> float:
	if _string_y.size() < 2:
		return _board_rect.size.y * 0.76 / float(STRING_COUNT)
	return absf(_string_y[1] - _string_y[0])


func _marker_radius() -> float:
	return _string_spacing() * 0.42


func _open_zone_width() -> float:
	return _marker_radius() * 2.4 + MARKER_ZONE_PADDING + 10.0


func _draw_fingerboard() -> void:
	if _board_rect.size.x <= 0.0:
		return

	draw_rect(_board_rect, fingerboard_color, true)
	if _open_zone_rect.size.x > 0.0:
		draw_rect(_open_zone_rect, open_zone_color, true)
	if _extension_zone_rect.size.x > 0.0:
		draw_rect(_extension_zone_rect, open_zone_color, true)

	_draw_nut()
	_draw_bridge()

	for pos in range(1, POSITION_COUNT + 1):
		var x := _position_x[pos]
		draw_line(
			Vector2(x, _board_rect.position.y),
			Vector2(x, _board_rect.position.y + _board_rect.size.y),
			fret_color, 1.5)

	_draw_strings()
	_draw_zone_note_labels(_open_zone_rect, 0)
	_draw_zone_note_labels(_extension_zone_rect, EXTENSION_POSITION)
	_draw_position_markers()
	_draw_active_cells()


func _draw_nut() -> void:
	if _nut_rect.size.x <= 0.0:
		return
	draw_rect(_nut_rect, nut_color, true)
	draw_rect(_nut_rect, edge_line_color.darkened(0.25), false, 1.0)
	var groove_x := _nut_rect.position.x + _nut_rect.size.x * 0.55
	draw_line(
		Vector2(groove_x, _board_rect.position.y),
		Vector2(groove_x, _board_rect.position.y + _board_rect.size.y),
		edge_line_color.darkened(0.15), 1.0)


func _draw_bridge() -> void:
	if _bridge_rect.size.x <= 0.0:
		return
	draw_rect(_bridge_rect, bridge_color, true)
	draw_rect(_bridge_rect, edge_line_color.darkened(0.35), false, 1.0)
	var saddle_x := _bridge_rect.position.x + _bridge_rect.size.x * 0.35
	draw_line(
		Vector2(saddle_x, _board_rect.position.y),
		Vector2(saddle_x, _board_rect.position.y + _board_rect.size.y),
		nut_color.darkened(0.12), 1.5)


func _string_line_width(string_idx: int) -> float:
	var width := STRING_WIDTHS[string_idx]
	if is_pitch_class_active(_note_for(string_idx, 0)):
		width *= OPEN_STRING_WIDTH_MULTIPLIER
	return width


func _draw_strings() -> void:
	var end_x := _bridge_rect.position.x if _bridge_rect.size.x > 0.0 else _board_rect.position.x + _board_rect.size.x
	var start_x := _open_zone_rect.position.x
	for string_idx in STRING_COUNT:
		var y := _string_y[string_idx]
		draw_line(Vector2(start_x, y), Vector2(end_x, y), string_color, _string_line_width(string_idx))


func _draw_zone_note_labels(zone: Rect2, position: int) -> void:
	if zone.size.x <= 0.0:
		return
	var font := ThemeDB.fallback_font
	var font_size := clampi(int(_string_spacing() * 0.38), 6, 10)
	var padding := 2.0
	var center_x := zone.position.x + zone.size.x * 0.5
	var text_width := zone.size.x * 0.9
	var min_baseline := _board_rect.position.y + font_size
	for string_idx in STRING_COUNT:
		var label := _note_for(string_idx, position)
		var string_y := _string_y[string_idx]
		var baseline_y := maxf(string_y - padding, min_baseline)
		draw_string(
			font, Vector2(center_x - text_width * 0.5, baseline_y), label,
			HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, label_color)


func _draw_note_marker(center: Vector2, radius: float, note: String, highlighted: bool = false) -> void:
	var fill := active_marker_color if highlighted else marker_color
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 32, fret_color, 1.0)

	var label := _normalize_pitch(note)
	if label == "":
		label = normalize_note(note)

	var font := _bold_marker_font
	var font_size := clampi(int(radius * 0.85), 7, 13)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline_y := center.y + (ascent - descent) * 0.5
	var text_width := radius * 2.0
	draw_string(
		font, Vector2(center.x - radius, baseline_y), label,
		HORIZONTAL_ALIGNMENT_CENTER, text_width, font_size, marker_text_color)


func _draw_position_markers() -> void:
	var radius := minf(_board_rect.size.y * 0.05, _string_spacing() * 0.28)
	var center_y := _board_rect.position.y + _board_rect.size.y * 0.5
	for pos in DOT_POSITIONS:
		_draw_position_marker_with_label(_position_center_x(pos), center_y, radius, str(pos))


func _draw_position_marker_with_label(center_x: float, center_y: float, radius: float, label: String) -> void:
	_draw_marker_dot(center_x, center_y, radius)
	var font := ThemeDB.fallback_font
	var font_size := clampi(int(radius * 1.1), 6, 10)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline_y := center_y + (ascent - descent) * 0.5
	draw_string(
		font, Vector2(center_x - radius, baseline_y), label,
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, position_label_color)


func _draw_marker_dot(center_x: float, center_y: float, radius: float) -> void:
	draw_circle(Vector2(center_x, center_y), radius, position_marker_color)
	draw_arc(Vector2(center_x, center_y), radius, 0.0, TAU, 24, fret_color, 1.0)


func _position_center_x(position: int) -> float:
	return (_position_x[position - 1] + _position_x[position]) * 0.5


func _draw_active_cells() -> void:
	if active_notes.is_empty():
		return
	var spacing := _string_spacing()
	var open_radius := _marker_radius()
	var finger_radius := minf(spacing * 0.38, _board_rect.size.y * 0.055)
	for cell in _finger_cells:
		var note: String = cell["note"]
		var is_primary := _note_matches(note)
		var is_neighbor := _note_matches_octave_neighbors(note)
		if not is_primary and not is_neighbor:
			continue
		var pos_num: int = int(cell["position"])
		var center := (cell["rect"] as Rect2).position + (cell["rect"] as Rect2).size * 0.5
		var is_open: bool = pos_num == 0
		var radius: float = open_radius if is_open else finger_radius
		if is_open:
			center.x = _open_zone_rect.position.x + _open_zone_rect.size.x * 0.62
		elif pos_num == EXTENSION_POSITION:
			center.x = _extension_zone_rect.position.x + _extension_zone_rect.size.x * 0.5
			center.y = _string_y[int(cell["string"])]
		elif pos_num > 0:
			center.x = _position_center_x(pos_num)
			center.y = _string_y[int(cell["string"])]
		_draw_note_marker(center, radius, note, is_primary)


func _note_at(local_pos: Vector2) -> String:
	_update_layout()
	for cell in _finger_cells:
		if (cell["rect"] as Rect2).has_point(local_pos):
			return cell["note"]
	return ""


func _note_for(string_idx: int, position: int) -> String:
	var open_pitch := normalize_note(OPEN_STRING_NOTES[string_idx])
	var open_pc := CHROMATIC.find(open_pitch)
	var octave: int = OPEN_STRING_OCTAVES[string_idx]
	var midi := (octave + 1) * 12 + open_pc + position
	return _midi_to_name(midi)
