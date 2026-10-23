extends Control
## Game over screen shown when the queen's quota is missed.

const GAME_SCENE := "res://Scenes/main.tscn"
const MENU_SCENE := "res://Scenes/UI/main_menu.tscn"

@onready var _message: Label = %Message
@onready var _score: Label = %Score
@onready var _retry_button: Button = %RetryButton
@onready var _main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	var info: Dictionary = {}
	if get_tree().has_meta("game_over_info"):
		info = get_tree().get_meta("game_over_info")
		get_tree().remove_meta("game_over_info")

	_message.text = str(info.get("message", "The colony has collapsed."))
	_score.text = "Queen quotas fulfilled: %d" % int(info.get("cycles", 0))

	_retry_button.pressed.connect(_on_retry_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)
	_retry_button.grab_focus()
	_retry_button.add_theme_color_override("font_focus_color", Color(0.12, 0.17, 0.14))


func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
