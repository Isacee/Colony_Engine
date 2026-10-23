extends Control
## Reusable interface for saving, loading, and deleting colony slots.

signal action_requested(action: String, slot_index: int)

const SaveSystem = preload("res://Scripts/save_system.gd")

var _game_mode := false
var _pending_action := ""
var _pending_slot := -1
var _slot_labels: Array[Label] = []
var _load_buttons: Array[Button] = []
var _save_buttons: Array[Button] = []
var _delete_buttons: Array[Button] = []
var _message_label: Label
var _dialog: ConfirmationDialog


func _ready() -> void:
	_build_interface()
	visible = false


func open_for_menu() -> void:
	_open(false)


func open_for_game() -> void:
	_open(true)


func refresh_slots() -> void:
	for slot_index in range(SaveSystem.SLOT_COUNT):
		var summary: Dictionary = SaveSystem.get_slot_summary(slot_index)
		_slot_labels[slot_index].text = "Slot %d  -  %s" % [slot_index + 1, summary["message"]]
		_load_buttons[slot_index].disabled = not summary["exists"]
		_delete_buttons[slot_index].disabled = not summary["exists"]
		_save_buttons[slot_index].text = "Overwrite" if summary["exists"] else "Save"


func show_message(message: String) -> void:
	_message_label.text = message


func _open(game_mode: bool) -> void:
	_game_mode = game_mode
	_message_label.text = ""
	for button in _save_buttons:
		button.visible = game_mode
	visible = true
	refresh_slots()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.58)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var heading := Label.new()
	heading.text = "Save Slots"
	heading.add_theme_font_size_override("font_size", 28)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_message_label)

	for slot_index in range(SaveSystem.SLOT_COUNT):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		content.add_child(row)

		var slot_label := Label.new()
		slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slot_label)
		_slot_labels.append(slot_label)

		var load_button := Button.new()
		load_button.text = "Load"
		load_button.pressed.connect(_request_action.bind("load", slot_index))
		row.add_child(load_button)
		_load_buttons.append(load_button)

		var save_button := Button.new()
		save_button.text = "Save"
		save_button.pressed.connect(_request_action.bind("save", slot_index))
		row.add_child(save_button)
		_save_buttons.append(save_button)

		var delete_button := Button.new()
		delete_button.text = "Delete"
		delete_button.pressed.connect(_request_action.bind("delete", slot_index))
		row.add_child(delete_button)
		_delete_buttons.append(delete_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(func(): visible = false)
	content.add_child(close_button)

	_dialog = ConfirmationDialog.new()
	_dialog.confirmed.connect(_confirm_pending_action)
	add_child(_dialog)


func _request_action(action: String, slot_index: int) -> void:
	var summary: Dictionary = SaveSystem.get_slot_summary(slot_index)
	if action == "load" and not summary["exists"]:
		return
	if action == "delete" and not summary["exists"]:
		return
	if action == "save" and not summary["exists"]:
		action_requested.emit(action, slot_index)
		return

	_pending_action = action
	_pending_slot = slot_index
	var slot_name := "Slot %d" % (slot_index + 1)
	match action:
		"save":
			_dialog.title = "Overwrite Save"
			_dialog.dialog_text = "Replace the saved game in %s?" % slot_name
		"load":
			_dialog.title = "Load Save"
			_dialog.dialog_text = "Load %s? Your current unsaved colony will be lost." % slot_name if _game_mode else "Load %s?" % slot_name
		"delete":
			_dialog.title = "Delete Save"
			_dialog.dialog_text = "Permanently delete the saved game in %s?" % slot_name
	_dialog.popup_centered()


func _confirm_pending_action() -> void:
	action_requested.emit(_pending_action, _pending_slot)
	_pending_action = ""
	_pending_slot = -1
