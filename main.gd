extends Node2D

@onready var tile_manager: TileManager = $TileManager


func _ready() -> void:
	var tiles := tile_manager.tiles
	if tiles.size() >= 2 and tiles[0] is BasicInstrument and tiles[1] is BasicInstrument:
		var source := tiles[0] as BasicInstrument
		var sink := tiles[1] as BasicInstrument
		source.title = "Source"
		sink.title = "Sink"
		source.connect_to(sink)
		source.emit_note("C")
