extends RefCounted
## Chooses the atlas tile for a cell based on which of its neighbors are in the same mask.

const LandMask = preload("res://Scripts/map/land_mask.gd")

const NONE := Vector2i(-1, -1)
const DECOR_CHANCE := 0.15
const PLAIN := Vector2i(1, 1)
const EDGE_N := Vector2i(1, 0)
const EDGE_S := Vector2i(1, 2)
const EDGE_W := Vector2i(0, 1)
const EDGE_E := Vector2i(2, 1)
const CORNER_NW := Vector2i(0, 0)
const CORNER_NE := Vector2i(2, 0)
const CORNER_SW := Vector2i(0, 2)
const CORNER_SE := Vector2i(2, 2)
const INNER_NW := Vector2i(6, 2)
const INNER_NE := Vector2i(5, 2)
const INNER_SW := Vector2i(6, 1)
const INNER_SE := Vector2i(5, 1)
const DECOR: Array[Vector2i] = [
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
	Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
]

const WATER := Vector2i(0, 0)

var _random: RandomNumberGenerator


func _init(random: RandomNumberGenerator) -> void:
	_random = random


func pick_ground(mask: LandMask, cell: Vector2i) -> Vector2i:
	var tile := _edge_tile(mask, cell)
	if tile == NONE:
		tile = _inner_corner_tile(mask, cell)
	if tile == NONE:
		tile = DECOR[_random.randi() % DECOR.size()] if _random.randf() < DECOR_CHANCE else PLAIN
	return tile


# Hills.png shares the Grass.png layout: edges, corners, and a cliff face on the bottom row.
func pick_hill(mask: LandMask, cell: Vector2i) -> Vector2i:
	var tile := _edge_tile(mask, cell)
	if tile == NONE:
		tile = _inner_corner_tile(mask, cell)
	return PLAIN if tile == NONE else tile


func _edge_tile(mask: LandMask, cell: Vector2i) -> Vector2i:
	var north := mask.is_land(cell + Vector2i.UP)
	var south := mask.is_land(cell + Vector2i.DOWN)
	var west := mask.is_land(cell + Vector2i.LEFT)
	var east := mask.is_land(cell + Vector2i.RIGHT)

	if not north and not west:
		return CORNER_NW
	if not north and not east:
		return CORNER_NE
	if not south and not west:
		return CORNER_SW
	if not south and not east:
		return CORNER_SE
	if not north:
		return EDGE_N
	if not south:
		return EDGE_S
	if not west:
		return EDGE_W
	if not east:
		return EDGE_E
	return NONE


# Interior cells get an inner-corner tile where a diagonal neighbor is missing.
func _inner_corner_tile(mask: LandMask, cell: Vector2i) -> Vector2i:
	if not mask.is_land(cell + Vector2i(-1, -1)):
		return INNER_NW
	if not mask.is_land(cell + Vector2i(1, -1)):
		return INNER_NE
	if not mask.is_land(cell + Vector2i(-1, 1)):
		return INNER_SW
	if not mask.is_land(cell + Vector2i(1, 1)):
		return INNER_SE
	return NONE
