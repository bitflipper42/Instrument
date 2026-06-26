class_name SourceInstrument
extends BasicInstrument

## Control tile. Hosts a row of dropdowns (root note + scale type), a generated
## row of chord "circle" buttons for that key, and a Clear button that releases
## all notes. Clicking a chord plays its tones out through `midi_out`.

## Emitted when the Clear button is pressed.
signal clear_pressed
## Emitted when the root note or scale selection changes.
signal scale_selection_changed(root_note: String, scale: String)

## Scale types offered by the scale dropdown, mapped to semitone offsets.
const SCALE_INTERVALS: Dictionary = {
	"Major": [0, 2, 4, 5, 7, 9, 11],
	"Minor": [0, 2, 3, 5, 7, 8, 10],
	"Major Pentatonic": [0, 2, 4, 7, 9],
	"Minor Pentatonic": [0, 3, 5, 7, 10],
}
const SCALE_NAMES: PackedStringArray = [
	"Major", "Minor", "Major Pentatonic", "Minor Pentatonic",
]

## Octave the generated chord roots are built in.
const CHORD_BASE_OCTAVE := 4

const TITLE_HEIGHT := 28.0
const UI_PADDING := 18.0
const CIRCLE_SIZE := 34.0

@export var chord_color: Color = Color(0.20, 0.30, 0.42)
@export var chord_pressed_color: Color = Color(0.28, 0.55, 0.85)
@export var chord_hover_color: Color = Color(0.26, 0.38, 0.52)
@export var chord_border_color: Color = Color(0.55, 0.66, 0.82)
@export var chord_text_color: Color = Color(0.95, 0.97, 1.0)

var _ui: VBoxContainer
var _note_option: OptionButton
var _scale_option: OptionButton
var _chord_row: HBoxContainer
var _clear_button: Button


func _ready() -> void:
	super._ready()
	if title == "Instrument":
		title = "Source"
	_build_ui()
	_layout_ui()


func _build_ui() -> void:
	_ui = VBoxContainer.new()
	_ui.add_theme_constant_override("separation", 8)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)

	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 8)
	_ui.add_child(controls_row)

	_note_option = OptionButton.new()
	for note_name in CHROMATIC:
		_note_option.add_item(note_name)
	_note_option.selected = 0
	_note_option.clip_text = true
	_note_option.custom_minimum_size.x = 60.0
	_note_option.size_flags_horizontal = Control.SIZE_FILL
	controls_row.add_child(_note_option)

	_scale_option = OptionButton.new()
	for scale_name in SCALE_NAMES:
		_scale_option.add_item(scale_name)
	_scale_option.selected = 0
	_scale_option.clip_text = true
	_scale_option.custom_minimum_size.x = 0.0
	_scale_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_row.add_child(_scale_option)

	_chord_row = HBoxContainer.new()
	_chord_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_chord_row.add_theme_constant_override("separation", 6)
	_ui.add_child(_chord_row)

	# Flexible spacer pushes the Clear button to the bottom.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(spacer)

	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ui.add_child(_clear_button)

	_note_option.item_selected.connect(_on_selection_changed)
	_scale_option.item_selected.connect(_on_selection_changed)
	_clear_button.pressed.connect(_on_clear_pressed)

	_rebuild_chords()


func _layout_ui() -> void:
	if _ui == null:
		return
	_ui.position = Vector2(UI_PADDING, TITLE_HEIGHT)
	_ui.size = Vector2(
		maxf(tile_size.x - UI_PADDING * 2.0, 0.0),
		maxf(tile_size.y - TITLE_HEIGHT - UI_PADDING, 0.0))


func set_rect(top_left: Vector2, size: Vector2) -> void:
	super.set_rect(top_left, size)
	_layout_ui()


func _active_note_label_font_size() -> int:
	return 9


## The currently selected root note name (e.g. "C", "F#").
func selected_root_note() -> String:
	if _note_option == null:
		return CHROMATIC[0]
	return _note_option.get_item_text(_note_option.selected)


## The currently selected scale type (e.g. "Major").
func selected_scale() -> String:
	if _scale_option == null:
		return SCALE_NAMES[0]
	return _scale_option.get_item_text(_scale_option.selected)


func _on_selection_changed(_index: int) -> void:
	_rebuild_chords()
	scale_selection_changed.emit(selected_root_note(), selected_scale())


func _on_clear_pressed() -> void:
	_reset_chord_buttons()
	clear_pressed.emit()


## Rebuilds the chord row from the current root note and scale. Each diatonic
## chord is a triad stacked in scale-thirds; its quality comes from its actual
## intervals.
func _rebuild_chords() -> void:
	if _chord_row == null:
		return
	release_all()
	for child in _chord_row.get_children():
		child.queue_free()

	var intervals: Array = SCALE_INTERVALS.get(selected_scale(), [])
	var root_pc := CHROMATIC.find(selected_root_note())
	if root_pc < 0 or intervals.is_empty():
		return

	var degree_count := intervals.size()
	for i in degree_count:
		var o1 := _ext_offset(intervals, i)
		var o2 := _ext_offset(intervals, i + 2)
		var o3 := _ext_offset(intervals, i + 4)
		var third := (o2 - o1) % 12
		var fifth := (o3 - o1) % 12
		var chord_root_pc := (root_pc + o1) % 12
		var label := CHROMATIC[chord_root_pc] + _quality_suffix(third, fifth)
		var base_root := (CHORD_BASE_OCTAVE + 1) * 12 + root_pc + o1
		var tones: Array[int] = [base_root, base_root + (o2 - o1), base_root + (o3 - o1)]
		_chord_row.add_child(_make_chord_button(label, tones))


func _ext_offset(intervals: Array, k: int) -> int:
	var n := intervals.size()
	return int(intervals[k % n]) + 12 * int(k / n)


func _quality_suffix(third: int, fifth: int) -> String:
	match [third, fifth]:
		[4, 7]:
			return ""
		[3, 7]:
			return "m"
		[3, 6]:
			return "°"
		[4, 8]:
			return "+"
		[5, 7]:
			return "sus4"
		[2, 7]:
			return "sus2"
		_:
			return "*"


func _make_chord_button(label: String, tones: Array[int]) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.text = label
	button.clip_text = true
	button.tooltip_text = label
	button.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_stylebox_override("normal", _circle_style(chord_color))
	button.add_theme_stylebox_override("hover", _circle_style(chord_hover_color))
	button.add_theme_stylebox_override("pressed", _circle_style(chord_pressed_color))
	button.add_theme_stylebox_override("hover_pressed", _circle_style(chord_pressed_color))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", chord_text_color)
	button.add_theme_color_override("font_pressed_color", chord_text_color)
	button.add_theme_color_override("font_hover_color", chord_text_color)
	button.add_theme_font_size_override("font_size", 8)
	button.toggled.connect(func(pressed: bool) -> void: _on_chord_toggled(pressed, tones))
	return button


func _circle_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = chord_border_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(CIRCLE_SIZE * 0.5))
	return sb


func _on_chord_toggled(pressed: bool, tones: Array[int]) -> void:
	for midi in tones:
		if pressed:
			note_on(_midi_to_name(midi))
		else:
			note_off(_midi_to_name(midi))


func _reset_chord_buttons() -> void:
	if _chord_row == null:
		return
	for child in _chord_row.get_children():
		if child is Button:
			(child as Button).set_pressed_no_signal(false)
