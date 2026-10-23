extends Node2D

signal food_delivered(amount: int)
signal materials_delivered(amount: int)
signal died(ant: Node2D)

enum Role { WORKER, EXPLORER, DEFENDER, GUARD_POST }

const NEAR_NEST_DISTANCE := 90.0
const FAR_FROM_NEST_DISTANCE := 450.0
const ADJACENT_DISTANCE := 45.0
const NEST_DEFENSE_RADIUS := 220.0
const REST_HEAL_PER_SECOND := 3.0
const FLEE_SPEED_BONUS := 1.3
const SEPARATION_RADIUS := 10.0
const SEPARATION_SPEED := 30.0

@export var movement_speed: float = 65.0
@export var carrying_capacity: int = 3

var role: Role = Role.WORKER
var colony_position: Vector2 = Vector2.ZERO
var simulation: Variant
var carried_food: int = 0
var carried_material: int = 0
var material_capacity: int = 0
var guard_post_position: Vector2 = Vector2.INF
var is_selected: bool = false
var max_health: float = 30.0
var health: float = -1.0
var attack_damage: float = 2.0
var damage_resistance: float = 0.0
var detection_range: float = 150.0

var _target_position: Vector2 = Vector2.INF
var _path := PackedVector2Array()
var _path_index: int = 0
var _path_target: Vector2 = Vector2.INF
var _sprite: AnimatedSprite2D
var _current_action: String = ""
var _move_order: Vector2 = Vector2.INF
var _attack_cooldown := 0.0
var _debug_refresh_timer := 0.0
var _rule_debug: Dictionary = {}
var _speed_boost := 1.0
var _gather_is_food := true
var _action_seconds := 0.0
var _personal_offset := Vector2.ZERO
var deliveries: int = 0
var harvests: int = 0

func _ready() -> void:
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite:
		_sprite.play("default")
	# A stable per-ant offset so ants heading to the same target spread out
	# around it instead of stacking on the exact same pixel.
	var slot := float(get_instance_id() % 12)
	_personal_offset = Vector2.RIGHT.rotated(slot * 2.39996) * (5.0 + slot)
	_update_appearance()
	_apply_role_attributes()


func _process(delta: float) -> void:
	if simulation == null:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_debug_refresh_timer = maxf(0.0, _debug_refresh_timer - delta)
	var moved_from := global_position
	_process_behavior(delta)
	if global_position.distance_squared_to(moved_from) < 0.0001:
		_apply_separation(delta)


func _process_behavior(delta: float) -> void:
	if _move_order != Vector2.INF:
		if _move_toward(_move_order, delta):
			_move_order = Vector2.INF
			_target_position = Vector2.INF
			_path_target = Vector2.INF
	else:
		var context := _build_rule_context()
		var include_debug: bool = (is_selected or simulation.show_behavior_overlay) and _debug_refresh_timer <= 0.0
		var behavior: Dictionary = simulation.interpret_behavior(context, _behavior_profile(), include_debug)
		var action: String = behavior["action"]
		if include_debug:
			_rule_debug = behavior
			_debug_refresh_timer = 0.25
		if action != _current_action:
			_current_action = action
			_target_position = Vector2.INF
			_action_seconds = 0.0
		else:
			_action_seconds += delta

		match action:
			"gather_food":
				_gather_food(delta)
			"gather_material":
				_gather_material(delta)
			"return_to_nest":
				_return_to_colony(delta)
			"explore":
				_explore(delta)
			"patrol":
				_patrol(delta)
			"idle":
				_target_position = Vector2.INF
			"attack_bugs":
				_attack_nearest_enemy(delta)
			"build_structure":
				_build_structure(delta)
			"flee":
				_flee(delta)
			"rest":
				_rest(delta)
			"defend_nest":
				_defend_nest(delta)
			"gather_nearest":
				_gather_nearest(delta)
			"guard_nest":
				_patrol(delta, colony_position)


func set_role(new_role: Role) -> void:
	role = new_role
	_target_position = Vector2.INF
	_current_action = ""
	_apply_role_attributes()
	_update_appearance()


func _behavior_profile() -> String:
	match role:
		Role.EXPLORER:
			return "explorer"
		Role.DEFENDER:
			return "defender"
		Role.GUARD_POST:
			return "guard"
	return "worker"


func issue_move_order(destination: Vector2) -> void:
	_move_order = destination
	_target_position = Vector2.INF
	_path_target = Vector2.INF


func set_selected(selected: bool) -> void:
	is_selected = selected
	if selected:
		_debug_refresh_timer = 0.0
	queue_redraw()


func get_behavior_debug_info() -> Dictionary:
	var rule_line := -1
	var trace: Array = _rule_debug.get("trace", [])
	for entry: Dictionary in trace:
		if entry.get("matched", false):
			rule_line = int(entry.get("line", -1))
			break
	return {
		"role": _behavior_profile(),
		"action": _current_action,
		"manual_order": _move_order != Vector2.INF,
		"target": _move_order if _move_order != Vector2.INF else _target_position,
		"rule_line": rule_line,
		"trace": _rule_debug.get("trace", []),
	}


func refresh_behavior_debug() -> void:
	_debug_refresh_timer = 0.0
	if simulation != null and (is_selected or simulation.show_behavior_overlay):
		_rule_debug = simulation.interpret_behavior(_build_rule_context(), _behavior_profile(), true)
		_debug_refresh_timer = 0.25


func _build_rule_context() -> Dictionary:
	return {
		"carrying_full": carried_food >= carrying_capacity,
		"carrying_material_full": carried_material >= material_capacity and material_capacity > 0,
		"food_nearby": simulation.has_food_nearby(global_position, detection_range),
		"material_nearby": simulation.has_material_nearby(global_position, detection_range),
		"role_is_worker": role == Role.WORKER or role == Role.GUARD_POST,
		"role_is_explorer": role == Role.EXPLORER,
		"role_is_defender": role == Role.DEFENDER,
		"role_is_guard_post": role == Role.GUARD_POST,
		"enemy_nearby": simulation.has_enemy_nearby(global_position, detection_range),
		"construction_available": simulation.has_construction_available(),
		"injured": health < max_health * 0.5,
		"critical_health": health < max_health * 0.25,
		"damaged": health < max_health,
		"health": health,
		"deliveries": deliveries,
		"harvests": harvests,
		"action_seconds": _action_seconds,
		"carrying_food": carried_food > 0,
		"carrying_material": carried_material > 0,
		"carrying_any": carried_food > 0 or carried_material > 0,
		"near_nest": global_position.distance_to(colony_position) <= NEAR_NEST_DISTANCE,
		"far_from_nest": global_position.distance_to(colony_position) >= FAR_FROM_NEST_DISTANCE,
		"many_bugs_nearby": simulation.count_enemies_near(global_position, detection_range) >= 2,
		"bug_adjacent": simulation.has_enemy_nearby(global_position, ADJACENT_DISTANCE),
		"nest_under_attack": simulation.has_enemy_nearby(colony_position, NEST_DEFENSE_RADIUS),
		"colony_food_low": simulation.colony_food < simulation.queen_food_demand(),
		"queen_soon": simulation.queen_demand_timer <= simulation.QUEEN_WARNING_SECONDS,
		"colony_materials_low": simulation.colony_materials < simulation.LOW_MATERIALS,
		"food_storage_full": simulation.colony_food >= simulation.food_storage_capacity,
		"material_storage_full": simulation.colony_materials >= simulation.material_storage_capacity,
	}


func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount * (1.0 - damage_resistance))
	if health == 0.0:
		died.emit(self)
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	if is_selected:
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.25), 2.0)
	draw_rect(Rect2(-12.0, 20.0, 24.0, 3.0), Color(0.18, 0.12, 0.1))
	draw_rect(Rect2(-12.0, 20.0, 24.0 * health / max_health, 3.0), Color(0.35, 0.85, 0.35))


func _apply_role_attributes() -> void:
	match role:
		Role.WORKER:
			max_health = 30.0
			attack_damage = 2.0
			damage_resistance = 0.0
			detection_range = 150.0
			movement_speed = 65.0
			carrying_capacity = 3
			material_capacity = 3
		Role.EXPLORER:
			max_health = 24.0
			attack_damage = 1.5
			damage_resistance = 0.0
			detection_range = 300.0
			movement_speed = 88.0
			carrying_capacity = 2
			material_capacity = 1
		Role.DEFENDER:
			max_health = 45.0
			attack_damage = 5.0
			damage_resistance = 0.35
			detection_range = 190.0
			movement_speed = 58.0
			carrying_capacity = 1
			material_capacity = 0
		Role.GUARD_POST:
			max_health = 22.0
			attack_damage = 3.0
			damage_resistance = 0.2
			detection_range = 210.0
			movement_speed = 65.0
			carrying_capacity = 3
			material_capacity = 3
	health = max_health if health < 0.0 else minf(health, max_health)


func _attack_nearest_enemy(delta: float) -> void:
	var enemy: Node2D = simulation.find_nearest_enemy(global_position, detection_range)
	if enemy == null:
		_target_position = Vector2.INF
		return
	_attack_enemy(enemy, delta)


func _attack_enemy(enemy: Node2D, delta: float) -> void:
	if global_position.distance_to(enemy.global_position) > 20.0:
		_move_toward(enemy.global_position, delta)
	elif _attack_cooldown == 0.0:
		enemy.take_damage(attack_damage)
		_attack_cooldown = 1.0


func _build_structure(delta: float) -> void:
	var site_position: Vector2 = simulation.find_construction_target(global_position)
	if site_position == Vector2.INF:
		_target_position = Vector2.INF
		return
	if global_position.distance_to(site_position) > 20.0:
		_move_toward(site_position, delta)
	else:
		simulation.contribute_build_progress(site_position, delta)


func _gather_food(delta: float) -> void:
	if carried_food >= carrying_capacity:
		_return_to_colony(delta)
		return

	if _target_position == Vector2.INF:
		_target_position = simulation.find_food_target(global_position)
		if _target_position == Vector2.INF:
			if carried_food > 0 or carried_material > 0:
				_return_to_colony(delta)
			return

	if _move_toward(_target_position, delta):
		if simulation.harvest_at(_target_position):
			carried_food += 1
			harvests += 1
		_target_position = Vector2.INF


func _gather_material(delta: float) -> void:
	if material_capacity == 0:
		return
	if carried_material >= material_capacity:
		_return_to_colony(delta)
		return
	if _target_position == Vector2.INF:
		_target_position = simulation.find_material_target(global_position)
		if _target_position == Vector2.INF:
			if carried_material > 0 or carried_food > 0:
				_return_to_colony(delta)
			return
	if _move_toward(_target_position, delta):
		if simulation.harvest_material_at(_target_position):
			carried_material += 1
			harvests += 1
		_target_position = Vector2.INF


func _return_to_colony(delta: float) -> void:
	if _move_toward(colony_position, delta):
		if carried_food > 0 or carried_material > 0:
			deliveries += 1
		if carried_food > 0:
			food_delivered.emit(carried_food)
			carried_food = 0
		if carried_material > 0:
			materials_delivered.emit(carried_material)
			carried_material = 0
		_target_position = Vector2.INF


func _explore(delta: float) -> void:
	if _target_position == Vector2.INF or global_position.distance_to(_target_position) < 5.0:
		_target_position = simulation.random_exploration_target()
	if _move_toward(_target_position, delta):
		_target_position = Vector2.INF


func _patrol(delta: float, center_override: Vector2 = Vector2.INF) -> void:
	if _target_position == Vector2.INF or global_position.distance_to(_target_position) < 5.0:
		var patrol_center := center_override
		if patrol_center == Vector2.INF:
			patrol_center = colony_position if guard_post_position == Vector2.INF else guard_post_position
		_target_position = simulation.random_defense_target(patrol_center)
	if _move_toward(_target_position, delta):
		_target_position = Vector2.INF


func _flee(delta: float) -> void:
	if global_position.distance_to(colony_position) < 30.0:
		_target_position = Vector2.INF
		return
	_speed_boost = FLEE_SPEED_BONUS
	_move_toward(colony_position, delta)
	_speed_boost = 1.0


func _rest(delta: float) -> void:
	if global_position.distance_to(colony_position) > 30.0:
		_move_toward(colony_position, delta)
		return
	_target_position = Vector2.INF
	if health < max_health:
		health = minf(max_health, health + REST_HEAL_PER_SECOND * delta)
		queue_redraw()


func _defend_nest(delta: float) -> void:
	var enemy: Node2D = simulation.find_nearest_enemy(colony_position, NEST_DEFENSE_RADIUS)
	if enemy == null:
		_patrol(delta, colony_position)
		return
	_attack_enemy(enemy, delta)


func _gather_nearest(delta: float) -> void:
	var food_full := carried_food >= carrying_capacity
	var material_full := carried_material >= material_capacity
	if food_full and material_full:
		_return_to_colony(delta)
		return
	if _target_position == Vector2.INF:
		var food_target: Vector2 = Vector2.INF if food_full else simulation.find_food_target(global_position)
		var material_target: Vector2 = Vector2.INF if material_full else simulation.find_material_target(global_position)
		var food_distance: float = INF if food_target == Vector2.INF else global_position.distance_squared_to(food_target)
		var material_distance: float = INF if material_target == Vector2.INF else global_position.distance_squared_to(material_target)
		if food_target == Vector2.INF and material_target == Vector2.INF:
			if carried_food > 0 or carried_material > 0:
				_return_to_colony(delta)
			return
		_gather_is_food = food_distance <= material_distance
		_target_position = food_target if _gather_is_food else material_target
	if _move_toward(_target_position, delta):
		if _gather_is_food:
			if simulation.harvest_at(_target_position):
				carried_food += 1
				harvests += 1
		elif simulation.harvest_material_at(_target_position):
			carried_material += 1
			harvests += 1
		_target_position = Vector2.INF


func _move_toward(target: Vector2, delta: float) -> bool:
	_target_position = target
	# Walk to a personal spot next to the target rather than the exact target.
	var arrival_point := target + _personal_offset
	if _path_target == Vector2.INF or _path_target.distance_to(arrival_point) > 16.0:
		_path_target = arrival_point
		_path = simulation.find_path(global_position, arrival_point)
		_path_index = 0

	var step: float = movement_speed * _speed_boost * simulation.movement_speed_multiplier(global_position) * delta
	while _path_index < _path.size():
		var waypoint := _path[_path_index]
		var offset := waypoint - global_position
		if offset.length() > step:
			global_position += offset.normalized() * step
			if _sprite and absf(offset.x) > 0.5:
				_sprite.flip_h = offset.x < 0.0
			return false
		global_position = waypoint
		step -= offset.length()
		_path_index += 1

	# Reached the end of the path, or no path exists (treated as done so a new target is chosen).
	_path_target = Vector2.INF
	return true


# Gently pushes this ant away from ants that are too close, so ants arriving at the
# same target spread out instead of stacking on one spot and fighting for it.
func _apply_separation(delta: float) -> void:
	var push := Vector2.ZERO
	var neighbors: int = 0
	for other: Node2D in simulation.ants_near(global_position, SEPARATION_RADIUS, self):
		var offset := global_position - other.global_position
		var distance := offset.length()
		if distance < 0.01:
			# Perfectly stacked: pick a stable but different direction per ant.
			offset = Vector2.RIGHT.rotated(TAU * float(get_instance_id() % 8) / 8.0)
			distance = 0.01
		push += offset.normalized() * (1.0 - distance / SEPARATION_RADIUS)
		neighbors += 1
	if neighbors == 0:
		return
	# Only accept the push if it lands on walkable ground. Never snap the ant
	# to a tile center here; that would undo its movement and trap it.
	var pushed := global_position + push * SEPARATION_SPEED * delta
	if simulation.is_open_ground(pushed):
		global_position = pushed


func _update_appearance() -> void:
	if not _sprite:
		return

	match role:
		Role.WORKER:
			_sprite.modulate = Color.WHITE
		Role.EXPLORER:
			_sprite.modulate = Color(0.55, 0.9, 1.0)
		Role.DEFENDER:
			_sprite.modulate = Color(1.0, 0.65, 0.45)
		Role.GUARD_POST:
			_sprite.modulate = Color(0.95, 0.8, 0.35)
