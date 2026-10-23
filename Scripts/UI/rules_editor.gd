extends PanelContainer
## Side panel for editing the colony's behavior rules. Main validates and stores them.

signal apply_requested(profile: String, rules_text: String)
signal example_requested(profile: String)
signal profile_changed(profile: String)
signal preview_requested(profile: String, rules_text: String, scenario: String)

const PROFILE_IDS := ["worker", "explorer", "defender", "guard"]
const RuleInterpreter = preload("res://Scripts/colony_rule_interpreter.gd")
const PROFILE_LABELS := ["Worker Script", "Explorer Script", "Defender Script", "Guard Script"]
const PREVIEW_IDLE_TEXT := "Test the current draft against a sample situation. Preview never applies or saves rules."
const PREVIEW_SCENARIOS := [
	{"id": "resources_nearby", "label": "Food and materials nearby"},
	{"id": "carrying_full", "label": "Carrying food capacity"},
	{"id": "bug_nearby", "label": "Bug nearby"},
	{"id": "building_available", "label": "Construction available"},
	{"id": "injured", "label": "Badly hurt, bug adjacent"},
	{"id": "bug_swarm", "label": "Several bugs, far from nest"},
	{"id": "nest_attack", "label": "Bugs attacking the nest"},
	{"id": "colony_hungry", "label": "Colony low on food, queen soon"},
	{"id": "quiet", "label": "No special conditions"},
]
const CONDITION_IDS := [
	"food_full", "materials_full", "food_near", "material_near", "worker", "searching", "defender", "guard", "bug_near", "construction_available", "always",
	"injured", "critical_health", "damaged", "carrying_food", "carrying_material", "carrying_any", "near_nest", "far_from_nest",
	"many_bugs_nearby", "bug_adjacent", "nest_under_attack", "colony_food_low", "queen_soon", "colony_materials_low",
	"food_storage_full", "material_storage_full",
]
const CONDITION_LABELS := [
	"Food full", "Materials full", "Food nearby", "Materials nearby", "Worker", "Searching", "Defender", "Guard", "Bug nearby", "Building available", "Always",
	"Injured (under 50% HP)", "Critical health (under 25% HP)", "Damaged (any HP lost)", "Carrying any food", "Carrying any materials", "Carrying anything", "Near nest", "Far from nest",
	"Many bugs nearby", "Bug adjacent", "Nest under attack", "Colony food low", "Queen deadline soon", "Colony materials low",
	"Food storage full", "Material storage full",
]
const ACTION_IDS := ["collect_food", "collect_material", "return", "search", "patrol", "build", "fight", "idle", "flee", "rest", "defend_nest", "forage", "guard_nest"]
const ACTION_LABELS := ["Gather food", "Gather materials", "Return to nest", "Explore", "Patrol", "Build structure", "Attack bugs", "Idle", "Flee to nest", "Rest and heal", "Defend nest", "Forage (nearest resource)", "Guard nest"]
const ERROR_COLOR := Color(1.0, 0.55, 0.45)
const OK_COLOR := Color(0.65, 0.9, 0.65)
const TUTORIAL_TEXT := """[b]HOW TO CODE YOUR ANTS: A STEP-BY-STEP COURSE[/b]
Read the lessons in order. Each one adds a new idea. Close this window at any time and come back with the Tutorial button.

[b]LESSON 1: WHAT YOU ARE PROGRAMMING[/b]
You are not writing normal code. You write short [i]rules[/i], and every ant uses them to decide what to do. An ant cannot think for itself: it only follows your list.

Each rule says: [b]IF this is true, THEN do that.[/b] In the game it looks like this:
[code]bug_near: fight[/code]
Read it as "if a bug is near, fight". The part before the colon is the [b]condition[/b]. The part after it is the [b]action[/b].

[b]LESSON 2: YOUR FIRST EDIT (2 minutes)[/b]
1. Open Commands (C), press [b]Edit Rules[/b]. The editor appears on the right.
2. Pick [b]Worker Script[/b] in the Editing menu. Each role has its own script. Changing one does not change the others.
3. Click in the text box and change [code]worker: collect_food[/code] to [code]worker: idle[/code].
4. Press [b]Apply Rules[/b]. Your workers stop collecting food.
5. Change it back, or press [b]Use Example[/b] to restore the starter rules.
You just changed how the colony behaves. Everything else in this guide builds on this loop: edit, test, apply, watch.

[b]LESSON 3: THE TOP-TO-BOTTOM RULE (the most important idea)[/b]
Ants read your rules from the top. They take the [b]first[/b] rule whose condition is true and ignore the rest. This is called "first match wins". Ants re-check all the time, so when something changes (for example a bug appears), they switch rules instantly.

Example:
[code]bug_near: fight
worker: collect_food[/code]
A worker with a bug nearby fights, because rule 1 is true and rule 2 is never read. A worker with no bug nearby collects food, because rule 1 is false and rule 2 is true.

Swap the two lines and workers will [i]never[/i] fight, because "worker" is always true. [b]Put specific rules at the top and broad rules at the bottom.[/b]

[b]LESSON 4: CONDITIONS (the questions an ant can ask)[/b]
[b]Who am I?[/b]
worker : I am a worker (or a guard, see Lesson 9).
searching : I am an explorer.
defender : I am a defender.
guard : I am a guard at a guard post.

[b]What am I carrying?[/b]
food_full : I hold all the food I can carry. (Worker 3, Explorer 2, Defender 1, Guard 3.)
materials_full : I hold all the materials I can carry. (Worker 3, Explorer 1, Guard 3. Defenders cannot carry materials.)

[b]What is around me?[/b]
food_near : food is inside my detection range.
material_near : materials are inside my detection range.
bug_near : a bug is inside my detection range.
Detection range: Worker 150, Explorer 300, Defender 190, Guard 210. Explorers see the farthest.

[b]What is happening in the colony?[/b]
construction_available : a blueprint has been placed and is not finished yet.

[b]Always true[/b]
always : true for every ant. Use it for the last rule so no ant is left without orders.

[b]How healthy am I?[/b]
damaged (scratched) : I have lost any health at all, even 1 point.
injured (hurt, low_health) : my health is under 50%.
critical_health (dying) : my health is under 25%.

[b]What am I carrying (any amount)?[/b]
carrying_food (has_food) : I hold at least 1 food.
carrying_material (has_material) : I hold at least 1 material.
carrying_any (has_cargo) : I hold food or materials.

[b]Where am I?[/b]
near_nest (at_nest) : within about 90 pixels of the nest.
far_from_nest (far_away) : more than about 450 pixels from the nest.

[b]How dangerous is it?[/b]
many_bugs_nearby (swarm) : 2 or more bugs inside my detection range.
bug_adjacent (bug_close) : a bug is right next to me (45 pixels).
nest_under_attack (nest_attacked) : a bug is within 220 pixels of the nest, wherever I am.

[b]How is the colony doing?[/b]
colony_food_low (food_low) : the colony has less food than the queen's next demand.
queen_soon (queen_urgent) : the queen's deadline is under 1 minute away.
colony_materials_low (materials_low) : the colony has fewer than 25 materials.
food_storage_full : the food stockpile is at its capacity. Extra food is wasted.
material_storage_full : the material stockpile is at its capacity.

Longer names also work: carrying_full, carrying_material_full, food_nearby, material_nearby, enemy_nearby, role_is_worker, role_is_explorer, role_is_defender, role_is_guard_post, building_ready.

[b]COUNTERS AND TIMERS (compare with a number)[/b]
Ants count what they do. Use >=, <=, >, <, = or != with a whole number:
[code]deliveries >= 3: rest[/code] means "after 3 drop-offs at the nest, rest".
[code]harvests >= 5: return[/code] means "after picking up 5 items, go home".
[code]action_seconds >= 10: return[/code] means "after 10 seconds on the same task, go home".
[code]health < 15: flee[/code] means "flee when my health drops under 15".
The counters are deliveries, harvests, action_seconds and health. Short names also work: trips or dropoffs (deliveries), items or pickups (harvests), task_seconds, timer or time_on_task (action_seconds), hp (health). A counter belongs to one ant and resets when that ant switches actions (action_seconds) or dies. Counters can be combined like any condition, for example [code]worker and harvests >= 5: return[/code], and can be used inside define lines.

[b]LESSON 5: ACTIONS (the things an ant can do)[/b]
[b]Gathering[/b]
collect_food : walk to the nearest food and pick up one. When full, it heads home.
collect_material : the same, for materials.
forage (gather_nearest) : go for whichever is closer, food or materials, as long as the ant still has room for it. Great when you want a mix.
return : walk to the nest and drop off everything carried.

[b]Moving[/b]
search : wander to new places and reveal food.
patrol : walk around the nest (guards walk around their guard post).
guard_nest : patrol around the nest itself, even for guards with a post.

[b]Fighting and survival[/b]
fight : chase the nearest bug and attack it.
defend_nest : go after any bug near the nest, even one the ant cannot see. With no bug there, patrol the nest.
flee (retreat, run) : run to the nest 30% faster than normal, without fighting. Does not drop off cargo.
rest (heal, recover) : go to the nest and recover 3 health every second.

[b]Other[/b]
build : walk to a blueprint and work on it. Workers only.
idle : stand still.
Long names also work: gather_food, gather_material, gather_nearest, return_to_nest, explore, build_structure, attack_bugs, wait.
An action is only a [i]goal[/i]. The game handles walking, picking up and fighting for you.

[b]LESSON 6: COMBINING CONDITIONS WITH and / or / not[/b]
[b]and[/b] : both must be true.
[code]worker and food_near: collect_food[/code]
[b]or[/b] : at least one must be true.
[code]searching or defender: patrol[/code]
[b]not[/b] : flips true to false.
[code]worker and not food_full: collect_food[/code]
[b]Parentheses[/b] group things. [i]and[/i] is read before [i]or[/i], so add brackets when in doubt:
[code]worker or guard and bug_near: fight[/code] means "worker, or (guard and bug nearby)"
[code](worker or guard) and bug_near: fight[/code] means "(worker or guard), and a bug is nearby"
They are different. Use brackets to say exactly what you mean.

[b]LESSON 7: DEFINE YOUR OWN CONDITIONS[/b]
When you repeat the same long condition, give it a name with [b]define[/b]. Definitions go at the [b]top[/b], before any rule.
[code]define busy_builder = worker and construction_available
define in_danger = bug_near and not defender
busy_builder: build
in_danger: return[/code]
Rules for names: letters, numbers and underscores only; no spaces; do not reuse a built-in word like worker or fight; each name only once. A definition may use earlier definitions, but not ones further down.

[b]LESSON 8: LAYOUT AND COMMENTS[/b]
Lines that start with # are notes for you. The game ignores them. Blank lines are ignored too.
[code]# Safety first
bug_near: fight[/code]
Comments must have their own line. Writing [code]bug_near: fight # attack[/code] is an error.
Capital letters do not matter. [code]Bug_Near: FIGHT[/code] works.
One rule per line, exactly one colon per rule.

[b]LESSON 9: ROLE TRAPS TO KNOW[/b]
- [b]Each role reads only its own script.[/b] Pick the script in the Editing menu: Worker, Explorer, Defender or Guard. Changing one never affects the others.
- [b]Guards count as workers.[/b] The condition [i]worker[/i] is also true for guards, but guards run the Guard script, so this only matters if you reuse scripts across roles.
- [b]Defenders cannot carry materials[/b], so collect_material does nothing for them.
- [b]build only works for workers.[/b] Other roles cannot build.
- [b]No rule matches?[/b] The ant goes idle. End every script with [code]always: idle[/code] (or a real action) so you notice gaps.
- [b]Workers and explorers lose fights.[/b] A bug has 24 health and hits for 5 every 1.2 seconds. A worker (30 HP, 2 damage per second) needs about 12 seconds to win and usually dies first. Only defenders (45 HP, 5 damage, 35% resistance) win 1v1. The starter scripts therefore make workers [code]flee[/code] from bugs and leave the fighting to defenders and guards. Make workers fight only if you accept losses: [code]bug_near: fight[/code] in the Worker script usually costs you ants. Prefer [code]bug_near: flee[/code].
- [b]Only the first matching rule is used[/b], so a broad rule near the top can hide everything under it.
- [b]Survival rules go first.[/b] Put [code]critical_health: ...[/code] and [code]nest_under_attack: ...[/code] above gathering rules, or ants will keep working while hurt or while the nest is being raided.
- [b]flee does not fight and does not deliver.[/b] It only runs home. Pair it with [code]rest[/code] so the ant heals once it arrives, for example [code]critical_health and near_nest: rest[/code] then [code]critical_health: flee[/code].
- [b]forage only picks what the ant can still carry.[/b] A defender (1 food, 0 materials) will only ever forage food.
- [b]colony_ conditions are the same for every ant.[/b] They describe the whole colony, not the ant. If food is low, [i]all[/i] ants matching the rule switch at once.

[b]LESSON 10: PRACTICE EXERCISES[/b]
Do these in the Worker script. Press Test Draft first, then Apply Rules.
[b]Exercise 1: Careful workers.[/b] Make workers run home as soon as they carry food. Put [code]food_full: return[/code] above [code]worker: collect_food[/code].
[b]Exercise 2: Material first.[/b] Make workers prefer materials. Put [code]worker and material_near: collect_material[/code] above [code]worker: collect_food[/code].
[b]Exercise 3: Stay out of trouble.[/b] Workers lose fights against bugs, so make them run: [code]bug_near: flee[/code] above the collect rules. Then change it to [code]bug_near: fight[/code], apply, and watch how many workers survive.
[b]Exercise 4: Your own name.[/b] Define [code]define loaded = food_full or materials_full[/code], then write [code]loaded: return[/code].
[b]Exercise 5: Self-preservation.[/b] Add [code]critical_health: flee[/code] at the very top, then test with the "Badly hurt, bug adjacent" scenario. Then add [code]critical_health and near_nest: rest[/code] above it. Which line wins now?
[b]Exercise 6: Panic button.[/b] Add [code]many_bugs_nearby and not defender: flee[/code] above the fight rule. Workers now avoid swarms while defenders still fight.
[b]Exercise 7: Smart priorities.[/b] Make workers gather materials only when the colony is short: [code]colony_materials_low and material_near: collect_material[/code] above [code]worker: collect_food[/code].
[b]Exercise 8: Counters.[/b] Add [code]deliveries >= 3: rest[/code] above the collect rules so workers rest after 3 drop-offs, then try [code]action_seconds >= 10: return[/code] to send ants home after 10 seconds on one task.
[b]Challenge:[/b] Build a guard post, assign a worker as a guard, then edit the [b]Guard Script[/b] so guards patrol until a bug appears, then fight.
[b]Hard challenge:[/b] Write a Defender script that defends the nest when it is attacked, rests when injured, and patrols otherwise.

[b]LESSON 11: A COMPLETE WORKER SCRIPT, LINE BY LINE[/b]
This is a full Worker script. Only workers read it; the other roles follow their own scripts.
[code]define builder = worker and construction_available

food_full: return
materials_full: return
bug_near: flee
builder: build
worker and material_near: collect_material
worker: collect_food
always: idle[/code]
1. [i]define builder[/i] gives a short name to "a worker when a blueprint exists".
2. The two [i]return[/i] rules come first, so a full ant always goes home.
3. [i]bug_near: flee[/i] keeps workers alive. Fighting is left to the Defender and Guard scripts.
4. Workers build when there is something to build.
5. Workers collect materials when some are nearby, otherwise food.
6. Anyone left over idles.
To change what defenders or explorers do, switch to their script in the Editing menu and write rules just like these.

[b]LESSON 12: TEST BEFORE YOU APPLY[/b]
[b]Test Draft[/b] : choose a sample situation (bug nearby, carrying full, etc.) and press Test Draft. It shows which rule would win and why, without touching your colony. Use it every time you change something.
[b]Apply Rules[/b] : checks the whole script and, if it is valid, switches your ants to it and saves it for next time.
[b]Use Example[/b] : loads and applies the starter script for the chosen role.
[b]Add Rule[/b] : pick a condition and action from the menus and add a line for you. Good for learning the names.
[b]Auto-complete[/b] : start typing a word and suggestions appear.
[b]Live check in the world[/b] : open Commands > [b]Behavior Overlay[/b] to draw a line from each ant to its target with its current action and rule. Select one ant (click it, then open Selection with V) to see which rule line it is using. Gold means you gave it a manual move order.

[b]LESSON 13: FIXING ERRORS[/b]
When something is wrong, the editor highlights the exact place and says the line and column. Common messages:
[b]"Unknown condition: xyz"[/b] : the word before the colon is not a known condition. Check the spelling against Lesson 4, or define it first.
[b]"Unknown action: xyz"[/b] : the word after the colon is not an action. See Lesson 5.
[b]"Use condition: action"[/b] : the line is missing its colon.
[b]"Use only one ':'"[/b] : there is a second colon on the line.
[b]"Put condition definitions before the rules"[/b] : move every define line to the top.
[b]"Use define name = condition"[/b] : a define needs exactly one equals sign.
[b]"Expected ')' ..."[/b] : a bracket is open and never closed.
[b]"Expected a condition"[/b] : you wrote and, or or not with nothing after it.
[b]"Compare a counter to a number"[/b] : a counter such as deliveries needs an operator and a whole number, like [code]deliveries >= 3[/code].
[b]"A number needs a counter before it"[/b] : you wrote a bare number. Put a counter in front of it.
[b]"... is a yes/no condition"[/b] : only counters can be compared to a number. Write [code]injured[/code], not [code]injured >= 1[/code].
[b]"Add at least one rule"[/b] : the script has no rules.
If a rule looks right but the ants behave strangely, the problem is almost always [b]order[/b]. Use Test Draft and read which line wins.

[b]LESSON 14: USEFUL RECIPES[/b]
[b]Safe workers[/b]
[code]bug_near: return
food_full: return
worker: collect_food
always: idle[/code]
[b]Aggressive defenders[/b]
[code]bug_near: fight
always: patrol[/code]
[b]Explorer that also scouts for food[/b]
[code]food_full: return
bug_near: return
food_near: collect_food
always: search[/code]
[b]Builder crew[/b]
[code]define builder = worker and construction_available
food_full: return
bug_near: flee
builder: build
worker: collect_food
always: idle[/code]
[b]Material hoarder[/b]
[code]materials_full: return
food_full: return
worker and material_near: collect_material
worker: collect_food
always: idle[/code]
[b]Survivor worker[/b] (flees, heals, then goes back to work)
[code]critical_health and near_nest: rest
critical_health: flee
nest_under_attack and defender: defend_nest
carrying_any and bug_near: return
food_full: return
materials_full: return
worker: forage
always: idle[/code]
[b]Nest guardian defender[/b]
[code]critical_health and near_nest: rest
critical_health: flee
nest_under_attack: defend_nest
bug_adjacent: fight
bug_near: fight
always: guard_nest[/code]
[b]Queen panic mode[/b] (everyone hunts food when the deadline is close)
[code]define crunch = colony_food_low and queen_soon
food_full: return
crunch and bug_near and worker: flee
crunch and worker: collect_food
worker: forage
always: idle[/code]
[b]Don't waste food[/b] (stop hauling when the storage is full)
[code]food_storage_full and worker: collect_material
worker: collect_food
always: idle[/code]

[b]LESSON 15: HOW IT FITS THE GAME[/b]
The queen demands more food every 5 minutes and the colony collapses if she is not fed. Your rules decide how well your ants gather, fight and build. Good scripts keep food coming in, keep ants safe and put blueprints up quickly. Farms (1 food per 30 s) and Workshops (1 material per 30 s) produce on their own, so build a few and let the ants focus on danger and expansion. Watch the Queen timer, experiment with the rules, and improve your scripts every cycle.

[b]QUICK REFERENCE[/b]
Rule: [code]condition: action[/code]
Logic: and, or, not, ( )
Counters: [code]deliveries[/code], [code]harvests[/code], [code]action_seconds[/code], [code]health[/code] compared with >=, <=, >, <, = or !=
Reusable: [code]define name = condition[/code]
Comment: a line starting with #
Order: top to bottom, first true rule wins
Fallback: always: idle

[b]GAME CONTROLS (reminder)[/b]
C opens Commands. V opens Selection. W A S D move the camera. Click or drag to select ants, Shift adds or removes. Right-click sends selected ants to a spot; they resume their rules when they arrive. Ctrl+1 to 9 saves a group and 1 to 9 recalls it."""
@onready var _condition_picker: OptionButton = %ConditionPicker
@onready var _action_picker: OptionButton = %ActionPicker
@onready var _editor: CodeEdit = %Editor
@onready var _feedback: Label = %Feedback
@onready var _tutorial_dialog: AcceptDialog = %TutorialDialog
@onready var _profile_picker: OptionButton = %ProfilePicker
@onready var _preview_picker: OptionButton = %PreviewPicker
@onready var _preview_output: Label = %PreviewOutput
var _error_line := -1
var _active_profile := "worker"
var _draft_sources: Dictionary = {}
var _loading_source := false


func _ready() -> void:
	for label in CONDITION_LABELS:
		_condition_picker.add_item(label)
	for label in ACTION_LABELS:
		_action_picker.add_item(label)
	for index in range(PROFILE_IDS.size()):
		_profile_picker.add_item(PROFILE_LABELS[index])
		_profile_picker.set_item_metadata(index, PROFILE_IDS[index])
	_profile_picker.select(0)
	for scenario in PREVIEW_SCENARIOS:
		_preview_picker.add_item(scenario["label"])
		_preview_picker.set_item_metadata(_preview_picker.item_count - 1, scenario["id"])
	_configure_editor()
	var tutorial_label := RichTextLabel.new()
	tutorial_label.bbcode_enabled = true
	tutorial_label.text = TUTORIAL_TEXT
	tutorial_label.add_theme_color_override("bold_color", Color(0.1, 0.35, 0.25, 1.0))
	tutorial_label.custom_minimum_size = Vector2(760, 560)
	tutorial_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_label.add_theme_color_override("default_color", Color(0.12, 0.17, 0.14, 1.0))
	tutorial_label.add_theme_font_size_override("normal_font_size", 16)
	var tutorial_background := StyleBoxFlat.new()
	tutorial_background.bg_color = Color(0.96, 0.93, 0.84, 1.0)
	tutorial_background.border_color = Color(0.42, 0.34, 0.22, 1.0)
	tutorial_background.border_width_left = 2
	tutorial_background.border_width_top = 2
	tutorial_background.border_width_right = 2
	tutorial_background.border_width_bottom = 2
	tutorial_background.content_margin_left = 16.0
	tutorial_background.content_margin_top = 14.0
	tutorial_background.content_margin_right = 16.0
	tutorial_background.content_margin_bottom = 14.0
	tutorial_label.add_theme_stylebox_override("normal", tutorial_background)
	_tutorial_dialog.add_child(tutorial_label)
	%AddRuleButton.pressed.connect(_add_selected_rule)
	_profile_picker.item_selected.connect(_on_profile_selected)
	%ApplyButton.pressed.connect(func(): apply_requested.emit(_active_profile, _editor.text))
	%ExampleButton.pressed.connect(func(): example_requested.emit(_active_profile))
	%TutorialButton.pressed.connect(func(): _tutorial_dialog.popup_centered(Vector2i(820, 680)))
	%TestDraftButton.pressed.connect(_test_draft)


func _configure_editor() -> void:
	_editor.set_auto_indent_enabled(true)
	_editor.auto_brace_completion_enabled = true
	_editor.indent_size = 4
	_editor.indent_use_spaces = true
	_editor.code_completion_enabled = true
	_editor.text_changed.connect(_on_editor_text_changed)
	_editor.code_completion_requested.connect(_complete_rules)

	var highlighter := CodeHighlighter.new()
	highlighter.add_color_region("#", "", Color(0.38, 0.48, 0.39), true)
	for keyword in ["and", "or", "not", "define"]:
		highlighter.add_keyword_color(keyword, Color(0.58, 0.3, 0.13))
	for condition in RuleInterpreter.CONDITIONS + RuleInterpreter.CONDITION_ALIASES.keys() + RuleInterpreter.NUMERIC_CONDITIONS + RuleInterpreter.NUMERIC_ALIASES.keys():
		highlighter.add_keyword_color(condition, Color(0.22, 0.42, 0.67))
	for action in RuleInterpreter.ACTIONS + RuleInterpreter.ACTION_ALIASES.keys():
		highlighter.add_keyword_color(action, Color(0.46, 0.28, 0.57))
	highlighter.symbol_color = Color(0.45, 0.38, 0.28)
	_editor.syntax_highlighter = highlighter


func _complete_rules() -> void:
	_editor.clear_code_completion_options()
	var suggestions: Array[String] = []
	for suggestion_value in CONDITION_IDS + ACTION_IDS + ["and", "or", "not", "define"] + RuleInterpreter.NUMERIC_CONDITIONS:
		var suggestion := str(suggestion_value)
		if not suggestions.has(suggestion):
			suggestions.append(suggestion)
	for raw_line in _editor.text.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with("define "):
			continue
		var definition_name := line.substr("define ".length()).split("=", false)[0].strip_edges()
		if not definition_name.is_empty() and not suggestions.has(definition_name):
			suggestions.append(definition_name)
	for suggestion in suggestions:
		_editor.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, suggestion, suggestion)
	_editor.update_code_completion_options(true)


func _on_editor_text_changed() -> void:
	if _loading_source:
		return
	_clear_error_highlight()
	_draft_sources[_active_profile] = _editor.text
	_reset_preview_output("Draft changed. Test it again to see which rule matches.")
	_feedback.text = "Edited. Apply rules to check them."
	_feedback.add_theme_color_override("font_color", Color(0.72, 0.78, 0.68))


func _clear_error_highlight() -> void:
	if _error_line >= 0 and _error_line < _editor.get_line_count():
		_editor.clear_line_background_color(_error_line)
	_error_line = -1


func set_source(text: String) -> void:
	_set_editor_source(str(_draft_sources.get(_active_profile, text)))


func reset_sources(sources: Dictionary) -> void:
	_draft_sources = sources.duplicate()
	_set_editor_source(str(_draft_sources.get(_active_profile, "")))


func replace_source(text: String) -> void:
	_draft_sources[_active_profile] = text
	_set_editor_source(text)


func _set_editor_source(text: String) -> void:
	_loading_source = true
	_editor.text = text
	_loading_source = false
	_reset_preview_output(PREVIEW_IDLE_TEXT)


func _reset_preview_output(message: String) -> void:
	_preview_output.text = message
	_preview_output.remove_theme_color_override("font_color")


func _on_profile_selected(index: int) -> void:
	_clear_error_highlight()
	_draft_sources[_active_profile] = _editor.text
	_active_profile = str(_profile_picker.get_item_metadata(index))
	_feedback.text = "Editing %s script." % PROFILE_LABELS[index].trim_suffix(" Script")
	_feedback.add_theme_color_override("font_color", OK_COLOR)
	profile_changed.emit(_active_profile)


func focus_editor() -> void:
	_editor.grab_focus()


func show_result(ok: bool, message: String, line: int = -1, column: int = -1, length: int = 1) -> void:
	_clear_error_highlight()
	_feedback.text = message
	_feedback.add_theme_color_override("font_color", OK_COLOR if ok else ERROR_COLOR)
	if ok or line < 1 or line > _editor.get_line_count():
		return

	_error_line = line - 1
	_editor.set_line_background_color(_error_line, Color(0.55, 0.16, 0.12, 0.24))
	var line_text := _editor.get_line(_error_line)
	var start_column := mini(maxi(column - 1, 0), line_text.length())
	var end_column := mini(start_column + maxi(length, 1), line_text.length())
	_editor.grab_focus()
	_editor.set_caret_line(_error_line)
	_editor.set_caret_column(start_column)
	if end_column > start_column:
		_editor.select(_error_line, start_column, _error_line, end_column)
	_editor.set_line_as_center_visible(_error_line)


func show_preview_result(message: String, ok: bool, line: int = -1, column: int = -1, length: int = 1) -> void:
	_preview_output.text = message
	_preview_output.add_theme_color_override("font_color", OK_COLOR if ok else ERROR_COLOR)
	if ok:
		_clear_error_highlight()
		_feedback.text = "Draft test complete; no rules were applied."
		_feedback.add_theme_color_override("font_color", OK_COLOR)
	else:
		show_result(false, message, line, column, length)


func _test_draft() -> void:
	var scenario: String = str(_preview_picker.get_item_metadata(_preview_picker.selected))
	preview_requested.emit(_active_profile, _editor.text, scenario)


func _add_selected_rule() -> void:
	var new_rule := "%s: %s" % [CONDITION_IDS[_condition_picker.selected], ACTION_IDS[_action_picker.selected]]
	var current_text := _editor.text.strip_edges()
	_editor.text = new_rule if current_text.is_empty() else current_text + "\n" + new_rule
	var last_line := _editor.get_line_count() - 1
	_editor.set_caret_line(last_line)
	_editor.set_caret_column(_editor.get_line(last_line).length())
	_editor.grab_focus()
	_on_editor_text_changed()
