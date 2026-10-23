extends RefCounted
## Facade for the world: generates it, streams tiles near the camera, and answers position queries.

const TileStreamer = preload("res://Scripts/map/tile_streamer.gd")
const WorldData = preload("res://Scripts/map/world_data.gd")

const MAP_SIZE := Vector2i(200, 200)
const WATER_COLOR := Color("9bd4c3")

var _world: WorldData
var _streamer: TileStreamer
var _random: RandomNumberGenerator


func _init(water: TileMapLayer, ground: TileMapLayer, hills: TileMapLayer, random: RandomNumberGenerator) -> void:
	_random = random
	_streamer = TileStreamer.new(water, ground, hills)
	for layer in [water, ground, hills]:
		layer.show_behind_parent = true
		layer.position = Vector2.ZERO
	RenderingServer.set_default_clear_color(WATER_COLOR)


func generate() -> void:
	_world = WorldData.new(MAP_SIZE, _random)
	_streamer.set_world(_world)


func update_view(view_center: Vector2, view_size: Vector2) -> void:
	_streamer.update(view_center, view_size)


func colony_position() -> Vector2:
	return _world.colony_position()


func map_rect() -> Rect2:
	return _world.map_rect()


func clamp_to_playable(world_position: Vector2) -> Vector2:
	return _world.clamp_to_playable(world_position)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return _world.find_path(from, to)


func is_open_ground(world_position: Vector2) -> bool:
	return _world.is_open_ground(world_position)


func nearest_open_position(world_position: Vector2) -> Vector2:
	return _world.nearest_open_position(world_position)


# Returns a random spot on open ground, or the colony position if none is found.
func random_open_position(center: Vector2, min_distance: float, max_distance: float) -> Vector2:
	for attempt in 100:
		var candidate := center + Vector2.RIGHT.rotated(_random.randf_range(0.0, TAU)) * _random.randf_range(min_distance, max_distance)
		if _world.is_open_ground(candidate):
			return candidate
	return _world.colony_position()
