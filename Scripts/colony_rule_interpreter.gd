extends RefCounted

const CONDITIONS := [
	"carrying_full",
	"carrying_material_full",
	"food_nearby",
	"material_nearby",
	"role_is_worker",
	"role_is_explorer",
	"role_is_defender",
	"role_is_guard_post",
	"enemy_nearby",
	"construction_available",
	"always",
	"injured",
	"critical_health",
	"damaged",
	"carrying_food",
	"carrying_material",
	"carrying_any",
	"near_nest",
	"far_from_nest",
	"many_bugs_nearby",
	"bug_adjacent",
	"nest_under_attack",
	"colony_food_low",
	"queen_soon",
	"colony_materials_low",
	"food_storage_full",
	"material_storage_full",
]
const ACTIONS := [
	"gather_food", "gather_material", "return_to_nest", "explore", "patrol", "build_structure", "attack_bugs", "idle",
	"flee", "rest", "defend_nest", "gather_nearest", "guard_nest",
]
const CONDITION_ALIASES := {
	"hurt": "injured",
	"low_health": "injured",
	"scratched": "damaged",
	"hurt_at_all": "damaged",
	"dying": "critical_health",
	"has_food": "carrying_food",
	"has_material": "carrying_material",
	"has_cargo": "carrying_any",
	"at_nest": "near_nest",
	"far_away": "far_from_nest",
	"swarm": "many_bugs_nearby",
	"bug_close": "bug_adjacent",
	"nest_attacked": "nest_under_attack",
	"food_low": "colony_food_low",
	"queen_urgent": "queen_soon",
	"materials_low": "colony_materials_low",
	"food_full": "carrying_full",
	"materials_full": "carrying_material_full",
	"material_full": "carrying_material_full",
	"food_near": "food_nearby",
	"material_near": "material_nearby",
	"materials_near": "material_nearby",
	"worker": "role_is_worker",
	"explorer": "role_is_explorer",
	"searching": "role_is_explorer",
	"defender": "role_is_defender",
	"guard": "role_is_guard_post",
	"bug_near": "enemy_nearby",
	"enemy": "enemy_nearby",
	"building_ready": "construction_available",
}
const ACTION_ALIASES := {
	"collect_food": "gather_food",
	"collect_material": "gather_material",
	"collect_materials": "gather_material",
	"return": "return_to_nest",
	"search": "explore",
	"searching": "explore",
	"build": "build_structure",
	"fight": "attack_bugs",
	"wait": "idle",
	"retreat": "flee",
	"run": "flee",
	"heal": "rest",
	"recover": "rest",
	"defend": "defend_nest",
	"forage": "gather_nearest",
	"gather_any": "gather_nearest",
	"protect_nest": "guard_nest",
}

# Counters and timers are numbers, so they are compared to a number:
# deliveries >= 3, harvests < 5, action_seconds >= 10, health < 15
const NUMERIC_CONDITIONS := ["health", "deliveries", "harvests", "action_seconds"]
const NUMERIC_ALIASES := {
	"hp": "health",
	"trips": "deliveries",
	"dropoffs": "deliveries",
	"items": "harvests",
	"pickups": "harvests",
	"task_seconds": "action_seconds",
	"timer": "action_seconds",
	"time_on_task": "action_seconds",
}
const COMPARISON_OPS := [">", "<", ">=", "<=", "=", "!="]

var _rules: Array[Dictionary] = []


func compile(source: String) -> Dictionary:
	var candidate_rules: Array[Dictionary] = []
	var definitions: Dictionary = {}
	var rules_started := false
	var lines := source.split("\n")
	for index in range(lines.size()):
		var raw_line: String = lines[index]
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var line_column := raw_line.find(line) + 1

		if line.begins_with("define "):
			if rules_started:
				return _error(index + 1, "Put condition definitions before the rules.", line_column)
			var definition := line.substr("define ".length())
			var separator := definition.find("=")
			if separator <= 0 or definition.find("=", separator + 1) >= 0:
				var equals_offset := definition.length()
				if separator == 0:
					equals_offset = 0
				elif separator > 0:
					equals_offset = definition.find("=", separator + 1)
				var equals_column := line_column + "define ".length() + equals_offset
				return _error(index + 1, "Use define name = condition", equals_column)
			var name := definition.substr(0, separator).strip_edges().to_lower()
			var name_start := definition.find(name)
			var name_column := line_column + "define ".length() + name_start
			var expression := definition.substr(separator + 1).strip_edges().to_lower()
			if not _is_valid_definition_name(name):
				return _error(index + 1, "Use a simple name containing letters, numbers, and underscores.", name_column, maxi(1, name.length()))
			if _is_reserved_definition_name(name):
				return _error(index + 1, "That name is already used by a condition, action, or logic word: " + name, name_column, name.length())
			if definitions.has(name):
				return _error(index + 1, "Condition already defined: " + name, name_column, name.length())

			var expression_offset := line.find("=") + 1
			var expression_leading_space := line.substr(expression_offset).length() - line.substr(expression_offset).strip_edges(true, false).length()
			var expression_column := line_column + expression_offset + expression_leading_space
			var token_result := _tokenize_condition(expression, index + 1, expression_column)
			if not token_result["ok"]:
				return token_result
			var definition_tokens: PackedStringArray = token_result["tokens"]
			var definition_columns: PackedInt32Array = token_result["columns"]
			var parsed_definition := _parse_or(definition_tokens, definition_columns, 0, definitions)
			if not parsed_definition["ok"]:
				return _error(index + 1, parsed_definition["message"], int(parsed_definition["column"]), int(parsed_definition.get("length", 1)))
			if parsed_definition["next"] != definition_tokens.size():
				var extra_index: int = parsed_definition["next"]
				return _error(index + 1, "Unexpected condition token: " + definition_tokens[extra_index], definition_columns[extra_index], definition_tokens[extra_index].length())
			var definition_node: Dictionary = parsed_definition["node"]
			definitions[name] = definition_node
			continue

		rules_started = true
		var separator := line.find(":")
		if separator < 0:
			return _error(index + 1, "Use condition: action", line_column + line.length())
		var second_separator := line.find(":", separator + 1)
		if second_separator >= 0:
			return _error(index + 1, "Use only one ':' between the condition and action.", line_column + second_separator)

		var condition := line.substr(0, separator).strip_edges().to_lower()
		var condition_start := line.find(condition)
		var condition_column := line_column + condition_start
		var action_part := line.substr(separator + 1)
		var action := action_part.strip_edges().to_lower()
		var action_offset := action_part.find(action)
		var action_column := line_column + separator + 1 + maxi(0, action_offset)
		action = str(ACTION_ALIASES.get(action, action))
		if not ACTIONS.has(action):
			return _error(index + 1, "Unknown action: " + line.substr(separator + 1).strip_edges(), action_column, maxi(1, line.substr(separator + 1).strip_edges().length()))

		var token_result := _tokenize_condition(condition, index + 1, condition_column)
		if not token_result["ok"]:
			return token_result
		var tokens: PackedStringArray = token_result["tokens"]
		var columns: PackedInt32Array = token_result["columns"]
		var parsed := _parse_or(tokens, columns, 0, definitions)
		if not parsed["ok"]:
			return _error(index + 1, parsed["message"], int(parsed["column"]), int(parsed.get("length", 1)))
		if parsed["next"] != tokens.size():
			var extra_index: int = parsed["next"]
			return _error(index + 1, "Unexpected condition token: " + tokens[extra_index], columns[extra_index], tokens[extra_index].length())
		var condition_node: Dictionary = parsed["node"]
		candidate_rules.append({
			"condition": condition_node,
			"condition_text": condition,
			"action": action,
			"line": index + 1,
		})

	if candidate_rules.is_empty():
		return {"ok": false, "message": "Add at least one rule.", "line": 1, "column": 1, "length": 1}

	_rules = candidate_rules
	return {"ok": true, "message": "Rules ready. First matching rule wins."}


func _tokenize_condition(expression: String, line_number: int, base_column: int) -> Dictionary:
	var tokens := PackedStringArray()
	var columns := PackedInt32Array()
	var index := 0
	while index < expression.length():
		var character := expression.substr(index, 1)
		if character.unicode_at(0) <= 32:
			index += 1
			continue
		if character == "(" or character == ")":
			tokens.append(character)
			columns.append(base_column + index)
			index += 1
			continue
		if character == ">" or character == "<" or character == "=" or character == "!":
			var operator_start := index
			index += 1
			if index < expression.length() and expression.substr(index, 1) == "=":
				index += 1
			var operator := expression.substr(operator_start, index - operator_start)
			if operator == "!":
				return _error(line_number, "Unexpected character: !", base_column + operator_start, 1)
			if operator == "==":
				operator = "="
			tokens.append(operator)
			columns.append(base_column + operator_start)
			continue

		var start := index
		while index < expression.length():
			character = expression.substr(index, 1)
			var codepoint := character.unicode_at(0)
			var is_letter := (codepoint >= 97 and codepoint <= 122) or (codepoint >= 65 and codepoint <= 90)
			var is_digit := codepoint >= 48 and codepoint <= 57
			if not is_letter and not is_digit and codepoint != 95:
				break
			index += 1
		if index == start:
			return _error(line_number, "Unexpected character: " + character, base_column + index, 1)
		tokens.append(expression.substr(start, index - start).to_lower())
		columns.append(base_column + start)

	columns.append(base_column + expression.length())
	return {"ok": true, "tokens": tokens, "columns": columns}


func _is_valid_definition_name(name: String) -> bool:
	if name.is_empty():
		return false
	for index in range(name.length()):
		var character := name.unicode_at(index)
		var is_letter := character >= 97 and character <= 122
		var is_digit := character >= 48 and character <= 57
		if index == 0:
			if not is_letter and character != 95:
				return false
		elif not is_letter and not is_digit and character != 95:
			return false
	return true


func _is_reserved_definition_name(name: String) -> bool:
	return (
		CONDITIONS.has(name)
		or ACTIONS.has(name)
		or CONDITION_ALIASES.has(name)
		or ACTION_ALIASES.has(name)
		or NUMERIC_CONDITIONS.has(name)
		or NUMERIC_ALIASES.has(name)
		or ["and", "or", "not", "define"].has(name)
	)


func interpret(context: Dictionary) -> String:
	for rule in _rules:
		if _condition_matches(rule["condition"], context):
			return rule["action"]
	return "idle"


func explain(context: Dictionary) -> Dictionary:
	var trace: Array[Dictionary] = []
	for rule in _rules:
		var checks: Array[String] = []
		var matched: bool = _condition_matches(rule["condition"], context, checks)
		trace.append({
			"line": rule["line"],
			"condition": rule["condition_text"],
			"action": rule["action"],
			"matched": matched,
			"checks": checks,
		})
		if matched:
			return {"action": rule["action"], "trace": trace}
	return {"action": "idle", "trace": trace}


func _condition_matches(node: Dictionary, context: Dictionary, checks: Variant = null) -> bool:
	if node.has("numeric"):
		var counter: String = node["numeric"]
		var actual := float(context.get(counter, 0.0))
		var target := float(node["value"])
		var matched := false
		match str(node["op"]):
			">":
				matched = actual > target
			"<":
				matched = actual < target
			">=":
				matched = actual >= target
			"<=":
				matched = actual <= target
			"=":
				matched = actual == target
			"!=":
				matched = actual != target
		if checks != null:
			checks.append("%s=%d (needs %s %d)" % [counter, int(actual), node["op"], int(target)])
		return matched
	if node.has("condition"):
		var condition: String = node["condition"]
		var matched: bool = condition == "always" or context.get(condition, false) == true
		if checks != null:
			checks.append("%s=%s" % [condition, "yes" if matched else "no"])
		return matched

	match node["operator"]:
		"and":
			var left_matches: bool = _condition_matches(node["left"], context, checks)
			if not left_matches and checks == null:
				return false
			var right_matches: bool = _condition_matches(node["right"], context, checks)
			return left_matches and right_matches
		"or":
			var left_matches: bool = _condition_matches(node["left"], context, checks)
			if left_matches and checks == null:
				return true
			var right_matches: bool = _condition_matches(node["right"], context, checks)
			return left_matches or right_matches
		"not":
			return not _condition_matches(node["operand"], context, checks)
	return false


func _parse_or(tokens: PackedStringArray, columns: PackedInt32Array, index: int, definitions: Dictionary) -> Dictionary:
	var parsed := _parse_and(tokens, columns, index, definitions)
	if not parsed["ok"]:
		return parsed
	var node: Dictionary = parsed["node"]
	var next_index: int = parsed["next"]
	while next_index < tokens.size() and tokens[next_index] == "or":
		var right := _parse_and(tokens, columns, next_index + 1, definitions)
		if not right["ok"]:
			return right
		node = {"operator": "or", "left": node, "right": right["node"]}
		next_index = right["next"]
	return {"ok": true, "node": node, "next": next_index}


func _parse_and(tokens: PackedStringArray, columns: PackedInt32Array, index: int, definitions: Dictionary) -> Dictionary:
	var parsed := _parse_unary(tokens, columns, index, definitions)
	if not parsed["ok"]:
		return parsed
	var node: Dictionary = parsed["node"]
	var next_index: int = parsed["next"]
	while next_index < tokens.size() and tokens[next_index] == "and":
		var right := _parse_unary(tokens, columns, next_index + 1, definitions)
		if not right["ok"]:
			return right
		node = {"operator": "and", "left": node, "right": right["node"]}
		next_index = right["next"]
	return {"ok": true, "node": node, "next": next_index}


func _parse_unary(tokens: PackedStringArray, columns: PackedInt32Array, index: int, definitions: Dictionary) -> Dictionary:
	if index >= tokens.size():
		return {"ok": false, "message": "Expected a condition.", "column": columns[index]}
	if tokens[index] == "not":
		var operand := _parse_unary(tokens, columns, index + 1, definitions)
		if not operand["ok"]:
			return operand
		return {
			"ok": true,
			"node": {"operator": "not", "operand": operand["node"]},
			"next": operand["next"],
		}
	if tokens[index] == "(":
		var grouped := _parse_or(tokens, columns, index + 1, definitions)
		if not grouped["ok"]:
			return grouped
		if grouped["next"] >= tokens.size() or tokens[grouped["next"]] != ")":
			return {"ok": false, "message": "Expected ')' to close the condition.", "column": columns[grouped["next"]]}
		grouped["next"] += 1
		return grouped
	if tokens[index] == ")":
		return {"ok": false, "message": "Expected a condition before ')'.", "column": columns[index]}
	if definitions.has(tokens[index]):
		return {
			"ok": true,
			"node": definitions[tokens[index]],
			"next": index + 1,
		}
	var word := tokens[index]
	var numeric := str(NUMERIC_ALIASES.get(word, word))
	if NUMERIC_CONDITIONS.has(numeric):
		if index + 1 >= tokens.size() or not COMPARISON_OPS.has(tokens[index + 1]):
			return {"ok": false, "message": "Compare a counter to a number, like deliveries >= 3.", "column": columns[index], "length": word.length()}
		if index + 2 >= tokens.size() or not tokens[index + 2].is_valid_int():
			var number_column := columns[mini(index + 2, columns.size() - 1)]
			return {"ok": false, "message": "Expected a whole number after '" + tokens[index + 1] + "'.", "column": number_column}
		return {
			"ok": true,
			"node": {"numeric": numeric, "op": tokens[index + 1], "value": tokens[index + 2].to_float()},
			"next": index + 3,
		}
	if word.is_valid_int():
		return {"ok": false, "message": "A number needs a counter before it, like deliveries >= 3.", "column": columns[index], "length": word.length()}
	var condition := str(CONDITION_ALIASES.get(word, word))
	if not CONDITIONS.has(condition):
		return {"ok": false, "message": "Unknown condition: " + word, "column": columns[index], "length": word.length()}
	if index + 1 < tokens.size() and COMPARISON_OPS.has(tokens[index + 1]):
		return {"ok": false, "message": condition + " is a yes/no condition. Only counters can be compared to a number.", "column": columns[index + 1], "length": tokens[index + 1].length()}
	return {
		"ok": true,
		"node": {"condition": condition},
		"next": index + 1,
	}


func _error(line_number: int, message: String, column: int = 1, length: int = 1) -> Dictionary:
	return {
		"ok": false,
		"message": "Line %d, column %d: %s" % [line_number, column, message],
		"line": line_number,
		"column": column,
		"length": length,
	}
