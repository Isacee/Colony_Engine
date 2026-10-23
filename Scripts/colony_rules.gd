extends RefCounted
## Owns the active behavior script for each ant role and its persisted source text.

const RuleInterpreter = preload("res://Scripts/colony_rule_interpreter.gd")

const SAVE_PATH := "user://colony_rules.txt"
const PROFILE_IDS := ["worker", "explorer", "defender", "guard"]
const DEFAULT_RULES := """# STARTER RULES: this is the WORKER script. Only workers read it.
# Explorers, defenders and guards each have their own script.
# Ants follow the first matching rule from top to bottom.
# Lines starting with # are notes. Workers lose fights, so they run home.
define worker_building = worker and construction_available
define worker_near_material = worker and material_near
critical_health and near_nest: rest
critical_health: flee
bug_near: flee
food_full: return
materials_full: return
worker_building: build
injured and near_nest and not food_near and not material_near: rest
worker_near_material: collect_material
worker: collect_food
always: idle"""
const DEFAULT_EXPLORER_RULES := """# Explorer behavior: stay alive, run from bugs, and reveal the map.
critical_health and near_nest: rest
critical_health: flee
bug_near: flee
food_full: return
materials_full: return
food_near: collect_food
injured and near_nest: rest
always: search"""
const DEFAULT_DEFENDER_RULES := """# Defender behavior: respond to bugs and protect the colony.
critical_health and near_nest: rest
critical_health: flee
nest_under_attack: defend_nest
food_full: return
materials_full: return
bug_near: fight
injured and near_nest: rest
defender: patrol
always: patrol"""
const DEFAULT_GUARD_RULES := """# Guard behavior: protect your assigned guard post.
critical_health and near_nest: rest
critical_health: flee
nest_under_attack: defend_nest
food_full: return
materials_full: return
bug_near: fight
injured and near_nest: rest
guard: patrol
always: patrol"""
const DEFAULTS := {
	"worker": DEFAULT_RULES,
	"explorer": DEFAULT_EXPLORER_RULES,
	"defender": DEFAULT_DEFENDER_RULES,
	"guard": DEFAULT_GUARD_RULES,
}

var sources: Dictionary = DEFAULTS.duplicate()
var _interpreters: Dictionary = {}


func _init() -> void:
	for profile in PROFILE_IDS:
		_compile_profile(profile, str(sources[profile]))
	_load_saved_rules()


func apply(profile: String, rules_source: String) -> Dictionary:
	if not PROFILE_IDS.has(profile):
		return {"ok": false, "message": "Choose a valid ant role script."}

	var interpreter = RuleInterpreter.new()
	var result: Dictionary = interpreter.compile(rules_source)
	if not result["ok"]:
		return result

	sources[profile] = rules_source
	_interpreters[profile] = interpreter

	var save_file := FileAccess.open(_profile_save_path(profile), FileAccess.WRITE)
	if save_file:
		save_file.store_string(rules_source)
		result["message"] = "%s script applied and saved." % profile.capitalize()
	else:
		result["message"] = "%s script applied, but could not be saved." % profile.capitalize()
	return result


func interpret(context: Dictionary, profile: String = "worker") -> String:
	var interpreter = _interpreters.get(profile, _interpreters["worker"])
	return interpreter.interpret(context)


func explain(context: Dictionary, profile: String = "worker") -> Dictionary:
	var interpreter = _interpreters.get(profile, _interpreters["worker"])
	return interpreter.explain(context)


func source_for(profile: String) -> String:
	return str(sources.get(profile, sources["worker"]))


func default_for(profile: String) -> String:
	return str(DEFAULTS.get(profile, DEFAULT_RULES))


func restore(rules_source: String, role_sources: Dictionary = {}) -> Dictionary:
	var restored_sources: Dictionary = {}
	if role_sources.is_empty():
		for profile in PROFILE_IDS:
			restored_sources[profile] = rules_source
	else:
		for profile in PROFILE_IDS:
			var profile_source: Variant = role_sources.get(profile)
			if typeof(profile_source) != TYPE_STRING:
				return {"ok": false, "message": "The saved %s script is missing or invalid." % profile}
			restored_sources[profile] = profile_source

	var restored_interpreters: Dictionary = {}
	for profile in PROFILE_IDS:
		var interpreter = RuleInterpreter.new()
		var result: Dictionary = interpreter.compile(restored_sources[profile])
		if not result["ok"]:
			return result
		restored_interpreters[profile] = interpreter

	sources = restored_sources
	_interpreters = restored_interpreters
	return {"ok": true, "message": "Saved role scripts restored."}


func _compile_profile(profile: String, rules_source: String) -> bool:
	var interpreter = RuleInterpreter.new()
	var result: Dictionary = interpreter.compile(rules_source)
	if not result["ok"]:
		return false
	sources[profile] = rules_source
	_interpreters[profile] = interpreter
	return true


func _load_saved_rules() -> void:
	var legacy_source := ""
	if FileAccess.file_exists(SAVE_PATH):
		var legacy_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if legacy_file:
			legacy_source = legacy_file.get_as_text()
			for profile in PROFILE_IDS:
				_compile_profile(profile, legacy_source)

	for profile in PROFILE_IDS:
		var path := _profile_save_path(profile)
		if not FileAccess.file_exists(path):
			continue
		var save_file := FileAccess.open(path, FileAccess.READ)
		if not save_file:
			continue
		_compile_profile(profile, save_file.get_as_text())


func _profile_save_path(profile: String) -> String:
	return "user://colony_rules_%s.txt" % profile
