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
var _text_stack: Control
var _sequence_display: RichTextLabel
var _text_edit: TextEdit
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
	_layout_ui()
	_reparse_sequence()


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	add_child(_canvas)

	_ui = VBoxContainer.new()
	_ui.add_theme_constant_override("separation", 4)
	_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_ui)

	_text_stack = Control.new()
	_text_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_stack.clip_contents = true
	_ui.add_child(_text_stack)

	_sequence_display = RichTextLabel.new()
	_sequence_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sequence_display.bbcode_enabled = true
	_sequence_display.scroll_active = false
	_sequence_display.fit_content = false
	_sequence_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sequence_display.add_theme_font_size_override("normal_font_size", 11)
	_sequence_display.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_sequence_display.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_text_stack.add_child(_sequence_display)

	_text_edit = TextEdit.new()
	_text_edit.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_edit.text = DEFAULT_SEQUENCE
	_text_edit.placeholder_text = "C G Am F"
	_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_text_edit.focus_mode = Control.FOCUS_ALL
	_text_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	_text_edit.add_theme_font_size_override("font_size", 11)
	_text_edit.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.0))
	_text_edit.add_theme_color_override("font_readonly_color", Color(1.0, 1.0, 1.0, 0.0))
	_text_edit.add_theme_color_override("caret_color", Color(0.92, 0.95, 1.0))
	_text_edit.add_theme_color_override("selection_color", Color(0.28, 0.55, 0.85, 0.35))
	_text_edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_text_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_text_stack.add_child(_text_edit)

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

	_tick_checkbox = CheckBox.new()
	_tick_checkbox.text = "Tick"
	_tick_checkbox.button_pressed = true
	controls.add_child(_tick_checkbox)

	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	controls.add_child(_play_button)

	_text_edit.text_changed.connect(_on_text_changed)
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
	# Tile chrome only — current chord is shown in the UI label.
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
	for token in ChordParser.tokenize(_text_edit.text):
		var result := ChordParser.parse(token)
		_parsed_chords.append(result)
		if result["valid"]:
			_valid_step_indices.append(_parsed_chords.size() - 1)
	_update_sequence_display()


func _update_sequence_display() -> void:
	if _sequence_display == null:
		return
	if _text_edit.text.is_empty():
		_sequence_display.text = "[color=#666666]%s[/color]" % _text_edit.placeholder_text
		return
	var bbcode := ""
	var chord_i := 0
	var valid_hex := valid_token_color.to_html(false)
	var invalid_hex := invalid_token_color.to_html(false)
	var active_hex := active_token_color.to_html(false)
	for line_i in _text_edit.get_line_count():
		if line_i > 0:
			bbcode += "\n"
		var line := _text_edit.get_line(line_i)
		var col := 0
		var first_token := true
		while col < line.length():
			while col < line.length() and line[col] == " ":
				bbcode += " "
				col += 1
			if col >= line.length():
				break
			if not first_token:
				bbcode += " "
			first_token = false
			var start := col
			while col < line.length() and line[col] != " ":
				col += 1
			var token := line.substr(start, col - start)
			if chord_i < _parsed_chords.size():
				var chord: Dictionary = _parsed_chords[chord_i]
				if chord_i == _active_parsed_index and _active_parsed_index >= 0:
					bbcode += "[bgcolor=#%s][color=#ffffff]%s[/color][/bgcolor]" % [active_hex, token]
				elif not chord["valid"]:
					bbcode += "[color=#%s]%s[/color]" % [invalid_hex, token]
				else:
					bbcode += "[color=#%s]%s[/color]" % [valid_hex, token]
				chord_i += 1
			else:
				bbcode += "[color=#%s]%s[/color]" % [invalid_hex, token]
	_sequence_display.text = bbcode


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
	_update_sequence_display()


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
	_update_sequence_display()
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
