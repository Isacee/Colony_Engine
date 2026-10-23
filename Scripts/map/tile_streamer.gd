extends RefCounted
## Keeps only the chunks of tiles around the camera painted on the TileMapLayers.

const WorldData = preload("res://Scripts/map/world_data.gd")
const TilePicker = preload("res://Scripts/map/tile_picker.gd")

const CHUNK_SIZE := 16
const CHUNK_MARGIN := 1
const GRASS_SOURCE_ID := 0
const HILLS_SOURCE_ID := 1
const WATER_SOURCE_ID := 2

var _water_layer: TileMapLayer
var _ground_layer: TileMapLayer
var _hills_layer: TileMapLayer
var _world: WorldData
var _loaded_chunks := {}


func _init(water: TileMapLayer, ground: TileMapLayer, hills: TileMapLayer) -> void:
	_water_layer = water
	_ground_layer = ground
	_hills_layer = hills


func set_world(world: WorldData) -> void:
	_world = world
	_loaded_chunks.clear()
	for layer in [_water_layer, _ground_layer, _hills_layer]:
		layer.clear()


func update(view_center: Vector2, view_size: Vector2) -> void:
	var chunk_pixels := float(CHUNK_SIZE * WorldData.TILE_SIZE)
	var center_chunk := Vector2i((view_center / chunk_pixels).floor())
	var radius := Vector2i((view_size * 0.5 / chunk_pixels).ceil()) + Vector2i.ONE * CHUNK_MARGIN

	var wanted := {}
	for x in range(center_chunk.x - radius.x, center_chunk.x + radius.x + 1):
		for y in range(center_chunk.y - radius.y, center_chunk.y + radius.y + 1):
			var chunk := Vector2i(x, y)
			if not _chunk_cells(chunk).has_area():
				continue
			wanted[chunk] = true

	for chunk in _loaded_chunks.keys():
		if not wanted.has(chunk):
			_unload_chunk(chunk)
	for chunk in wanted:
		if not _loaded_chunks.has(chunk):
			_load_chunk(chunk)


func _chunk_cells(chunk: Vector2i) -> Rect2i:
	var cells := Rect2i(chunk * CHUNK_SIZE, Vector2i.ONE * CHUNK_SIZE)
	return cells.intersection(Rect2i(Vector2i.ZERO, _world.size))


func _load_chunk(chunk: Vector2i) -> void:
	var cells := _chunk_cells(chunk)
	for x in range(cells.position.x, cells.end.x):
		for y in range(cells.position.y, cells.end.y):
			var cell := Vector2i(x, y)
			_water_layer.set_cell(cell, WATER_SOURCE_ID, TilePicker.WATER)
			if _world.ground_tiles.has(cell):
				_ground_layer.set_cell(cell, GRASS_SOURCE_ID, _world.ground_tiles[cell])
			if _world.hill_tiles.has(cell):
				_hills_layer.set_cell(cell, HILLS_SOURCE_ID, _world.hill_tiles[cell])
	_loaded_chunks[chunk] = true


func _unload_chunk(chunk: Vector2i) -> void:
	var cells := _chunk_cells(chunk)
	for x in range(cells.position.x, cells.end.x):
		for y in range(cells.position.y, cells.end.y):
			var cell := Vector2i(x, y)
			_water_layer.erase_cell(cell)
			_ground_layer.erase_cell(cell)
			_hills_layer.erase_cell(cell)
	_loaded_chunks.erase(chunk)
