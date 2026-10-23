extends CanvasLayer
## In-game overlay: colony status, spawn/pause/reset buttons, and the rules editor.

signal spawn_requested(role: int)
signal pause_toggled
signal reset_requested
signal menu_requested
signal selection_requested(scope: String)
signal build_requested(structure_type: String)
signal guard_assignment_requested(assign: bool)
signal behavior_overlay_toggled(enabled: bool)

const AntWorker = preload("res://Scripts/ant_worker.gd")
const BUILDING_IDS := ["hatchery", "food_storage", "material_storage", "guard_post", "tunnel", "farm", "workshop"]
const BUILDING_LABELS := ["Hatchery (30F/20M)", "Food storage (15F/20M)", "Material storage (10F/15M)", "Guard post (20F/25M)", "Tunnel (5F/10M)", "Farm (20F/25M)", "Workshop (25F/15M)"]
const GAMEPLAY_HELP := """QUICK START
Goal: every 5 minutes the queen demands food (see the Queen label). If you have less, the colony collapses. Ants collect food on their own using their rules, so add workers (C), build a Hatchery for more room (V > Build), and watch the Queen timer. Move the camera with W A S D.

GAMEPLAY CONTROLS

TOP BAR
Commands (C): Opens the panel with colony actions.
Selection (V): Opens ant selection filters and selected-ant controls.
? Help: Opens this guide.
Food / Materials / Ants: Current colony supplies, capacities, and role counts.
Queen: Food demand countdown, cycle, and difficulty.
Message: Recent game feedback.

COLONY COMMANDS
+ Worker / + Explorer / + Defender: Create that ant role if you are below the ant limit. Hatcheries increase the limit. Guards are made by assigning workers at a guard post.
Pause / Resume: Stop or resume the simulation.
Reset: Start a fresh colony and world (asks for confirmation).
Edit Rules: Edit each ant role's behavior script. The role picker switches scripts. Condition and Action pickers choose a rule for Add Rule. There are 27 conditions (health, cargo, distance to nest, danger, colony and storage state), 4 number counters you compare with a number (deliveries, harvests, action_seconds, health; for example deliveries >= 3) and 13 actions (including flee, rest, defend_nest, forage and guard_nest). Apply Rules validates and activates the script; Use Example loads and applies that role's starter rules; Tutorial is a full step-by-step course; Test Draft previews a sample situation (such as "badly hurt" or "nest under attack") without applying it.
Behavior Overlay: Toggle lines from ants to their current targets, with the active action/rule. Gold indicates a manual move.
Save Slots: Save, load, or delete colony saves. Loading replaces the current unsaved colony; overwriting and deleting ask for confirmation.
Menu: Leave the current game and return to the main menu.

SELECTION PANEL
All / Workers / Explorers / Defenders / Guards: Select ants by role.
Build: Choose a structure, then click open ground to place its blueprint. The listed food/material costs are paid at placement. Hatcheries increase the ant limit, storages each add 100 capacity, guard posts allow 3 guards, and paired tunnels speed travel. A Farm makes 1 food and a Workshop makes 1 material every 30 seconds by themselves (max 4 each). Press Escape to cancel placement.
Click any structure (with no ant under the cursor) to select it and see its status and effect in the Selection panel; a gold ring marks it.
Assign Guard: Turn selected workers into guards, subject to completed guard-post capacity (3 guards per post).
Unassign: Turn selected guards back into workers.
Selected ant details show health, speed, attack, resistance, detection, carrying capacity, active behavior, and rule checks.

MOUSE AND KEYBOARD
Left-click an ant to select it; drag to box-select. Hold Shift while clicking or dragging to add/remove ants.
Right-click the ground to send selected ants there. They resume their role rules when they arrive.
Ctrl+1..9 saves the current selection as a control group; 1..9 recalls it. Hold Shift with a number to add that group to the current selection.
C opens/closes Commands. V opens/closes Selection. Escape cancels structure placement.

SAVE AND GAME OVER DIALOGS
Save Slots: Each slot has Load, Save (or Overwrite), and Delete; Close hides the panel. Confirmation dialogs let you confirm or cancel overwriting, loading, or deleting.
Colony Fallen: Return to Main Menu leaves the ended game."""

@onready var rules_editor: PanelContainer = %RulesEditor
@onready var _status_label: Label = %StatusLabel
@onready var _pause_button: Button = %PauseButton
@onready var _rules_button: Button = %RulesButton
@onready var save_slots: Control = %SaveSlotsPanel
var _selection_label: Label
var _selection_details_label: Label
var _selection_actions_label: Label
var _selection_panel: PanelContainer
var _commands_panel: PanelContainer
var _message_label: Label
var _queen_label: Label
var _game_over_dialog: ConfirmationDialog
var _reset_dialog: ConfirmationDialog
var _help_dialog: AcceptDialog
var _build_button: Button
var _assign_guard_button: Button
var _unassign_guard_button: Button


func _ready() -> void:
	%WorkerButton.pressed.connect(func(): spawn_requested.emit(AntWorker.Role.WORKER))
	%ExplorerButton.pressed.connect(func(): spawn_requested.emit(AntWorker.Role.EXPLORER))
	%DefenderButton.pressed.connect(func(): spawn_requested.emit(AntWorker.Role.DEFENDER))
	_pause_button.pressed.connect(func(): pause_toggled.emit())
	%ResetButton.pressed.connect(func(): _reset_dialog.popup_centered())
	%MenuButton.pressed.connect(func(): menu_requested.emit())
	_rules_button.pressed.connect(_toggle_rules_editor)
	%BehaviorOverlayButton.toggled.connect(func(enabled: bool): behavior_overlay_toggled.emit(enabled))
	%SaveSlotsButton.pressed.connect(save_slots.open_for_game)
	%HelpButton.pressed.connect(_show_gameplay_help)
	%HelpButton.tooltip_text = "Explain gameplay buttons and controls"
	_build_selection_panel()
	_build_popup_toggles()
	var build_menu := PopupMenu.new()
	for index in range(BUILDING_IDS.size()):
		build_menu.add_item(BUILDING_LABELS[index], index)
	build_menu.id_pressed.connect(func(id: int): build_requested.emit(BUILDING_IDS[id]))
	add_child(build_menu)
	_build_button.pressed.connect(func():
		build_menu.position = _build_button.global_position
		build_menu.popup()
	)
	_assign_guard_button.pressed.connect(func(): guard_assignment_requested.emit(true))
	_unassign_guard_button.pressed.connect(func(): guard_assignment_requested.emit(false))
	_game_over_dialog = ConfirmationDialog.new()
	_game_over_dialog.title = "Colony Fallen"
	_game_over_dialog.ok_button_text = "Return to Main Menu"
	_game_over_dialog.confirmed.connect(func(): menu_requested.emit())
	add_child(_game_over_dialog)
	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.title = "Reset Colony"
	_reset_dialog.dialog_text = "Start a fresh colony and world? Unsaved progress will be lost."
	_reset_dialog.confirmed.connect(func(): reset_requested.emit())
	add_child(_reset_dialog)
	_help_dialog = AcceptDialog.new()
	_help_dialog.title = "Gameplay Help"
	var help_text := RichTextLabel.new()
	help_text.text = GAMEPLAY_HELP
	help_text.custom_minimum_size = Vector2(720, 520)
	help_text.add_theme_color_override("default_color", Color(0.95, 0.95, 0.92))
	_help_dialog.add_child(help_text)
	var help_ok := _help_dialog.get_ok_button()
	for color_name in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		help_ok.add_theme_color_override(color_name, Color(0.12, 0.17, 0.14))
	add_child(_help_dialog)


func set_status(food: int, workers: int, explorers: int, defenders: int, materials: int = 0, guards: int = 0, food_capacity: int = 100, material_capacity: int = 100) -> void:
	var total_ants := workers + explorers + defenders + guards
	_status_label.text = "Food %d/%d  |  Materials %d/%d  |  Ants %d (%dW %dE %dD %dG)" % [food, food_capacity, materials, material_capacity, total_ants, workers, explorers, defenders, guards]


func set_paused(paused: bool) -> void:
	_pause_button.text = "Resume" if paused else "Pause"


func set_selection_summary(
	count: int,
	details: String = "",
	actions: String = "",
	show_assign_guard: bool = false,
	can_assign_guard: bool = false,
	show_unassign_guard: bool = false
) -> void:
	_selection_label.text = "Selected: %d   |   Ctrl+1-9 save group, 1-9 recall" % count
	_selection_details_label.text = details
	_selection_details_label.visible = not details.is_empty()
	_selection_actions_label.text = actions
	_selection_actions_label.visible = not actions.is_empty()
	_assign_guard_button.visible = show_assign_guard
	_assign_guard_button.disabled = not can_assign_guard
	_unassign_guard_button.visible = show_unassign_guard


func show_message(message: String) -> void:
	_message_label.text = message


func set_queen_status(demand: int, seconds_remaining: float, cycle: int, difficulty: String) -> void:
	var remaining := maxi(0, ceili(seconds_remaining))
	_queen_label.text = "Queen: %d food in %02d:%02d  |  Cycle %d  |  %s" % [
		demand, floori(float(remaining) / 60.0), remaining % 60, cycle + 1, difficulty.capitalize(),
	]
	if remaining <= 30:
		_queen_label.add_theme_color_override("font_color", Color(0.78, 0.16, 0.1))
	elif remaining <= 120:
		_queen_label.add_theme_color_override("font_color", Color(0.68, 0.37, 0.08))
	else:
		_queen_label.add_theme_color_override("font_color", Color(0.12, 0.17, 0.14, 1.0))


func show_game_over(message: String) -> void:
	_game_over_dialog.dialog_text = message
	_game_over_dialog.popup_centered()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is CodeEdit or focus_owner is LineEdit or focus_owner is TextEdit:
		return
	if key.keycode == KEY_C:
		_commands_panel.visible = not _commands_panel.visible
	elif key.keycode == KEY_V:
		_selection_panel.visible = not _selection_panel.visible


# Slim top bar keeps status visible; command buttons and the selection panel are pop-ups.
func _build_popup_toggles() -> void:
	var row: HBoxContainer = %StatusLabel.get_parent()
	var action_buttons: Array[Button] = [
		%WorkerButton, %ExplorerButton, %DefenderButton, _pause_button,
		%ResetButton, _rules_button, %BehaviorOverlayButton, %SaveSlotsButton, %MenuButton,
	]
	_commands_panel = PanelContainer.new()
	_commands_panel.visible = false
	_commands_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_commands_panel.offset_left = 8.0
	_commands_panel.offset_top = 48.0
	var grid := GridContainer.new()
	grid.columns = 3
	_commands_panel.add_child(grid)
	add_child(_commands_panel)
	for button in action_buttons:
		button.get_parent().remove_child(button)
		grid.add_child(button)
	row.add_child(_queen_label)
	_queen_label.get_parent().move_child(_queen_label, 1)
	row.add_child(_message_label)
	var commands_button := Button.new()
	commands_button.text = "Commands (C)"
	commands_button.pressed.connect(func(): _commands_panel.visible = not _commands_panel.visible)
	row.add_child(commands_button)
	var selection_button := Button.new()
	selection_button.text = "Selection (V)"
	selection_button.pressed.connect(func(): _selection_panel.visible = not _selection_panel.visible)
	row.add_child(selection_button)
	var top_bar: Control = row.get_parent()
	top_bar.offset_bottom = 40.0


func _build_selection_panel() -> void:
	var panel := PanelContainer.new()
	_selection_panel = panel
	panel.visible = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 8.0
	panel.offset_right = 760.0
	panel.offset_top = -190.0
	panel.offset_bottom = -8.0
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	panel.add_child(rows)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	rows.add_child(status_row)
	_selection_label = Label.new()
	_selection_label.text = "Selected: 0   |   Ctrl+1-9 save group, 1-9 recall"
	_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_selection_label)
	_selection_details_label = Label.new()
	_selection_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_selection_details_label)
	_selection_actions_label = Label.new()
	_selection_actions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_selection_actions_label)
	_queen_label = Label.new()
	_message_label = Label.new()
	var controls_row := GridContainer.new()
	controls_row.columns = 4
	controls_row.add_theme_constant_override("separation", 6)
	rows.add_child(controls_row)
	_add_selection_button(controls_row, "All", "all")
	_add_selection_button(controls_row, "Workers", str(AntWorker.Role.WORKER))
	_add_selection_button(controls_row, "Explorers", str(AntWorker.Role.EXPLORER))
	_add_selection_button(controls_row, "Defenders", str(AntWorker.Role.DEFENDER))
	_add_selection_button(controls_row, "Guards", str(AntWorker.Role.GUARD_POST))
	_build_button = Button.new()
	_build_button.text = "Build"
	controls_row.add_child(_build_button)
	_assign_guard_button = Button.new()
	_assign_guard_button.text = "Assign Guard"
	_assign_guard_button.visible = false
	controls_row.add_child(_assign_guard_button)
	_unassign_guard_button = Button.new()
	_unassign_guard_button.text = "Unassign"
	_unassign_guard_button.visible = false
	controls_row.add_child(_unassign_guard_button)
	var move_hint := Label.new()
	move_hint.text = "?"
	move_hint.tooltip_text = "Click/drag select · Shift add/remove · Right-click move · Ctrl+1-9 save group / 1-9 recall"
	move_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	controls_row.add_child(move_hint)


func _add_selection_button(row: GridContainer, title: String, scope: String) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(func(): selection_requested.emit(scope))
	row.add_child(button)


func _toggle_rules_editor() -> void:
	rules_editor.visible = not rules_editor.visible
	_rules_button.text = "Close Rules" if rules_editor.visible else "Edit Rules"
	if rules_editor.visible:
		rules_editor.focus_editor()


func _show_gameplay_help() -> void:
	_help_dialog.popup_centered(Vector2i(760, 680))
