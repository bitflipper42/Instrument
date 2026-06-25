class_name InstTile
extends Node2D

## A single instrument tile. A 2D object that occupies a rectangular region
## assigned by the TileManager. Draws a filled rect with a border and a title
## so the layout is visible at a glance.

@export var tile_color: Color = Color(0.15, 0.18, 0.27)
@export var border_color: Color = Color(0.28, 0.55, 0.75)
@export var border_width: float = 2.0
@export var title: String = "":
	set(value):
		title = value
		queue_redraw()

## Current size of the tile in local pixels. Position lives on `position`.
var tile_size: Vector2 = Vector2(100, 100)

## Places the tile: `top_left` is in parent space, `size` is the tile's extent.
func set_rect(top_left: Vector2, size: Vector2) -> void:
	position = top_left
	tile_size = size
	queue_redraw()

func get_rect() -> Rect2:
	return Rect2(position, tile_size)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, tile_size)
	draw_rect(rect, tile_color, true)
	draw_rect(rect, border_color, false, border_width)
	if title != "":
		var font := ThemeDB.fallback_font
		var font_size := 18
		draw_string(font, Vector2(10, 10 + font_size), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_color)
