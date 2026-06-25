extends Node2D

const GuitarScene := preload("res://guitar_instrument.tscn")

@onready var tile_manager: TileManager = $TileManager


func _ready() -> void:
	var tiles := tile_manager.tiles
	if tiles.is_empty():
		return

	if tiles[0] is BasicInstrument:
		tiles[0].title = "Piano"

	if tiles.size() >= 2:
		tile_manager.remove_tile(1)
	var guitar := tile_manager.add_tile_from_scene(GuitarScene, "Guitar") as BasicInstrument

	if tiles[0] is BasicInstrument:
		(tiles[0] as BasicInstrument).connect_to(guitar)
