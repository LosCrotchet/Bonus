class_name MainMenu
extends Control

signal single_player_requested(
	player_count: int,
	rules: GameRules,
	seed_value: int,
	use_custom_seed: bool,
	seed_text: String,
)
signal resume_game_requested
signal quit_requested

@onready var menu_panel: PanelContainer = %MenuPanel
@onready var single_player_panel: PanelContainer = %SinglePlayerPanel
@onready var settings_side_panel: AppSettingsPanel = %SettingsSidePanel
@onready var player_count_buttons: Array[Button] = [
	%PlayerCount2,
	%PlayerCount3,
	%PlayerCount4,
]
@onready var include_jokers_toggle: CheckBox = %IncludeJokersToggle
@onready var jokers_wild_row: HBoxContainer = %JokersWildRow
@onready var jokers_wild_toggle: CheckBox = %JokersWildToggle
@onready var wildcard_finish_row: HBoxContainer = %WildcardFinishRow
@onready var wildcard_finish_toggle: CheckBox = %WildcardFinishToggle
@onready var sequences_include_two_toggle: CheckBox = %SequencesIncludeTwoToggle
@onready var variable_draw_toggle: CheckBox = %VariableDrawToggle
@onready var custom_seed_toggle: CheckBox = %CustomSeedToggle
@onready var seed_input_row: HBoxContainer = %SeedInputRow
@onready var seed_input: LineEdit = %SeedInput
@onready var resume_prompt: VBoxContainer = %ResumePrompt
@onready var resume_details: Label = %ResumeDetails
@onready var start_game_button: Button = %StartGameButton
@onready var exit_game_button: Button = %ExitGameButton
@onready var exit_confirmation: HBoxContainer = %ExitConfirmation

var _active_secondary: Control
var _button_tweens: Dictionary = {}
var _transitioning := false
var _secondary_tween: Tween
var _secondary_targets: Dictionary = {}
var _menu_target_position := Vector2.ZERO


func _ready() -> void:
	AudioService.play_music(&"menu")
	%SinglePlayerButton.pressed.connect(_open_single_player)
	%SettingsButton.pressed.connect(_open_settings)
	%StartGameButton.pressed.connect(_start_single_player)
	%ContinueGameButton.pressed.connect(_continue_saved_game)
	%StartNewGameButton.pressed.connect(_discard_saved_game)
	%SinglePlayerBackButton.pressed.connect(_close_secondary)
	settings_side_panel.canceled.connect(_close_secondary)
	exit_game_button.pressed.connect(_show_exit_confirmation)
	%ExitYesButton.pressed.connect(_confirm_exit_game)
	%ExitNoButton.pressed.connect(_hide_exit_confirmation)
	include_jokers_toggle.toggled.connect(_on_include_jokers_toggled)
	jokers_wild_toggle.toggled.connect(_on_jokers_wild_toggled)
	custom_seed_toggle.toggled.connect(_on_custom_seed_toggled)
	seed_input.text_changed.connect(_on_seed_text_changed)
	SettingsService.language_changed.connect(_on_language_changed)
	_setup_player_count_buttons()
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
	_transitioning = true
	await get_tree().process_frame
	AudioService.play(&"ui_fade_in")
	var target_position := _menu_target_position
	menu_panel.position = target_position + Vector2(-menu_panel.size.x, 0.0)
	menu_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(menu_panel, "position", target_position, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_panel, "modulate:a", 1.0, 0.3)
	await tween.finished
	_transitioning = false


func play_exit_transition() -> void:
	_transitioning = true
	AudioService.play(&"ui_fade_out")
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


func _setup_player_count_buttons() -> void:
	var selected_count := _get_selected_player_count()
	for index in range(player_count_buttons.size()):
		var count := index + 2
		player_count_buttons[index].text = tr(&"UI_PLAYER_COUNT_OPTION").format(
			{"count": count},
		)
		player_count_buttons[index].set_meta(&"player_count", count)
		if count == selected_count:
			player_count_buttons[index].button_pressed = true


func _on_language_changed(_locale: String) -> void:
	_setup_player_count_buttons()
	if resume_prompt.visible:
		var payload := SaveGameService.load_game()
		if not payload.is_empty():
			_populate_resume_details(payload)


func _reset_single_player_options() -> void:
	include_jokers_toggle.button_pressed = true
	jokers_wild_toggle.button_pressed = true
	wildcard_finish_toggle.button_pressed = true
	sequences_include_two_toggle.button_pressed = false
	variable_draw_toggle.button_pressed = false
	custom_seed_toggle.button_pressed = false
	seed_input.text = ""
	_refresh_seed_controls()
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


func _on_custom_seed_toggled(_enabled: bool) -> void:
	_refresh_seed_controls()


func _on_seed_text_changed(_value: String) -> void:
	_refresh_seed_controls()


func _refresh_seed_controls() -> void:
	seed_input_row.visible = custom_seed_toggle.button_pressed and not resume_prompt.visible
	start_game_button.disabled = (
		custom_seed_toggle.button_pressed and not SeedCodec.is_valid(seed_input.text)
	)


func _open_single_player() -> void:
	if _active_secondary == single_player_panel and single_player_panel.visible:
		_close_secondary()
		return
	_show_secondary(single_player_panel)
	var payload := SaveGameService.load_game()
	var session_snapshot := payload.get("session", {}) as Dictionary
	var has_unfinished_game := (
		not payload.is_empty()
		and int(session_snapshot.get("phase", GameSession.Phase.FINISHED))
		!= GameSession.Phase.FINISHED
	)
	_set_resume_prompt_visible(has_unfinished_game)
	if has_unfinished_game:
		_populate_resume_details(payload)


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
	AudioService.play(&"ui_fade_in")
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
	AudioService.play(&"ui_fade_out")
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
	AudioService.play(&"ui_confirm")
	var rules := GameRules.new()
	rules.include_jokers = include_jokers_toggle.button_pressed
	rules.jokers_are_wild = jokers_wild_toggle.button_pressed
	rules.draw_two_on_wildcard_finish = wildcard_finish_toggle.button_pressed
	rules.allow_two_in_sequences = sequences_include_two_toggle.button_pressed
	rules.draw_count_uses_dice = variable_draw_toggle.button_pressed
	var use_custom_seed := custom_seed_toggle.button_pressed
	var seed_text := (
		SeedCodec.sanitize(seed_input.text)
		if use_custom_seed
		else SeedCodec.generate_random_text()
	)
	var seed_value := SeedCodec.to_int(seed_text)
	SaveGameService.clear_save()
	single_player_requested.emit(
		_get_selected_player_count(),
		rules,
		seed_value,
		use_custom_seed,
		seed_text,
	)


func _continue_saved_game() -> void:
	AudioService.play(&"ui_confirm")
	resume_game_requested.emit()


func _discard_saved_game() -> void:
	AudioService.play(&"ui_confirm")
	SaveGameService.clear_save()
	_set_resume_prompt_visible(false)


func _set_resume_prompt_visible(should_show: bool) -> void:
	resume_prompt.visible = should_show
	if not should_show:
		resume_details.text = ""
	for node in [
		%PlayerCountRow,
		%IncludeJokersRow,
		%JokersWildRow,
		%WildcardFinishRow,
		%SequencesIncludeTwoRow,
		%VariableDrawRow,
		%CustomSeedRow,
		%SeedInputRow,
		%Spacer,
		%StartGameButton,
	]:
		(node as CanvasItem).visible = not should_show
	if not should_show:
		_refresh_rule_dependencies()
		_refresh_seed_controls()


func _populate_resume_details(payload: Dictionary) -> void:
	var session_snapshot := payload.get("session", {}) as Dictionary
	var rules := session_snapshot.get("rules", {}) as Dictionary
	var player_count := (session_snapshot.get("players", []) as Array).size()
	var rule_names := PackedStringArray()
	if bool(rules.get("include_jokers", true)):
		rule_names.append(tr(&"RULE_INCLUDE_JOKERS"))
		if bool(rules.get("jokers_are_wild", true)):
			rule_names.append(tr(&"RULE_JOKERS_WILD"))
			if bool(rules.get("draw_two_on_wildcard_finish", true)):
				rule_names.append(tr(&"RULE_WILDCARD_FINISH_DRAW"))
			else:
				rule_names.append(tr(&"RULE_WILDCARD_FINISH_NO_DRAW"))
		else:
			rule_names.append(tr(&"RULE_JOKERS_NATURAL"))
	else:
		rule_names.append(tr(&"RULE_EXCLUDE_JOKERS"))
	rule_names.append(
		tr(&"RULE_SEQUENCE_WITH_TWO")
		if bool(rules.get("allow_two_in_sequences", false))
		else tr(&"RULE_SEQUENCE_WITHOUT_TWO")
	)
	rule_names.append(
		tr(&"RULE_VARIABLE_DRAW")
		if bool(rules.get("draw_count_uses_dice", false))
		else tr(&"RULE_FIXED_DRAW")
	)
	var seed_key := (
		&"UI_SEED_SUMMARY_CUSTOM"
		if bool(payload.get("custom_seed", false))
		else &"UI_SEED_SUMMARY_RANDOM"
	)
	var seed_summary := tr(seed_key).format({
		"seed": str(session_snapshot.get(
			"seed_text",
			SeedCodec.from_int(int(str(session_snapshot.get("game_seed", "0")))),
		)),
	})
	resume_details.text = "%s\n%s" % [
		tr(&"UI_SAVED_GAME_META").format({
			"count": player_count,
			"seed": seed_summary,
		}),
		tr(&"UI_SAVED_GAME_RULES").format({"rules": " · ".join(rule_names)}),
	]


func _get_selected_player_count() -> int:
	for button in player_count_buttons:
		if button.button_pressed:
			return int(button.get_meta(&"player_count", 3))
	return 3

func _show_exit_confirmation() -> void:
	exit_game_button.visible = false
	if _active_secondary != null:
		_close_secondary()
		await get_tree().create_timer(0.24).timeout
	AudioService.play(&"ui_confirm")
	exit_confirmation.visible = true


func _hide_exit_confirmation() -> void:
	if exit_confirmation.visible:
		AudioService.play(&"ui_cancel")
	exit_game_button.visible = true
	exit_confirmation.visible = false


func _confirm_exit_game() -> void:
	AudioService.play(&"ui_confirm")
	quit_requested.emit()


func _setup_button_motion() -> void:
	for button in [
		%SinglePlayerButton,
		%MultiplayerButton,
		%SettingsButton,
		exit_game_button,
		%StartGameButton,
		%ContinueGameButton,
		%StartNewGameButton,
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
