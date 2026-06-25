class_name GuitarInstrument
extends BasicInstrument

## Horizontal 12-fret guitar neck derived from BasicInstrument. Nut on the left,
## frets run vertically left-to-right, strings run horizontally.

const FRET_COUNT := 12
const STRING_COUNT := 6
const OPEN_STRING_NOTES: PackedStringArray = ["E", "A", "D", "G", "B", "E"]
const OPEN_STRING_OCTAVES: PackedInt32Array = [2, 2, 3, 3, 3, 4]
const DOT_FRETS: PackedInt32Array = [3, 5, 7, 9]

@export var fretboard_color: Color = Color(0.32, 0.20, 0.11)
@export var open_zone_color: Color = Color(0.26, 0.16, 0.09)
@export var fret_color: Color = Color(0.78, 0.78, 0.80)
@export var string_color: Color = Color(0.70, 0.70, 0.72)
@export var marker_color: Color = Color(0.76, 0.72, 0.64)
@export var marker_text_color: Color = Color(0.22, 0.18, 0.14)
@export var active_marker_color: Color = Color(0.22, 0.50, 0.78)
@export var edge_line_color: Color = Color(0.88, 0.86, 0.82)

const TITLE_HEIGHT := 28.0
const BOARD_PADDING := Vector2(10.0, 8.0)
const MARKER_ZONE_PADDING := 6.0

var _board_rect := Rect2()
var _open_zone_rect := Rect2()
var _fret_x: Array[float] = []
var _string_y: Array[float] = []
var _fret_cells: Array[Dictionary] = []
var _bold_marker_font: FontVariation
var _show_open_markers := false


func _ready() -> void:
	super._ready()
	if title == "Instrument":
		title = "Guitar"
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
	var ok := super.emit_note(note)
	if ok:
		_show_open_markers = false
	return ok


func receive_note(note: String) -> bool:
	var ok := super.receive_note(note)
	if ok:
		_show_open_markers = true
	return ok


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
		return

	var neck_height := body.size.y * 0.82
	var neck_top := body.position.y + (body.size.y - neck_height) * 0.5
	_board_rect = Rect2(body.position.x, neck_top, body.size.x, neck_height)

	for i in STRING_COUNT:
		var y := lerpf(
			_board_rect.position.y + _board_rect.size.y * 0.10,
			_board_rect.position.y + _board_rect.size.y * 0.90,
			float(i) / float(STRING_COUNT - 1))
		_string_y.append(y)

	var open_width := _open_zone_width()
	_open_zone_rect = Rect2(_board_rect.position.x, _board_rect.position.y, open_width, _board_rect.size.y)

	var nut_x := _board_rect.position.x + open_width
	var span := _board_rect.size.x - open_width
	var fret_span := 1.0 - pow(2.0, -float(FRET_COUNT) / 12.0)

	_fret_x.append(nut_x)
	for fret in range(1, FRET_COUNT + 1):
		var t := (1.0 - pow(2.0, -float(fret) / 12.0)) / fret_span
		_fret_x.append(nut_x + span * t)

	var string_gap := _string_spacing()
	for string_idx in STRING_COUNT:
		var open_note := _note_for(string_idx, 0)
		_fret_cells.append({
			"fret": 0,
			"string": string_idx,
			"note": open_note,
			"rect": Rect2(
				Vector2(_open_zone_rect.position.x, _string_y[string_idx] - string_gap * 0.5),
				Vector2(_open_zone_rect.size.x, string_gap)),
		})

	for fret in range(1, FRET_COUNT + 1):
		var x0 := _fret_x[fret]
		var x1 := _fret_x[fret + 1] if fret < FRET_COUNT else _board_rect.position.x + _board_rect.size.x
		for string_idx in STRING_COUNT:
			_fret_cells.append({
				"fret": fret,
				"string": string_idx,
				"note": _note_for(string_idx, fret),
				"rect": Rect2(
					Vector2(x0, _string_y[string_idx] - string_gap * 0.5),
					Vector2(x1 - x0, string_gap)),
			})


func _string_spacing() -> float:
	if _string_y.size() < 2:
		return _board_rect.size.y
	return (_string_y[1] - _string_y[0])


func _marker_radius() -> float:
	return _string_spacing() * 0.42


func _open_zone_width() -> float:
	return _marker_radius() * 2.0 + MARKER_ZONE_PADDING


func _draw_fretboard() -> void:
	if _board_rect.size.x <= 0.0:
		return

	draw_rect(_board_rect, fretboard_color, true)
	if _open_zone_rect.size.x > 0.0:
		draw_rect(_open_zone_rect, open_zone_color, true)

	var line_gap := maxf(2.0, _board_rect.size.y * 0.02)
	var nut_x := _fret_x[0]
	draw_line(
		Vector2(nut_x, _board_rect.position.y),
		Vector2(nut_x, _board_rect.position.y + _board_rect.size.y),
		edge_line_color, 2.5)
	draw_line(
		Vector2(nut_x + line_gap, _board_rect.position.y),
		Vector2(nut_x + line_gap, _board_rect.position.y + _board_rect.size.y),
		edge_line_color, 2.5)

	for fret in range(1, FRET_COUNT + 1):
		var x := _fret_x[fret]
		draw_line(
			Vector2(x, _board_rect.position.y),
			Vector2(x, _board_rect.position.y + _board_rect.size.y),
			fret_color, 2.0)

	for y in _string_y:
		draw_line(
			Vector2(_open_zone_rect.position.x, y),
			Vector2(_board_rect.position.x + _board_rect.size.x, y),
			string_color, 1.0)

	_draw_open_string_markers()
	_draw_fret_markers()
	_draw_active_cells()


func _draw_open_string_markers() -> void:
	if not _show_open_markers or _open_zone_rect.size.x <= 0.0:
		return
	var radius := _marker_radius()
	for string_idx in STRING_COUNT:
		var note := _note_for(string_idx, 0)
		if not _note_matches(note):
			continue
		var center := Vector2(
			_open_zone_rect.position.x + _open_zone_rect.size.x * 0.5,
			_string_y[string_idx])
		_draw_note_marker(center, radius, note, true)


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
	for fret in DOT_FRETS:
		_draw_marker_dot(_fret_center_x(fret), _board_rect.position.y + _board_rect.size.y * 0.5, radius)

	var upper_y := _board_rect.position.y + _board_rect.size.y * 0.35
	var lower_y := _board_rect.position.y + _board_rect.size.y * 0.65
	_draw_marker_dot(_fret_center_x(12), upper_y, radius)
	_draw_marker_dot(_fret_center_x(12), lower_y, radius)


func _draw_marker_dot(center_x: float, center_y: float, radius: float) -> void:
	draw_circle(Vector2(center_x, center_y), radius, marker_color)
	draw_arc(Vector2(center_x, center_y), radius, 0.0, TAU, 24, fret_color, 1.0)


func _fret_center_x(fret: int) -> float:
	return (_fret_x[fret - 1] + _fret_x[fret]) * 0.5


func _draw_active_cells() -> void:
	var spacing := _string_spacing()
	var radius := minf(spacing * 0.38, _board_rect.size.y * 0.055)
	for cell in _fret_cells:
		if cell["fret"] == 0:
			continue
		if not _note_matches(cell["note"]):
			continue
		var rect := cell["rect"] as Rect2
		var center := rect.position + rect.size * 0.5
		_draw_note_marker(center, radius, cell["note"], true)


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
