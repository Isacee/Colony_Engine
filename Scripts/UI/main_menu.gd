extends Control
## Title screen: starts the game or quits.

const GAME_SCENE := "res://Scenes/main.tscn"
const SaveSystem = preload("res://Scripts/save_system.gd")

const HOW_TO_PLAY := """[b]GOAL[/b]
Keep your ant colony alive. every 5 minutes the queen demands food. If the colony has less food than she asks for, the colony collapses and the game is over. If it has enough, that food is paid and the next demand is bigger.

[b]THE FIRST 5 MINUTES[/b]
1. Press Start Game. You begin with 3 workers, 1 explorer and 1 defender.
2. Move the camera with W A S D or the arrow keys.
3. Look at the top bar. Food and Materials show what the colony owns. The Queen label shows how much food she wants and the time left.
4. Do nothing special at first: ants already follow starter rules. Workers collect food and carry it to the nest. Watch Food go up.
5. Press C (Commands) and add more workers so food comes in faster. You can only have 5 ants until you build a hatchery.
6. Press V (Selection), then Build, and place a Hatchery to raise the ant limit by 5.

[b]THE ANTS[/b]
Worker: gathers food and materials, and builds structures.
Explorer: fast and far-sighted. Searches the map for food.
Defender: strong. Patrols and fights bugs.
Guard: a worker assigned to a guard post. Protects that post.

[b]DANGERS AND FOOD[/b]
Bugs wander the map and attack ants. Defenders and other ants fight back. A defeated bug drops food you can collect. Bugs appear more often and hit harder on Hard.

[b]BUILDING[/b]
Open Selection (V), press Build, pick a structure, then click open ground (not too close to the nest). Costs are paid right away. Workers build it over time. Press Esc to cancel.
Hatchery: +5 ant limit (you may own one per queen cycle).
Food storage / Material storage: +100 capacity each.
Guard post: lets you assign up to 3 guards.
Tunnel: build two to make a fast lane between them.

[b]CONTROLS[/b]
W A S D / arrows: move camera
Left-click ant: select. Drag: box-select. Shift: add or remove.
Right-click ground: send selected ants there. They return to their rules when they arrive.
Ctrl + 1-9: save selected ants as a group. 1-9: select that group.
C: Commands panel. V: Selection panel.
? Help: full list of buttons.

[b]CHANGING ANT BEHAVIOR[/b]
Commands > Edit Rules lets you write rules such as [code]food_full: return[/code] or [code]deliveries >= 3: rest[/code]. Ants use the first rule from the top that is true. Press Use Example to load the starter rules, Tutorial to learn the language, and Test Draft to try rules before applying.

[b]TIPS[/b]
- Check the Queen timer often. Get food above the demand before it reaches zero.
- Build storage before your food hits 100, because extra food is wasted.
- Keep a defender or two near the nest.
- Save Slots (in Commands) lets you save and come back later."""

@onready var _start_button: Button = %StartButton
@onready var _load_button: Button = %LoadButton
@onready var _quit_button: Button = %QuitButton
@onready var _save_slots: Control = %SaveSlotsPanel
@onready var _difficulty_picker: OptionButton = %DifficultyPicker


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_load_button.pressed.connect(_save_slots.open_for_menu)
	_save_slots.action_requested.connect(_on_save_slot_action)
	_quit_button.pressed.connect(_on_quit_pressed)
	_start_button.grab_focus()
	_start_button.add_theme_color_override("font_focus_color", Color(0.12, 0.17, 0.14))
	# Browsers can't quit the page, so the button is hidden on web exports.
	_quit_button.visible = not OS.has_feature("web")
	_difficulty_picker.add_item("Easy")
	_difficulty_picker.add_item("Normal")
	_difficulty_picker.add_item("Hard")
	_difficulty_picker.select(1)
	_add_how_to_play()


func _add_how_to_play() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "How to Play"
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = HOW_TO_PLAY
	text.add_theme_color_override("default_color", Color(0.95, 0.95, 0.92))
	text.add_theme_color_override("bold_color", Color(1.0, 0.85, 0.4))
	text.custom_minimum_size = Vector2(620, 480)
	dialog.add_child(text)
	var ok_button := dialog.get_ok_button()
	for color_name in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		ok_button.add_theme_color_override(color_name, Color(0.12, 0.17, 0.14))
	add_child(dialog)
	var button := Button.new()
	button.text = "How to Play"
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(func(): dialog.popup_centered())
	var container := _quit_button.get_parent()
	container.add_child(button)
	container.move_child(button, _load_button.get_index() + 1)


func _on_start_pressed() -> void:
	get_tree().set_meta("new_game_difficulty", _difficulty_picker.get_item_text(_difficulty_picker.selected).to_lower())
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_save_slot_action(action: String, slot_index: int) -> void:
	match action:
		"load":
			var result: Dictionary = SaveSystem.load_slot(slot_index)
			if not result["ok"]:
				_save_slots.show_message(result["message"])
				return
			get_tree().set_meta("pending_save_data", result["data"])
			get_tree().change_scene_to_file(GAME_SCENE)
		"delete":
			var result: Dictionary = SaveSystem.delete_slot(slot_index)
			_save_slots.refresh_slots()
			_save_slots.show_message(result["message"])


func _on_quit_pressed() -> void:
	get_tree().quit()
