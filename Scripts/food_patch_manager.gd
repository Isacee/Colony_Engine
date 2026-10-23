extends RefCounted
## Generates and manages harvestable food patches.

signal patches_changed

const WorldMap = preload("res://Scripts/map/world_map.gd")

const STARTING_PATCHES := 30
const STARTING_MATERIAL_PATCHES := 24
const MIN_DISTANCE := 150.0
const MAX_DISTANCE := 1200.0

var patches: Array[Dictionary] = []
var material_patches: Array[Dictionary] = []
var _world_map: WorldMap
var _random: RandomNumberGenerator


func _init(world_map: WorldMap, random: RandomNumberGenerator) -> void:
	_world_map = world_map
	_random = random


func populate(colony_position: Vector2) -> void:
	patches.clear()
	material_patches.clear()
	for index in range(STARTING_PATCHES):
		var position: Vector2 = _world_map.random_open_position(colony_position, MIN_DISTANCE, MAX_DISTANCE)
		patches.append({"position": position, "amount": _random.randi_range(3, 7)})
	for index in range(STARTING_MATERIAL_PATCHES):
		var position: Vector2 = _world_map.random_open_position(colony_position, MIN_DISTANCE, MAX_DISTANCE)
		material_patches.append({"position": position, "amount": _random.randi_range(2, 5)})
	patches_changed.emit()


func replenish(colony_position: Vector2, food_count: int, material_count: int) -> void:
	for index in range(food_count):
		var position: Vector2 = _world_map.random_open_position(colony_position, MIN_DISTANCE, MAX_DISTANCE)
		patches.append({"position": position, "amount": _random.randi_range(3, 7)})
	for index in range(material_count):
		var position: Vector2 = _world_map.random_open_position(colony_position, MIN_DISTANCE, MAX_DISTANCE)
		material_patches.append({"position": position, "amount": _random.randi_range(2, 5)})
	patches_changed.emit()


func restore(saved_patches: Array, saved_material_patches: Array = []) -> void:
	patches.clear()
	for saved_patch in saved_patches:
		var coordinates: Array = saved_patch["position"]
		patches.append({
			"position": Vector2(float(coordinates[0]), float(coordinates[1])),
			"amount": int(saved_patch["amount"]),
		})
	material_patches.clear()
	for saved_patch in saved_material_patches:
		var coordinates: Array = saved_patch["position"]
		material_patches.append({
			"position": Vector2(float(coordinates[0]), float(coordinates[1])),
			"amount": int(saved_patch["amount"]),
		})
	patches_changed.emit()


func add_food_patch(position: Vector2, amount: int) -> void:
	if amount > 0:
		patches.append({"position": position, "amount": amount})
		patches_changed.emit()


func find_target(from_position: Vector2) -> Vector2:
	return _find_target_in(patches, from_position)


func find_material_target(from_position: Vector2) -> Vector2:
	return _find_target_in(material_patches, from_position)


func _find_target_in(source: Array[Dictionary], from_position: Vector2) -> Vector2:
	var nearest_position := Vector2.INF
	var nearest_distance := INF
	for patch in source:
		if patch["amount"] <= 0:
			continue
		var distance: float = from_position.distance_squared_to(patch["position"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_position = patch["position"]
	return nearest_position


func has_food_nearby(from_position: Vector2, radius: float) -> bool:
	var target := find_target(from_position)
	return target != Vector2.INF and from_position.distance_squared_to(target) <= radius * radius


func harvest_at(target_position: Vector2) -> bool:
	return _harvest_from(patches, target_position)


func harvest_material_at(target_position: Vector2) -> bool:
	return _harvest_from(material_patches, target_position)


func _harvest_from(source: Array[Dictionary], target_position: Vector2) -> bool:
	for index in range(source.size()):
		var patch: Dictionary = source[index]
		if patch["amount"] > 0 and patch["position"].distance_to(target_position) < 1.0:
			patch["amount"] -= 1
			source[index] = patch
			patches_changed.emit()
			return true
	return false
