extends Control

signal return_to_menu_requested
signal tutorial_event(event_key: StringName, payload: Dictionary)
signal tutorial_gameplay_unlocked

const DEFAULT_PLAYER_COUNT := 3
const DICE_ROOT := "res://assets/art/dice/"
const INACTIVE_BORDER_COLOR := Color(0.25, 0.4, 0.36, 0.75)
const FLOW_BORDER_SHADER := preload("res://assets/shaders/flow_border.gdshader")
const DISCONNECTED_SHADER := preload("res://assets/shaders/disconnected_grayscale.gdshader")
const DISCONNECT_ICON := preload("res://assets/icons/disconnect_icon.png")
const CARTOON_CONTROLS := preload("res://assets/themes/cartoon_ui/controls.tres")
const NETWORK_GAME_VIEW = preload("res://multiplayer/session/network_game_view.gd")
const TUTORIAL_DIRECTOR_SCENE := preload(
	"res://features/tutorial/tutorial_director.tscn"
)
const DEFAULT_TUTORIAL_SCENARIO := preload(
	"res://features/tutorial/content/default_tutorial.tres"
)
const PLAYED_CARD_REVEAL_DURATION := 0.22
const FLYING_CARD_FADE_DURATION := 0.06
const SCENE_TRANSITION_DURATION := 0.38
const BONUS_DICE_FRAME_INTERVAL := 0.14

@onready var settings_button: Button = %SettingsButton
@onready var hand_types_button: Button = %HandTypesButton
@onready var header_title: Label = %HeaderTitle
@onready var header_seed: Label = %HeaderSeed
@onready var hand_types_overlay: Control = %HandTypesOverlay
@onready var hand_types_dialog: HandTypesDialog = %HandTypesDialog
@onready var hand_types_dismiss_button: Button = %HandTypesDismissButton
@onready var settings_overlay: Control = %SettingsOverlay
@onready var settings_panel: AppSettingsPanel = %SettingsPanel
@onready var settings_dismiss_button: Button = %SettingsDismissButton
@onready var status_label: Label = %StatusLabel
@onready var deck_count_label: Label = %DeckCountLabel
@onready var draw_pile_view: TextureRect = %DrawPile
@onready var dice_button: TextureButton = %DiceButton
@onready var dice_value_label: Label = %DiceValue
@onready var roll_panel: PanelContainer = %RollPanel
@onready var played_panel: PanelContainer = %PlayedPanel
@onready var table_band: PanelContainer = %TableBand
@onready var table_bonus_effect: ColorRect = %TableBonusEffect
@onready var played_cards: HBoxContainer = %PlayedCards
@onready var played_caption: Label = %PlayedCaption
@onready var instruction_hint: Control = %InstructionHint
@onready var select_hint_text: Label = %SelectHintText
@onready var clear_hint_text: Label = %ClearHintText
@onready var auto_roll_button: TextureButton = %AutoRollButton
@onready var auto_skip_button: TextureButton = %AutoSkipButton
@onready var auto_play_button: TextureButton = %AutoPlayButton
@onready var auto_roll_check: Label = %AutoRollCheck
@onready var auto_skip_check: Label = %AutoSkipCheck
@onready var auto_play_check: Label = %AutoPlayCheck
@onready var action_bar: HBoxContainer = %ActionBar
@onready var hint_button: Button = %HintButton
@onready var pass_button: Button = %PassButton
@onready var play_button: Button = %PlayButton
@onready var hand_panel: PanelContainer = %HandPanel
@onready var bonus_effect: ColorRect = %BonusEffect
@onready var hand_title: Label = %HandTitle
@onready var hand_view: HandView = %HandView
@onready var selected_label: Label = %SelectedLabel
@onready var selection_type_label: Label = %SelectionTypeLabel
@onready var turn_indicator: Control = %TurnIndicator
@onready var turn_timer: Control = %TurnTimer
@onready var turn_seconds_label: Label = %TurnSeconds
@onready var interpretation_popup: PopupPanel = %InterpretationPopup
@onready var interpretation_options: VBoxContainer = %InterpretationOptions
@onready var result_overlay: Control = %ResultOverlay
@onready var winner_label: Label = %WinnerLabel
@onready var restart_button: Button = %RestartButton
@onready var result_menu_button: Button = %ResultMenuButton

var _session: GameSession
var _human_player_index := 0
var _network_mode := false
var _tutorial_mode := false
var _tutorial_scenario: TutorialScenario
var _tutorial_director: TutorialDirector
var _tutorial_gameplay_locked := false
var _tutorial_input_locks := 0
var _tutorial_show_locked_action_bar := false
var _tutorial_state_signature := ""
var _pending_tutorial_ai_commands: Dictionary = {}
var _tutorial_first_human_roll_pending := false
var _tutorial_needs_next_player_intro := false
var tutorial_core_explained := false
var tutorial_draw_explained := false
var tutorial_bonus_lesson_complete := false
var _tutorial_completion_requested := false
var tutorial_bonus_explained := false
var _network_initial_snapshot: Dictionary = {}
var _network_player_meta: Dictionary = {}
var _selected_card_ids: Array[int] = []
var _player_count := DEFAULT_PLAYER_COUNT
var _game_rules := GameRules.new()
var _embedded_in_app := false
var _configured_seed := 0
var _use_custom_seed := false
var _configured_seed_text := ""
var _resume_payload: Dictionary = {}
var _transient_key: StringName = &""
var _transient_args: Dictionary = {}
var _strategies: Dictionary = {}
var _seat_views := {}
var _pending_interpretations: Array[HandPattern] = []
var _ai_task_running := false
var _rolling := false
var _game_serial := 0
var _last_bonus_state := false
var _actions_should_show := false
var _dice_hovered := false
var _dice_rest_position := Vector2.ZERO
var _dice_prompt_tween: Tween
var _draw_pile_rest_position := Vector2.ZERO
var _draw_pile_tween: Tween
var _draw_pile_activity_tween: Tween
var _action_bar_tween: Tween
var _action_bar_rest_position := Vector2.ZERO
var _action_bar_layout_ready := false
var _settings_tween: Tween
var _hand_types_tween: Tween
var _status_tween: Tween
var _table_bonus_tween: Tween
var _flow_borders: Dictionary = {}
var _seat_card_counts: Dictionary = {}
var _panel_active_states: Dictionary = {}
var _bonus_dice_elapsed := 0.0
var _bonus_dice_frame := 0
var _automation_pending := false
var _last_status_message := ""
var _indicator_player_index := -1
var _presentation_busy := false
var _last_play_signature := ""
var _last_human_hand_count := -1
var _dealing := false
var _deal_animation_running := false
var _deal_visible_counts := PackedInt32Array()
var _deal_flying_cards: Array[TextureRect] = []
var _session_revision := 0
var _automation_checked_revision := -1
var _automation_generation := 0
var _auto_roll_enabled := false
var _auto_skip_enabled := false
var _auto_play_enabled := false
var _human_auto_strategy: PlayerStrategy
var _bonus_sound_step := 0
var _round_start_sound_played := false
var _presentation_random := RandomNumberGenerator.new()
var _last_network_revision := -1
var _last_network_timer_second := -1
var _disconnect_icons: Dictionary = {}
var _turn_timer_tween: Tween
var _played_reveal_tween: Tween
var _indicator_update_suspended := false
var _instruction_tween: Tween
var _instruction_should_show := false
var _disconnected_material := ShaderMaterial.new()


func configure(
	player_count: int,
	game_rules: GameRules = null,
	embedded_in_app: bool = false,
	seed_value: int = 0,
	use_custom_seed: bool = false,
	seed_text: String = "",
) -> void:
	_player_count = clampi(player_count, 2, 4)
	_game_rules = game_rules.clone() if game_rules != null else GameRules.new()
	_embedded_in_app = embedded_in_app
	_configured_seed = seed_value
	_use_custom_seed = use_custom_seed
	_configured_seed_text = SeedCodec.sanitize(seed_text)
	_resume_payload.clear()


func configure_resume(payload: Dictionary, embedded_in_app: bool = false) -> void:
	_resume_payload = payload.duplicate(true)
	_embedded_in_app = embedded_in_app


func configure_network(snapshot: Dictionary, embedded_in_app: bool = false) -> void:
	_network_mode = true
	_network_initial_snapshot = snapshot.duplicate(true)
	_human_player_index = int(snapshot.get("local_player_index", 0))
	_embedded_in_app = embedded_in_app


func configure_tutorial(
	embedded_in_app: bool = false,
	scenario: TutorialScenario = null,
) -> void:
	_tutorial_mode = true
	_tutorial_scenario = scenario if scenario != null else DEFAULT_TUTORIAL_SCENARIO
	_player_count = clampi(_tutorial_scenario.player_count, 2, 4)
	_game_rules = _tutorial_scenario.build_rules()
	_configured_seed_text = SeedCodec.sanitize(_tutorial_scenario.seed_text)
	_configured_seed = SeedCodec.to_int(_configured_seed_text)
	_use_custom_seed = false
	_embedded_in_app = embedded_in_app
	_resume_payload.clear()


func _ready() -> void:
	theme = CARTOON_CONTROLS
	_disconnected_material.shader = DISCONNECTED_SHADER
	AudioService.play_music(&"game")
	_presentation_random.randomize()
	CardTextureCatalog.warm_up()
	_finish_card_texture_warmup.call_deferred()
	settings_button.pressed.connect(_on_settings_pressed)
	hand_types_button.pressed.connect(_open_hand_types)
	hand_types_dialog.close_requested.connect(_close_hand_types)
	hand_types_dismiss_button.pressed.connect(_close_hand_types)
	settings_dismiss_button.pressed.connect(settings_panel.cancel_edit)
	settings_panel.applied.connect(_on_settings_applied)
	settings_panel.canceled.connect(_close_settings)
	settings_panel.return_to_menu_requested.connect(_on_return_to_menu_requested)
	interpretation_popup.popup_hide.connect(_on_interpretation_popup_hidden)
	dice_button.pressed.connect(_on_dice_pressed)
	dice_button.mouse_entered.connect(_on_dice_mouse_entered)
	dice_button.mouse_exited.connect(_on_dice_mouse_exited)
	draw_pile_view.mouse_entered.connect(_on_draw_pile_mouse_entered)
	draw_pile_view.mouse_exited.connect(_on_draw_pile_mouse_exited)
	hint_button.pressed.connect(_on_hint_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	play_button.pressed.connect(_on_play_pressed)
	_setup_automation_controls()
	restart_button.pressed.connect(_on_restart_pressed)
	result_menu_button.pressed.connect(_on_return_to_menu_requested)
	hand_view.selection_changed.connect(_on_hand_selection_changed)
	SettingsService.language_changed.connect(_on_language_changed)
	SettingsService.settings_changed.connect(_on_settings_changed)
	LanMultiplayerService.game_snapshot_received.connect(_on_network_snapshot_received)
	LanMultiplayerService.game_started.connect(_on_network_game_restarted)
	LanMultiplayerService.lobby_updated.connect(_on_network_lobby_updated)
	LanMultiplayerService.network_error.connect(_on_network_error)
	LanMultiplayerService.match_ended.connect(_on_network_match_ended)

	_seat_views = {
		"SEAT_NORTH": {
			"panel": %NorthSeat,
			"name": %NorthName,
			"count": %NorthCount,
			"cards": %NorthCards,
		},
		"SEAT_WEST": {
			"panel": %WestSeat,
			"name": %WestName,
			"count": %WestCount,
			"cards": %WestCards,
		},
		"SEAT_EAST": {
			"panel": %EastSeat,
			"name": %EastName,
			"count": %EastCount,
			"cards": %EastCards,
		},
	}

	action_bar.visible = false
	action_bar.modulate.a = 0.0
	settings_overlay.visible = false
	hand_types_overlay.visible = false
	_setup_flow_borders()
	_setup_tutorial_director()
	if _embedded_in_app:
		%Background.visible = false
	if _network_mode:
		_start_network_game(_network_initial_snapshot)
	elif _resume_payload.is_empty() or not _restore_saved_game():
		_start_new_game(not _embedded_in_app)
	await get_tree().process_frame
	_action_bar_rest_position = action_bar.position
	_action_bar_layout_ready = true
	_update_instruction_text()
	_dice_rest_position = dice_button.position
	dice_button.pivot_offset = dice_button.size * 0.5
	_draw_pile_rest_position = draw_pile_view.position
	draw_pile_view.pivot_offset = draw_pile_view.size * 0.5
	_setup_button_motion()
	_refresh_dice_prompt()


func _finish_card_texture_warmup() -> void:
	await get_tree().create_timer(0.2, false).timeout
	CardTextureCatalog.finish_warm_up()


func _process(delta: float) -> void:
	if _network_mode:
		var timer_second := LanMultiplayerService.get_turn_seconds_remaining()
		if timer_second != _last_network_timer_second:
			_last_network_timer_second = timer_second
			turn_seconds_label.text = str(timer_second)
	if _session == null or not _session.is_bonus or _rolling:
		_bonus_dice_elapsed = 0.0
		return
	_bonus_dice_elapsed += delta
	if _bonus_dice_elapsed < BONUS_DICE_FRAME_INTERVAL:
		return
	_bonus_dice_elapsed = 0.0
	var next_frame := _presentation_random.randi_range(0, 4)
	if next_frame >= _bonus_dice_frame:
		next_frame += 1
	_bonus_dice_frame = next_frame
	dice_button.texture_normal = _dice_texture(_bonus_dice_frame + 1)
	dice_button.modulate = Color.WHITE


func _start_new_game(start_deal_animation: bool = true) -> void:
	_game_serial += 1
	_ai_task_running = false
	_rolling = false
	_last_bonus_state = false
	_reset_table_bonus_effect()
	_pending_interpretations.clear()
	_selected_card_ids.clear()
	_automation_pending = false
	_presentation_busy = false
	_indicator_player_index = -1
	_last_play_signature = ""
	_last_human_hand_count = -1
	_bonus_sound_step = 0
	_round_start_sound_played = false
	_seat_card_counts.clear()
	_panel_active_states.clear()
	played_panel.modulate.a = 1.0
	_session_revision = 0
	_automation_checked_revision = -1
	_tutorial_state_signature = ""
	_pending_tutorial_ai_commands.clear()
	_tutorial_first_human_roll_pending = (
		_tutorial_mode
		and _tutorial_scenario != null
		and _tutorial_scenario.forced_first_human_roll > 0
	)
	_tutorial_needs_next_player_intro = false
	tutorial_core_explained = false
	tutorial_draw_explained = false
	tutorial_bonus_lesson_complete = false
	_tutorial_completion_requested = false
	tutorial_bonus_explained = false
	_dealing = true
	_deal_animation_running = false
	_deal_visible_counts = PackedInt32Array()
	_clear_transient()
	_stop_dice_prompt()
	interpretation_popup.hide()
	_reset_draw_pile_activity()

	_session = GameSession.new()
	_session.state_changed.connect(_on_session_state_changed)
	_session.game_finished.connect(_on_game_finished)
	_session.action_resolved.connect(_on_public_action_resolved)
	_session.start_game(
		_player_names_for_count(_player_count),
		_configured_seed,
		_game_rules,
		_configured_seed_text,
	)
	_initialize_strategies()
	_deal_visible_counts.resize(_session.players.size())
	_deal_visible_counts.fill(0)
	result_overlay.visible = false
	_refresh()
	if _tutorial_director != null:
		_tutorial_director.restart()
	if start_deal_animation:
		_run_initial_deal.call_deferred(_game_serial)


func _start_network_game(snapshot: Dictionary) -> void:
	_game_serial += 1
	_ai_task_running = false
	_rolling = false
	_last_bonus_state = false
	_reset_table_bonus_effect()
	_pending_interpretations.clear()
	_selected_card_ids.clear()
	_automation_pending = false
	_presentation_busy = false
	_indicator_player_index = -1
	_last_play_signature = ""
	_last_human_hand_count = -1
	_bonus_sound_step = 0
	_round_start_sound_played = false
	_seat_card_counts.clear()
	_panel_active_states.clear()
	_session_revision = int(snapshot.get("revision", 0))
	_last_network_revision = _session_revision
	_automation_checked_revision = -1
	_dealing = false
	_deal_animation_running = false
	_clear_transient()
	_stop_dice_prompt()
	interpretation_popup.hide()
	_reset_draw_pile_activity()

	_session = GameSession.new()
	if not NETWORK_GAME_VIEW.apply_snapshot(_session, snapshot):
		_on_network_match_ended(&"LAN_ERROR_PROTOCOL_MISMATCH")
		return
	_human_player_index = int(snapshot.get("local_player_index", 0))
	_player_count = _session.players.size()
	_game_rules = _session.rules.clone()
	_configured_seed_text = _session.game_seed_text
	_initialize_human_auto_strategy()
	_update_network_player_meta(snapshot)
	_deal_visible_counts.resize(_player_count)
	for player_index in range(_player_count):
		_deal_visible_counts[player_index] = _session.players[player_index].hand.size()
	result_overlay.visible = false
	_refresh()


func _on_network_snapshot_received(snapshot: Dictionary) -> void:
	if not _network_mode or _session == null:
		return
	var revision := int(snapshot.get("revision", 0))
	if revision <= _last_network_revision:
		return
	var previous_counts := _snapshot_hand_counts()
	var previous_phase := _session.phase
	var action := snapshot.get("public_action", {}) as Dictionary
	if not NETWORK_GAME_VIEW.apply_snapshot(_session, snapshot):
		_on_network_error(&"LAN_ERROR_PROTOCOL_MISMATCH")
		return
	_last_network_revision = revision
	_session_revision = revision
	_update_network_player_meta(snapshot)
	_rolling = false
	dice_button.rotation = 0.0
	var action_type := StringName(str(action.get("type", "")))
	var actor := int(action.get("player_index", -1))
	var is_play_action := action_type == &"play"
	_presentation_busy = is_play_action
	_indicator_update_suspended = is_play_action
	if not action.is_empty():
		_on_public_action_resolved(action)
		match action_type:
			&"pass":
				if actor != _human_player_index:
					_show_pass_feedback(actor)
			&"play":
				if actor != _human_player_index:
					await _animate_ai_card_play(
						actor,
						(action.get("cards", []) as Array).size(),
					)
	_refresh()
	if is_play_action:
		if not await _wait_for_play_presentation(_game_serial):
			_indicator_update_suspended = false
			return
		_indicator_update_suspended = false
		_presentation_busy = false
		_refresh()
	await _animate_non_human_draws(previous_counts)
	if previous_phase != GameSession.Phase.FINISHED and _session.phase == GameSession.Phase.FINISHED:
		_on_game_finished(_session.winner_index)


func _on_network_game_restarted(snapshot: Dictionary) -> void:
	if not _network_mode or _network_initial_snapshot == snapshot:
		return
	_network_initial_snapshot = snapshot.duplicate(true)
	_start_network_game(snapshot)


func _update_network_player_meta(snapshot: Dictionary) -> void:
	_network_player_meta.clear()
	for value in snapshot.get("players", []) as Array:
		if value is Dictionary:
			var player := value as Dictionary
			_network_player_meta[int(player.get("player_index", -1))] = player.duplicate(true)


func _on_network_lobby_updated(_snapshot: Dictionary) -> void:
	if _network_mode:
		_refresh()


func _on_network_error(error_key: StringName) -> void:
	if not _network_mode:
		return
	_presentation_busy = false
	hand_view.set_cards_animation_hidden(_selected_card_ids, false)
	_set_transient(error_key)
	_refresh()


func _on_network_match_ended(reason_key: StringName) -> void:
	if not _network_mode:
		return
	_set_transient(reason_key)
	_refresh()
	_return_after_network_end.call_deferred(_game_serial)


func _return_after_network_end(serial: int) -> void:
	await get_tree().create_timer(1.8, false).timeout
	if serial == _game_serial:
		return_to_menu_requested.emit()


func _restore_saved_game() -> bool:
	var session_snapshot := _resume_payload.get("session", {}) as Dictionary
	if session_snapshot.is_empty():
		return false
	_game_serial += 1
	_ai_task_running = false
	_rolling = false
	_last_bonus_state = false
	_reset_table_bonus_effect()
	_pending_interpretations.clear()
	_selected_card_ids.clear()
	_automation_pending = false
	_presentation_busy = false
	_indicator_player_index = -1
	_last_play_signature = ""
	_last_human_hand_count = -1
	_bonus_sound_step = 0
	_round_start_sound_played = false
	_seat_card_counts.clear()
	_panel_active_states.clear()
	_session_revision = 0
	_automation_checked_revision = -1
	_dealing = false
	_deal_animation_running = false
	_clear_transient()
	_stop_dice_prompt()
	interpretation_popup.hide()
	_reset_draw_pile_activity()

	_session = GameSession.new()
	_session.state_changed.connect(_on_session_state_changed)
	_session.game_finished.connect(_on_game_finished)
	_session.action_resolved.connect(_on_public_action_resolved)
	if not _session.restore_from_snapshot(session_snapshot):
		_resume_payload.clear()
		return false
	_player_count = _session.players.size()
	_game_rules = _session.rules.clone()
	_configured_seed = _session.game_seed
	_configured_seed_text = _session.game_seed_text
	_use_custom_seed = bool(_resume_payload.get("custom_seed", false))
	_deal_visible_counts.resize(_player_count)
	for player_index in range(_player_count):
		_deal_visible_counts[player_index] = _session.players[player_index].hand.size()
	result_overlay.visible = false
	_initialize_strategies()
	_refresh()
	_resume_payload.clear()
	return true


func _on_restart_pressed() -> void:
	AudioService.play(&"ui_confirm")
	if _network_mode:
		if LanMultiplayerService.is_host:
			LanMultiplayerService.restart_game()
		return
	_start_new_game()


func _player_names_for_count(count: int) -> Array[String]:
	# The array is turn order. Empty compass seats are skipped.
	match count:
		2:
			return ["SEAT_SOUTH", "SEAT_NORTH"]
		3:
			return ["SEAT_SOUTH", "SEAT_NORTH", "SEAT_WEST"]
		4:
			return ["SEAT_SOUTH", "SEAT_EAST", "SEAT_NORTH", "SEAT_WEST"]
	return ["SEAT_SOUTH", "SEAT_NORTH", "SEAT_WEST"]


func _initialize_strategies() -> void:
	_strategies.clear()
	_initialize_human_auto_strategy()
	for player_index in range(1, _session.players.size()):
		var strategy := StrategyRegistry.create(
			&"tutorial" if _tutorial_mode else &"default",
		)
		strategy.setup(player_index, _session.players.size())
		_strategies[player_index] = strategy
		_flush_tutorial_ai_commands(player_index)


func _initialize_human_auto_strategy() -> void:
	_human_auto_strategy = StrategyRegistry.create(&"default")
	_human_auto_strategy.setup(_human_player_index, _session.players.size())


func _setup_tutorial_director() -> void:
	if not _tutorial_mode or _tutorial_scenario == null:
		return
	_tutorial_director = TUTORIAL_DIRECTOR_SCENE.instantiate() as TutorialDirector
	add_child(_tutorial_director)
	_tutorial_director.setup(self, _tutorial_scenario)


func set_tutorial_gameplay_locked(locked: bool) -> void:
	if not _tutorial_mode or _tutorial_gameplay_locked == locked:
		return
	_tutorial_gameplay_locked = locked
	if locked:
		_automation_generation += 1
		_automation_pending = false
		hand_view.set_interaction_enabled(false)
		_stop_dice_prompt()
	else:
		_automation_checked_revision = -1
		tutorial_gameplay_unlocked.emit()
	for button in [auto_roll_button, auto_skip_button, auto_play_button]:
		button.disabled = locked
	_refresh.call_deferred()


func set_tutorial_input_locks(input_locks: int) -> void:
	if not _tutorial_mode:
		return
	_tutorial_input_locks = input_locks
	if _has_tutorial_input_lock(TutorialStep.InputLock.AUTOMATION):
		_automation_generation += 1
		_automation_pending = false
	for button in [auto_roll_button, auto_skip_button, auto_play_button]:
		button.disabled = (
			_tutorial_gameplay_locked
			or _has_tutorial_input_lock(TutorialStep.InputLock.AUTOMATION)
		)
	_refresh.call_deferred()


func set_tutorial_action_bar_override(enabled: bool) -> void:
	if not _tutorial_mode or _tutorial_show_locked_action_bar == enabled:
		return
	_tutorial_show_locked_action_bar = enabled
	_refresh.call_deferred()


func _has_tutorial_input_lock(input_lock: int) -> bool:
	return _tutorial_mode and (_tutorial_input_locks & input_lock) != 0


func is_tutorial_input_passthrough_point(point: Vector2) -> bool:
	if settings_overlay.visible or hand_types_overlay.visible:
		return true
	return (
		settings_button.get_global_rect().has_point(point)
		or hand_types_button.get_global_rect().has_point(point)
	)


func queue_tutorial_ai_command(player_index: int, command: Dictionary) -> void:
	if not _tutorial_mode or player_index <= 0:
		return
	var strategy := _strategies.get(player_index) as TutorialStrategy
	if strategy != null:
		strategy.queue_command(command)
		return
	var pending := _pending_tutorial_ai_commands.get(player_index, []) as Array
	pending.append(command.duplicate(true))
	_pending_tutorial_ai_commands[player_index] = pending


func mark_tutorial_step_shown(step_id: StringName) -> void:
	if step_id in [&"bonus_human", &"bonus_other", &"bonus_human_late", &"bonus_other_late"]:
		tutorial_bonus_explained = true


func mark_tutorial_step_finished(step_id: StringName) -> void:
	if not _tutorial_mode or step_id.is_empty():
		return
	match step_id:
		&"joker_reminder":
			tutorial_core_explained = true
		&"next_player_intro":
			tutorial_draw_explained = true
		&"bonus_human", &"bonus_other":
			tutorial_bonus_lesson_complete = true
	_maybe_finish_tutorial_lessons.call_deferred()


func _maybe_finish_tutorial_lessons() -> void:
	if (
		_tutorial_completion_requested
		or not tutorial_core_explained
		or not tutorial_draw_explained
		or not tutorial_bonus_lesson_complete
	):
		return
	_tutorial_completion_requested = true
	_notify_tutorial_event(&"tutorial_lessons_finished")


func _flush_tutorial_ai_commands(player_index: int) -> void:
	var strategy := _strategies.get(player_index) as TutorialStrategy
	if strategy == null:
		return
	for command in _pending_tutorial_ai_commands.get(player_index, []) as Array:
		strategy.queue_command(command as Dictionary)
	_pending_tutorial_ai_commands.erase(player_index)


func _refresh_tutorial_state() -> void:
	if not _tutorial_mode or _tutorial_director == null or _session == null:
		return
	var signature := "%d:%d:%d:%s" % [
		_session.phase,
		_session.current_player_index,
		_session.dice_value,
		str(_session.is_bonus),
	]
	if signature == _tutorial_state_signature:
		return
	_tutorial_state_signature = signature
	var payload := {
		"player_index": _session.current_player_index,
		"dice_value": _session.dice_value,
		"is_bonus": _session.is_bonus,
	}
	_notify_tutorial_event(&"turn_changed", payload)
	if _session.phase == GameSession.Phase.AWAITING_ROLL:
		_notify_tutorial_event(&"awaiting_roll", payload)
	elif _session.phase == GameSession.Phase.AWAITING_ACTION:
		_notify_tutorial_event(&"awaiting_action", payload)


func _notify_tutorial_event(
	event_key: StringName,
	payload: Dictionary = {},
) -> void:
	if not _tutorial_mode:
		return
	tutorial_event.emit(event_key, payload.duplicate(true))
	if _tutorial_director != null:
		_tutorial_director.notify_event(event_key, payload)


func _await_tutorial_checkpoint(
	event_key: StringName,
	payload: Dictionary = {},
) -> bool:
	if not _tutorial_mode or _tutorial_director == null:
		return false
	if not _tutorial_director.notify_checkpoint(event_key, payload):
		return false
	await _tutorial_director.event_source_released
	return true


func _is_empty_round_about_to_draw() -> bool:
	return (
		_tutorial_mode
		and _session.get_pass_draw_count(_session.current_player_index) > 0
	)


func _handle_tutorial_round_boundary(serial: int) -> void:
	if (
		not _tutorial_mode
		or serial != _game_serial
		or _session.phase != GameSession.Phase.AWAITING_ROLL
	):
		return
	if _tutorial_needs_next_player_intro:
		await get_tree().create_timer(SettingsService.get_gameplay_duration(
			SettingsService.GameplayTiming.ACTION_PAUSE,
		), false).timeout
		if (
			serial != _game_serial
			or _session.phase != GameSession.Phase.AWAITING_ROLL
			or not _tutorial_needs_next_player_intro
		):
			return
		_tutorial_needs_next_player_intro = false
		await _await_tutorial_checkpoint(
			&"before_next_player_roll",
			{"player_index": _session.current_player_index},
		)


func skip_initial_deal() -> void:
	if (
		not _dealing
		or _tutorial_gameplay_locked
		or _has_tutorial_input_lock(TutorialStep.InputLock.DEAL_SKIP)
	):
		return
	_finish_initial_deal()


func _run_initial_deal(serial: int) -> void:
	if _deal_animation_running or not _dealing or serial != _game_serial:
		return
	if _tutorial_gameplay_locked:
		await tutorial_gameplay_unlocked
		if not _dealing or serial != _game_serial:
			return
	_deal_animation_running = true
	_presentation_busy = true
	await get_tree().process_frame
	for _round_index in range(GameSession.STARTING_HAND_SIZE):
		for player_index in range(_session.players.size()):
			if serial != _game_serial or not _dealing:
				_deal_animation_running = false
				return
			await _animate_initial_deal_card(player_index)
			if serial != _game_serial or not _dealing:
				_deal_animation_running = false
				return
			_deal_visible_counts[player_index] += 1
			_refresh()
	_finish_initial_deal()


func _animate_initial_deal_card(player_index: int) -> void:
	var target_panel := _get_player_panel(player_index)
	if target_panel == null:
		return
	_pulse_draw_pile()
	AudioService.play(&"card_deal")
	var card := TextureRect.new()
	card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	card.texture = CardTextureCatalog.get_card_back()
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 48
	card.size = Vector2(44.0, 62.0)
	card.pivot_offset = card.size * 0.5
	var source := draw_pile_view.get_global_rect().get_center() - global_position
	var target := target_panel.get_global_rect().get_center() - global_position
	if player_index == _human_player_index:
		target = hand_view.get_global_rect().get_center() - global_position
	card.position = source - card.size * 0.5
	card.scale = Vector2(0.82, 0.82)
	card.rotation = -0.08
	add_child(card)
	_deal_flying_cards.append(card)
	var duration := _get_initial_deal_card_duration()
	var destination_size := (
		Vector2(52.0, 74.0)
		if player_index == _human_player_index
		else Vector2(36.0, 50.0)
	)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(
		card,
		"position",
		target - destination_size * 0.5,
		duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "size", destination_size, duration)
	tween.tween_property(card, "rotation", 0.04, duration)
	tween.tween_property(card, "scale", Vector2.ONE, duration)
	await tween.finished
	if is_instance_valid(card):
		_deal_flying_cards.erase(card)
		card.queue_free()


func _finish_initial_deal() -> void:
	if not _dealing:
		return
	_dealing = false
	_deal_animation_running = false
	_presentation_busy = false
	for player_index in range(_session.players.size()):
		_deal_visible_counts[player_index] = _session.players[player_index].hand.size()
	for card in _deal_flying_cards:
		if is_instance_valid(card):
			card.queue_free()
	_deal_flying_cards.clear()
	_reset_draw_pile_activity()
	_notify_tutorial_event(&"initial_deal_finished")
	_refresh()
	_play_round_start_if_needed()


func _play_round_start_if_needed() -> void:
	if _session == null:
		return
	if _session.phase != GameSession.Phase.AWAITING_ROLL:
		_round_start_sound_played = false
		return
	if _dealing or _round_start_sound_played:
		return
	_round_start_sound_played = true
	AudioService.play(&"round_start")


func _pulse_draw_pile() -> void:
	if not is_instance_valid(draw_pile_view):
		return
	if _draw_pile_activity_tween != null:
		_draw_pile_activity_tween.kill()
	draw_pile_view.pivot_offset = draw_pile_view.size * 0.5
	draw_pile_view.rotation = 0.0
	var duration := _get_initial_deal_card_duration() * 0.8
	_draw_pile_activity_tween = create_tween()
	_draw_pile_activity_tween.tween_property(
		draw_pile_view,
		"rotation",
		-0.035,
		duration * 0.25,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_draw_pile_activity_tween.tween_property(
		draw_pile_view,
		"rotation",
		0.025,
		duration * 0.4,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_draw_pile_activity_tween.tween_property(
		draw_pile_view,
		"rotation",
		0.0,
		duration * 0.35,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _reset_draw_pile_activity() -> void:
	if _draw_pile_activity_tween != null:
		_draw_pile_activity_tween.kill()
		_draw_pile_activity_tween = null
	if is_instance_valid(draw_pile_view):
		draw_pile_view.rotation = 0.0


func _get_initial_deal_card_duration() -> float:
	var duration := SettingsService.get_deal_card_duration()
	return duration * 0.5 if _tutorial_mode else duration


func _get_visible_hand_count(player_index: int) -> int:
	if not _dealing or player_index >= _deal_visible_counts.size():
		return _session.players[player_index].hand.size()
	return mini(
		_deal_visible_counts[player_index],
		_session.players[player_index].hand.size(),
	)


func _get_visible_human_hand() -> Array[CardData]:
	var result: Array[CardData] = []
	var hand := _session.players[_human_player_index].hand
	var visible_count := _get_visible_hand_count(_human_player_index)
	if not _dealing or _session.initial_deal_card_ids.is_empty():
		for index in range(visible_count):
			result.append(hand[index])
		return result
	var dealt_ids := {}
	var deal_order := _session.initial_deal_card_ids[_human_player_index]
	for index in range(mini(visible_count, deal_order.size())):
		dealt_ids[deal_order[index]] = true
	for card in hand:
		if dealt_ids.has(card.card_id):
			result.append(card)
	return result


func _get_visible_draw_pile_count() -> int:
	if not _dealing:
		return _session.draw_pile.size()
	var hidden_dealt_cards := 0
	for player_index in range(_session.players.size()):
		hidden_dealt_cards += (
			_session.players[player_index].hand.size()
			- _get_visible_hand_count(player_index)
		)
	return _session.draw_pile.size() + hidden_dealt_cards


func _refresh() -> void:
	if _session == null or _session.players.is_empty():
		return
	_prune_selection()
	_refresh_seats()
	_refresh_center_table()
	if not _dealing:
		_schedule_human_automation_if_needed()
	_refresh_hand()
	_refresh_actions()
	_refresh_status()
	_refresh_instruction_hint()
	_refresh_bonus_effect()
	_refresh_turn_indicator()
	_refresh_dice_prompt()
	_refresh_tutorial_state()
	if not _dealing:
		_schedule_ai_if_needed()


func _on_session_state_changed() -> void:
	_session_revision += 1
	if _tutorial_mode:
		pass
	elif _session.phase == GameSession.Phase.FINISHED:
		SaveGameService.clear_save()
	else:
		SaveGameService.save_session(_session, _use_custom_seed)
	_play_round_start_if_needed()
	_refresh()


func _refresh_seats() -> void:
	header_title.text = _translated(
		&"UI_GAME_HEADER",
		{
			"mode": (
				tr(&"UI_TUTORIAL")
				if _tutorial_mode
				else tr(&"UI_MULTIPLAYER") if _network_mode else tr(&"UI_SINGLE_PLAYER")
			),
			"count": _player_count,
		},
	)
	header_seed.text = _translated(
		&"UI_GAME_SEED",
		{"seed": _session.game_seed_text},
	)
	for seat_key in _seat_views:
		var view: Dictionary = _seat_views[seat_key]
		var player_index := _get_visual_player_index(seat_key)
		var panel := view["panel"] as PanelContainer
		panel.visible = player_index != -1
		if player_index == -1:
			_seat_card_counts.erase(seat_key)
			continue

		(view["name"] as Label).text = _player_name(player_index)
		var visible_count := _get_visible_hand_count(player_index)
		(view["count"] as Label).text = str(visible_count)
		_apply_network_connection_visual(panel, player_index)
		_set_active_border(panel, player_index == _session.roller_index)
		if int(_seat_card_counts.get(seat_key, -1)) != visible_count:
			_fill_card_backs(view["cards"] as HBoxContainer, visible_count)
			_seat_card_counts[seat_key] = visible_count

	hand_title.text = (
		_translated(
			&"LAN_HAND_TITLE",
			{
				"player": _player_name(_human_player_index),
				"count": _get_visible_hand_count(_human_player_index),
			},
		)
		if _network_mode
		else _translated(
			&"UI_HAND_TITLE",
			{"count": _get_visible_hand_count(_human_player_index)},
		)
	)
	_apply_network_connection_visual(hand_panel, _human_player_index)
	_set_active_border(hand_panel, _session.roller_index == _human_player_index)


func _refresh_center_table() -> void:
	deck_count_label.text = _translated(
		&"UI_DRAW_REMAINING",
		{"count": _get_visible_draw_pile_count()},
	)
	if not _rolling:
		if _session.is_bonus:
			dice_button.texture_normal = _dice_texture(_bonus_dice_frame + 1)
			dice_button.modulate = Color.WHITE
			dice_value_label.text = tr(&"UI_DICE_ANY")
		elif _session.dice_value == 0:
			dice_button.texture_normal = _dice_texture(1)
			dice_button.modulate = Color(1.0, 1.0, 1.0, 0.5)
			dice_value_label.text = tr(&"UI_DICE_CLICK") if _can_human_roll() else tr(&"UI_DICE_WAIT")
		else:
			dice_button.texture_normal = _dice_texture(_session.dice_value)
			dice_button.modulate = Color.WHITE
			dice_value_label.text = _translated(&"UI_DICE_VALUE", {"value": _session.dice_value})

	var play_signature := _get_play_signature()
	if _session.last_played_cards.is_empty():
		if not _last_play_signature.is_empty() or played_cards.get_child_count() > 0:
			_clear_container(played_cards)
		_last_play_signature = ""
		played_caption.text = tr(&"UI_PLAY_AREA_EMPTY")
		return

	played_caption.text = _translated(
		&"UI_PLAY_AREA_PLAYED",
		{
			"player": _player_name(_session.played_by_index),
			"hand_type": _hand_type_name(_session.last_play_pattern),
		},
	)
	if (
		play_signature == _last_play_signature
		and played_cards.get_child_count() == _session.last_played_cards.size()
	):
		return
	_last_play_signature = play_signature
	_clear_container(played_cards)
	for card in _session.last_played_cards:
		var card_texture := TextureRect.new()
		card_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card_texture.texture = CardTextureCatalog.get_texture(card)
		card_texture.custom_minimum_size = Vector2(68.0, 96.0)
		card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		played_cards.add_child(card_texture)
	_animate_played_cards_reveal(play_signature)


func _refresh_hand() -> void:
	var hand_count := _session.players[_human_player_index].hand.size()
	var drawn_count := hand_count - _last_human_hand_count
	if _last_human_hand_count >= 0 and drawn_count > 0 and not _dealing:
		_pulse_draw_pile()
		for index in range(mini(drawn_count, 3)):
			AudioService.play_delayed(
				&"card_draw",
				index * SettingsService.get_card_travel_duration() * 0.1,
			)
	_last_human_hand_count = hand_count
	var visible_hand := _get_visible_human_hand()
	var can_select := (
		not _dealing
		and not _tutorial_gameplay_locked
		and not _has_tutorial_input_lock(TutorialStep.InputLock.HAND)
		and _session.phase != GameSession.Phase.FINISHED
	)
	hand_view.set_hand(
		visible_hand,
		_selected_card_ids,
		can_select,
	)
	_refresh_selection_labels()


func _refresh_actions() -> void:
	var awaiting_action := (
		_can_human_act()
		and not _rolling
		and not _automation_pending
		and not _dealing
	)
	var must_play_bonus := (
		_session.is_bonus
		and _session.last_play_pattern == null
	)
	pass_button.visible = not must_play_bonus
	hint_button.disabled = not awaiting_action or _has_tutorial_input_lock(TutorialStep.InputLock.HINT)
	pass_button.disabled = not awaiting_action or _has_tutorial_input_lock(TutorialStep.InputLock.PASS)
	play_button.disabled = not awaiting_action or _has_tutorial_input_lock(TutorialStep.InputLock.PLAY)
	dice_button.disabled = (
		not _can_human_roll()
		or _rolling
		or _dealing
		or _automation_pending
	)
	dice_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not dice_button.disabled else Control.CURSOR_ARROW
	)
	var tutorial_actions_hidden := (
		_has_tutorial_input_lock(TutorialStep.InputLock.PLAY)
		and _has_tutorial_input_lock(TutorialStep.InputLock.PASS)
	)
	var show_tutorial_locked_actions := (
		_tutorial_show_locked_action_bar
		and _session.current_player_index == _human_player_index
		and _session.phase == GameSession.Phase.AWAITING_ACTION
		and not _dealing
		and not _rolling
	)
	_set_action_bar_visible(
		(awaiting_action and not tutorial_actions_hidden)
		or show_tutorial_locked_actions,
	)


func _refresh_status() -> void:
	status_label.visible = SettingsService.show_status_text
	if not status_label.visible:
		if _status_tween != null:
			_status_tween.kill()
		_last_status_message = ""
		return
	var message := ""
	if not _transient_key.is_empty():
		message = _translated(_transient_key, _transient_args)
	elif _dealing:
		message = tr(
			&"STATUS_TUTORIAL_DEALING" if _tutorial_mode else &"STATUS_DEALING"
		)
	elif _rolling:
		message = _translated(
			&"STATUS_ROLLING",
			{"player": _player_name(_session.current_player_index)},
		)
	elif _session.phase == GameSession.Phase.FINISHED:
		message = _translated(
			&"STATUS_WINNER",
			{"player": _player_name(_session.winner_index)},
		)
	else:
		var current_name := _player_name(_session.current_player_index)
		if _session.phase == GameSession.Phase.AWAITING_ROLL:
			message = (
				tr(&"STATUS_CLICK_DICE")
				if _session.current_player_index == _human_player_index
				else _translated(&"STATUS_PREPARING_ROLL", {"player": current_name})
			)
		elif _session.is_bonus and _session.last_play_pattern == null:
			message = _translated(&"STATUS_BONUS", {"player": current_name})
		elif _session.last_play_pattern != null:
			message = _translated(
				&"STATUS_MUST_COVER",
				{
					"player": current_name,
					"hand_type": _hand_type_name(_session.last_play_pattern),
				},
			)
		else:
			message = _translated(
				&"STATUS_MUST_PLAY",
				{"player": current_name, "count": _session.dice_value},
			)
	_set_status_message(message)


func _update_instruction_text() -> void:
	select_hint_text.text = tr(&"UI_CARD_SELECT_HINT")
	clear_hint_text.text = tr(&"UI_CARD_CLEAR_HINT")


func _refresh_instruction_hint() -> void:
	var should_show := SettingsService.show_status_text
	if should_show == _instruction_should_show:
		return
	_instruction_should_show = should_show
	if _instruction_tween != null and _instruction_tween.is_valid():
		_instruction_tween.kill()
	_instruction_tween = create_tween()
	if should_show:
		instruction_hint.modulate.a = 0.0
		_instruction_tween.tween_property(
			instruction_hint,
			"modulate:a",
			1.0,
			0.18,
		)
	else:
		_instruction_tween.tween_property(
			instruction_hint,
			"modulate:a",
			0.0,
			0.14,
		)
		_instruction_tween.tween_callback(_finish_instruction_fade)


func _finish_instruction_fade() -> void:
	_instruction_tween = null


func _set_status_message(message: String) -> void:
	if message == _last_status_message:
		status_label.text = message
		return
	_last_status_message = message
	if _status_tween != null:
		_status_tween.kill()
	status_label.text = message
	status_label.modulate.a = 0.0
	_status_tween = create_tween()
	_status_tween.tween_property(
		status_label,
		"modulate:a",
		1.0,
		SettingsService.get_ui_animation_duration(),
	)


func _refresh_selection_labels() -> void:
	var has_selection := _can_human_act() and not _selected_card_ids.is_empty()
	selected_label.visible = has_selection
	selection_type_label.visible = has_selection
	if not has_selection:
		return
	if not _can_human_act():
		selected_label.text = _translated(&"UI_SELECTED_COUNT", {"count": 0})
	elif _session.is_bonus and _session.last_play_pattern == null:
		selected_label.text = _translated(
			&"UI_SELECTED_BONUS",
			{"count": _selected_card_ids.size()},
		)
	elif _session.last_play_pattern != null:
		selected_label.text = _translated(
			&"UI_SELECTED_TARGET",
			{
				"count": _selected_card_ids.size(),
				"target": _session.last_play_pattern.card_count,
			},
		)
	else:
		selected_label.text = _translated(
			&"UI_SELECTED_TARGET",
			{"count": _selected_card_ids.size(), "target": _session.dice_value},
		)

	var interpretations := HandEvaluator.get_distinct_interpretations(
		_get_selected_cards(),
		_session.rules,
	)
	if interpretations.is_empty():
		selection_type_label.text = tr(&"UI_HAND_TYPE_INVALID")
	elif interpretations.size() == 1:
		selection_type_label.text = _translated(
			&"UI_HAND_TYPE_SINGLE",
			{"hand_type": _hand_type_name(interpretations[0])},
		)
	else:
		var names: PackedStringArray = []
		for pattern in interpretations:
			names.append(_hand_type_name(pattern))
		selection_type_label.text = _translated(
			&"UI_HAND_TYPE_MULTIPLE",
			{"hand_types": " / ".join(names)},
		)


func _refresh_bonus_effect() -> void:
	var bonus_owner := _session.roller_index
	bonus_effect.visible = _session.is_bonus and bonus_owner == _human_player_index
	_set_bonus_border(hand_panel, false)
	for seat_key in _seat_views:
		var player_index := _find_player_index(seat_key)
		if player_index == -1:
			continue
		var panel := (_seat_views[seat_key] as Dictionary)["panel"] as PanelContainer
		_set_bonus_border(
			panel,
			_session.is_bonus and player_index == bonus_owner,
		)
	if _session.is_bonus and not _last_bonus_state:
		AudioService.play_bonus_step(_bonus_sound_step)
		_bonus_sound_step = (_bonus_sound_step + 1) % maxi(1, AudioService.get_bonus_step_count())
		_notify_tutorial_event(&"bonus_started", {
			"player_index": bonus_owner,
			"is_human": bonus_owner == _human_player_index,
		})
		_show_center_feedback(&"UI_BONUS_FEEDBACK", Color(1.0, 0.76, 0.25))
	if _session.is_bonus != _last_bonus_state:
		_animate_table_bonus(_session.is_bonus)
	_last_bonus_state = _session.is_bonus


func _animate_table_bonus(entering: bool) -> void:
	if _table_bonus_tween != null:
		_table_bonus_tween.kill()
	var bonus_material := table_bonus_effect.material as ShaderMaterial
	var duration := SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.BONUS_TRANSITION,
	)
	_table_bonus_tween = create_tween()
	if entering:
		table_bonus_effect.visible = true
		bonus_material.set_shader_parameter("wipe_left", 0.0)
		bonus_material.set_shader_parameter("wipe_right", 0.0)
		_table_bonus_tween.tween_method(
			func(value: float) -> void:
				bonus_material.set_shader_parameter("wipe_right", value),
			0.0,
			1.0,
			duration,
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		bonus_material.set_shader_parameter("wipe_left", 0.0)
		bonus_material.set_shader_parameter("wipe_right", 1.0)
		_table_bonus_tween.tween_method(
			func(value: float) -> void:
				bonus_material.set_shader_parameter("wipe_left", value),
			0.0,
			1.0,
			duration,
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_table_bonus_tween.tween_callback(_finish_table_bonus_exit)


func _reset_table_bonus_effect() -> void:
	if _table_bonus_tween != null:
		_table_bonus_tween.kill()
		_table_bonus_tween = null
	_finish_table_bonus_exit()


func _finish_table_bonus_exit() -> void:
	var bonus_material := table_bonus_effect.material as ShaderMaterial
	bonus_material.set_shader_parameter("wipe_left", 0.0)
	bonus_material.set_shader_parameter("wipe_right", 1.0)
	table_bonus_effect.visible = false
	_table_bonus_tween = null


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed:
		return
	if settings_overlay.visible:
		if (
			event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
			and not settings_panel.get_global_rect().has_point(event.position)
		):
			settings_panel.cancel_edit()
			get_viewport().set_input_as_handled()
		return
	if hand_types_overlay.visible:
		if (
			event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
			and not hand_types_dialog.get_global_rect().has_point(event.position)
		):
			_close_hand_types()
			get_viewport().set_input_as_handled()
		return
	if result_overlay.visible or interpretation_popup.visible:
		return
	if %Header.get_global_rect().has_point(event.position):
		return
	if _tutorial_gameplay_locked:
		return
	if _dealing:
		if (
			event.double_click
			and event.button_index == MOUSE_BUTTON_LEFT
			and not _has_tutorial_input_lock(TutorialStep.InputLock.DEAL_SKIP)
		):
			skip_initial_deal()
			get_viewport().set_input_as_handled()
		return
	if (
		event.button_index == MOUSE_BUTTON_LEFT
		and _can_human_roll()
		and not _automation_pending
	):
		_on_dice_pressed()
		get_viewport().set_input_as_handled()
		return
	if (
		event.double_click
		and not _has_tutorial_input_lock(TutorialStep.InputLock.DOUBLE_CLICK)
		and SettingsService.double_click_actions
		and _can_human_act()
		and not _automation_pending
		and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
		and not _is_card_point(event.position)
	):
		_handle_gameplay_double_click(event.button_index)
		get_viewport().set_input_as_handled()


func _is_card_point(point: Vector2) -> bool:
	for child in hand_view.get_children():
		if child is CardView and (child as CardView).get_global_rect().has_point(point):
			return true
	return false


func _handle_gameplay_double_click(button_index: int) -> void:
	if (
		not SettingsService.double_click_actions
		or not _can_human_act()
		or _automation_pending
	):
		return
	if button_index == MOUSE_BUTTON_RIGHT:
		_on_pass_pressed()
	elif button_index == MOUSE_BUTTON_LEFT and not _selected_card_ids.is_empty():
		_on_play_pressed()


func _on_dice_pressed() -> void:
	if not _can_human_roll() or _rolling:
		return
	_animate_roll_and_commit(_human_player_index, _game_serial)


func _animate_roll_and_commit(player_index: int, serial: int) -> void:
	var forced_value := 0
	if _tutorial_mode:
		if player_index == _human_player_index and _tutorial_first_human_roll_pending:
			forced_value = _tutorial_scenario.forced_first_human_roll
			_tutorial_first_human_roll_pending = false
		elif player_index != _human_player_index:
			var tutorial_strategy := _strategies.get(player_index) as TutorialStrategy
			if tutorial_strategy != null:
				forced_value = tutorial_strategy.take_forced_dice_value()
	_rolling = true
	_presentation_busy = true
	AudioService.play(&"dice_shake")
	_clear_transient()
	_selected_card_ids.clear()
	_stop_dice_prompt()
	_refresh_actions()
	_refresh_status()

	for step in range(8):
		if serial != _game_serial:
			return
		dice_button.texture_normal = _dice_texture((step * 5 + 2) % 6 + 1)
		dice_button.modulate = Color.WHITE
		dice_button.rotation = -0.09 if step % 2 == 0 else 0.09
		await get_tree().create_timer(
			SettingsService.get_dice_step_duration(),
			false,
		).timeout

	if serial != _game_serial:
		return
	if _network_mode:
		LanMultiplayerService.request_roll()
	elif forced_value > 0:
		_session.accept_dice_result(player_index, forced_value)
	else:
		_session.roll_dice(player_index)
	AudioService.play(&"dice_land")
	_rolling = false
	dice_button.rotation = 0.0
	_refresh()
	await get_tree().create_timer(SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.ACTION_PAUSE,
	), false).timeout
	if serial != _game_serial:
		return
	_presentation_busy = false
	_refresh()


func _on_hint_pressed() -> void:
	if _has_tutorial_input_lock(TutorialStep.InputLock.HINT):
		return
	_clear_transient()
	var recommendation := _session.get_recommended_play(_human_player_index)
	if recommendation.is_empty():
		AudioService.play(&"ui_invalid")
		_set_transient(&"STATUS_NO_LEGAL_PLAY")
	else:
		AudioService.play(&"ui_confirm")
		_selected_card_ids.assign(recommendation)
		hand_view.set_selection(_selected_card_ids)
	_refresh_selection_labels()
	_refresh_status()


func _on_pass_pressed() -> void:
	if not _can_human_act() or _has_tutorial_input_lock(TutorialStep.InputLock.PASS):
		return
	_clear_transient()
	_selected_card_ids.clear()
	var serial := _game_serial
	_presentation_busy = true
	_refresh_actions()
	var hand_counts := _snapshot_hand_counts()
	_show_pass_feedback(_human_player_index)
	await get_tree().create_timer(SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.ACTION_PAUSE,
	), false).timeout
	if serial != _game_serial:
		return
	if not _network_mode and _is_empty_round_about_to_draw():
		var pending_draw_count := _session.get_pass_draw_count(
			_human_player_index,
		)
		var draw_tutorial_blocked := await _await_tutorial_checkpoint(
			&"before_forced_draw",
			{
				"player_index": _session.roller_index,
				"draw_count": pending_draw_count,
			},
		)
		if draw_tutorial_blocked:
			_tutorial_needs_next_player_intro = true
		if serial != _game_serial:
			return
	if _network_mode:
		LanMultiplayerService.request_pass()
	elif not _session.pass_turn(_human_player_index):
		_show_session_error()
	else:
		_animate_non_human_draws(hand_counts)
		await _handle_tutorial_round_boundary(serial)
	_presentation_busy = false
	_refresh()


func _on_play_pressed() -> void:
	if (
		not _can_human_act()
		or _has_tutorial_input_lock(TutorialStep.InputLock.PLAY)
		or _selected_card_ids.is_empty()
	):
		return
	_clear_transient()
	var interpretations := _session.get_legal_interpretations(
		_human_player_index,
		_selected_card_ids,
	)
	if interpretations.is_empty():
		if _network_mode:
			_set_transient(&"ERROR_INVALID_HAND")
		elif not _session.play_cards(_human_player_index, _selected_card_ids):
			_show_session_error()
		_refresh()
		return
	if interpretations.size() == 1:
		_commit_play(interpretations[0].get_key())
		return
	_show_interpretation_popup(interpretations)


func _show_interpretation_popup(interpretations: Array[HandPattern]) -> void:
	_pending_interpretations.assign(interpretations)
	_clear_container(interpretation_options)
	for pattern in interpretations:
		var option := Button.new()
		option.custom_minimum_size = Vector2(0.0, 46.0)
		option.text = _translated(
			&"UI_INTERPRETATION_OPTION",
			{
				"hand_type": _hand_type_name(pattern),
				"rank": CardData.rank_to_label(pattern.main_rank),
			},
		)
		option.pressed.connect(_commit_play.bind(pattern.get_key()))
		interpretation_options.add_child(option)
		ControlMotion.bind_buttons(interpretation_options)
	AudioService.play(&"ui_fade_in")
	interpretation_popup.popup_centered(Vector2i(440, 350))


func _commit_play(interpretation_key: String) -> void:
	interpretation_popup.hide()
	_pending_interpretations.clear()
	var selected_ids: Array[int] = []
	selected_ids.assign(_selected_card_ids)
	var snapshots := hand_view.get_animation_snapshots(selected_ids)
	var serial := _game_serial
	_presentation_busy = true
	_refresh_actions()
	hand_view.set_cards_animation_hidden(selected_ids, true)
	await _animate_human_card_play(snapshots)
	if serial != _game_serial:
		return
	if _network_mode:
		LanMultiplayerService.request_play(selected_ids, interpretation_key)
		_selected_card_ids.clear()
	else:
		_indicator_update_suspended = true
		if not _session.play_cards(
			_human_player_index,
			selected_ids,
			interpretation_key,
		):
			_indicator_update_suspended = false
			hand_view.set_cards_animation_hidden(selected_ids, false)
			_show_session_error()
		else:
			_selected_card_ids.clear()
			if not await _wait_for_play_presentation(serial):
				_indicator_update_suspended = false
				return
			_indicator_update_suspended = false
	_presentation_busy = false
	_refresh()


func _on_interpretation_popup_hidden() -> void:
	if not _pending_interpretations.is_empty():
		AudioService.play(&"ui_fade_out")


func _on_hand_selection_changed(selected_ids: Array[int]) -> void:
	_clear_transient()
	_selected_card_ids.assign(selected_ids)
	_refresh_selection_labels()
	_refresh_status()


func _schedule_human_automation_if_needed() -> void:
	if (
		_has_tutorial_input_lock(TutorialStep.InputLock.AUTOMATION)
		or _automation_pending
		or _automation_checked_revision == _session_revision
	):
		return
	var should_schedule := false
	if _auto_play_enabled:
		should_schedule = _can_human_roll() or _can_human_act()
	elif _auto_roll_enabled and _can_human_roll():
		should_schedule = true
	elif _auto_skip_enabled:
		should_schedule = _can_auto_skip_now()
	if not should_schedule:
		return
	_automation_checked_revision = _session_revision
	_automation_pending = true
	_run_human_automation.call_deferred(
		_game_serial,
		_session.current_player_index,
		_automation_generation,
	)


func _run_human_automation(
	serial: int,
	player_index: int,
	generation: int,
) -> void:
	await get_tree().create_timer(
		SettingsService.get_ui_animation_duration(),
		false,
	).timeout
	if (
		serial != _game_serial
		or generation != _automation_generation
		or player_index != _human_player_index
	):
		return
	_automation_pending = false
	if _auto_play_enabled and (_can_human_roll() or _can_human_act()):
		var context := _session.create_strategy_context(_human_player_index)
		var decision := _human_auto_strategy.choose_action(context)
		_execute_human_auto_decision(decision)
		return
	if _auto_roll_enabled and _can_human_roll():
		_on_dice_pressed()
		return
	if _auto_skip_enabled and _can_auto_skip_now():
		_on_pass_pressed()
		return
	_refresh()


func _execute_human_auto_decision(decision: PlayerDecision) -> void:
	match decision.action:
		PlayerDecision.Action.ROLL:
			if _can_human_roll():
				_on_dice_pressed()
		PlayerDecision.Action.PLAY:
			if not _can_human_act() or decision.card_ids.is_empty():
				return
			_selected_card_ids.assign(decision.card_ids)
			hand_view.set_selection(_selected_card_ids)
			_refresh_selection_labels()
			_commit_play(decision.interpretation_key)
		PlayerDecision.Action.PASS:
			if _can_auto_skip_now():
				_on_pass_pressed()


func _can_auto_skip_now() -> bool:
	if (
		not _can_human_act()
		or (_session.is_bonus and _session.last_play_pattern == null)
	):
		return false
	# The recommendation search is exhaustive for the required card count.
	return _session.get_recommended_play(_human_player_index).is_empty()


func _schedule_ai_if_needed() -> void:
	if _network_mode:
		return
	if _tutorial_gameplay_locked:
		return
	if _has_tutorial_input_lock(TutorialStep.InputLock.AI):
		return
	if _ai_task_running or _presentation_busy or _session.phase == GameSession.Phase.FINISHED:
		return
	if _session.current_player_index == _human_player_index:
		return
	_ai_task_running = true
	_run_ai_until_human.call_deferred(_game_serial)


func _run_ai_until_human(serial: int) -> void:
	while (
		serial == _game_serial
		and _session.phase != GameSession.Phase.FINISHED
		and _session.current_player_index != _human_player_index
		and not _tutorial_gameplay_locked
		and not _has_tutorial_input_lock(TutorialStep.InputLock.AI)
	):
		var player_index := _session.current_player_index
		var strategy := _strategies[player_index] as PlayerStrategy
		var context := _session.create_strategy_context(player_index)
		var decision := strategy.choose_action(context)
		await get_tree().create_timer(
			SettingsService.get_ai_think_delay(),
			false,
		).timeout
		if serial != _game_serial or player_index != _session.current_player_index:
			return
		if (
			_tutorial_gameplay_locked
			or _has_tutorial_input_lock(TutorialStep.InputLock.AI)
		):
			_ai_task_running = false
			return

		match decision.action:
			PlayerDecision.Action.ROLL:
				await _animate_roll_and_commit(player_index, serial)
			PlayerDecision.Action.PLAY:
				var play_hand_counts := _snapshot_hand_counts()
				await _animate_ai_card_play(player_index, decision.card_ids.size())
				if serial != _game_serial:
					return
				_indicator_update_suspended = true
				if not _session.play_cards(
					player_index,
					decision.card_ids,
					decision.interpretation_key,
				):
					_apply_ai_fallback(player_index)
				if not await _wait_for_play_presentation(serial):
					_indicator_update_suspended = false
					return
				_indicator_update_suspended = false
				_refresh()
				await _animate_non_human_draws(play_hand_counts)
			PlayerDecision.Action.PASS:
				_show_pass_feedback(player_index)
				await get_tree().create_timer(SettingsService.get_gameplay_duration(
					SettingsService.GameplayTiming.ACTION_PAUSE,
				), false).timeout
				if serial != _game_serial:
					return
				if _is_empty_round_about_to_draw():
					var pending_draw_count := _session.get_pass_draw_count(player_index)
					var draw_tutorial_blocked := await _await_tutorial_checkpoint(
						&"before_forced_draw",
						{
							"player_index": _session.roller_index,
							"draw_count": pending_draw_count,
						},
					)
					if draw_tutorial_blocked:
						_tutorial_needs_next_player_intro = true
					if serial != _game_serial:
						return
				var pass_hand_counts := _snapshot_hand_counts()
				if not _session.pass_turn(player_index):
					_apply_ai_fallback(player_index)
				await _animate_non_human_draws(pass_hand_counts)
				await _handle_tutorial_round_boundary(serial)
	_ai_task_running = false


func _apply_ai_fallback(player_index: int) -> void:
	var recommendation := _session.get_recommended_play(player_index)
	if recommendation.is_empty():
		_session.pass_turn(player_index)
		return
	var interpretations := _session.get_legal_interpretations(player_index, recommendation)
	var interpretation_key := interpretations[0].get_key() if not interpretations.is_empty() else ""
	_session.play_cards(player_index, recommendation, interpretation_key)


func _animate_ai_card_play(player_index: int, card_count: int) -> void:
	var source_panel := _get_player_panel(player_index)
	if source_panel == null or card_count <= 0:
		return
	AudioService.play(&"card_draw")
	var source: Vector2 = source_panel.get_global_rect().get_center() - global_position
	var target: Vector2 = played_panel.get_global_rect().get_center() - global_position
	var flying_cards: Array[TextureRect] = []
	var tween := create_tween().set_parallel(true)
	var total_duration := SettingsService.get_card_travel_duration()
	var travel_duration := total_duration * 0.82
	var stagger_span := total_duration - travel_duration
	for index in range(card_count):
		var card_back := TextureRect.new()
		card_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.texture = CardTextureCatalog.get_card_back()
		card_back.custom_minimum_size = Vector2(58.0, 82.0)
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_back.z_index = 40 + index
		add_child(card_back)
		card_back.size = Vector2(58.0, 82.0)
		card_back.position = source - card_back.size * 0.5 + Vector2(index * 8.0, 0.0)
		flying_cards.append(card_back)
		var delay := stagger_span * float(index) / float(maxi(1, card_count - 1))
		var destination: Vector2 = target - card_back.size * 0.5 + Vector2(index * 10.0, 0.0)
		tween.tween_property(
			card_back,
			"position",
			destination,
			travel_duration,
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			card_back,
			"rotation",
			0.08 * (index - card_count * 0.5),
			travel_duration,
		).set_delay(delay)
	await tween.finished
	AudioService.play(&"card_play")
	_fade_out_flying_cards(flying_cards)


func _animate_human_card_play(snapshots: Array[Dictionary]) -> void:
	if snapshots.is_empty():
		return
	AudioService.play(&"card_draw")
	var target := played_panel.get_global_rect().get_center() - global_position
	var flying_cards: Array[TextureRect] = []
	var tween := create_tween().set_parallel(true)
	var total_duration := SettingsService.get_card_travel_duration()
	var travel_duration := total_duration * 0.82
	var stagger_span := total_duration - travel_duration
	for index in range(snapshots.size()):
		var snapshot := snapshots[index]
		var card := TextureRect.new()
		card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card.texture = snapshot["texture"] as Texture2D
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size = snapshot["size"] as Vector2
		card.position = (snapshot["global_position"] as Vector2) - global_position
		card.rotation = float(snapshot["global_rotation"])
		card.z_index = 44 + index
		add_child(card)
		flying_cards.append(card)
		var delay := stagger_span * float(index) / float(maxi(1, snapshots.size() - 1))
		var destination := target - Vector2(34.0, 48.0) + Vector2(index * 9.0, 0.0)
		tween.tween_property(
			card,
			"position",
			destination,
			travel_duration,
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			card,
			"size",
			Vector2(68.0, 96.0),
			travel_duration,
		).set_delay(delay)
		tween.tween_property(card, "rotation", 0.0, travel_duration).set_delay(delay)
	await tween.finished
	AudioService.play(&"card_play")
	_fade_out_flying_cards(flying_cards)


func _fade_out_flying_cards(cards: Array[TextureRect]) -> void:
	if cards.is_empty():
		return
	var cleanup := create_tween().set_parallel(true)
	for card in cards:
		if is_instance_valid(card):
			cleanup.tween_property(
				card,
				"modulate:a",
				0.0,
				FLYING_CARD_FADE_DURATION,
			)
	cleanup.chain().tween_callback(
		func() -> void:
			for card in cards:
				if is_instance_valid(card):
					card.queue_free()
	)


func _animate_played_cards_reveal(expected_signature: String) -> void:
	if expected_signature != _last_play_signature or played_cards.get_child_count() == 0:
		return
	AudioService.play(&"card_reveal")
	if _played_reveal_tween != null and _played_reveal_tween.is_valid():
		_played_reveal_tween.kill()
	_played_reveal_tween = create_tween().set_parallel(true)
	var total_duration := PLAYED_CARD_REVEAL_DURATION
	var reveal_duration := total_duration * 0.72
	var stagger_span := total_duration - reveal_duration
	for index in range(played_cards.get_child_count()):
		var card := played_cards.get_child(index) as Control
		card.pivot_offset = Vector2(0.0, 48.0)
		card.scale = Vector2(0.08, 0.92)
		card.modulate.a = 0.0
		var delay := stagger_span * float(index) / float(
			maxi(1, played_cards.get_child_count() - 1),
		)
		_played_reveal_tween.tween_property(
			card,
			"scale",
			Vector2.ONE,
			reveal_duration,
		).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_played_reveal_tween.tween_property(
			card,
			"modulate:a",
			1.0,
			reveal_duration * 0.55,
		).set_delay(delay)


func _wait_for_play_presentation(serial: int) -> bool:
	var reveal := _played_reveal_tween
	if reveal != null and reveal.is_valid() and reveal.is_running():
		await reveal.finished
	if serial != _game_serial:
		return false
	await get_tree().create_timer(SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.ACTION_PAUSE,
	), false).timeout
	return serial == _game_serial


func _snapshot_hand_counts() -> PackedInt32Array:
	var counts := PackedInt32Array()
	for player in _session.players:
		counts.append(player.hand.size())
	return counts


func _animate_non_human_draws(previous_counts: PackedInt32Array) -> void:
	for player_index in range(mini(previous_counts.size(), _session.players.size())):
		if player_index == _human_player_index:
			continue
		var drawn_count := _session.players[player_index].hand.size() - previous_counts[player_index]
		if drawn_count > 0:
			await _animate_ai_draw(player_index, drawn_count)


func _animate_ai_draw(player_index: int, drawn_count: int) -> void:
	var target_panel := _get_player_panel(player_index)
	if target_panel == null or drawn_count <= 0:
		return
	var source := draw_pile_view.get_global_rect().get_center() - global_position
	var target := target_panel.get_global_rect().get_center() - global_position
	_pulse_draw_pile()
	var flying_cards: Array[TextureRect] = []
	var tween := create_tween().set_parallel(true)
	var visible_draw_count := mini(drawn_count, 3)
	var total_duration := SettingsService.get_card_travel_duration()
	var travel_duration := total_duration * 0.82
	var stagger_span := total_duration - travel_duration
	for index in range(visible_draw_count):
		var delay := stagger_span * float(index) / float(maxi(1, visible_draw_count - 1))
		AudioService.play_delayed(&"card_draw", delay)
		var card_back := TextureRect.new()
		card_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card_back.texture = CardTextureCatalog.get_card_back()
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_back.size = Vector2(48.0, 68.0)
		card_back.position = source - card_back.size * 0.5 + Vector2(index * 5.0, 0.0)
		card_back.z_index = 42 + index
		add_child(card_back)
		flying_cards.append(card_back)
		tween.tween_property(
			card_back,
			"position",
			target - card_back.size * 0.5 + Vector2(index * 5.0, 0.0),
			travel_duration,
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			card_back,
			"scale",
			Vector2(0.82, 0.82),
			travel_duration,
		).set_delay(delay)
	await tween.finished
	for card_back in flying_cards:
		card_back.queue_free()
	_show_draw_feedback(player_index, drawn_count)


func _show_draw_feedback(player_index: int, drawn_count: int) -> void:
	var panel := _get_player_panel(player_index)
	if panel == null:
		return
	var label := _create_feedback_label("+%d" % drawn_count, Color(0.5, 0.94, 0.76))
	label.add_theme_font_size_override("font_size", 30)
	var rect := panel.get_global_rect()
	label.position = Vector2(rect.end.x - 150.0, rect.end.y + 4.0) - global_position
	_animate_pass_label(label)


func _show_pass_feedback(player_index: int) -> void:
	AudioService.play(&"pass")
	var panel := _get_player_panel(player_index)
	if panel == null:
		return
	var label := _create_feedback_label(tr(&"UI_PASS_FEEDBACK"), Color(0.92, 0.94, 0.93))
	label.size = Vector2(180.0, 54.0)
	label.add_theme_font_size_override("font_size", 32)
	var rect := panel.get_global_rect()
	if player_index == _human_player_index:
		var title_rect := hand_title.get_global_rect()
		label.position = Vector2(title_rect.position.x + 80.0, title_rect.position.y - 60.0) - global_position
	else:
		label.position = Vector2(rect.end.x - 100.0, rect.end.y + 5.0) - global_position
	_animate_pass_label(label)


func _show_center_feedback(key: StringName, color: Color) -> void:
	var label := _create_feedback_label(tr(key), color)
	label.size = Vector2(620.0, 150.0)
	label.add_theme_font_size_override("font_size", 92)
	label.position = get_global_rect().get_center() - global_position - label.size * 0.5
	label.pivot_offset = label.size * 0.5
	played_panel.modulate.a = 0.0
	status_label.visible = false
	label.modulate.a = 0.0
	label.scale = Vector2(0.62, 0.62)
	label.rotation = deg_to_rad(-3.0)
	var total_duration := SettingsService.get_feedback_duration()
	var enter_duration := total_duration * 0.15
	var hold_duration := total_duration * 0.07
	var exit_duration := total_duration - enter_duration - hold_duration
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, enter_duration)
	tween.tween_property(label, "scale", Vector2(1.08, 1.08), enter_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "rotation", 0.0, enter_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(hold_duration)
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -34.0), exit_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate:a", 0.0, exit_duration)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
	tween.tween_callback(
		func() -> void:
			if is_instance_valid(played_panel):
				played_panel.modulate.a = 1.0
			if is_instance_valid(status_label):
				status_label.visible = SettingsService.show_status_text
				_refresh_status()
	)


func _create_feedback_label(text_value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.size = Vector2(160.0, 40.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.03, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	label.z_index = 45
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _animate_feedback_label(
	label: Label,
	offset: Vector2,
	finished: Callable = Callable(),
) -> void:
	label.modulate.a = 0.0
	label.scale = Vector2(0.92, 0.92)
	var total_duration := SettingsService.get_feedback_duration()
	var enter_duration := total_duration * 0.18
	var hold_duration := total_duration * 1.55
	var exit_duration := total_duration * 0.26
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, enter_duration)
	tween.tween_property(label, "scale", Vector2.ONE, enter_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var exit_delay := enter_duration + hold_duration
	tween.tween_property(label, "position", label.position + offset, exit_duration).set_delay(exit_delay)
	tween.tween_property(label, "modulate:a", 0.0, exit_duration).set_delay(exit_delay)
	tween.chain().tween_callback(label.queue_free)
	if finished.is_valid():
		tween.tween_callback(finished)


func _animate_pass_label(label: Label) -> void:
	_animate_feedback_label(label, Vector2(0.0, -30.0))


func _on_settings_pressed() -> void:
	if settings_overlay.visible:
		return
	if _settings_tween != null:
		_settings_tween.kill()
	settings_panel.begin_edit()
	AudioService.play(&"ui_fade_in")
	settings_overlay.visible = true
	settings_overlay.modulate.a = 0.0
	settings_panel.scale = Vector2(0.96, 0.96)
	settings_panel.pivot_offset = settings_panel.size * 0.5
	_set_overlay_pause(true)
	_settings_tween = create_tween().set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS,
	).set_parallel(true)
	_settings_tween.tween_property(settings_overlay, "modulate:a", 1.0, SettingsService.get_ui_animation_duration())
	_settings_tween.tween_property(settings_panel, "scale", Vector2.ONE, SettingsService.get_ui_animation_duration()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _open_hand_types() -> void:
	if hand_types_overlay.visible:
		return
	if _hand_types_tween != null:
		_hand_types_tween.kill()
	AudioService.play(&"ui_fade_in")
	_set_overlay_pause(true)
	hand_types_overlay.visible = true
	hand_types_overlay.modulate.a = 0.0
	hand_types_dialog.scale = Vector2(0.97, 0.97)
	hand_types_dialog.pivot_offset = hand_types_dialog.size * 0.5
	_hand_types_tween = create_tween().set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS,
	).set_parallel(true)
	var duration := SettingsService.get_ui_animation_duration()
	_hand_types_tween.tween_property(
		hand_types_overlay,
		"modulate:a",
		1.0,
		duration * 0.82,
	)
	_hand_types_tween.tween_property(
		hand_types_dialog,
		"scale",
		Vector2.ONE,
		duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_hand_types() -> void:
	if not hand_types_overlay.visible:
		return
	if _hand_types_tween != null:
		_hand_types_tween.kill()
	AudioService.play(&"ui_fade_out")
	_hand_types_tween = create_tween().set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS,
	).set_parallel(true)
	var duration := SettingsService.get_ui_animation_duration() * 0.78
	_hand_types_tween.tween_property(hand_types_overlay, "modulate:a", 0.0, duration)
	_hand_types_tween.tween_property(
		hand_types_dialog,
		"scale",
		Vector2(0.98, 0.98),
		duration,
	)
	_hand_types_tween.chain().tween_callback(
		func() -> void:
			hand_types_overlay.visible = false
			hand_types_overlay.modulate.a = 1.0
			hand_types_dialog.scale = Vector2.ONE
			_set_overlay_pause(false)
	)


func _close_settings() -> void:
	if not settings_overlay.visible:
		return
	if _settings_tween != null:
		_settings_tween.kill()
	AudioService.play(&"ui_fade_out")
	_settings_tween = create_tween().set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS,
	).set_parallel(true)
	_settings_tween.tween_property(
		settings_overlay,
		"modulate:a",
		0.0,
		SettingsService.get_ui_animation_duration(),
	)
	_settings_tween.tween_property(
		settings_panel,
		"scale",
		Vector2(0.96, 0.96),
		SettingsService.get_ui_animation_duration(),
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_settings_tween.chain().tween_callback(
		func() -> void:
			settings_overlay.visible = false
			settings_overlay.modulate.a = 1.0
			settings_panel.scale = Vector2.ONE
			_set_overlay_pause(false)
	)


func _set_overlay_pause(paused: bool) -> void:
	if _network_mode:
		return
	get_tree().paused = paused or settings_overlay.visible or hand_types_overlay.visible


func _exit_tree() -> void:
	if not _network_mode and get_tree() != null:
		get_tree().paused = false


func _on_settings_applied() -> void:
	_refresh()
	# The match is paused while settings are open, so underlying gameplay UI
	# tweens intentionally do not run. Snap settings-driven visibility to its
	# final state while the modal remains open.
	if get_tree().paused and settings_overlay.visible:
		if _instruction_tween != null and _instruction_tween.is_valid():
			_instruction_tween.kill()
		_instruction_tween = null
		instruction_hint.modulate.a = (
			1.0 if SettingsService.show_status_text else 0.0
		)


func _on_settings_changed(_snapshot: Dictionary) -> void:
	hand_view.refresh_card_textures()
	hand_types_dialog.refresh_card_style()
	_last_play_signature = ""
	_refresh()


func _on_language_changed(_locale: String) -> void:
	_update_instruction_text()
	_refresh()


func _on_return_to_menu_requested() -> void:
	if _network_mode:
		LanMultiplayerService.close_connection()
	elif (
		not _tutorial_mode
		and _session != null
		and _session.phase != GameSession.Phase.FINISHED
	):
		SaveGameService.save_session(_session, _use_custom_seed)
	settings_overlay.visible = false
	hand_types_overlay.visible = false
	_set_overlay_pause(false)
	result_overlay.visible = false
	return_to_menu_requested.emit()


func _on_game_finished(player_index: int) -> void:
	if not _network_mode and not _tutorial_mode:
		SaveGameService.clear_save()
	_notify_tutorial_event(&"game_finished", {"player_index": player_index})
	AudioService.play(&"game_win" if player_index == _human_player_index else &"game_lose")
	winner_label.text = _translated(&"STATUS_WINNER", {"player": _player_name(player_index)})
	result_overlay.visible = true
	restart_button.visible = not _network_mode or LanMultiplayerService.is_host


func _on_public_action_resolved(public_action: Dictionary) -> void:
	for strategy in _strategies.values():
		(strategy as PlayerStrategy).observe_action(public_action.duplicate(true))
	if _human_auto_strategy != null:
		_human_auto_strategy.observe_action(public_action.duplicate(true))
	_notify_tutorial_event(&"action_resolved", public_action)
	var action_type := StringName(str(public_action.get("type", "")))
	if not action_type.is_empty():
		_notify_tutorial_event(StringName("action_%s" % action_type), public_action)


func _set_action_bar_visible(should_show: bool) -> void:
	if should_show == _actions_should_show:
		return
	_actions_should_show = should_show
	if _action_bar_tween != null:
		_action_bar_tween.kill()
	if not _action_bar_layout_ready:
		action_bar.visible = should_show
		action_bar.mouse_filter = (
			Control.MOUSE_FILTER_PASS if should_show else Control.MOUSE_FILTER_IGNORE
		)
		action_bar.modulate.a = 1.0 if should_show else 0.0
		return
	var duration := SettingsService.get_ui_animation_duration()
	if should_show:
		action_bar.visible = true
		action_bar.mouse_filter = Control.MOUSE_FILTER_PASS
		action_bar.position = _action_bar_rest_position + Vector2(0.0, action_bar.size.y)
		action_bar.modulate.a = 0.0
		_action_bar_tween = create_tween().set_parallel(true)
		_action_bar_tween.tween_property(action_bar, "position", _action_bar_rest_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_action_bar_tween.tween_property(action_bar, "modulate:a", 1.0, duration)
	else:
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_action_bar_tween = create_tween().set_parallel(true)
		_action_bar_tween.tween_property(action_bar, "position", _action_bar_rest_position + Vector2(0.0, action_bar.size.y), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_action_bar_tween.tween_property(action_bar, "modulate:a", 0.0, duration)
		_action_bar_tween.chain().tween_callback(
			func() -> void:
				if not _actions_should_show:
					action_bar.visible = false
		)


func _setup_automation_controls() -> void:
	for button in [auto_roll_button, auto_skip_button, auto_play_button]:
		button.pivot_offset = button.size * 0.5
		button.toggled.connect(_on_automation_toggled.bind(button))
		button.mouse_entered.connect(_on_automation_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_automation_mouse_exited.bind(button))
	_sync_automation_checks()


func _on_automation_toggled(enabled: bool, button: TextureButton) -> void:
	if (
		_tutorial_gameplay_locked
		or _has_tutorial_input_lock(TutorialStep.InputLock.AUTOMATION)
	):
		button.set_pressed_no_signal(not enabled)
		_sync_automation_checks()
		return
	AudioService.play(&"ui_confirm")
	if button == auto_roll_button:
		_auto_roll_enabled = enabled
	elif button == auto_skip_button:
		_auto_skip_enabled = enabled
	elif button == auto_play_button:
		_auto_play_enabled = enabled
	_automation_generation += 1
	_automation_pending = false
	_automation_checked_revision = -1
	_sync_automation_checks()
	_refresh()


func _sync_automation_checks() -> void:
	auto_roll_check.visible = _auto_roll_enabled
	auto_skip_check.visible = _auto_skip_enabled
	auto_play_check.visible = _auto_play_enabled


func _on_automation_mouse_entered(button: TextureButton) -> void:
	if _tutorial_gameplay_locked:
		return
	AudioService.play(&"ui_hover")
	_kill_automation_hover(button)
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.06, 1.06), 0.08)
	tween.tween_property(button, "modulate", Color(1.15, 1.15, 1.15, 1.0), 0.08)
	tween.tween_property(button, "rotation", -0.055, 0.07)
	tween.set_parallel(false)
	tween.tween_property(button, "rotation", 0.055, 0.08)
	tween.tween_property(button, "rotation", 0.0, 0.08)
	button.set_meta(&"automation_hover_tween", tween)


func _on_automation_mouse_exited(button: TextureButton) -> void:
	_kill_automation_hover(button)
	var tween := button.create_tween().set_parallel(true)
	tween.tween_property(button, "scale", Vector2.ONE, 0.1)
	tween.tween_property(button, "modulate", Color.WHITE, 0.1)
	tween.tween_property(button, "rotation", 0.0, 0.1)
	button.set_meta(&"automation_hover_tween", tween)


func _kill_automation_hover(button: TextureButton) -> void:
	if not button.has_meta(&"automation_hover_tween"):
		return
	var tween := button.get_meta(&"automation_hover_tween") as Tween
	if tween != null and tween.is_valid():
		tween.kill()


func _setup_button_motion() -> void:
	ControlMotion.bind_buttons(self)


func _on_dice_mouse_entered() -> void:
	if _tutorial_gameplay_locked:
		return
	_dice_hovered = true
	if not _rolling:
		_start_dice_hover()


func _on_dice_mouse_exited() -> void:
	_dice_hovered = false
	_refresh_dice_prompt()


func _on_draw_pile_mouse_entered() -> void:
	if _tutorial_gameplay_locked:
		return
	if _draw_pile_tween != null:
		_draw_pile_tween.kill()
	draw_pile_view.pivot_offset = draw_pile_view.size * 0.5
	_draw_pile_tween = create_tween().set_parallel(true)
	_draw_pile_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_draw_pile_tween.tween_property(
		draw_pile_view,
		"position",
		_draw_pile_rest_position + Vector2(0.0, -6.0),
		0.16,
	)
	_draw_pile_tween.tween_property(draw_pile_view, "scale", Vector2(1.045, 1.045), 0.16)


func _on_draw_pile_mouse_exited() -> void:
	if _draw_pile_tween != null:
		_draw_pile_tween.kill()
	_draw_pile_tween = create_tween().set_parallel(true)
	_draw_pile_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_draw_pile_tween.tween_property(draw_pile_view, "position", _draw_pile_rest_position, 0.15)
	_draw_pile_tween.tween_property(draw_pile_view, "scale", Vector2.ONE, 0.15)


func _refresh_dice_prompt() -> void:
	if not is_node_ready() or _rolling:
		return
	if _dice_hovered:
		_start_dice_hover()
	elif _can_human_roll() and not _automation_pending:
		_start_dice_prompt()
	else:
		_stop_dice_prompt()


func _start_dice_prompt() -> void:
	if _dice_prompt_tween != null and _dice_prompt_tween.is_running():
		return
	if _dice_rest_position == Vector2.ZERO:
		_dice_rest_position = dice_button.position
	_stop_dice_prompt()
	_dice_prompt_tween = create_tween().set_loops()
	_dice_prompt_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dice_prompt_tween.tween_property(dice_button, "position", _dice_rest_position + Vector2(0.0, -5.0), 0.55)
	_dice_prompt_tween.parallel().tween_property(dice_button, "scale", Vector2(1.05, 1.05), 0.55)
	_dice_prompt_tween.tween_property(dice_button, "position", _dice_rest_position, 0.55)
	_dice_prompt_tween.parallel().tween_property(dice_button, "scale", Vector2.ONE, 0.55)


func _start_dice_hover() -> void:
	_stop_dice_prompt()
	_dice_prompt_tween = create_tween().set_loops()
	_dice_prompt_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dice_prompt_tween.tween_property(dice_button, "position", _dice_rest_position + Vector2(0.0, -9.0), 0.34)
	_dice_prompt_tween.parallel().tween_property(dice_button, "scale", Vector2(1.1, 1.1), 0.34)
	_dice_prompt_tween.tween_property(dice_button, "position", _dice_rest_position + Vector2(0.0, -5.0), 0.34)
	_dice_prompt_tween.parallel().tween_property(dice_button, "scale", Vector2(1.07, 1.07), 0.34)


func _stop_dice_prompt() -> void:
	if _dice_prompt_tween != null:
		_dice_prompt_tween.kill()
		_dice_prompt_tween = null
	if is_instance_valid(dice_button):
		if _dice_rest_position != Vector2.ZERO:
			dice_button.position = _dice_rest_position
		dice_button.scale = Vector2.ONE


func _fill_card_backs(container: HBoxContainer, card_count: int) -> void:
	_clear_container(container)
	for _index in range(mini(card_count, 7)):
		var card_back := TextureRect.new()
		card_back.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card_back.texture = CardTextureCatalog.get_card_back()
		card_back.custom_minimum_size = Vector2(38.0, 52.0)
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(card_back)
	if card_count > 7:
		var ellipsis := Label.new()
		ellipsis.text = "..."
		ellipsis.custom_minimum_size = Vector2(70.0, 52.0)
		ellipsis.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ellipsis.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ellipsis.add_theme_font_size_override("font_size", 32)
		ellipsis.add_theme_color_override("font_color", Color(0.98, 0.77, 0.28, 1.0))
		ellipsis.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.04, 0.95))
		ellipsis.add_theme_constant_override("outline_size", 3)
		ellipsis.z_index = 10
		ellipsis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(ellipsis)


func _set_active_border(panel: PanelContainer, active: bool) -> void:
	if _panel_active_states.get(panel, null) != active:
		_panel_active_states[panel] = active
		var source := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if source != null:
			var style := source.duplicate() as StyleBoxFlat
			style.border_color = INACTIVE_BORDER_COLOR
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			panel.add_theme_stylebox_override("panel", style)
	if _flow_borders.has(panel):
		var border := _flow_borders[panel] as ColorRect
		border.visible = active and panel.visible


func _refresh_turn_indicator() -> void:
	if _indicator_update_suspended:
		return
	if _dealing or _session.phase == GameSession.Phase.FINISHED:
		turn_indicator.visible = false
		_hide_turn_timer()
		return
	var player_index := _session.current_player_index
	var panel := _get_player_panel(player_index)
	if panel == null or not panel.visible:
		turn_indicator.visible = false
		_hide_turn_timer()
		return
	turn_indicator.visible = true
	var panel_rect := panel.get_global_rect()
	var target_center: Vector2
	var facing_rotation: float
	if player_index == _human_player_index:
		var title_rect := hand_title.get_global_rect()
		target_center = Vector2(title_rect.position.x + 60.0, title_rect.position.y - 38.0) - global_position
		facing_rotation = PI
	else:
		target_center = Vector2(panel_rect.get_center().x, panel_rect.end.y + 28.0) - global_position
		facing_rotation = 0.0
	var moved_from_player := _indicator_player_index != -1 and _indicator_player_index != player_index
	var instant := _indicator_player_index == -1
	turn_indicator.move_to(target_center, facing_rotation, instant)
	_move_turn_timer(target_center, instant)
	if moved_from_player:
		AudioService.play(&"turn_change")
	_indicator_player_index = player_index


func _move_turn_timer(target_center: Vector2, instant: bool) -> void:
	if not _network_mode or not LanMultiplayerService.is_turn_clock_active():
		_hide_turn_timer()
		return
	var target := target_center + Vector2(46.0, -17.0)
	turn_seconds_label.text = str(LanMultiplayerService.get_turn_seconds_remaining())
	if _turn_timer_tween != null:
		_turn_timer_tween.kill()
	var was_hidden := not turn_timer.visible
	turn_timer.visible = true
	if was_hidden:
		turn_timer.modulate.a = 0.0
	if instant:
		turn_timer.position = target
	_turn_timer_tween = create_tween().set_parallel(true)
	if not instant:
		_turn_timer_tween.tween_property(
			turn_timer,
			"position",
			target,
			SettingsService.get_gameplay_duration(
				SettingsService.GameplayTiming.INDICATOR_MOVE,
			),
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if was_hidden:
		_turn_timer_tween.tween_property(
			turn_timer,
			"modulate:a",
			1.0,
			SettingsService.get_ui_animation_duration(),
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hide_turn_timer() -> void:
	if _turn_timer_tween != null:
		_turn_timer_tween.kill()
	turn_timer.visible = false
	turn_timer.modulate.a = 0.0


func _setup_flow_borders() -> void:
	for panel in [%NorthSeat, %WestSeat, %EastSeat, hand_panel]:
		var border := ColorRect.new()
		border.name = "FlowBorder"
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.z_index = 20
		border.visible = false
		var border_material := ShaderMaterial.new()
		border_material.shader = FLOW_BORDER_SHADER
		border_material.set_shader_parameter("bonus_mode", false)
		border_material.set_shader_parameter("rect_size", panel.size)
		border_material.set_shader_parameter("corner_radius", 6.0)
		border.material = border_material
		add_child(border)
		_flow_borders[panel] = border
		panel.item_rect_changed.connect(_update_flow_border_size.bind(panel))
	_update_all_flow_borders.call_deferred()


func _update_flow_border_size(panel: PanelContainer) -> void:
	if not _flow_borders.has(panel):
		return
	var border := _flow_borders[panel] as ColorRect
	var panel_rect := panel.get_global_rect()
	border.position = panel_rect.position - global_position
	border.size = panel_rect.size
	(border.material as ShaderMaterial).set_shader_parameter("rect_size", panel_rect.size)


func _update_all_flow_borders() -> void:
	for panel in _flow_borders:
		_update_flow_border_size(panel as PanelContainer)


func _set_bonus_border(panel: PanelContainer, active: bool) -> void:
	if not _flow_borders.has(panel):
		return
	var border := _flow_borders[panel] as ColorRect
	(border.material as ShaderMaterial).set_shader_parameter("bonus_mode", active)
	if active:
		border.visible = panel.visible


func play_enter_transition() -> void:
	await get_tree().process_frame
	AudioService.play(&"ui_fade_in")
	if _status_tween != null:
		_status_tween.kill()
	var entries := [
		[%Header, Vector2(0.0, -70.0)],
		[%WestSeat, Vector2(-170.0, 0.0)],
		[%NorthSeat, Vector2(0.0, -120.0)],
		[%EastSeat, Vector2(170.0, 0.0)],
		[status_label, Vector2(0.0, -42.0)],
		[table_band, Vector2(0.0, -100.0)],
		[%TableRow, Vector2(0.0, -100.0)],
		[turn_indicator, Vector2.ZERO],
		[%ActionSlot, Vector2(0.0, 70.0)],
		[hand_panel, Vector2(0.0, 220.0)],
	]
	var originals := {}
	for entry in entries:
		var node := entry[0] as Control
		originals[node] = node.position
		node.position += entry[1] as Vector2
		node.modulate.a = 0.0
	var duration := SCENE_TRANSITION_DURATION
	var tween := create_tween().set_parallel(true)
	for entry in entries:
		var node := entry[0] as Control
		tween.tween_property(node, "position", originals[node], duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "modulate:a", 1.0, duration * 0.72)
	await tween.finished
	if _dealing and not _deal_animation_running:
		_run_initial_deal.call_deferred(_game_serial)


func play_exit_transition() -> void:
	AudioService.play(&"ui_fade_out")
	settings_overlay.visible = false
	result_overlay.visible = false
	var exits := [
		[%Header, Vector2(0.0, -70.0)],
		[%WestSeat, Vector2(-170.0, 0.0)],
		[%NorthSeat, Vector2(0.0, -120.0)],
		[%EastSeat, Vector2(170.0, 0.0)],
		[status_label, Vector2(0.0, -42.0)],
		[%TableRow, Vector2(0.0, -100.0)],
		[turn_indicator, Vector2.ZERO],
		[%ActionSlot, Vector2(0.0, 70.0)],
		[hand_panel, Vector2(0.0, 220.0)],
	]
	var duration := SCENE_TRANSITION_DURATION * 0.84
	var tween := create_tween().set_parallel(true)
	for entry in exits:
		var node := entry[0] as Control
		tween.tween_property(node, "position", node.position + entry[1] as Vector2, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(node, "modulate:a", 0.0, duration * 0.76)
	await tween.finished


func _find_player_index(display_name_key: String) -> int:
	for index in range(_session.players.size()):
		if _session.players[index].display_name == display_name_key:
			return index
	return -1


func _get_visual_player_index(visual_seat_key: String) -> int:
	if not _network_mode:
		return _find_player_index(visual_seat_key)
	var count := _session.players.size()
	if count == 2:
		return (_human_player_index + 1) % count if visual_seat_key == "SEAT_NORTH" else -1
	if count == 3:
		if visual_seat_key == "SEAT_NORTH":
			return (_human_player_index + 1) % count
		if visual_seat_key == "SEAT_WEST":
			return (_human_player_index + 2) % count
		return -1
	match visual_seat_key:
		"SEAT_EAST":
			return (_human_player_index + 1) % count
		"SEAT_NORTH":
			return (_human_player_index + 2) % count
		"SEAT_WEST":
			return (_human_player_index + 3) % count
	return -1


func _get_player_panel(player_index: int) -> PanelContainer:
	if player_index < 0 or player_index >= _session.players.size():
		return null
	if player_index == _human_player_index:
		return hand_panel
	if _network_mode:
		for visual_seat_key in _seat_views:
			if _get_visual_player_index(visual_seat_key) == player_index:
				return (_seat_views[visual_seat_key] as Dictionary)["panel"] as PanelContainer
		return null
	var seat_key := _session.players[player_index].display_name
	return (
		(_seat_views[seat_key] as Dictionary)["panel"] as PanelContainer
		if _seat_views.has(seat_key)
		else null
	)


func _apply_network_connection_visual(panel: PanelContainer, player_index: int) -> void:
	if not _network_mode:
		_set_panel_disconnected(panel, false)
		_hide_disconnect_icon(panel)
		return
	var meta := _network_player_meta.get(player_index, {}) as Dictionary
	var disconnected := (
		not bool(meta.get("is_ai", false))
		and not bool(meta.get("connected", true))
	)
	_set_panel_disconnected(panel, disconnected)
	if disconnected:
		_show_disconnect_icon(panel)
	else:
		_hide_disconnect_icon(panel)


func _set_panel_disconnected(panel: PanelContainer, disconnected: bool) -> void:
	panel.material = _disconnected_material if disconnected else null
	_set_descendants_use_parent_material(panel, disconnected)
	if _flow_borders.has(panel):
		var border := _flow_borders[panel] as ColorRect
		border.self_modulate = (
			Color(0.55, 0.55, 0.55, 0.72) if disconnected else Color.WHITE
		)


func _set_descendants_use_parent_material(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).use_parent_material = enabled
		_set_descendants_use_parent_material(child, enabled)


func _show_disconnect_icon(panel: PanelContainer) -> void:
	var badge := _disconnect_icons.get(panel) as PanelContainer
	if badge == null:
		badge = PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.z_index = 60
		badge.size = Vector2(76.0, 76.0)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.015, 0.02, 0.02, 0.88)
		badge_style.border_width_left = 2
		badge_style.border_width_top = 2
		badge_style.border_width_right = 2
		badge_style.border_width_bottom = 2
		badge_style.border_color = Color(1.0, 1.0, 1.0, 0.82)
		badge_style.corner_radius_top_left = 38
		badge_style.corner_radius_top_right = 38
		badge_style.corner_radius_bottom_right = 38
		badge_style.corner_radius_bottom_left = 38
		badge.add_theme_stylebox_override("panel", badge_style)
		var icon := TextureRect.new()
		icon.texture = DISCONNECT_ICON
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(56.0, 56.0)
		badge.add_child(icon)
		add_child(badge)
		_disconnect_icons[panel] = badge
	badge.visible = true
	var rect := panel.get_global_rect()
	badge.position = rect.get_center() - global_position - badge.size * 0.5


func _hide_disconnect_icon(panel: PanelContainer) -> void:
	var badge := _disconnect_icons.get(panel) as PanelContainer
	if badge != null:
		badge.visible = false


func _get_selected_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id in _selected_card_ids:
		var index := _session.players[_human_player_index].find_card_index(card_id)
		if index != -1:
			cards.append(_session.players[_human_player_index].hand[index])
	return cards


func _can_human_roll() -> bool:
	return (
		_session != null
		and not _tutorial_gameplay_locked
		and not _has_tutorial_input_lock(TutorialStep.InputLock.ROLL)
		and not _dealing
		and _session.current_player_index == _human_player_index
		and _session.phase == GameSession.Phase.AWAITING_ROLL
	)


func _can_human_act() -> bool:
	return (
		_session != null
		and not _tutorial_gameplay_locked
		and not _dealing
		and _session.current_player_index == _human_player_index
		and _session.phase == GameSession.Phase.AWAITING_ACTION
		and not _rolling
		and not _presentation_busy
	)


func _dice_texture(value: int) -> Texture2D:
	return load(DICE_ROOT + "die_white_%d.png" % value) as Texture2D


func _player_name(player_index: int) -> String:
	if _network_mode:
		var meta := _network_player_meta.get(player_index, {}) as Dictionary
		var player_id := str(meta.get("player_id", ""))
		var seat_name := tr(StringName(_session.players[player_index].display_name))
		return "%s · %s" % [seat_name, player_id] if not player_id.is_empty() else seat_name
	return tr(_session.players[player_index].display_name)


func _hand_type_name(pattern: HandPattern) -> String:
	return tr(pattern.get_translation_key()) if pattern != null else tr(&"HAND_UNKNOWN")


func _translated(key: StringName, args: Dictionary = {}) -> String:
	return tr(key).format(args)


func _set_transient(key: StringName, args: Dictionary = {}) -> void:
	_transient_key = key
	_transient_args = args.duplicate(true)


func _clear_transient() -> void:
	_transient_key = &""
	_transient_args.clear()


func _show_session_error() -> void:
	AudioService.play(&"ui_invalid")
	_set_transient(_session.last_error_key, _session.last_error_args)


func _get_play_signature() -> String:
	if _session.last_played_cards.is_empty():
		return ""
	var parts := PackedStringArray([str(_session.played_by_index)])
	for card in _session.last_played_cards:
		parts.append(str(card.card_id))
	return ":".join(parts)


func _prune_selection() -> void:
	for index in range(_selected_card_ids.size() - 1, -1, -1):
		if _session.players[_human_player_index].find_card_index(_selected_card_ids[index]) == -1:
			_selected_card_ids.remove_at(index)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
