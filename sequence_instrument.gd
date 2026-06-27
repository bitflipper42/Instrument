class_name SequenceInstrument
extends BasicInstrument

## Control tile that parses a whitespace-separated chord sequence, highlights
## invalid tokens in red, and steps through valid chords on each beat.

const TITLE_HEIGHT := 28.0
const UI_PADDING := 8.0
const DEFAULT_BPM := 40
const MIN_BPM := 20
const MAX_BPM := 80
const DEFAULT_SEQUENCE := "C G Am F"

@export var valid_token_color: Color = Color(0.92, 0.95, 1.0)
@export var invalid_token_color: Color = Color(1.0, 0.35, 0.35)
@export var active_token_color: Color = Color(1.0, 0.2, 0.2)

var _canvas: CanvasLayer
var _ui: VBoxContainer
var _code_edit: CodeEdit
var _highlighter: ChordSequenceHighlighter
var _current_label: Label
var _bpm_slider: HSlider
var _bpm_label: Label
var _tick_checkbox: CheckBox
var _play_button: Button
var _tick_player: AudioStreamPlayer

var _parsed_chords: Array = []
var _valid_step_indices: Array[int] = []
var _playing := false
var _step_index := 0
var _beat_accum := 0.0
var _current_tones: Array[int] = []
var _active_parsed_index := -1


func _ready() -> void:
	super._ready()
	if title == "Instrument":
		title = "Sequence"
	set_process(true)
	_build_ui()
	_highlighter.set_colors(valid_token_color, invalid_token_color, active_token_color)
	_layout_ui()
	_reparse_sequence()


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	add_child(_canvas)

	_ui = VBoxContainer.new()
	_ui.add_theme_constant_override("separation", 4)
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_ui)

	_code_edit = CodeEdit.new()
	_code_edit.text = DEFAULT_SEQUENCE
	_code_edit.placeholder_text = "C G Am F"
	_code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code_edit.focus_mode = Control.FOCUS_ALL
	_code_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.gutters_draw_line_numbers = false
	_code_edit.gutters_draw_fold_gutter = false
	_code_edit.minimap_draw = false
	_code_edit.highlight_current_line = false
	_code_edit.draw_spaces = false
	_code_edit.draw_tabs = false
	_code_edit.line_folding = false
	_code_edit.code_completion_enabled = false
	_code_edit.indent_automatic = false
	_code_edit.auto_brace_completion_enabled = false
	_code_edit.add_theme_font_size_override("font_size", 11)
	var editor_bg := StyleBoxFlat.new()
	editor_bg.bg_color = Color(0.10, 0.12, 0.18, 0.55)
	editor_bg.set_corner_radius_all(4)
	_code_edit.add_theme_stylebox_override("normal", editor_bg)
	_code_edit.add_theme_stylebox_override("focus", editor_bg)
	_highlighter = ChordSequenceHighlighter.new()
	_code_edit.syntax_highlighter = _highlighter
	_ui.add_child(_code_edit)

	_current_label = Label.new()
	_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_label.add_theme_color_override("font_color", active_token_color)
	_current_label.add_theme_font_size_override("font_size", 14)
	_ui.add_child(_current_label)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 4)
	_ui.add_child(controls)

	var bpm_row := HBoxContainer.new()
	bpm_row.add_theme_constant_override("separation", 6)
	controls.add_child(bpm_row)

	var bpm_caption := Label.new()
	bpm_caption.text = "BPM"
	bpm_row.add_child(bpm_caption)

	_bpm_slider = HSlider.new()
	_bpm_slider.min_value = MIN_BPM
	_bpm_slider.max_value = MAX_BPM
	_bpm_slider.step = 1.0
	_bpm_slider.value = DEFAULT_BPM
	_bpm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bpm_row.add_child(_bpm_slider)

	_bpm_label = Label.new()
	_bpm_label.custom_minimum_size.x = 28.0
	_bpm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bpm_row.add_child(_bpm_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	controls.add_child(action_row)

	_tick_checkbox = CheckBox.new()
	_tick_checkbox.text = "Tick"
	_tick_checkbox.button_pressed = true
	_tick_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(_tick_checkbox)

	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	action_row.add_child(_play_button)

	_code_edit.text_changed.connect(_on_text_changed)
	_bpm_slider.value_changed.connect(_on_bpm_changed)
	_play_button.pressed.connect(_on_play_pressed)
	_on_bpm_changed(_bpm_slider.value)

	_tick_player = AudioStreamPlayer.new()
	_tick_player.stream = _make_tick_stream()
	add_child(_tick_player)


func _layout_ui() -> void:
	if _ui == null:
		return
	_ui.position = global_position + Vector2(UI_PADDING, TITLE_HEIGHT)
	_ui.size = Vector2(
		maxf(tile_size.x - UI_PADDING * 2.0, 0.0),
		maxf(tile_size.y - TITLE_HEIGHT - UI_PADDING, 0.0))


func set_rect(top_left: Vector2, size: Vector2) -> void:
	super.set_rect(top_left, size)
	_layout_ui()


func _input(_event: InputEvent) -> void:
	# UI-only tile; don't handle instrument click gestures.
	pass


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, tile_size)
	draw_rect(rect, tile_color, true)
	draw_rect(rect, border_color, false, border_width)
	if title != "":
		var font := ThemeDB.fallback_font
		var font_size := 18
		draw_string(font, Vector2(10, 10 + font_size), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_color)


func release_all() -> void:
	_stop_playback()
	super.release_all()


func _on_text_changed() -> void:
	_reparse_sequence()
	if _playing:
		_restart_playback_from_current()


func _on_bpm_changed(value: float) -> void:
	_bpm_label.text = str(int(value))


func _on_play_pressed() -> void:
	if _playing:
		_stop_playback()
	else:
		_start_playback()


func _reparse_sequence() -> void:
	_parsed_chords.clear()
	_valid_step_indices.clear()
	for token in ChordParser.tokenize(_code_edit.text):
		var result := ChordParser.parse(token)
		_parsed_chords.append(result)
		if result["valid"]:
			_valid_step_indices.append(_parsed_chords.size() - 1)
	_refresh_highlight(false)


func _refresh_highlight(force_redraw: bool) -> void:
	_highlighter.set_parsed_chords(_parsed_chords, _active_parsed_index)
	if force_redraw:
		# TextEdit only repaints syntax colors after lines_edited_from (godot#12503).
		# Reassigning the highlighter forces a full re-fetch during playback.
		var hi := _highlighter
		_code_edit.syntax_highlighter = null
		_code_edit.syntax_highlighter = hi
	else:
		_highlighter.clear_highlighting_cache()
		for line in _code_edit.get_line_count():
			_highlighter.get_line_syntax_highlighting(line)
	_code_edit.queue_redraw()


func _start_playback() -> void:
	if _valid_step_indices.is_empty():
		_current_label.text = "—"
		return
	_playing = true
	_beat_accum = 0.0
	_step_index = 0
	_play_button.text = "Pause"
	_play_chord_at(_valid_step_indices[_step_index])


func _stop_playback() -> void:
	_playing = false
	_beat_accum = 0.0
	_play_button.text = "Play"
	_active_parsed_index = -1
	_current_label.text = ""
	_release_current_chord()
	_refresh_highlight(true)


func _restart_playback_from_current() -> void:
	_release_current_chord()
	if _valid_step_indices.is_empty():
		_stop_playback()
		return
	_step_index = clampi(_step_index, 0, _valid_step_indices.size() - 1)
	_play_chord_at(_valid_step_indices[_step_index])


func _advance_sequence() -> void:
	_release_current_chord()
	if _valid_step_indices.is_empty():
		_stop_playback()
		return
	_step_index = (_step_index + 1) % _valid_step_indices.size()
	_play_chord_at(_valid_step_indices[_step_index])


func _play_chord_at(parsed_index: int) -> void:
	if parsed_index < 0 or parsed_index >= _parsed_chords.size():
		return
	var chord: Dictionary = _parsed_chords[parsed_index]
	if not chord["valid"]:
		return
	_active_parsed_index = parsed_index
	_current_tones = (chord["tones"] as Array).duplicate()
	_current_label.text = chord["token"]
	_refresh_highlight(true)
	if _tick_checkbox != null and _tick_checkbox.button_pressed:
		_tick_player.play()
	for midi in _current_tones:
		note_on(_midi_to_name(midi))


func _release_current_chord() -> void:
	for midi in _current_tones:
		note_off(_midi_to_name(midi))
	_current_tones.clear()


func _process(delta: float) -> void:
	if not _playing or _valid_step_indices.is_empty():
		return
	var beat_len := 60.0 / _bpm_slider.value
	_beat_accum += delta
	while _beat_accum >= beat_len:
		_beat_accum -= beat_len
		_advance_sequence()


func _make_tick_stream() -> AudioStreamWAV:
	var sample_hz := 44100
	var duration := 0.025
	var frame_count := int(sample_hz * duration)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for i in frame_count:
		var t := float(i) / float(sample_hz)
		var env := exp(-t * 140.0)
		var sample := sin(TAU * 1000.0 * t) * env * 0.4
		var s16 := int(clampf(sample * 32767.0, -32768.0, 32767.0))
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_hz
	stream.stereo = false
	stream.data = data
	return stream


class ChordSequenceHighlighter:
	extends SyntaxHighlighter

	var _parsed_by_line: Array = []
	var _valid_color := Color(0.92, 0.95, 1.0)
	var _invalid_color := Color(1.0, 0.35, 0.35)
	var _active_color := Color(1.0, 0.2, 0.2)
	var _active_chord_index := -1


	func set_parsed_chords(chords: Array, active_chord_index: int = -1) -> void:
		_active_chord_index = active_chord_index
		_parsed_by_line = _group_tokens_by_line(chords)


	func set_colors(valid_color: Color, invalid_color: Color, active_color: Color) -> void:
		_valid_color = valid_color
		_invalid_color = invalid_color
		_active_color = active_color


	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		var result := {}
		if line < 0 or line >= _parsed_by_line.size():
			return result
		for entry in _parsed_by_line[line]:
			var color := _valid_color
			if not entry["valid"]:
				color = _invalid_color
			elif entry["chord_index"] == _active_chord_index:
				color = _active_color
			result[entry["start"]] = {"color": color}
		return _sort_by_column(result)


	func _sort_by_column(color_map: Dictionary) -> Dictionary:
		var sorted := {}
		var keys: Array = color_map.keys()
		keys.sort()
		for key in keys:
			sorted[key] = color_map[key]
		return sorted


	func _group_tokens_by_line(chords: Array) -> Array:
		var text_edit := get_text_edit()
		if text_edit == null:
			return []
		var grouped: Array = []
		var chord_i := 0
		for line_i in text_edit.get_line_count():
			grouped.append([])
			var line := text_edit.get_line(line_i)
			var col := 0
			while col < line.length():
				while col < line.length() and line[col] == " ":
					col += 1
				if col >= line.length():
					break
				var start := col
				while col < line.length() and line[col] != " ":
					col += 1
				var valid := false
				var chord_index := -1
				if chord_i < chords.size():
					valid = chords[chord_i]["valid"]
					chord_index = chord_i
					chord_i += 1
				grouped[line_i].append({
					"start": start, "end": col, "valid": valid, "chord_index": chord_index,
				})
		return grouped
