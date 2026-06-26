class_name SourceInstrument
extends BasicInstrument

## Control tile. Hosts a row of dropdowns (root note + scale type) and a Clear
## button that asks every connected instrument to release all of its notes.

## Emitted when the Clear button is pressed.
signal clear_pressed
## Emitted when the root note or scale selection changes.
signal scale_selection_changed(root_note: String, scale: String)

## Scale types offered by the scale dropdown.
const SCALES: PackedStringArray = [
	"Major", "Minor", "Major Pentatonic", "Minor Pentatonic",
]

const TITLE_HEIGHT := 28.0
const UI_PADDING := 18.0

var _ui: VBoxContainer
var _note_option: OptionButton
var _scale_option: OptionButton
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
	for scale_name in SCALES:
		_scale_option.add_item(scale_name)
	_scale_option.selected = 0
	_scale_option.clip_text = true
	_scale_option.custom_minimum_size.x = 0.0
	_scale_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_row.add_child(_scale_option)

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
	_clear_button.pressed.connect(func() -> void: clear_pressed.emit())


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


## The currently selected root note name (e.g. "C", "F#").
func selected_root_note() -> String:
	if _note_option == null:
		return CHROMATIC[0]
	return _note_option.get_item_text(_note_option.selected)


## The currently selected scale type (e.g. "Major").
func selected_scale() -> String:
	if _scale_option == null:
		return SCALES[0]
	return _scale_option.get_item_text(_scale_option.selected)


func _on_selection_changed(_index: int) -> void:
	scale_selection_changed.emit(selected_root_note(), selected_scale())
