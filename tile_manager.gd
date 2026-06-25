class_name TileManager
extends Node2D

## Manages a row of InstTiles. Lays them out as equal-width columns that span
## the visible viewport, and exposes helpers to add, remove and rearrange them.
## Re-arranges automatically when the window size changes.

const InstTileScene := preload("res://inst_tile.tscn")

## The tile scene to instantiate for new tiles. Defaults to BasicInstrument.
@export var tile_scene: PackedScene = preload("res://basic_instrument.tscn")
## How many tiles to create on startup. Defaults to two horizontal tiles.
@export var default_tile_count: int = 2
## Gap between adjacent tiles, in pixels.
@export var spacing: float = 0.0
## Outer margin (x = left/right, y = top/bottom), in pixels.
@export var margin: Vector2 = Vector2.ZERO

## Ordered list of managed tiles (left to right).
var tiles: Array[InstTile] = []

const _PALETTE: Array[Color] = [
	Color(0.15, 0.18, 0.27),
	Color(0.18, 0.24, 0.22),
	Color(0.24, 0.18, 0.24),
	Color(0.24, 0.22, 0.16),
]

func _ready() -> void:
	for i in default_tile_count:
		add_tile()
	get_viewport().size_changed.connect(arrange_tiles)
	arrange_tiles()

## Creates a new tile, appends it to the row and re-arranges. Returns the tile.
func add_tile(title: String = "") -> InstTile:
	var scene := tile_scene if tile_scene != null else InstTileScene
	var tile := scene.instantiate() as InstTile
	tile.tile_color = _PALETTE[tiles.size() % _PALETTE.size()]
	tile.title = title if title != "" else "Tile %d" % (tiles.size() + 1)
	add_child(tile)
	tiles.append(tile)
	arrange_tiles()
	return tile

## Removes the tile at `index` (and frees it).
func remove_tile(index: int) -> void:
	if index < 0 or index >= tiles.size():
		return
	var tile := tiles[index]
	tiles.remove_at(index)
	tile.queue_free()
	arrange_tiles()

## Swaps the positions of two tiles by index.
func swap_tiles(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= tiles.size() or b >= tiles.size():
		return
	var tmp := tiles[a]
	tiles[a] = tiles[b]
	tiles[b] = tmp
	arrange_tiles()

## Moves a tile from one slot to another, shifting the rest.
func move_tile(from: int, to: int) -> void:
	if from < 0 or from >= tiles.size():
		return
	to = clampi(to, 0, tiles.size() - 1)
	var tile := tiles[from]
	tiles.remove_at(from)
	tiles.insert(to, tile)
	arrange_tiles()

## Recomputes each tile's rect. Tiles are horizontal bars (full width) stacked
## vertically to fill the visible viewport.
func arrange_tiles() -> void:
	var count := tiles.size()
	if count == 0:
		return
	var screen := get_viewport().get_visible_rect().size
	var available := screen - margin * 2.0
	var total_spacing := spacing * float(count - 1)
	var tile_width := available.x
	var tile_height := (available.y - total_spacing) / float(count)
	for i in count:
		var x := margin.x
		var y := margin.y + float(i) * (tile_height + spacing)
		tiles[i].set_rect(Vector2(x, y), Vector2(tile_width, tile_height))
