extends RefCounted
## Handles the three persistent colony save slots.

const RuleInterpreter = preload("res://Scripts/colony_rule_interpreter.gd")

const SLOT_COUNT := 3
const SAVE_DIRECTORY := "user://saves"
const SCHEMA_VERSION := 1
const RULE_PROFILES := ["worker", "explorer", "defender", "guard"]


static func save_slot(slot_index: int, data: Dictionary) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return _failure("Invalid save slot.")
	if data.get("schema_version") != SCHEMA_VERSION:
		return _failure("The save data has an unsupported version.")

	var directory_path := ProjectSettings.globalize_path(SAVE_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(directory_path)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure("Could not create the save directory.")

	var file := FileAccess.open(_slot_path(slot_index), FileAccess.WRITE)
	if not file:
		return _failure("Could not open the save slot for writing.")
	file.store_string(JSON.stringify(data))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _failure("Could not write the save slot.")
	return {"ok": true, "message": "Game saved to Slot %d." % (slot_index + 1)}


static func load_slot(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return _failure("Invalid save slot.")
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return _failure("Slot %d is empty." % (slot_index + 1))

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return _failure("Could not open Slot %d." % (slot_index + 1))
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return _failure("Slot %d contains invalid save data." % (slot_index + 1))
	if not _is_valid_save_data(json.data):
		return _failure("Slot %d has incomplete or unsupported save data." % (slot_index + 1))
	return {"ok": true, "data": json.data}


static func delete_slot(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return _failure("Invalid save slot.")
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return _failure("Slot %d is already empty." % (slot_index + 1))
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return _failure("Could not delete Slot %d." % (slot_index + 1))
	return {"ok": true, "message": "Slot %d deleted." % (slot_index + 1)}


static func get_slot_summary(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {"exists": false, "message": "Invalid slot"}
	var result := load_slot(slot_index)
	if not result["ok"]:
		if not FileAccess.file_exists(_slot_path(slot_index)):
			return {"exists": false, "message": "Empty"}
		return {"exists": true, "message": "Invalid save"}

	var saved_at := int(result["data"].get("saved_at", 0))
	var message := "Saved game"
	if saved_at > 0:
		message = "Saved %s" % Time.get_datetime_string_from_unix_time(saved_at, true)
	return {"exists": true, "message": message}


static func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT


static func _slot_path(slot_index: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIRECTORY, slot_index + 1]


static func _is_valid_save_data(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = value
	if data.get("schema_version") != SCHEMA_VERSION:
		return false
	if not _is_number(data.get("world_seed")) or not _is_number(data.get("world_rng_state")):
		return false
	if not _is_number(data.get("random_state")) or not _is_number(data.get("colony_food")):
		return false
	if int(data["colony_food"]) < 0:
		return false
	if data.has("colony_materials") and (not _is_number(data["colony_materials"]) or int(data["colony_materials"]) < 0):
		return false
	if data.has("queen_cycle") and (not _is_number(data["queen_cycle"]) or int(data["queen_cycle"]) < 0):
		return false
	if data.has("queen_demand_timer") and (not _is_number(data["queen_demand_timer"]) or float(data["queen_demand_timer"]) < 0.0):
		return false
	if data.has("difficulty") and (typeof(data["difficulty"]) != TYPE_STRING or not ["easy", "normal", "hard"].has(data["difficulty"])):
		return false
	if typeof(data.get("rules")) != TYPE_STRING:
		return false
	var rules_check: Dictionary = RuleInterpreter.new().compile(data["rules"])
	if not rules_check["ok"]:
		return false
	if data.has("role_rules"):
		if typeof(data["role_rules"]) != TYPE_DICTIONARY:
			return false
		var role_rules: Dictionary = data["role_rules"]
		if role_rules.size() != RULE_PROFILES.size():
			return false
		for profile in RULE_PROFILES:
			if typeof(role_rules.get(profile)) != TYPE_STRING:
				return false
			var profile_check: Dictionary = RuleInterpreter.new().compile(role_rules[profile])
			if not profile_check["ok"]:
				return false
		if role_rules["worker"] != data["rules"]:
			return false
	if typeof(data.get("food_patches")) != TYPE_ARRAY or typeof(data.get("ants")) != TYPE_ARRAY:
		return false
	if typeof(data.get("material_patches", [])) != TYPE_ARRAY or typeof(data.get("bugs", [])) != TYPE_ARRAY:
		return false
	for patch in data["food_patches"]:
		if typeof(patch) != TYPE_DICTIONARY or not _has_position_and_amount(patch):
			return false
		if int(patch["amount"]) < 0:
			return false
	for patch in data.get("material_patches", []):
		if typeof(patch) != TYPE_DICTIONARY or not _has_position_and_amount(patch):
			return false
		if int(patch["amount"]) < 0:
			return false
	for ant in data["ants"]:
		if typeof(ant) != TYPE_DICTIONARY or not _has_position(ant):
			return false
		if not _is_number(ant.get("role")) or not _is_number(ant.get("carried_food")):
			return false
		if int(ant["role"]) < 0 or int(ant["role"]) > 3 or int(ant["carried_food"]) < 0:
			return false
		if ant.has("carried_material") and (not _is_number(ant["carried_material"]) or int(ant["carried_material"]) < 0):
			return false
		if ant.has("health") and (not _is_number(ant["health"]) or float(ant["health"]) < 0.0):
			return false
		if ant.has("guard_post_position") and ant["guard_post_position"] != null and not _has_coordinates(ant["guard_post_position"]):
			return false
	for bug in data.get("bugs", []):
		if typeof(bug) != TYPE_DICTIONARY or not _has_position(bug):
			return false
		if bug.has("health") and (not _is_number(bug["health"]) or float(bug["health"]) < 0.0):
			return false
	if typeof(data.get("structures", [])) != TYPE_ARRAY:
		return false
	for structure in data.get("structures", []):
		if typeof(structure) != TYPE_DICTIONARY or not _has_position(structure):
			return false
		if not ["hatchery", "food_storage", "material_storage", "guard_post", "tunnel", "farm", "workshop"].has(structure.get("type")):
			return false
		if not _is_number(structure.get("progress")) or not _is_number(structure.get("build_time")):
			return false
		if float(structure["progress"]) < 0.0 or float(structure["build_time"]) <= 0.0 or float(structure["progress"]) > float(structure["build_time"]):
			return false
		if typeof(structure.get("complete")) != TYPE_BOOL:
			return false
	if typeof(data.get("control_groups", {})) != TYPE_DICTIONARY:
		return false
	for group_number in data.get("control_groups", {}):
		if not str(group_number).is_valid_int() or int(group_number) < 1 or int(group_number) > 9:
			return false
		var members: Variant = data["control_groups"][group_number]
		if typeof(members) != TYPE_ARRAY:
			return false
		for ant_index in members:
			if not _is_number(ant_index) or int(ant_index) < 0 or int(ant_index) >= data["ants"].size():
				return false
	return true


static func _has_position_and_amount(value: Dictionary) -> bool:
	return _has_position(value) and _is_number(value.get("amount"))


static func _has_position(value: Dictionary) -> bool:
	return _has_coordinates(value.get("position"))


static func _has_coordinates(position: Variant) -> bool:
	if typeof(position) != TYPE_ARRAY or position.size() != 2:
		return false
	return _is_number(position[0]) and _is_number(position[1])


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
