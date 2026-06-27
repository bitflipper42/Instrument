extends Node2D

const PianoScene := preload("res://piano_instrument.tscn")
const GuitarScene := preload("res://guitar_instrument.tscn")
const ViolaScene := preload("res://viola_instrument.tscn")
const SourceScene := preload("res://source_instrument.tscn")
const SequenceScene := preload("res://sequence_instrument.tscn")
const NafScene := preload("res://naf_instrument.tscn")

@onready var tile_manager: TileManager = $TileManager


func _ready() -> void:
	# Row 0: Piano (flexible width) alongside a square Source tile.
	var top_row := tile_manager.add_row()
	var piano := tile_manager.add_tile_to_row(top_row, PianoScene, "Piano") as BasicInstrument
	var source := tile_manager.add_tile_to_row(top_row, SourceScene, "Source", true, 1.44) as SourceInstrument

	# Row 1: Guitar (left) and Sequence (right). Row 2: Viola.
	var guitar_row := tile_manager.add_row()
	var guitar := tile_manager.add_tile_to_row(guitar_row, GuitarScene, "Guitar") as BasicInstrument
	var sequence := tile_manager.add_tile_to_row(
		guitar_row, SequenceScene, "Sequence", true, 1.0) as SequenceInstrument
	var viola := tile_manager.add_tile_from_scene(ViolaScene, "Viola") as BasicInstrument

	# Row 3: Native American flute (full width, taller than the other rows).
	var naf_row := tile_manager.add_row(1.2)
	var naf := tile_manager.add_tile_to_row(naf_row, NafScene, "NAF") as BasicInstrument

	if piano and guitar:
		piano.connect_bidirectional(guitar)
	if piano and viola:
		piano.connect_bidirectional(viola)
	if guitar and viola:
		guitar.connect_bidirectional(viola)
	if naf:
		if piano:
			naf.connect_bidirectional(piano)
		if guitar:
			naf.connect_bidirectional(guitar)
		if viola:
			naf.connect_bidirectional(viola)

	if source:
		source.clear_pressed.connect(_release_all_notes)
		# Source sends generated chords to every playable instrument.
		if piano:
			source.connect_to(piano)
		if guitar:
			source.connect_to(guitar)
		if viola:
			source.connect_to(viola)
		if naf:
			source.connect_to(naf)

	if sequence:
		if piano:
			sequence.connect_to(piano)
		if guitar:
			sequence.connect_to(guitar)
		if viola:
			sequence.connect_to(viola)
		if naf:
			sequence.connect_to(naf)


## Releases all notes on every instrument (Source's Clear button).
func _release_all_notes() -> void:
	for tile in tile_manager.all_tiles():
		if tile is BasicInstrument:
			(tile as BasicInstrument).release_all()
