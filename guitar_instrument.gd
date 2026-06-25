class_name GuitarInstrument
extends BasicInstrument

## Neck runs left → right (nut at min X, bridge at max X). Strings are horizontal;
## high E (index 5) at top, low E (index 0) at bottom.

const FRET_COUNT := 12
const EXTENSION_FRET := 13
const STRING_COUNT := 6
const OPEN_STRING_NOTES: PackedStringArray = ["E", "A", "D", "G", "B", "E"]
const OPEN_STRING_OCTAVES: PackedInt32Array = [2, 2, 3, 3, 3, 4]
const DOT_FRETS: PackedInt32Array = [3, 5, 7, 9]

@export var fretboard_color: Color = Color(0.32, 0.20, 0.11)
@export var open_zone_color: Color = Color(0.26, 0.16, 0.09)
@export var fret_color: Color = Color(0.78, 0.78, 0.80)
@export var string_color: Color = Color(0.70, 0.70, 0.72)
@export var marker_color: Color = Color(0.76, 0.72, 0.64)
@export var fret_position_marker_color: Color = Color(0.40, 0.26, 0.14)
@export var marker_text_color: Color = Color(0.22, 0.18, 0.14)
@export var fret_marker_text_color: Color = Color(0.92, 0.90, 0.86, 0.72)
@export var active_marker_color: Color = Color(0.22, 0.50, 0.78)
@export var edge_line_color: Color = Color(0.88, 0.86, 0.82)
@export var nut_color: Color = Color(0.92, 0.90, 0.84)
@export var bridge_color: Color = Color(0.55, 0.38, 0.22)
@export var label_color: Color = Color(0.55, 0.52, 0.48)

const TITLE_HEIGHT := 28.0
const BOARD_PADDING := Vector2(10.0, 8.0)
const MARKER_ZONE_PADDING := 6.0
## Per-string line width (index 0 = low E … 5 = high E); bass strings are thicker.
const STRING_WIDTHS: PackedFloat32Array = [2.2, 1.9, 1.6, 1.4, 1.2, 1.0]

var _board_rect := Rect2()
var _open_zone_rect := Rect2()
var _fret13_zone_rect := Rect2()
var _nut_rect := Rect2()
var _bridge_rect := Rect2()
var _fret_x: Array[float] = []
var _string_y: Array[float] = []
var _fret_cells: Array[Dictionary] = []
var _bold_marker_font: FontVariation


func _ready() -> void:
	super._ready()
	if title == "Instrument":
		title = "Guitar"
	_bold_marker_font = FontVariation.new()
	_bold_marker_font.base_font = ThemeDB.fallback_font
	_bold_marker_font.variation_embolden = 1.2


func _draw() -> void:
	_update_layout()
	_draw_tile_chrome()
	_draw_fretboard()


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
	_fret_x.clear()
	_string_y.clear()
	_fret_cells.clear()

	var body := _body_rect()
	if body.size.x <= 0.0 or body.size.y <= 0.0:
		_board_rect = Rect2()
		_open_zone_rect = Rect2()
		_fret13_zone_rect = Rect2()
		_nut_rect = Rect2()
		_bridge_rect = Rect2()
		return

	var neck_height := body.size.y * 0.82
	var neck_top := body.position.y + (body.size.y - neck_height) * 0.5
	_board_rect = Rect2(body.position.x, neck_top, body.size.x, neck_height)

	var string_top := _board_rect.position.y + _board_rect.size.y * 0.10
	var string_bottom := _board_rect.position.y + _board_rect.size.y * 0.90
	for string_idx in STRING_COUNT:
		# Index 5 = high E at top, index 0 = low E at bottom.
		var t := float(string_idx) / float(STRING_COUNT - 1)
		_string_y.append(lerpf(string_top, string_bottom, 1.0 - t))

	var open_width := _open_zone_width()
	_open_zone_rect = Rect2(_board_rect.position.x, _board_rect.position.y, open_width, _board_rect.size.y)

	var nut_x := _board_rect.position.x + open_width
	var bridge_width := maxf(4.0, _board_rect.size.y * 0.05)
	var bridge_x := _board_rect.position.x + _board_rect.size.x - bridge_width
	_bridge_rect = Rect2(bridge_x, _board_rect.position.y, bridge_width, _board_rect.size.y)

	var fret13_width := open_width
	var fret13_left := bridge_x - fret13_width
	_fret13_zone_rect = Rect2(fret13_left, _board_rect.position.y, fret13_width, _board_rect.size.y)

	var span := fret13_left - nut_x
	var fret_span := 1.0 - pow(2.0, -float(FRET_COUNT) / 12.0)
	var nut_width := maxf(3.0, _board_rect.size.y * 0.04)
	_nut_rect = Rect2(nut_x - nut_width, _board_rect.position.y, nut_width, _board_rect.size.y)

	_fret_x.append(nut_x)
	for fret in range(1, FRET_COUNT + 1):
		var t := (1.0 - pow(2.0, -float(fret) / 12.0)) / fret_span
		_fret_x.append(nut_x + span * t)

	var string_gap := _string_spacing()
	for string_idx in STRING_COUNT:
		var cy := _string_y[string_idx]
		var open_note := _note_for(string_idx, 0)
		_fret_cells.append({
			"fret": 0,
			"string": string_idx,
			"note": open_note,
			"rect": Rect2(
				Vector2(_open_zone_rect.position.x, cy - string_gap * 0.5),
				Vector2(_open_zone_rect.size.x, string_gap)),
		})

	for fret in range(1, FRET_COUNT + 1):
		# Playable area lies between the previous wire (or nut) and this fret wire.
		var x0 := _fret_x[fret - 1]
		var x1 := _fret_x[fret]
		for string_idx in STRING_COUNT:
			var cy := _string_y[string_idx]
			_fret_cells.append({
				"fret": fret,
				"string": string_idx,
				"note": _note_for(string_idx, fret),
				"rect": Rect2(
					Vector2(x0, cy - string_gap * 0.5),
					Vector2(x1 - x0, string_gap)),
			})

	var fret13_x0 := _fret_x[FRET_COUNT]
	for string_idx in STRING_COUNT:
		var cy := _string_y[string_idx]
		_fret_cells.append({
			"fret": EXTENSION_FRET,
			"string": string_idx,
			"note": _note_for(string_idx, EXTENSION_FRET),
			"rect": Rect2(
				Vector2(fret13_x0, cy - string_gap * 0.5),
				Vector2(fret13_width, string_gap)),
		})


func _string_spacing() -> float:
	if _string_y.size() < 2:
		return _board_rect.size.y * 0.8 / float(STRING_COUNT)
	return absf(_string_y[1] - _string_y[0])


func _marker_radius() -> float:
	return _string_spacing() * 0.42


func _open_zone_width() -> float:
	return _marker_radius() * 2.4 + MARKER_ZONE_PADDING + 10.0


func _draw_fretboard() -> void:
	if _board_rect.size.x <= 0.0:
		return

	draw_rect(_board_rect, fretboard_color, true)
	if _open_zone_rect.size.x > 0.0:
		draw_rect(_open_zone_rect, open_zone_color, true)
	if _fret13_zone_rect.size.x > 0.0:
		draw_rect(_fret13_zone_rect, open_zone_color, true)

	_draw_nut()
	_draw_bridge()

	for fret in range(1, FRET_COUNT + 1):
		var x := _fret_x[fret]
		draw_line(
			Vector2(x, _board_rect.position.y),
			Vector2(x, _board_rect.position.y + _board_rect.size.y),
			fret_color, 2.0)

	_draw_strings()
	_draw_zone_note_labels(_open_zone_rect, 0)
	_draw_zone_note_labels(_fret13_zone_rect, EXTENSION_FRET)
	_draw_fret_markers()
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


func _draw_strings() -> void:
	var end_x := _bridge_rect.position.x if _bridge_rect.size.x > 0.0 else _board_rect.position.x + _board_rect.size.x
	var start_x := _open_zone_rect.position.x
	for string_idx in STRING_COUNT:
		var y := _string_y[string_idx]
		var width := STRING_WIDTHS[string_idx]
		draw_line(Vector2(start_x, y), Vector2(end_x, y), string_color, width)


func _draw_zone_note_labels(zone: Rect2, fret: int) -> void:
	if zone.size.x <= 0.0:
		return
	var font := ThemeDB.fallback_font
	var font_size := clampi(int(_string_spacing() * 0.38), 6, 10)
	var padding := 2.0
	var center_x := zone.position.x + zone.size.x * 0.5
	var text_width := zone.size.x * 0.9
	var min_baseline := _board_rect.position.y + font_size
	for string_idx in STRING_COUNT:
		var label := _note_for(string_idx, fret)
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


func _draw_fret_markers() -> void:
	var radius := minf(_board_rect.size.y * 0.06, _string_spacing() * 0.30)
	var center_y := _board_rect.position.y + _board_rect.size.y * 0.5
	for fret in DOT_FRETS:
		_draw_fret_marker_with_label(_fret_center_x(fret), center_y, radius, str(fret))

	var upper_y := _board_rect.position.y + _board_rect.size.y * 0.35
	var lower_y := _board_rect.position.y + _board_rect.size.y * 0.65
	var x12 := _fret_center_x(12)
	_draw_marker_dot(x12, upper_y, radius)
	_draw_marker_dot(x12, lower_y, radius)
	_draw_fret_marker_label(x12, (upper_y + lower_y) * 0.5, radius, "12")


func _draw_fret_marker_with_label(center_x: float, center_y: float, radius: float, label: String) -> void:
	_draw_marker_dot(center_x, center_y, radius)
	_draw_fret_marker_label(center_x, center_y, radius, label)


func _draw_fret_marker_label(center_x: float, center_y: float, radius: float, label: String) -> void:
	var font := ThemeDB.fallback_font
	var font_size := clampi(int(radius * 1.1), 6, 10)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline_y := center_y + (ascent - descent) * 0.5
	draw_string(
		font, Vector2(center_x - radius, baseline_y), label,
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, fret_marker_text_color)


func _draw_marker_dot(center_x: float, center_y: float, radius: float) -> void:
	draw_circle(Vector2(center_x, center_y), radius, fret_position_marker_color)
	draw_arc(Vector2(center_x, center_y), radius, 0.0, TAU, 24, fret_color, 1.0)


func _fret_center_x(fret: int) -> float:
	return (_fret_x[fret - 1] + _fret_x[fret]) * 0.5


func _draw_active_cells() -> void:
	if active_notes.is_empty():
		return
	var spacing := _string_spacing()
	var open_radius := _marker_radius()
	var fret_radius := minf(spacing * 0.38, _board_rect.size.y * 0.055)
	for cell in _fret_cells:
		var note: String = cell["note"]
		var is_primary := _note_matches(note)
		var is_neighbor := _note_matches_octave_neighbors(note)
		if not is_primary and not is_neighbor:
			continue
		var rect := cell["rect"] as Rect2
		var fret_num: int = int(cell["fret"])
		var center := rect.position + rect.size * 0.5
		var is_open: bool = fret_num == 0
		var radius: float = open_radius if is_open else fret_radius
		if is_open:
			center.x = _open_zone_rect.position.x + _open_zone_rect.size.x * 0.62
		elif fret_num == EXTENSION_FRET:
			center.x = _fret13_zone_rect.position.x + _fret13_zone_rect.size.x * 0.5
			center.y = _string_y[int(cell["string"])]
		elif fret_num > 0:
			center.x = _fret_center_x(fret_num)
			center.y = _string_y[int(cell["string"])]
		_draw_note_marker(center, radius, note, is_primary)


func _note_at(local_pos: Vector2) -> String:
	_update_layout()
	for cell in _fret_cells:
		if (cell["rect"] as Rect2).has_point(local_pos):
			return cell["note"]
	return ""


func _note_for(string_idx: int, fret: int) -> String:
	var open_pitch := normalize_note(OPEN_STRING_NOTES[string_idx])
	var open_pc := CHROMATIC.find(open_pitch)
	var octave: int = OPEN_STRING_OCTAVES[string_idx]
	var midi := (octave + 1) * 12 + open_pc + fret
	return _midi_to_name(midi)
