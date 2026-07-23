class_name MainMenu
extends Control

signal single_player_requested(player_count: int, rules: GameRules)
signal quit_requested

@onready var menu_panel: PanelContainer = %MenuPanel
@onready var single_player_panel: PanelContainer = %SinglePlayerPanel
@onready var settings_side_panel: AppSettingsPanel = %SettingsSidePanel
@onready var player_count_option: OptionButton = %PlayerCountOption
@onready var include_jokers_toggle: CheckButton = %IncludeJokersToggle
@onready var jokers_wild_row: HBoxContainer = %JokersWildRow
@onready var jokers_wild_toggle: CheckButton = %JokersWildToggle
@onready var wildcard_finish_row: HBoxContainer = %WildcardFinishRow
@onready var wildcard_finish_toggle: CheckButton = %WildcardFinishToggle
@onready var sequences_include_two_toggle: CheckButton = %SequencesIncludeTwoToggle
@onready var variable_draw_toggle: CheckButton = %VariableDrawToggle
@onready var exit_game_button: Button = %ExitGameButton
@onready var exit_confirmation: HBoxContainer = %ExitConfirmation

var _active_secondary: Control
var _button_tweens: Dictionary = {}
var _transitioning := false
var _secondary_tween: Tween
var _secondary_targets: Dictionary = {}
var _menu_target_position := Vector2.ZERO


func _ready() -> void:
	%SinglePlayerButton.pressed.connect(_open_single_player)
	%SettingsButton.pressed.connect(_open_settings)
	%StartGameButton.pressed.connect(_start_single_player)
	%SinglePlayerBackButton.pressed.connect(_close_secondary)
	settings_side_panel.canceled.connect(_close_secondary)
	exit_game_button.pressed.connect(_show_exit_confirmation)
	%ExitYesButton.pressed.connect(func() -> void: quit_requested.emit())
	%ExitNoButton.pressed.connect(_hide_exit_confirmation)
	include_jokers_toggle.toggled.connect(_on_include_jokers_toggled)
	jokers_wild_toggle.toggled.connect(_on_jokers_wild_toggled)
	_populate_player_counts()
	_reset_single_player_options()
	single_player_panel.visible = false
	settings_side_panel.visible = false
	_hide_exit_confirmation()
	_setup_button_motion()
	await get_tree().process_frame
	_menu_target_position = menu_panel.position
	_secondary_targets = {
		single_player_panel: single_player_panel.position,
		settings_side_panel: settings_side_panel.position,
	}


func play_enter_transition() -> void:
	await get_tree().process_frame
	var target_position := _menu_target_position
	menu_panel.position = target_position + Vector2(-menu_panel.size.x, 0.0)
	menu_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(menu_panel, "position", target_position, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.3)
	await tween.finished


func play_exit_transition() -> void:
	_transitioning = true
	if _secondary_tween != null:
		_secondary_tween.kill()
	var tween := create_tween().set_parallel(true)
	menu_panel.position = _menu_target_position
	tween.tween_property(menu_panel, "position", _menu_target_position + Vector2(-menu_panel.size.x, 0.0), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(menu_panel, "modulate:a", 0.0, 0.25)
	if _active_secondary != null and _active_secondary.visible:
		var target := _get_secondary_target(_active_secondary)
		_active_secondary.position = target
		tween.tween_property(_active_secondary, "position", target + Vector2(-_active_secondary.size.x, 0.0), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(_active_secondary, "modulate:a", 0.0, 0.24)
	await tween.finished


func _populate_player_counts() -> void:
	player_count_option.clear()
	for count in range(2, 5):
		player_count_option.add_item(
			tr(&"UI_PLAYER_COUNT_OPTION").format({"count": count}),
			count,
		)
		if count == 3:
			player_count_option.select(player_count_option.item_count - 1)


func _reset_single_player_options() -> void:
	include_jokers_toggle.button_pressed = true
	jokers_wild_toggle.button_pressed = true
	wildcard_finish_toggle.button_pressed = true
	sequences_include_two_toggle.button_pressed = false
	variable_draw_toggle.button_pressed = false
	_refresh_rule_dependencies()


func _on_include_jokers_toggled(enabled: bool) -> void:
	if not enabled:
		jokers_wild_toggle.set_pressed_no_signal(false)
	_refresh_rule_dependencies()


func _on_jokers_wild_toggled(enabled: bool) -> void:
	if not enabled:
		wildcard_finish_toggle.set_pressed_no_signal(false)
	_refresh_rule_dependencies()


func _refresh_rule_dependencies() -> void:
	var show_wild_rules := include_jokers_toggle.button_pressed
	if not show_wild_rules:
		jokers_wild_toggle.set_pressed_no_signal(false)
	if not show_wild_rules or not jokers_wild_toggle.button_pressed:
		wildcard_finish_toggle.set_pressed_no_signal(false)
	jokers_wild_row.visible = show_wild_rules
	var show_finish_rule := show_wild_rules and jokers_wild_toggle.button_pressed
	wildcard_finish_row.visible = show_finish_rule


func _open_single_player() -> void:
	if _active_secondary == single_player_panel and single_player_panel.visible:
		_close_secondary()
		return
	_show_secondary(single_player_panel)


func _open_settings() -> void:
	if _active_secondary == settings_side_panel and settings_side_panel.visible:
		_close_secondary()
		return
	settings_side_panel.begin_edit()
	_show_secondary(settings_side_panel)


func _show_secondary(panel: Control) -> void:
	if _transitioning:
		return
	if _secondary_tween != null:
		_secondary_tween.kill()
	if _active_secondary != null and _active_secondary != panel:
		_active_secondary.position = _get_secondary_target(_active_secondary)
		_active_secondary.modulate.a = 1.0
		_active_secondary.visible = false
	_active_secondary = panel
	var target_position := _get_secondary_target(panel)
	panel.visible = true
	panel.position = target_position + Vector2(-44.0, 0.0)
	panel.modulate.a = 0.0
	_secondary_tween = create_tween().set_parallel(true)
	_secondary_tween.tween_property(panel, "position", target_position, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_secondary_tween.tween_property(panel, "modulate:a", 1.0, 0.22)


func _close_secondary() -> void:
	if _active_secondary == null or not _active_secondary.visible:
		return
	var panel := _active_secondary
	_active_secondary = null
	if _secondary_tween != null:
		_secondary_tween.kill()
	var target_position := _get_secondary_target(panel)
	panel.position = target_position
	_secondary_tween = create_tween().set_parallel(true)
	_secondary_tween.tween_property(panel, "position", target_position + Vector2(-36.0, 0.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_secondary_tween.tween_property(panel, "modulate:a", 0.0, 0.18)
	_secondary_tween.chain().tween_callback(
		func() -> void:
			panel.visible = false
			panel.position = target_position
			panel.modulate.a = 1.0
	)


func _input(event: InputEvent) -> void:
	if (
		_active_secondary == null
		or event is not InputEventMouseButton
		or event.button_index != MOUSE_BUTTON_RIGHT
		or not event.pressed
	):
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered is BaseButton or hovered is LineEdit or hovered is SpinBox:
		return
	_close_secondary()
	get_viewport().set_input_as_handled()


func _get_secondary_target(panel: Control) -> Vector2:
	return _secondary_targets.get(panel, panel.position) as Vector2


func _start_single_player() -> void:
	if _transitioning:
		return
	var rules := GameRules.new()
	rules.include_jokers = include_jokers_toggle.button_pressed
	rules.jokers_are_wild = jokers_wild_toggle.button_pressed
	rules.draw_two_on_wildcard_finish = wildcard_finish_toggle.button_pressed
	rules.allow_two_in_sequences = sequences_include_two_toggle.button_pressed
	rules.draw_count_uses_dice = variable_draw_toggle.button_pressed
	single_player_requested.emit(player_count_option.get_selected_id(), rules)


func _show_exit_confirmation() -> void:
	exit_game_button.visible = false
	exit_confirmation.visible = true


func _hide_exit_confirmation() -> void:
	exit_game_button.visible = true
	exit_confirmation.visible = false


func _setup_button_motion() -> void:
	for button in [
		%SinglePlayerButton,
		%MultiplayerButton,
		%SettingsButton,
		exit_game_button,
		%StartGameButton,
		%SinglePlayerBackButton,
		%ExitYesButton,
		%ExitNoButton,
	]:
		var typed_button := button as Button
		typed_button.mouse_entered.connect(
			func() -> void: _tween_button(typed_button, Vector2(1.025, 1.025))
		)
		typed_button.mouse_exited.connect(
			func() -> void: _tween_button(typed_button, Vector2.ONE)
		)
		typed_button.button_down.connect(
			func() -> void: _tween_button(typed_button, Vector2(0.98, 0.98))
		)
		typed_button.button_up.connect(
			func() -> void: _tween_button(typed_button, Vector2(1.025, 1.025))
		)


func _tween_button(button: Button, target_scale: Vector2) -> void:
	if _button_tweens.has(button):
		(_button_tweens[button] as Tween).kill()
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", target_scale, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_button_tweens[button] = tween
