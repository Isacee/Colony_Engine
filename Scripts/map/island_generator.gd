extends RefCounted
## Builds a single island shaped by noise and a falloff from the map center.

const LandMask = preload("res://Scripts/map/land_mask.gd")

const NOISE_FREQUENCY := 0.07
const NOISE_STRENGTH := 0.4
const BASE_HEIGHT := 0.85
const FALLOFF := 0.9
const LAND_THRESHOLD := 0.1

var _map_size: Vector2i
var _random: RandomNumberGenerator


func _init(map_size: Vector2i, random: RandomNumberGenerator) -> void:
	_map_size = map_size
	_random = random


func generate() -> LandMask:
	var mask := _carve_noise_island()
	_remove_thin_spurs(mask)
	return _keep_central_island(mask)


func _carve_noise_island() -> LandMask:
	var noise := FastNoiseLite.new()
	noise.seed = _random.randi()
	noise.frequency = NOISE_FREQUENCY
	var mask := LandMask.new(_map_size)
	var center := Vector2(_map_size) * 0.5
	# The outer ring stays water so the island never touches the map border.
	for x in range(1, _map_size.x - 1):
		for y in range(1, _map_size.y - 1):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center) / (_map_size.x * 0.5)
			var height := BASE_HEIGHT - distance * FALLOFF + noise.get_noise_2d(x, y) * NOISE_STRENGTH
			mask.set_land(Vector2i(x, y), height > LAND_THRESHOLD)
	return mask


# The tileset has no tiles for one-tile-wide strips, so they are removed.
func _remove_thin_spurs(mask: LandMask) -> void:
	var changed := true
	while changed:
		changed = false
		for x in _map_size.x:
			for y in _map_size.y:
				var cell := Vector2i(x, y)
				if mask.is_land(cell) and _is_spur(mask, cell):
					mask.set_land(cell, false)
					changed = true


func _is_spur(mask: LandMask, cell: Vector2i) -> bool:
	var north := mask.is_land(cell + Vector2i.UP)
	var south := mask.is_land(cell + Vector2i.DOWN)
	var west := mask.is_land(cell + Vector2i.LEFT)
	var east := mask.is_land(cell + Vector2i.RIGHT)
	return (not north and not south) or (not west and not east) or mask.land_neighbor_count(cell) < 2


# Flood fill from the map center, where the colony starts.
func _keep_central_island(mask: LandMask) -> LandMask:
	var kept := LandMask.new(_map_size)
	var start := Vector2i(_map_size / 2)
	if not mask.is_land(start):
		return kept
	kept.set_land(start, true)
	var pending: Array[Vector2i] = [start]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + dir
			if mask.is_land(next) and not kept.is_land(next):
				kept.set_land(next, true)
				pending.append(next)
	return kept
