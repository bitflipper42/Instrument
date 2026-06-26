extends Node2D

const PianoScene := preload("res://piano_instrument.tscn")
const GuitarScene := preload("res://guitar_instrument.tscn")
const ViolaScene := preload("res://viola_instrument.tscn")
const SourceScene := preload("res://source_instrument.tscn")

@onready var tile_manager: TileManager = $TileManager


func _ready() -> void:
	# Row 0: Piano (flexible width) alongside a square Source tile.
	var top_row := tile_manager.add_row()
	var piano := tile_manager.add_tile_to_row(top_row, PianoScene, "Piano") as BasicInstrument
	var source := tile_manager.add_tile_to_row(top_row, SourceScene, "Source", true) as SourceInstrument

	# Rows 1 and 2: full-width Guitar, then Viola.
	var guitar := tile_manager.add_tile_from_scene(GuitarScene, "Guitar") as BasicInstrument
	var viola := tile_manager.add_tile_from_scene(ViolaScene, "Viola") as BasicInstrument

	if piano and guitar:
		piano.connect_bidirectional(guitar)
	if piano and viola:
		piano.connect_bidirectional(viola)
	if guitar and viola:
		guitar.connect_bidirectional(viola)

	if source:
		source.clear_pressed.connect(_release_all_notes)


## Releases all notes on every instrument (Source's Clear button).
func _release_all_notes() -> void:
	for tile in tile_manager.all_tiles():
		if tile is BasicInstrument:
			(tile as BasicInstrument).release_all()
