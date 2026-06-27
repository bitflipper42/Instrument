class_name NafInstrument
extends BasicInstrument

## Native American flute (6-hole, minor-pentatonic "mode 1"). Unlike the chromatic
## keyboard/neck instruments the NAF only sounds the notes in its scale, so it
## highlights just those incoming notes and stays dark for the rest. The body runs
## left (mouthpiece) → right (foot); the fingering row below shows each note's
## open/closed hole pattern.

const HOLE_COUNT := 6
## Fundamental (all holes closed). A4 = a mid-range NAF in the key of A.
const ROOT_MIDI := 69
## Minor-pentatonic "mode 1" fingering intervals from the root (ascending).
const SCALE_INTERVALS: PackedInt32Array = [0, 3, 5, 7, 10, 12]
## Open finger holes for each scale degree, by hole index (0 = mouth end … 5 = foot
## end). The first four notes open sequentially from the foot, but the ♭7 and the
## octave use forked/cross fingerings (Flutopedia mode-1 SNAFT
## <xxx|xxx <xxx|xxo <xxx|xoo <xxx|ooo <xox|ooo <oox|ooo).
const FINGERINGS: Array[PackedInt32Array] = [
	[],                  # A  root      ●●●●●●
	[5],                 # C  ♭3        ●●●●●○
	[4, 5],              # D  4         ●●●●○○
	[3, 4, 5],           # E  5         ●●●○○○
	[1, 3, 4, 5],        # G  ♭7        ●○●○○○ (forked)
	[0, 1, 3, 4, 5],     # A  octave    ○○●○○○ (forked)
]
## Single (normal breath) register.
const REGISTER_COUNT := 1

const TITLE_HEIGHT := 28.0
const BOARD_PADDING := Vector2(12.0, 10.0)

@export var tube_color: Color = Color(0.40, 0.26, 0.15)
@export var tube_highlight_color: Color = Color(0.56, 0.40, 0.24)
@export var tube_edge_color: Color = Color(0.20, 0.13, 0.08)
@export var block_color: Color = Color(0.30, 0.19, 0.11)
## Covered hole: a solid (lighter) plug sitting on the wood.
@export var hole_closed_color: Color = Color(0.58, 0.43, 0.26)
## Open hole: a dark void you can see into.
@export var hole_open_color: Color = Color(0.06, 0.04, 0.03)
@export var hole_ring_color: Color = Color(0.62, 0.50, 0.36)
@export var cell_bg_color: Color = Color(0.16, 0.12, 0.10)
@export var cell_border_color: Color = Color(0.42, 0.34, 0.26)
@export var marker_color: Color = Color(0.76, 0.72, 0.64)
@export var active_marker_color: Color = Color(1.0, 1.0, 1.0)
@export var label_color: Color = Color(0.86, 0.82, 0.74)
@export var marker_text_color: Color = Color(0.14, 0.10, 0.06)

var _tube_rect := Rect2()
var _block_rect := Rect2()
var _hole_centers: Array[Vector2] = []
var _hole_radius := 0.0
var _fingering_cells: Array[Dictionary] = []
var _bold_font: FontVariation


func _ready() -> void:
	super._ready()
	if title == "Instrument":
		title = "NAF"
	_bold_font = FontVariation.new()
	_bold_font.base_font = ThemeDB.fallback_font
	_bold_font.variation_embolden = 1.2


func receive_midi(message: MidiMessage) -> void:
	super.receive_midi(message)
	queue_redraw()


## A NAF can only sound the notes in its pentatonic scale.
func _can_play(note: String) -> bool:
	return _is_scale_note(note)


## The NAF ignores octave when highlighting: a fingering lights up whenever its
## pitch class is sounding anywhere (no separate octave-neighbor markers).
func _note_matches(key_note: String) -> bool:
	return is_pitch_class_active(key_note)


func _draw() -> void:
	_update_layout()
	_draw_tile_chrome()
	_draw_flute()
	_draw_fingerings()


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
	_hole_centers.clear()
	_fingering_cells.clear()

	var body := _body_rect()
	if body.size.x <= 0.0 or body.size.y <= 0.0:
		_tube_rect = Rect2()
		_block_rect = Rect2()
		return

	var tube_band_h := body.size.y * 0.40
	var tube_h := minf(tube_band_h * 0.55, 64.0)
	var tube_y := body.position.y + (tube_band_h - tube_h) * 0.5
	_tube_rect = Rect2(body.position.x, tube_y, body.size.x, tube_h)

	# Block ("bird"/fetish) sits on top of the tube around the left third.
	var block_w := _tube_rect.size.x * 0.10
	var block_h := tube_h * 0.7
	var block_x := _tube_rect.position.x + _tube_rect.size.x * 0.26
	_block_rect = Rect2(block_x, _tube_rect.position.y - block_h * 0.45, block_w, block_h)

	# Six finger holes spread across the right portion of the tube.
	_hole_radius = minf(tube_h * 0.18, _tube_rect.size.x * 0.02)
	var holes_left := _tube_rect.position.x + _tube_rect.size.x * 0.40
	var holes_right := _tube_rect.position.x + _tube_rect.size.x * 0.92
	var hole_cy := _tube_rect.position.y + _tube_rect.size.y * 0.5
	for h in HOLE_COUNT:
		var t := float(h) / float(HOLE_COUNT - 1)
		_hole_centers.append(Vector2(lerpf(holes_left, holes_right, t), hole_cy))

	# Fingering rows below the tube, one per register.
	var fingers_top := body.position.y + tube_band_h
	var fingers_h := body.size.y - tube_band_h
	var row_h := fingers_h / float(REGISTER_COUNT)
	var cols := SCALE_INTERVALS.size()
	var cell_w := body.size.x / float(cols)
	for r in REGISTER_COUNT:
		var row_y := fingers_top + row_h * float(r)
		for i in cols:
			var rect := Rect2(
				Vector2(body.position.x + cell_w * float(i) + cell_w * 0.04, row_y + row_h * 0.08),
				Vector2(cell_w * 0.92, row_h * 0.84))
			_fingering_cells.append({
				"note": _note_for(r, i),
				"rect": rect,
				"register": r,
				"index": i,
				"open_holes": FINGERINGS[i],
			})


func _draw_flute() -> void:
	if _tube_rect.size.x <= 0.0 or _tube_rect.size.y <= 0.0:
		return
	_draw_tube()

	draw_rect(_block_rect, block_color, true)
	draw_rect(_block_rect, tube_edge_color, false, 1.0)

	var open_set := _active_open_holes()
	for h in HOLE_COUNT:
		var center: Vector2 = _hole_centers[h]
		if open_set.has(h):
			draw_circle(center, _hole_radius, hole_open_color)
			draw_arc(center, _hole_radius, 0.0, TAU, 24, hole_ring_color, 1.5)
		else:
			draw_circle(center, _hole_radius, hole_closed_color)
			draw_arc(center, _hole_radius, 0.0, TAU, 24, hole_ring_color, 1.0)


func _draw_tube() -> void:
	var r := _tube_rect
	var radius := r.size.y * 0.5
	var inner_w := maxf(r.size.x - radius * 2.0, 0.0)
	draw_rect(Rect2(r.position.x + radius, r.position.y, inner_w, r.size.y), tube_color, true)
	draw_circle(Vector2(r.position.x + radius, r.position.y + radius), radius, tube_color)
	draw_circle(Vector2(r.position.x + r.size.x - radius, r.position.y + radius), radius, tube_color)

	# Cylinder highlight stripe near the top.
	var stripe_y := r.position.y + r.size.y * 0.28
	draw_line(
		Vector2(r.position.x + radius, stripe_y),
		Vector2(r.position.x + r.size.x - radius, stripe_y),
		tube_highlight_color, maxf(r.size.y * 0.10, 1.0))

	# Edge lines along the straight section.
	draw_line(
		Vector2(r.position.x + radius, r.position.y),
		Vector2(r.position.x + r.size.x - radius, r.position.y), tube_edge_color, 1.0)
	draw_line(
		Vector2(r.position.x + radius, r.position.y + r.size.y),
		Vector2(r.position.x + r.size.x - radius, r.position.y + r.size.y), tube_edge_color, 1.0)


func _draw_fingerings() -> void:
	var font := _bold_font
	for cell in _fingering_cells:
		var rect: Rect2 = cell["rect"]
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var note: String = cell["note"]
		var is_primary := _note_matches(note)

		var bg := cell_bg_color
		var border := cell_border_color
		if is_primary:
			bg = active_marker_color.darkened(0.15)
			border = active_marker_color
		draw_rect(rect, bg, true)
		draw_rect(rect, border, false, 1.5 if is_primary else 1.0)

		var label := _normalize_pitch(note)
		var label_size := clampi(int(rect.size.y * 0.22), 9, 16)
		var label_col := marker_text_color if is_primary else label_color
		var ascent := font.get_ascent(label_size)
		draw_string(
			font, Vector2(rect.position.x, rect.position.y + ascent + rect.size.y * 0.06),
			label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, label_size, label_col)

		_draw_hole_pattern(rect, cell["open_holes"], is_primary)


func _draw_hole_pattern(rect: Rect2, open_holes: PackedInt32Array, primary: bool) -> void:
	var diag_y := rect.position.y + rect.size.y * 0.64
	var side_margin := rect.size.x * 0.12
	var span := maxf(rect.size.x - side_margin * 2.0, 0.0)
	var radius := minf(span / float(HOLE_COUNT) * 0.32, rect.size.y * 0.12)
	if radius <= 0.0:
		return
	var ring := marker_text_color if primary else hole_ring_color
	for h in HOLE_COUNT:
		var t := float(h) / float(HOLE_COUNT - 1)
		var center := Vector2(rect.position.x + side_margin + span * t, diag_y)
		if open_holes.has(h):
			draw_arc(center, radius, 0.0, TAU, 18, ring, 1.5)
		else:
			draw_circle(center, radius, ring)


## Open finger holes for the primary active fingering, used to animate the body
## holes. Returns an empty set when nothing (or only octave neighbors) is sounding.
func _active_open_holes() -> PackedInt32Array:
	for cell in _fingering_cells:
		if _note_matches(cell["note"]):
			return cell["open_holes"]
	return PackedInt32Array()


func _note_at(local_pos: Vector2) -> String:
	_update_layout()
	for cell in _fingering_cells:
		if (cell["rect"] as Rect2).has_point(local_pos):
			return cell["note"]
	return ""


func _note_for(register: int, index: int) -> String:
	return _midi_to_name(ROOT_MIDI + SCALE_INTERVALS[index] + 12 * register)


func _scale_midis() -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in REGISTER_COUNT:
		for interval in SCALE_INTERVALS:
			out.append(ROOT_MIDI + interval + 12 * r)
	return out


func _is_scale_note(note: String) -> bool:
	var midi := _name_to_midi(note)
	return midi >= 0 and _scale_midis().has(midi)
