extends RefCounted
## Places rectangular hills on solid land inside the given bounds, away from the colony.

const LandMask = preload("res://Scripts/map/land_mask.gd")

const HILL_COUNT := 30
const PLACEMENT_ATTEMPTS := 600
const MIN_SIZE := Vector2i(4, 3)
const MAX_SIZE := Vector2i(8, 6)
const COLONY_CLEARANCE := 9
const HILL_SPACING := 2

var _random: RandomNumberGenerator


func _init(random: RandomNumberGenerator) -> void:
	_random = random


func generate(mask: LandMask, bounds: Rect2i) -> Array[Rect2i]:
	var hills: Array[Rect2i] = []
	for attempt in PLACEMENT_ATTEMPTS:
		if hills.size() >= HILL_COUNT:
			break
		var candidate := _random_rect(bounds)
		if _is_valid(candidate, mask, bounds, hills):
			hills.append(candidate)
	return hills


func _random_rect(bounds: Rect2i) -> Rect2i:
	var size := Vector2i(
		_random.randi_range(MIN_SIZE.x, MAX_SIZE.x),
		_random.randi_range(MIN_SIZE.y, MAX_SIZE.y))
	var position := Vector2i(
		_random.randi_range(bounds.position.x, bounds.end.x - size.x),
		_random.randi_range(bounds.position.y, bounds.end.y - size.y))
	return Rect2i(position, size)


func _is_valid(candidate: Rect2i, mask: LandMask, bounds: Rect2i, existing: Array[Rect2i]) -> bool:
	if not bounds.encloses(candidate.grow(HILL_SPACING)):
		return false
	# Land must surround the hill so it never touches the shoreline tiles.
	for cell in _cells_of(candidate.grow(1)):
		if not mask.is_land(cell):
			return false
	var colony_area := Rect2i(Vector2i(mask.size / 2), Vector2i.ZERO).grow(COLONY_CLEARANCE)
	if candidate.intersects(colony_area):
		return false
	for other in existing:
		if candidate.intersects(other.grow(HILL_SPACING)):
			return false
	return true


func _cells_of(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			cells.append(Vector2i(x, y))
	return cells
