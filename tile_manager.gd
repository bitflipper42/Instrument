class_name TileManager
extends Node2D

## Lays out InstTiles in a grid of rows. Rows stack vertically and share the
## viewport height equally; within a row, tiles are placed left to right.
## A tile can be marked "square" so its width tracks the row height.
## Re-arranges automatically when the window size changes.

const InstTileScene := preload("res://inst_tile.tscn")

## The tile scene used by `add_tile()` / startup tiles.
@export var tile_scene: PackedScene = preload("res://piano_instrument.tscn")
## How many single-tile rows to create on startup (0 = build everything from code).
@export var default_tile_count: int = 0
## Gap between adjacent tiles and rows, in pixels.
@export var spacing: float = 0.0
## Outer margin (x = left/right, y = top/bottom), in pixels.
@export var margin: Vector2 = Vector2.ZERO

## Rows of tiles. Each row is an Array of { "tile": InstTile, "square": bool }.
var rows: Array = []

## Per-row vertical weight (parallel to `rows`). Rows split the viewport height in
## proportion to these weights, so a weight < 1.0 makes a row shorter than the rest.
var row_weights: Array[float] = []

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


## Flattened list of every tile across all rows (row-major order).
func all_tiles() -> Array[InstTile]:
	var out: Array[InstTile] = []
	for row in rows:
		for entry in row:
			out.append(entry["tile"])
	return out


## Appends an empty row and returns its index. `weight` sets the row's share of the
## viewport height relative to other rows (1.0 = a normal full-height row).
func add_row(weight: float = 1.0) -> int:
	rows.append([])
	row_weights.append(weight)
	return rows.size() - 1


## Creates a tile from `scene` and appends it to `row_index`. When `square` is
## true the tile width is `row_height * width_factor` (height stays row height).
func add_tile_to_row(
	row_index: int,
	scene: PackedScene,
	title: String = "",
	square: bool = false,
	width_factor: float = 1.0,
) -> InstTile:
	if row_index < 0 or row_index >= rows.size():
		push_warning("TileManager: invalid row index %d" % row_index)
		return null
	var tile := scene.instantiate() as InstTile
	var index := _total_tiles()
	tile.tile_color = _PALETTE[index % _PALETTE.size()]
	tile.title = title if title != "" else "Tile %d" % (index + 1)
	add_child(tile)
	rows[row_index].append({"tile": tile, "square": square, "width_factor": width_factor})
	arrange_tiles()
	return tile


## Convenience: creates a new row holding a single tile from `scene`.
func add_tile_from_scene(scene: PackedScene, title: String = "", square: bool = false) -> InstTile:
	return add_tile_to_row(add_row(), scene, title, square)


## Convenience: a new single-tile row using the default `tile_scene`.
func add_tile(title: String = "") -> InstTile:
	return add_tile_from_scene(tile_scene if tile_scene != null else InstTileScene, title)


## Removes a tile (by reference) and frees it; drops the row if it becomes empty.
func remove_tile(tile: InstTile) -> void:
	for r in rows.size():
		var row: Array = rows[r]
		for i in row.size():
			if row[i]["tile"] == tile:
				row.remove_at(i)
				tile.queue_free()
				if row.is_empty():
					rows.remove_at(r)
					if r < row_weights.size():
						row_weights.remove_at(r)
				arrange_tiles()
				return


func _total_tiles() -> int:
	var n := 0
	for row in rows:
		n += row.size()
	return n


## Recomputes every tile's rect. Rows split the viewport height equally; tiles
## within a row split the leftover width equally (squares take a fixed width).
func arrange_tiles() -> void:
	var row_count := rows.size()
	if row_count == 0:
		return
	var screen := get_viewport().get_visible_rect().size
	var available := screen - margin * 2.0
	var total_v_spacing := spacing * float(row_count - 1)
	var content_height := available.y - total_v_spacing
	var total_weight := 0.0
	for i in row_count:
		total_weight += _row_weight(i)
	if total_weight <= 0.0:
		total_weight = float(row_count)
	var y := margin.y
	for i in row_count:
		var row_height := content_height * (_row_weight(i) / total_weight)
		_arrange_row(rows[i], margin.x, y, available.x, row_height)
		y += row_height + spacing


func _row_weight(row_index: int) -> float:
	if row_index < 0 or row_index >= row_weights.size():
		return 1.0
	return row_weights[row_index]


func _arrange_row(row: Array, x0: float, y: float, total_width: float, row_height: float) -> void:
	var count := row.size()
	if count == 0:
		return
	var h_spacing := spacing * float(count - 1)
	var square_width_sum := 0.0
	var flexible_count := 0
	for entry in row:
		if entry["square"]:
			square_width_sum += row_height * float(entry.get("width_factor", 1.0))
		else:
			flexible_count += 1
	var flexible_width := total_width - h_spacing - square_width_sum
	var per_flexible := 0.0
	if flexible_count > 0:
		per_flexible = maxf(flexible_width / float(flexible_count), 0.0)
	var x := x0
	for entry in row:
		var w: float
		if entry["square"]:
			w = row_height * float(entry.get("width_factor", 1.0))
		else:
			w = per_flexible
		(entry["tile"] as InstTile).set_rect(Vector2(x, y), Vector2(w, row_height))
		x += w + spacing
