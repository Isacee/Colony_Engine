extends Node2D
## Coordinates the colony simulation, workers, world, and in-game interface.

const WORKER_SCENE: PackedScene = preload("res://Scenes/NPCs/ant_worker.tscn")
const AntWorker = preload("res://Scripts/ant_worker.gd")
const RoamingBug = preload("res://Scripts/roaming_bug.gd")
const ColonyRules = preload("res://Scripts/colony_rules.gd")
const RuleInterpreter = preload("res://Scripts/colony_rule_interpreter.gd")
const FoodPatchManager = preload("res://Scripts/food_patch_manager.gd")
const SaveSystem = preload("res://Scripts/save_system.gd")
const WorldMap = preload("res://Scripts/map/world_map.gd")
const FOOD_TEXTURE: Texture2D = preload("res://Assets/Sprout Lands - Sprites - Basic pack/Objects/Basic_Plants.png")
const MENU_SCENE := "res://Scenes/UI/main_menu.tscn"
const EXPLORE_MAX_DISTANCE := 1200.0
const QUEEN_DEMAND_INTERVAL := 300.0
const QUEEN_WARNING_SECONDS := 60.0
const GAME_OVER_SCENE := "res://Scenes/UI/game_over.tscn"
const BUG_SAFE_NEST_DISTANCE := 450.0
const BUG_SAFE_STRUCTURE_DISTANCE := 250.0
const BUG_SAFE_ANT_DISTANCE := 250.0
const REPLENISH_FOOD_PATCHES := 15
const REPLENISH_MATERIAL_PATCHES := 12
const QUEEN_URGENT_WARNING_SECONDS := 30.0
const MAX_PREVIEW_TRACE_ROWS := 4
const LOW_MATERIALS := 25
const STRUCTURE_COSTS := {
	"hatchery": {"food": 30, "materials": 20, "build_time": 30.0},
	"food_storage": {"food": 15, "materials": 20, "build_time": 20.0},
	"material_storage": {"food": 10, "materials": 15, "build_time": 20.0},
	"guard_post": {"food": 20, "materials": 25, "build_time": 25.0},
	"tunnel": {"food": 5, "materials": 10, "build_time": 12.0},
	"farm": {"food": 20, "materials": 25, "build_time": 25.0},
	"workshop": {"food": 25, "materials": 15, "build_time": 25.0},
}
const STRUCTURE_INFO := {
	"hatchery": ["Hatchery", "Adds 5 to the ant limit."],
	"food_storage": ["Food Storage", "Adds 100 food capacity."],
	"material_storage": ["Material Storage", "Adds 100 material capacity."],
	"guard_post": ["Guard Post", "Lets up to 3 workers become guards."],
	"tunnel": ["Tunnel", "Two tunnels form a lane that makes ants 1.75x faster."],
	"farm": ["Farm", "Grows 1 food every 30 seconds, no ant needed."],
	"workshop": ["Workshop", "Makes 1 material every 30 seconds, no ant needed."],
}
const PRODUCTION_INTERVAL := 30.0
const PRODUCER_LIMIT := 4
const STRUCTURE_PICK_RADIUS := 26.0

var colony_position: Vector2
var colony_food: int = 0
var colony_materials: int = 20
var food_storage_capacity: int = 100
var material_storage_capacity: int = 100
var difficulty := "normal"
var queen_cycle := 0
var queen_demand_timer := QUEEN_DEMAND_INTERVAL
var queen_demand_base := 10
var queen_demand_increment := 5
var _bug_spawn_interval := 15.0
var _bug_limit := 14
var _starting_food := 40
var _starting_materials := 20
var _initial_bug_count := 3
var _game_over := false
var ants: Array = []
var bugs: Array[Node2D] = []
var structures: Array[Dictionary] = []
var _pending_structure_type := ""
var _selected_ants: Array[AntWorker] = []
var _selected_structure_index := -1
var _production_timer := PRODUCTION_INTERVAL
var _control_groups: Dictionary = {}
var _selection_drag_start := Vector2.ZERO
var _selection_drag_active := false
var _selection_dragging := false
var _bug_spawn_timer := 15.0
var _queen_warning_level := 0
var simulation_running: bool = true
var show_behavior_overlay: bool = false
var _rules: ColonyRules = ColonyRules.new()
var _food_manager: FoodPatchManager
var _status_timer: float = 0.0
var _random := RandomNumberGenerator.new()
var _world_random := RandomNumberGenerator.new()
var _world_seed: int
var _world_map: WorldMap
@onready var _camera: Camera2D = $Camera
@onready var _hud: CanvasLayer = $Hud


func _ready() -> void:
	_random.randomize()
	difficulty = str(get_tree().get_meta("new_game_difficulty", "normal"))
	get_tree().remove_meta("new_game_difficulty")
	_world_seed = _random.randi()
	_world_random.seed = _world_seed
	_world_map = WorldMap.new($Water, $Ground, $Hills, _world_random)
	_camera.view_changed.connect(_world_map.update_view)
	_food_manager = FoodPatchManager.new(_world_map, _random)
	_food_manager.patches_changed.connect(queue_redraw)
	_hud.rules_editor.reset_sources(_rules.sources)
	_hud.rules_editor.apply_requested.connect(_on_rules_apply_requested)
	_hud.rules_editor.example_requested.connect(_on_rules_example_requested)
	_hud.rules_editor.preview_requested.connect(_on_rules_preview_requested)
	_hud.rules_editor.profile_changed.connect(_on_rules_profile_changed)
	_hud.save_slots.action_requested.connect(_on_save_slot_action)
	_hud.spawn_requested.connect(_spawn_worker)
	_hud.pause_toggled.connect(_toggle_simulation)
	_hud.reset_requested.connect(_reset_colony)
	_hud.menu_requested.connect(_return_to_menu)
	_hud.selection_requested.connect(_select_scope)
	_hud.build_requested.connect(_begin_structure_placement)
	_hud.guard_assignment_requested.connect(_assign_selected_guard_roles)
	_hud.behavior_overlay_toggled.connect(_set_behavior_overlay)

	if get_tree().has_meta("pending_save_data"):
		var save_data: Variant = get_tree().get_meta("pending_save_data")
		get_tree().remove_meta("pending_save_data")
		if save_data is Dictionary and _restore_game(save_data):
			return
	_start_new_colony()


func _process(delta: float) -> void:
	if not _game_over:
		queen_demand_timer -= delta
		_update_queen_warning()
		if queen_demand_timer <= 0.0:
			_check_queen_demand()
	if not _game_over:
		_production_timer -= delta
		if _production_timer <= 0.0:
			_production_timer += PRODUCTION_INTERVAL
			_run_production()
	_bug_spawn_timer -= delta
	if _bug_spawn_timer <= 0.0:
		_spawn_bug()
		_bug_spawn_timer = _bug_spawn_interval
	_status_timer += delta
	if _status_timer >= 0.25:
		_status_timer = 0.0
		_update_status()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_selection_drag_start = get_global_mouse_position()
			_selection_drag_active = true
			_selection_dragging = false
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _selection_drag_active:
			if not _pending_structure_type.is_empty():
				_place_structure(get_global_mouse_position())
				_selection_drag_active = false
				_selection_dragging = false
			else:
				_finish_selection(event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_move_order(get_global_mouse_position())
	elif event is InputEventMouseMotion and _selection_drag_active:
		if _selection_drag_start.distance_to(get_global_mouse_position()) > 12.0:
			_selection_dragging = true
			queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and event.keycode == KEY_ESCAPE and not _pending_structure_type.is_empty():
		_pending_structure_type = ""
		_selection_drag_active = false
		_selection_dragging = false
		_hud.show_message("Structure placement cancelled.")
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is CodeEdit or focus_owner is LineEdit or focus_owner is TextEdit:
		return
	if not event.pressed or event.echo or event.keycode < KEY_1 or event.keycode > KEY_9:
		return
	var group_number: int = event.keycode - KEY_0
	if event.ctrl_pressed:
		_control_groups[group_number] = _selected_ants.duplicate()
		_hud.show_message("Saved selection to group %d." % group_number)
	else:
		_select_group(group_number, event.shift_pressed)


func find_food_target(from_position: Vector2) -> Vector2:
	return _food_manager.find_target(from_position)


func has_food_nearby(from_position: Vector2, radius: float) -> bool:
	return _food_manager.has_food_nearby(from_position, radius)


func has_material_nearby(from_position: Vector2, radius: float) -> bool:
	var target := _food_manager.find_material_target(from_position)
	return target != Vector2.INF and from_position.distance_squared_to(target) <= radius * radius


func find_material_target(from_position: Vector2) -> Vector2:
	return _food_manager.find_material_target(from_position)


func harvest_material_at(target_position: Vector2) -> bool:
	return _food_manager.harvest_material_at(target_position)


func has_enemy_nearby(from_position: Vector2, radius: float) -> bool:
	return find_nearest_enemy(from_position, radius) != null


func count_enemies_near(from_position: Vector2, radius: float) -> int:
	var count := 0
	var limit := radius * radius
	for bug in bugs:
		if is_instance_valid(bug) and from_position.distance_squared_to(bug.global_position) <= limit:
			count += 1
	return count


func find_nearest_enemy(from_position: Vector2, radius: float) -> Node2D:
	var nearest: Node2D
	var nearest_distance := radius * radius
	for bug in bugs:
		if not is_instance_valid(bug):
			continue
		var distance := from_position.distance_squared_to(bug.global_position)
		if distance <= nearest_distance:
			nearest = bug
			nearest_distance = distance
	return nearest


func find_nearest_ant(from_position: Vector2, radius: float) -> AntWorker:
	var nearest: AntWorker
	var nearest_distance := radius * radius
	for ant in ants:
		if not is_instance_valid(ant):
			continue
		var distance: float = from_position.distance_squared_to(ant.global_position)
		if distance <= nearest_distance:
			nearest = ant
			nearest_distance = distance
	return nearest


func ants_near(from_position: Vector2, radius: float, exclude: AntWorker = null) -> Array[AntWorker]:
	var found: Array[AntWorker] = []
	var limit := radius * radius
	for ant in ants:
		if ant == exclude or not is_instance_valid(ant):
			continue
		if from_position.distance_squared_to(ant.global_position) <= limit:
			found.append(ant)
	return found


func interpret_behavior(context: Dictionary, profile: String, include_debug: bool = false) -> Dictionary:
	if include_debug:
		var explanation := _rules.explain(context, profile)
		explanation["profile"] = profile
		return explanation
	return {"action": _rules.interpret(context, profile)}


func _on_rules_preview_requested(profile: String, rules_text: String, scenario: String) -> void:
	var interpreter = RuleInterpreter.new()
	var compile_result: Dictionary = interpreter.compile(rules_text)
	if not compile_result["ok"]:
		_hud.rules_editor.show_preview_result(
			str(compile_result["message"]),
			false,
			int(compile_result.get("line", -1)),
			int(compile_result.get("column", -1)),
			int(compile_result.get("length", 1))
		)
		return

	var preview_context := _preview_context(profile, scenario)
	var explanation: Dictionary = interpreter.explain(preview_context)
	var report := "%s script / %s -> %s\n" % [
		profile.capitalize(),
		_preview_scenario_label(scenario),
		explanation["action"],
	]
	var trace: Array = explanation["trace"]
	if trace.is_empty():
		report += "No rules matched; the ant would idle."
	else:
		var rows_to_show: int = mini(trace.size(), MAX_PREVIEW_TRACE_ROWS)
		var last_index: int = trace.size() - 1
		var has_match: bool = bool(trace[last_index]["matched"])
		for index in range(rows_to_show):
			var trace_index := index
			if has_match and trace.size() > MAX_PREVIEW_TRACE_ROWS and index == rows_to_show - 1:
				trace_index = last_index
			var entry: Dictionary = trace[trace_index]
			var status: String = "matched" if entry["matched"] else "did not match"
			var checks: Array = entry["checks"]
			report += "Line %d: %s (%s)\n" % [
				entry["line"],
				status,
				", ".join(PackedStringArray(checks)),
			]
		if trace.size() > rows_to_show:
			report += "%d additional rule checks omitted.\n" % (trace.size() - rows_to_show)
	_hud.rules_editor.show_preview_result(report.strip_edges(), true)


func _preview_context(profile: String, scenario: String) -> Dictionary:
	var context := {}
	for condition in RuleInterpreter.CONDITIONS:
		context[condition] = false
	for counter in RuleInterpreter.NUMERIC_CONDITIONS:
		context[counter] = 0.0
	context["health"] = 30.0
	context["role_is_worker"] = profile == "worker" or profile == "guard"
	context["role_is_explorer"] = profile == "explorer"
	context["role_is_defender"] = profile == "defender"
	context["role_is_guard_post"] = profile == "guard"
	match scenario:
		"resources_nearby":
			context["food_nearby"] = true
			context["material_nearby"] = true
		"carrying_full":
			context["carrying_full"] = true
			context["carrying_food"] = true
			context["carrying_any"] = true
		"bug_nearby":
			context["enemy_nearby"] = true
		"building_available":
			context["construction_available"] = true
		"injured":
			context["injured"] = true
			context["critical_health"] = true
			context["damaged"] = true
			context["health"] = 6.0
			context["enemy_nearby"] = true
			context["bug_adjacent"] = true
		"bug_swarm":
			context["enemy_nearby"] = true
			context["many_bugs_nearby"] = true
			context["far_from_nest"] = true
		"nest_attack":
			context["nest_under_attack"] = true
			context["near_nest"] = true
		"colony_hungry":
			context["colony_food_low"] = true
			context["queen_soon"] = true
			context["colony_materials_low"] = true
	return context


func _preview_scenario_label(scenario: String) -> String:
	match scenario:
		"resources_nearby":
			return "food and materials nearby"
		"carrying_full":
			return "carrying food capacity"
		"bug_nearby":
			return "bug nearby"
		"building_available":
			return "construction available"
		"injured":
			return "badly hurt with a bug adjacent"
		"bug_swarm":
			return "several bugs far from the nest"
		"nest_attack":
			return "bugs attacking the nest"
		"colony_hungry":
			return "colony low on food, queen soon"
		"quiet":
			return "no special conditions"
	return "Sample situation"


func _set_behavior_overlay(enabled: bool) -> void:
	show_behavior_overlay = enabled
	for ant in ants:
		if is_instance_valid(ant):
			ant.refresh_behavior_debug()
	queue_redraw()


func harvest_at(target_position: Vector2) -> bool:
	return _food_manager.harvest_at(target_position)


func random_exploration_target() -> Vector2:
	return _world_map.random_open_position(colony_position, 0.0, EXPLORE_MAX_DISTANCE)


func random_defense_target(center_position: Vector2 = Vector2.INF) -> Vector2:
	var center := colony_position if center_position == Vector2.INF else center_position
	return _world_map.random_open_position(center, 45.0, 85.0)


func clamp_to_playable(world_position: Vector2) -> Vector2:
	return _world_map.clamp_to_playable(world_position)


func is_open_ground(world_position: Vector2) -> bool:
	return _world_map.is_open_ground(world_position)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return _world_map.find_path(from, to)


func _spawn_worker(role: int) -> void:
	if ants.size() >= 5 + _hatchery_count() * 5:
		_hud.show_message("Build a hatchery to increase ant capacity.")
		return
	var spawn_position := colony_position + Vector2(_random.randf_range(-18.0, 18.0), _random.randf_range(-12.0, 12.0))
	_create_worker(role, spawn_position, 0)


func _create_worker(role: int, position: Vector2, carried_food: int) -> void:
	var worker: AntWorker = WORKER_SCENE.instantiate()
	worker.role = role
	worker.simulation = self
	worker.colony_position = colony_position
	worker.global_position = position
	worker.carried_food = carried_food
	worker.food_delivered.connect(_on_food_delivered)
	worker.materials_delivered.connect(_on_materials_delivered)
	worker.died.connect(_on_ant_died)
	add_child(worker)
	worker.add_to_group("ants")
	ants.append(worker)
	_update_status()


func _spawn_bug() -> void:
	bugs = bugs.filter(func(bug): return is_instance_valid(bug))
	if bugs.size() >= _bug_limit:
		return
	var spawn_position := Vector2.ZERO
	var found := false
	for attempt in 30:
		var candidate: Vector2 = _world_map.random_open_position(colony_position, BUG_SAFE_NEST_DISTANCE, 1400.0)
		if candidate != colony_position and _is_safe_bug_spawn(candidate):
			spawn_position = candidate
			found = true
			break
	if not found:
		return
	var bug: Variant = RoamingBug.new()
	bug.simulation = self
	bug.max_health = 24.0 * _bug_health_multiplier()
	bug.health = bug.max_health
	bug.attack_damage = 5.0 * _bug_health_multiplier()
	bug.global_position = spawn_position
	bug.defeated.connect(_on_bug_defeated)
	add_child(bug)
	bugs.append(bug)


func _is_safe_bug_spawn(point: Vector2) -> bool:
	if point.distance_to(colony_position) < BUG_SAFE_NEST_DISTANCE:
		return false
	for structure in structures:
		if point.distance_to(structure["position"]) < BUG_SAFE_STRUCTURE_DISTANCE:
			return false
	for ant in ants:
		if is_instance_valid(ant) and point.distance_to(ant.global_position) < BUG_SAFE_ANT_DISTANCE:
			return false
	return true


func _on_ant_died(ant: Node2D) -> void:
	ants.erase(ant)
	_selected_ants.erase(ant)
	_update_selection()
	_update_status()


func _on_bug_defeated(position: Vector2, food_dropped: int) -> void:
	bugs = bugs.filter(func(bug): return is_instance_valid(bug))
	if food_dropped > 0:
		_food_manager.add_food_patch(position, food_dropped)
		_hud.show_message("A bug dropped %d food." % food_dropped)


func _finish_selection(add_to_selection: bool) -> void:
	_selection_drag_active = false
	if _selection_dragging:
		var current := get_global_mouse_position()
		var top_left := _selection_drag_start.min(current)
		var rect := Rect2(top_left, _selection_drag_start.max(current) - top_left)
		var found: Array[AntWorker] = []
		for ant in ants:
			if is_instance_valid(ant) and rect.has_point(ant.global_position):
				found.append(ant)
		if not add_to_selection:
			_selected_ants.clear()
		for ant in found:
			if not _selected_ants.has(ant):
				_selected_ants.append(ant)
	else:
		var nearest: AntWorker
		var nearest_distance := 28.0
		var mouse_position := get_global_mouse_position()
		for ant in ants:
			if not is_instance_valid(ant):
				continue
			var distance: float = mouse_position.distance_to(ant.global_position)
			if distance < nearest_distance:
				nearest = ant
				nearest_distance = distance
		if not add_to_selection:
			_selected_ants.clear()
		if nearest != null:
			_selected_structure_index = -1
			if add_to_selection and _selected_ants.has(nearest):
				_selected_ants.erase(nearest)
			elif not _selected_ants.has(nearest):
				_selected_ants.append(nearest)
		elif not add_to_selection:
			_selected_structure_index = _structure_index_at(mouse_position)
	if _selection_dragging:
		_selected_structure_index = -1
	_selection_dragging = false
	_update_selection()
	queue_redraw()


func _select_group(group_number: int, add_to_selection: bool) -> void:
	if not _control_groups.has(group_number):
		return
	if not add_to_selection:
		_selected_ants.clear()
	for ant in _control_groups[group_number]:
		if is_instance_valid(ant) and not _selected_ants.has(ant):
			_selected_ants.append(ant)
	_update_selection()


func _select_scope(scope: String) -> void:
	_selected_ants.clear()
	for ant in ants:
		if not is_instance_valid(ant):
			continue
		if scope == "all" or ant.role == int(scope):
			_selected_ants.append(ant)
	_update_selection()


func _issue_move_order(destination: Vector2) -> void:
	if _selected_ants.is_empty():
		return
	var selected_count := _selected_ants.size()
	for index in range(selected_count):
		var ant: AntWorker = _selected_ants[index]
		if is_instance_valid(ant):
			var angle := TAU * float(index) / float(selected_count)
			var radius := 24.0 + minf(float(selected_count), 8.0) * 4.0
			var offset := Vector2.ZERO if selected_count == 1 else Vector2.RIGHT.rotated(angle) * radius
			ant.issue_move_order(_world_map.clamp_to_playable(destination + offset))


func _structure_index_at(point: Vector2) -> int:
	var best := -1
	var best_distance := STRUCTURE_PICK_RADIUS
	for index in range(structures.size()):
		var distance: float = point.distance_to(structures[index]["position"])
		if distance < best_distance:
			best = index
			best_distance = distance
	return best


func _structure_summary(structure: Dictionary) -> Array[String]:
	var info: Array = STRUCTURE_INFO[structure["type"]]
	var status := "Complete"
	if not structure["complete"]:
		status = "Under construction %d%% (workers build it when rules allow)" % int(100.0 * structure["progress"] / structure["build_time"])
	var details := "%s  |  %s" % [info[0], status]
	var actions: String = info[1]
	if structure["complete"] and (structure["type"] == "farm" or structure["type"] == "workshop"):
		actions += " Next harvest in %d s." % int(ceil(_production_timer))
	return [details, actions]


func _run_production() -> void:
	var food_gain := 0
	var material_gain := 0
	for structure in structures:
		if not structure["complete"]:
			continue
		if structure["type"] == "farm":
			food_gain += 1
		elif structure["type"] == "workshop":
			material_gain += 1
	if food_gain > 0:
		colony_food = mini(food_storage_capacity, colony_food + food_gain)
	if material_gain > 0:
		colony_materials = mini(material_storage_capacity, colony_materials + material_gain)
	if food_gain > 0 or material_gain > 0:
		_update_status()


func _producer_count(structure_type: String) -> int:
	var count := 0
	for structure in structures:
		if structure["type"] == structure_type:
			count += 1
	return count


func _update_selection() -> void:
	if not _selected_ants.is_empty():
		_selected_structure_index = -1
	for ant in ants:
		if is_instance_valid(ant):
			ant.set_selected(_selected_ants.has(ant))
	_refresh_selection_summary()


func _refresh_selection_summary() -> void:
	if _selected_structure_index >= 0 and _selected_structure_index < structures.size() and _selected_ants.is_empty():
		var summary := _structure_summary(structures[_selected_structure_index])
		_hud.set_selection_summary(1, summary[0], summary[1])
		return
	_refresh_ant_selection_summary()


func _refresh_ant_selection_summary() -> void:
	var valid_selection: Array[AntWorker] = []
	for ant in _selected_ants:
		if is_instance_valid(ant):
			valid_selection.append(ant)
	var selected_workers := false
	var selected_guards := false
	for ant in valid_selection:
		selected_workers = selected_workers or ant.role == AntWorker.Role.WORKER
		selected_guards = selected_guards or ant.role == AntWorker.Role.GUARD_POST
	var completed_guard_posts := 0
	for structure in structures:
		if structure["type"] == "guard_post" and structure["complete"]:
			completed_guard_posts += 1
	var current_guard_count := 0
	for ant in ants:
		if is_instance_valid(ant) and ant.role == AntWorker.Role.GUARD_POST:
			current_guard_count += 1
	var can_assign_guard := (
		selected_workers
		and completed_guard_posts > 0
		and current_guard_count < completed_guard_posts * 3
	)
	if valid_selection.size() == 1:
		var ant := valid_selection[0]
		var role_name: String = ["Worker", "Explorer", "Defender", "Guard"][ant.role]
		var details := "%s  HP %.0f/%.0f  SPD %.0f  ATK %.1f  RES %.0f%%  DET %.0f  CARRY %dF/%dM" % [
			role_name, ant.health, ant.max_health, ant.movement_speed, ant.attack_damage,
			ant.damage_resistance * 100.0, ant.detection_range, ant.carrying_capacity, ant.material_capacity,
		]
		var behavior := ant.get_behavior_debug_info()
		var actions := _format_ant_behavior(behavior)
		_hud.set_selection_summary(1, details, actions, selected_workers, can_assign_guard, selected_guards)
	else:
		var role_counts := [0, 0, 0, 0]
		var action_counts: Dictionary = {}
		for ant in valid_selection:
			role_counts[ant.role] += 1
			var action_name := _display_action(ant.get_behavior_debug_info())
			action_counts[action_name] = int(action_counts.get(action_name, 0)) + 1
		var role_summary := "Roles: Workers %d, Explorers %d, Defenders %d, Guards %d" % role_counts
		var action_names: Array[String] = []
		for action_name in action_counts:
			action_names.append("%d %s" % [action_counts[action_name], action_name])
		_hud.set_selection_summary(
			valid_selection.size(),
			role_summary,
			"Actions: " + (", ".join(PackedStringArray(action_names)) if not action_names.is_empty() else "No active actions"),
			selected_workers,
			can_assign_guard,
			selected_guards
		)


func _format_ant_behavior(behavior: Dictionary) -> String:
	var action_name := _display_action(behavior)
	if behavior.get("manual_order", false):
		return "Current action: %s (manual order; rules resume on arrival)" % action_name

	var trace: Array = behavior.get("trace", [])
	if trace.is_empty():
		return "Current action: %s" % action_name
	var explanation_parts: Array[String] = []
	for entry in trace:
		var checks: Array = entry["checks"]
		explanation_parts.append(
			"Rule %d (%s): %s" % [
				entry["line"],
				"matched" if entry["matched"] else "did not match",
				", ".join(PackedStringArray(checks)),
			]
		)
	var explanation := "; ".join(explanation_parts)
	if explanation.length() > 220:
		explanation = explanation.substr(0, 217) + "..."
	return "Current action: %s\n%s" % [action_name, explanation]


func _display_action(behavior: Dictionary) -> String:
	if behavior.get("manual_order", false):
		return "Manual move"
	var action: String = behavior.get("action", "idle")
	match action:
		"gather_food":
			return "Gathering food"
		"gather_material":
			return "Gathering materials"
		"return_to_nest":
			return "Returning"
		"explore":
			return "Exploring"
		"patrol":
			return "Patrolling"
		"build_structure":
			return "Building"
		"flee":
			return "Fleeing"
		"rest":
			return "Resting"
		"defend_nest":
			return "Defending nest"
		"gather_nearest":
			return "Foraging"
		"guard_nest":
			return "Guarding nest"
		"attack_bugs":
			return "Fighting"
		_:
			return "Idle"


func _start_new_colony() -> void:
	_pending_structure_type = ""
	_selection_drag_active = false
	_selection_dragging = false
	_generate_world()
	_apply_difficulty()
	structures.clear()
	_selected_structure_index = -1
	_production_timer = PRODUCTION_INTERVAL
	colony_food = _starting_food
	colony_materials = _starting_materials
	food_storage_capacity = 100
	material_storage_capacity = 100
	queen_cycle = 0
	queen_demand_timer = QUEEN_DEMAND_INTERVAL
	_queen_warning_level = 0
	_game_over = false
	_food_manager.populate(colony_position)
	_spawn_worker(AntWorker.Role.WORKER)
	_spawn_worker(AntWorker.Role.WORKER)
	_spawn_worker(AntWorker.Role.WORKER)
	_spawn_worker(AntWorker.Role.EXPLORER)
	_spawn_worker(AntWorker.Role.DEFENDER)
	for index in _initial_bug_count:
		_spawn_bug()
	_bug_spawn_timer = _bug_spawn_interval
	_hud.show_message("Goal: feed the queen on time. Press ? Help for a quick start.")


func _apply_difficulty() -> void:
	match difficulty:
		"easy":
			queen_demand_base = 6
			queen_demand_increment = 3
			_bug_spawn_interval = 25.0
			_bug_limit = 8
			_starting_food = 70
			_starting_materials = 30
			_initial_bug_count = 2
		"hard":
			queen_demand_base = 15
			queen_demand_increment = 8
			_bug_spawn_interval = 10.0
			_bug_limit = 20
			_starting_food = 25
			_starting_materials = 12
			_initial_bug_count = 4
		_:
			difficulty = "normal"
			queen_demand_base = 10
			queen_demand_increment = 5
			_bug_spawn_interval = 15.0
			_bug_limit = 14
			_starting_food = 40
			_starting_materials = 20
			_initial_bug_count = 3


func _bug_health_multiplier() -> float:
	return 1.25 if difficulty == "hard" else (0.8 if difficulty == "easy" else 1.0)


func queen_food_demand() -> int:
	return queen_demand_base + queen_cycle * queen_demand_increment


func _update_queen_warning() -> void:
	if queen_demand_timer <= QUEEN_URGENT_WARNING_SECONDS and _queen_warning_level < 2:
		_queen_warning_level = 2
		_hud.show_message("Urgent: the queen needs %d food in 30 seconds. The colony has %d." % [queen_food_demand(), colony_food])
	elif queen_demand_timer <= QUEEN_WARNING_SECONDS and _queen_warning_level < 1:
		_queen_warning_level = 1
		_hud.show_message("The queen needs %d food in 1 minute. The colony has %d." % [queen_food_demand(), colony_food])


func _check_queen_demand() -> void:
	var demand := queen_food_demand()
	if colony_food < demand:
		_game_over = true
		simulation_running = false
		get_tree().paused = false
		get_tree().set_meta("game_over_info", {
			"message": "The queen needed %d food, but the colony had %d. The colony has collapsed." % [demand, colony_food],
			"cycles": queen_cycle,
		})
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
		return
	colony_food -= demand
	queen_cycle += 1
	_food_manager.replenish(colony_position, REPLENISH_FOOD_PATCHES, REPLENISH_MATERIAL_PATCHES)
	_hud.show_message("The queen is fed. Food and materials have appeared around the map.")
	queen_demand_timer = QUEEN_DEMAND_INTERVAL
	_queen_warning_level = 0
	_update_status()


func _generate_world() -> void:
	_world_map.generate()
	colony_position = _world_map.colony_position()
	_camera.set_bounds(_world_map.map_rect())
	_camera.focus_on(colony_position)


func _on_rules_apply_requested(profile: String, rules_text: String) -> void:
	var result: Dictionary = _rules.apply(profile, rules_text)
	var error_line := int(result.get("line", -1))
	var error_column := int(result.get("column", -1))
	var error_length := int(result.get("length", 1))
	_hud.rules_editor.show_result(
		bool(result["ok"]),
		str(result["message"]),
		error_line,
		error_column,
		error_length
	)


func _on_rules_example_requested(profile: String) -> void:
	var example := _rules.default_for(profile)
	_hud.rules_editor.replace_source(example)
	_on_rules_apply_requested(profile, example)


func _on_rules_profile_changed(profile: String) -> void:
	_hud.rules_editor.set_source(_rules.source_for(profile))


func _toggle_simulation() -> void:
	if _game_over:
		_hud.show_message("The colony has fallen. Reset or load a save to keep playing.")
		return
	simulation_running = not simulation_running
	get_tree().paused = not simulation_running
	_hud.set_paused(not simulation_running)


func _reset_colony() -> void:
	_clear_workers()
	_clear_bugs()
	_world_seed = _random.randi()
	_world_random.seed = _world_seed
	_start_new_colony()
	get_tree().paused = false
	simulation_running = true
	_hud.set_paused(false)


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_food_delivered(amount: int) -> void:
	colony_food = mini(food_storage_capacity, colony_food + amount)
	_update_status()


func _on_materials_delivered(amount: int) -> void:
	colony_materials = mini(material_storage_capacity, colony_materials + amount)
	_update_status()


func has_construction_available() -> bool:
	for structure in structures:
		if not structure["complete"]:
			return true
	return false


func find_construction_target(from_position: Vector2) -> Vector2:
	var nearest := Vector2.INF
	var nearest_distance := INF
	for structure in structures:
		if structure["complete"]:
			continue
		var distance: float = from_position.distance_squared_to(structure["position"])
		if distance < nearest_distance:
			nearest = structure["position"]
			nearest_distance = distance
	return nearest


func contribute_build_progress(site_position: Vector2, delta: float) -> void:
	for index in range(structures.size()):
		var structure: Dictionary = structures[index]
		if structure["complete"] or structure["position"].distance_to(site_position) > 1.0:
			continue
		structure["progress"] = minf(structure["build_time"], structure["progress"] + delta)
		if structure["progress"] >= structure["build_time"]:
			structure["complete"] = true
			match structure["type"]:
				"food_storage":
					food_storage_capacity += 100
				"material_storage":
					material_storage_capacity += 100
		structures[index] = structure
		queue_redraw()
		_update_status()
		return


func _begin_structure_placement(structure_type: String) -> void:
	if not STRUCTURE_COSTS.has(structure_type):
		return
	_pending_structure_type = structure_type
	_hud.show_message("Click open ground to place %s; Esc cancels." % structure_type.replace("_", " "))


func _place_structure(position: Vector2) -> void:
	var structure_type := _pending_structure_type
	_pending_structure_type = ""
	if not _world_map.is_open_ground(position):
		_hud.show_message("Structures must be placed on open ground.")
		return
	if position.distance_to(colony_position) < 70.0:
		_hud.show_message("Place structures farther from the nest.")
		return
	for structure in structures:
		if position.distance_to(structure["position"]) < 52.0:
			_hud.show_message("Structures need more space.")
			return
	if structure_type == "hatchery" and _hatchery_count() >= 1 + queen_cycle:
		_hud.show_message("Hatchery limit reached for this queen cycle.")
		return
	var cost: Dictionary = STRUCTURE_COSTS[structure_type]
	if (structure_type == "farm" or structure_type == "workshop") and _producer_count(structure_type) >= PRODUCER_LIMIT:
		_hud.show_message("Limit of %d %ss reached." % [PRODUCER_LIMIT, STRUCTURE_INFO[structure_type][0].to_lower()])
		return
	if colony_food < cost["food"] or colony_materials < cost["materials"]:
		_hud.show_message("Need %d food and %d materials." % [cost["food"], cost["materials"]])
		return
	colony_food -= cost["food"]
	colony_materials -= cost["materials"]
	structures.append({
		"type": structure_type,
		"position": position,
		"progress": 0.0,
		"build_time": cost["build_time"],
		"complete": false,
	})
	_hud.show_message("Blueprint placed. Workers will build it when their rules allow.")
	_update_status()
	queue_redraw()


func _hatchery_count() -> int:
	var count := 0
	for structure in structures:
		if structure["type"] == "hatchery" and structure["complete"]:
			count += 1
	return count


func _assign_selected_guard_roles(assign: bool) -> void:
	var guard_posts := 0
	for structure in structures:
		if structure["type"] == "guard_post" and structure["complete"]:
			guard_posts += 1
	if assign and guard_posts == 0:
		_hud.show_message("Build a guard post first.")
		return
	var guard_limit := guard_posts * 3
	var guard_count := 0
	for ant in ants:
		if is_instance_valid(ant) and ant.role == AntWorker.Role.GUARD_POST:
			guard_count += 1
	for ant in _selected_ants:
		if not is_instance_valid(ant):
			continue
		if assign and ant.role == AntWorker.Role.WORKER and guard_count < guard_limit:
			var nearest_post := Vector2.INF
			var nearest_distance := INF
			for structure in structures:
				if structure["type"] != "guard_post" or not structure["complete"]:
					continue
				var distance: float = ant.global_position.distance_squared_to(structure["position"])
				if distance < nearest_distance:
					nearest_post = structure["position"]
					nearest_distance = distance
			ant.set_role(AntWorker.Role.GUARD_POST)
			ant.guard_post_position = nearest_post
			guard_count += 1
		elif not assign and ant.role == AntWorker.Role.GUARD_POST:
			ant.set_role(AntWorker.Role.WORKER)
			ant.guard_post_position = Vector2.INF
	_update_status()


func movement_speed_multiplier(position: Vector2) -> float:
	var tunnel_positions: Array[Vector2] = []
	for structure in structures:
		if structure["type"] == "tunnel" and structure["complete"]:
			tunnel_positions.append(structure["position"])
	for first in range(tunnel_positions.size()):
		for second in range(first + 1, tunnel_positions.size()):
			if Geometry2D.get_closest_point_to_segment(position, tunnel_positions[first], tunnel_positions[second]).distance_to(position) <= 20.0:
				return 1.75
	return 1.0


func _on_save_slot_action(action: String, slot_index: int) -> void:
	match action:
		"save":
			if _game_over:
				_hud.save_slots.show_message("The colony has fallen and cannot be saved.")
				return
			var result: Dictionary = SaveSystem.save_slot(slot_index, _create_save_data())
			_hud.save_slots.show_message(result["message"])
			_hud.save_slots.refresh_slots()
		"load":
			var result: Dictionary = SaveSystem.load_slot(slot_index)
			if not result["ok"]:
				_hud.save_slots.show_message(result["message"])
				return
			if not _restore_game(result["data"]):
				_hud.save_slots.show_message("Could not restore this save.")
				return
			_hud.save_slots.show_message("Loaded Slot %d." % (slot_index + 1))
			_hud.save_slots.refresh_slots()
		"delete":
			var result: Dictionary = SaveSystem.delete_slot(slot_index)
			_hud.save_slots.refresh_slots()
			_hud.save_slots.show_message(result["message"])


func _create_save_data() -> Dictionary:
	var saved_ants: Array[Dictionary] = []
	var saved_ant_indices: Dictionary = {}
	for ant in ants:
		if not is_instance_valid(ant):
			continue
		saved_ant_indices[ant.get_instance_id()] = saved_ants.size()
		saved_ants.append({
			"role": ant.role,
			"position": [ant.global_position.x, ant.global_position.y],
			"carried_food": ant.carried_food,
			"carried_material": ant.carried_material,
			"health": ant.health,
			"guard_post_position": [ant.guard_post_position.x, ant.guard_post_position.y] if ant.guard_post_position != Vector2.INF else null,
		})
	var saved_groups: Dictionary = {}
	for group_number in _control_groups:
		var group_indices: Array[int] = []
		for ant in _control_groups[group_number]:
			if is_instance_valid(ant) and saved_ant_indices.has(ant.get_instance_id()):
				group_indices.append(saved_ant_indices[ant.get_instance_id()])
		saved_groups[str(group_number)] = group_indices

	var saved_patches: Array[Dictionary] = []
	for patch in _food_manager.patches:
		var position: Vector2 = patch["position"]
		saved_patches.append({
			"position": [position.x, position.y],
			"amount": patch["amount"],
		})
	var saved_material_patches: Array[Dictionary] = []
	for patch in _food_manager.material_patches:
		var position: Vector2 = patch["position"]
		saved_material_patches.append({
			"position": [position.x, position.y],
			"amount": patch["amount"],
		})
	var saved_bugs: Array[Dictionary] = []
	for bug in bugs:
		if is_instance_valid(bug):
			saved_bugs.append({
				"position": [bug.global_position.x, bug.global_position.y],
				"health": bug.health,
			})
	var saved_structures: Array[Dictionary] = []
	for structure in structures:
		var position: Vector2 = structure["position"]
		saved_structures.append({
			"type": structure["type"],
			"position": [position.x, position.y],
			"progress": structure["progress"],
			"build_time": structure["build_time"],
			"complete": structure["complete"],
		})

	return {
		"schema_version": SaveSystem.SCHEMA_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"world_seed": _world_seed,
		"world_rng_state": _world_random.state,
		"random_state": _random.state,
		"colony_food": colony_food,
		"colony_materials": colony_materials,
		"difficulty": difficulty,
		"queen_cycle": queen_cycle,
		"queen_demand_timer": queen_demand_timer,
		"rules": _rules.source_for("worker"),
		"role_rules": _rules.sources.duplicate(),
		"food_patches": saved_patches,
		"material_patches": saved_material_patches,
		"bugs": saved_bugs,
		"structures": saved_structures,
		"ants": saved_ants,
		"control_groups": saved_groups,
	}


func _restore_game(data: Dictionary) -> bool:
	var role_rules: Dictionary = data.get("role_rules", {})
	var rules_result: Dictionary = _rules.restore(data["rules"], role_rules)
	if not rules_result["ok"]:
		return false

	_clear_workers()
	_clear_bugs()
	structures.clear()
	_selected_structure_index = -1
	_pending_structure_type = ""
	_selection_drag_active = false
	_selection_dragging = false
	_game_over = false
	_queen_warning_level = 0
	_production_timer = PRODUCTION_INTERVAL
	food_storage_capacity = 100
	material_storage_capacity = 100
	difficulty = str(data.get("difficulty", "normal"))
	_apply_difficulty()
	_world_seed = int(data["world_seed"])
	_world_random.seed = _world_seed
	_random.state = int(data["random_state"])
	_generate_world()
	_world_random.state = int(data["world_rng_state"])
	colony_food = int(data["colony_food"])
	colony_materials = int(data.get("colony_materials", 20))
	queen_cycle = int(data.get("queen_cycle", 0))
	queen_demand_timer = minf(float(data.get("queen_demand_timer", QUEEN_DEMAND_INTERVAL)), QUEEN_DEMAND_INTERVAL)
	_food_manager.restore(data["food_patches"], data.get("material_patches", []))
	_hud.rules_editor.reset_sources(_rules.sources)
	for ant in data["ants"]:
		var coordinates: Array = ant["position"]
		var position := Vector2(float(coordinates[0]), float(coordinates[1]))
		_create_worker(int(ant["role"]), position, int(ant["carried_food"]))
		var restored_ant: AntWorker = ants.back()
		restored_ant.carried_material = int(ant.get("carried_material", 0))
		restored_ant.health = minf(float(ant.get("health", restored_ant.max_health)), restored_ant.max_health)
		var saved_post_position: Variant = ant.get("guard_post_position")
		if typeof(saved_post_position) == TYPE_ARRAY:
			restored_ant.guard_post_position = Vector2(float(saved_post_position[0]), float(saved_post_position[1]))
		restored_ant.queue_redraw()
	var saved_groups: Dictionary = data.get("control_groups", {})
	for group_number in saved_groups:
		var group: Array[AntWorker] = []
		for ant_index in saved_groups[group_number]:
			if int(ant_index) >= 0 and int(ant_index) < ants.size():
				group.append(ants[int(ant_index)])
		_control_groups[int(group_number)] = group
	for bug in data.get("bugs", []):
		var coordinates: Array = bug["position"]
		var bug_position := Vector2(float(coordinates[0]), float(coordinates[1]))
		var restored_bug: Variant = RoamingBug.new()
		restored_bug.simulation = self
		restored_bug.max_health = 24.0 * _bug_health_multiplier()
		restored_bug.attack_damage = 5.0 * _bug_health_multiplier()
		restored_bug.global_position = bug_position
		restored_bug.defeated.connect(_on_bug_defeated)
		add_child(restored_bug)
		restored_bug.health = minf(float(bug.get("health", restored_bug.max_health)), restored_bug.max_health)
		bugs.append(restored_bug)
	for saved_structure in data.get("structures", []):
		var structure: Dictionary = saved_structure.duplicate()
		var coordinates: Array = structure["position"]
		structure["position"] = Vector2(float(coordinates[0]), float(coordinates[1]))
		structures.append(structure)
		if structure["complete"]:
			if structure["type"] == "food_storage":
				food_storage_capacity += 100
			elif structure["type"] == "material_storage":
				material_storage_capacity += 100
	_update_status()
	_bug_spawn_timer = _bug_spawn_interval
	simulation_running = false
	get_tree().paused = true
	_hud.set_paused(true)
	_hud.show_message("Save loaded. Press Resume to continue.")
	return true


func _clear_workers() -> void:
	for worker in ants:
		if is_instance_valid(worker):
			worker.queue_free()
	ants.clear()
	_selected_ants.clear()
	_control_groups.clear()
	_update_selection()


func _clear_bugs() -> void:
	for bug in bugs:
		if is_instance_valid(bug):
			bug.queue_free()
	bugs.clear()


func _update_status() -> void:
	var worker_count := 0
	var explorer_count := 0
	var defender_count := 0
	var guard_count := 0
	for ant in ants:
		if not is_instance_valid(ant):
			continue
		match ant.role:
			AntWorker.Role.WORKER:
				worker_count += 1
			AntWorker.Role.EXPLORER:
				explorer_count += 1
			AntWorker.Role.DEFENDER:
				defender_count += 1
			AntWorker.Role.GUARD_POST:
				guard_count += 1
	_hud.set_status(
		colony_food, worker_count, explorer_count, defender_count,
		colony_materials, guard_count, food_storage_capacity, material_storage_capacity,
	)
	_hud.set_queen_status(queen_food_demand(), queen_demand_timer, queen_cycle, difficulty)
	_refresh_selection_summary()


func _draw() -> void:
	draw_circle(colony_position, 54.0, Color(0.39, 0.29, 0.19))
	draw_circle(colony_position, 34.0, Color(0.55, 0.39, 0.24))
	draw_circle(colony_position, 12.0, Color(0.2, 0.16, 0.12))
	for patch in _food_manager.patches:
		var amount: int = patch["amount"]
		if amount > 0:
			var position: Vector2 = patch["position"]
			var size := 16.0 + minf(amount, 5) * 2.0
			var destination := Rect2(position - Vector2.ONE * size * 0.5, Vector2.ONE * size)
			draw_texture_rect_region(FOOD_TEXTURE, destination, Rect2(80.0, 16.0, 16.0, 16.0))
	for patch in _food_manager.material_patches:
		var amount: int = patch["amount"]
		if amount > 0:
			var position: Vector2 = patch["position"]
			draw_rect(Rect2(position - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(0.63, 0.67, 0.72))
	var tunnel_positions: Array[Vector2] = []
	for structure in structures:
		if structure["type"] == "tunnel" and structure["complete"]:
			tunnel_positions.append(structure["position"])
	for first in range(tunnel_positions.size()):
		for second in range(first + 1, tunnel_positions.size()):
			draw_line(tunnel_positions[first], tunnel_positions[second], Color(0.75, 0.62, 0.38, 0.7), 5.0)
	for structure in structures:
		var position: Vector2 = structure["position"]
		var color := Color(0.5, 0.36, 0.24)
		match structure["type"]:
			"hatchery":
				color = Color(0.75, 0.47, 0.37)
			"food_storage":
				color = Color(0.78, 0.68, 0.35)
			"material_storage":
				color = Color(0.5, 0.59, 0.65)
			"guard_post":
				color = Color(0.74, 0.42, 0.31)
			"tunnel":
				color = Color(0.45, 0.34, 0.25)
			"farm":
				color = Color(0.36, 0.67, 0.32)
			"workshop":
				color = Color(0.82, 0.55, 0.2)
		draw_circle(position, 17.0, color if structure["complete"] else color.darkened(0.55))
		var letter: String = STRUCTURE_INFO[structure["type"]][0].substr(0, 1)
		draw_string(ThemeDB.fallback_font, position + Vector2(-5.0, 5.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.1, 0.08, 0.05))
		if structures.find(structure) == _selected_structure_index:
			draw_arc(position, 25.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.3), 3.0)
		if not structure["complete"]:
			var progress_ratio: float = structure["progress"] / structure["build_time"]
			draw_arc(position, 21.0, -PI * 0.5, -PI * 0.5 + TAU * progress_ratio, 24, Color(0.95, 0.9, 0.55), 3.0)
	if show_behavior_overlay:
		_draw_behavior_overlay()
	if _selection_drag_active and _selection_dragging:
		var current := get_global_mouse_position()
		var top_left := to_local(_selection_drag_start.min(current))
		var rect := Rect2(top_left, to_local(_selection_drag_start.max(current)) - top_left)
		draw_rect(rect, Color(1.0, 0.9, 0.3, 0.16), true)
		draw_rect(rect, Color(1.0, 0.9, 0.3), false, 2.0)


func _draw_behavior_overlay() -> void:
	for ant in ants:
		if not is_instance_valid(ant):
			continue
		var behavior: Dictionary = ant.get_behavior_debug_info()
		var target: Vector2 = behavior["target"]
		if target == Vector2.INF:
			continue
		var start := to_local(ant.global_position)
		var destination := to_local(target)
		var manual_order: bool = behavior["manual_order"]
		var color := Color(1.0, 0.72, 0.24, 0.78) if manual_order else Color(0.28, 0.88, 0.92, 0.72)
		draw_line(start, destination, color, 1.5)
		draw_circle(destination, 6.0, color)
		var label := "Manual move" if manual_order else str(behavior["action"]).replace("_", " ")
		var rule_line: int = int(behavior["rule_line"])
		if rule_line > 0 and not manual_order:
			label += " | rule %d" % rule_line
		draw_string(ThemeDB.fallback_font, destination + Vector2(8.0, -8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.95, 0.97, 0.84))