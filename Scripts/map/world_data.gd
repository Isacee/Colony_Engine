extends RefCounted
## The generated world: terrain masks plus the atlas tile chosen for every cell.
## Hills form a wall around the map edge that is outside the playable area.

const HillGenerator = preload("res://Scripts/map/hill_generator.gd")
const IslandGenerator = preload("res://Scripts/map/island_generator.gd")
const LandMask = preload("res://Scripts/map/land_mask.gd")
const TilePicker = preload("res://Scripts/map/tile_picker.gd")

const TILE_SIZE := 16
const BORDER_THICKNESS := 4

var size: Vector2i
var land: LandMask
var hills: LandMask
var ground_tiles := {}
var hill_tiles := {}

var _random: RandomNumberGenerator
var _navigation: AStarGrid2D


func _init(map_size: Vector2i, random: RandomNumberGenerator) -> void:
	size = map_size
	_random = random
	land = IslandGenerator.new(size, _random).generate()
	hills = LandMask.new(size)
	_add_inner_hills()
	_add_border_hills()
	_choose_tiles()
	_build_navigation()


func playable_cells() -> Rect2i:
	return Rect2i(Vector2i.ONE * BORDER_THICKNESS, size - Vector2i.ONE * BORDER_THICKNESS * 2)


func playable_rect() -> Rect2:
	var cells := playable_cells()
	return Rect2(Vector2(cells.position * TILE_SIZE), Vector2(cells.size * TILE_SIZE))


func map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size * TILE_SIZE))


func colony_position() -> Vector2:
	return (Vector2(size / 2) + Vector2.ONE * 0.5) * TILE_SIZE


func clamp_to_playable(world_position: Vector2) -> Vector2:
	var rect := playable_rect()
	return nearest_open_position(world_position.clamp(rect.position, rect.end))


func nearest_open_position(world_position: Vector2) -> Vector2:
	var start := _to_cell(world_position)
	if is_open_cell(start):
		return (Vector2(start) + Vector2.ONE * 0.5) * TILE_SIZE
	for radius in range(1, 24):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var candidate := start + Vector2i(x, y)
				if is_open_cell(candidate):
					return (Vector2(candidate) + Vector2.ONE * 0.5) * TILE_SIZE
	return colony_position()


func is_open_ground(world_position: Vector2) -> bool:
	return is_open_cell(Vector2i((world_position / TILE_SIZE).floor()))


func is_open_cell(cell: Vector2i) -> bool:
	return playable_cells().has_point(cell) and land.is_land(cell) and not hills.is_land(cell)


# Returns waypoints from one world position to another that avoid water and hills.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	# A start or goal on a blocked cell yields no path, which made ants stall and re-plan every frame.
	var start := _to_cell(from)
	if not is_open_cell(start):
		start = _to_cell(nearest_open_position(from))
	var goal := _to_cell(to)
	if not is_open_cell(goal):
		to = nearest_open_position(to)
		goal = _to_cell(to)
	var path := _navigation.get_point_path(start, goal)
	if path.is_empty():
		return path
	# The first point is the centre of the current cell; skip it so ants don't step back to it.
	if path.size() > 1:
		path.remove_at(0)
	path[path.size() - 1] = to
	return path


func _to_cell(world_position: Vector2) -> Vector2i:
	var cell := Vector2i((world_position / TILE_SIZE).floor())
	return cell.clamp(Vector2i.ZERO, size - Vector2i.ONE)


func _build_navigation() -> void:
	_navigation = AStarGrid2D.new()
	_navigation.region = Rect2i(Vector2i.ZERO, size)
	_navigation.cell_size = Vector2.ONE * TILE_SIZE
	_navigation.offset = Vector2.ONE * TILE_SIZE * 0.5
	_navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_navigation.update()
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			if not is_open_cell(cell):
				_navigation.set_point_solid(cell)


func _add_inner_hills() -> void:
	for hill in HillGenerator.new(_random).generate(land, playable_cells()):
		for x in range(hill.position.x, hill.end.x):
			for y in range(hill.position.y, hill.end.y):
				hills.set_land(Vector2i(x, y), true)


func _add_border_hills() -> void:
	var playable := playable_cells()
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			if not playable.has_point(cell):
				hills.set_land(cell, true)


func _choose_tiles() -> void:
	var picker := TilePicker.new(_random)
	for x in size.x:
		for y in size.y:
			var cell := Vector2i(x, y)
			if land.is_land(cell):
				ground_tiles[cell] = picker.pick_ground(land, cell)
			if hills.is_land(cell):
				hill_tiles[cell] = picker.pick_hill(hills, cell)
