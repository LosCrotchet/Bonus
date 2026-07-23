extends Control

signal return_to_menu_requested

const HUMAN_PLAYER_INDEX := 0
const DEFAULT_PLAYER_COUNT := 3
const DICE_ROOT := "res://assets/art/dice/"
const INACTIVE_BORDER_COLOR := Color(0.25, 0.4, 0.36, 0.75)
const FLOW_BORDER_SHADER := preload("res://assets/shaders/flow_border.gdshader")

@onready var settings_button: Button = %SettingsButton
@onready var hand_types_button: Button = %HandTypesButton
@onready var header_title: Label = %HeaderTitle
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
@onready var interpretation_popup: PopupPanel = %InterpretationPopup
@onready var interpretation_options: VBoxContainer = %InterpretationOptions
@onready var result_overlay: Control = %ResultOverlay
@onready var winner_label: Label = %WinnerLabel
@onready var restart_button: Button = %RestartButton
@onready var result_menu_button: Button = %ResultMenuButton

var _session: GameSession
var _selected_card_ids: Array[int] = []
var _player_count := DEFAULT_PLAYER_COUNT
var _game_rules := GameRules.new()
var _embedded_in_app := false
var _configured_seed := 0
var _use_custom_seed := false
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
var _settings_tween: Tween
var _hand_types_tween: Tween
var _status_tween: Tween
var _table_bonus_tween: Tween
var _button_tweens: Dictionary = {}
var _flow_borders: Dictionary = {}
var _seat_card_counts: Dictionary = {}
var _panel_active_states: Dictionary = {}
var _bonus_dice_elapsed := 0.0
var _bonus_dice_frame := 0
var _auto_pass_pending := false
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
var _auto_pass_checked_revision := -1
var _bonus_sound_step := 0
var _round_start_sound_played := false
var _presentation_random := RandomNumberGenerator.new()


func configure(
	player_count: int,
	game_rules: GameRules = null,
	embedded_in_app: bool = false,
	seed_value: int = 0,
	use_custom_seed: bool = false,
) -> void:
	_player_count = clampi(player_count, 2, 4)
	_game_rules = game_rules.clone() if game_rules != null else GameRules.new()
	_embedded_in_app = embedded_in_app
	_configured_seed = seed_value
	_use_custom_seed = use_custom_seed
	_resume_payload.clear()


func configure_resume(payload: Dictionary, embedded_in_app: bool = false) -> void:
	_resume_payload = payload.duplicate(true)
	_embedded_in_app = embedded_in_app


func _ready() -> void:
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
	restart_button.pressed.connect(_on_restart_pressed)
	result_menu_button.pressed.connect(_on_return_to_menu_requested)
	hand_view.selection_changed.connect(_on_hand_selection_changed)
	SettingsService.language_changed.connect(_on_language_changed)
	SettingsService.settings_changed.connect(_on_settings_changed)

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
	if _embedded_in_app:
		%Background.visible = false
	if _resume_payload.is_empty() or not _restore_saved_game():
		_start_new_game(not _embedded_in_app)
	await get_tree().process_frame
	_dice_rest_position = dice_button.position
	dice_button.pivot_offset = dice_button.size * 0.5
	_draw_pile_rest_position = draw_pile_view.position
	draw_pile_view.pivot_offset = draw_pile_view.size * 0.5
	_setup_button_motion()
	_refresh_dice_prompt()


func _finish_card_texture_warmup() -> void:
	await get_tree().create_timer(0.2).timeout
	CardTextureCatalog.finish_warm_up()


func _process(delta: float) -> void:
	if _session == null or not _session.is_bonus or _rolling:
		_bonus_dice_elapsed = 0.0
		return
	_bonus_dice_elapsed += delta
	if _bonus_dice_elapsed < SettingsService.get_dice_step_duration() * 1.75:
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
	_auto_pass_pending = false
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
	_auto_pass_checked_revision = -1
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
		_configured_seed if _use_custom_seed else 0,
		_game_rules,
	)
	_initialize_strategies()
	_deal_visible_counts.resize(_session.players.size())
	_deal_visible_counts.fill(0)
	result_overlay.visible = false
	_refresh()
	if start_deal_animation:
		_run_initial_deal.call_deferred(_game_serial)


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
	_auto_pass_pending = false
	_presentation_busy = false
	_indicator_player_index = -1
	_last_play_signature = ""
	_last_human_hand_count = -1
	_bonus_sound_step = 0
	_round_start_sound_played = false
	_seat_card_counts.clear()
	_panel_active_states.clear()
	_session_revision = 0
	_auto_pass_checked_revision = -1
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
	for player_index in range(1, _session.players.size()):
		var strategy := StrategyRegistry.create(&"default")
		strategy.setup(player_index, _session.players.size())
		_strategies[player_index] = strategy


func skip_initial_deal() -> void:
	if not _dealing:
		return
	_finish_initial_deal()


func _run_initial_deal(serial: int) -> void:
	if _deal_animation_running or not _dealing or serial != _game_serial:
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
	if player_index == HUMAN_PLAYER_INDEX:
		target = hand_view.get_global_rect().get_center() - global_position
	card.position = source - card.size * 0.5
	card.scale = Vector2(0.82, 0.82)
	card.rotation = -0.08
	add_child(card)
	_deal_flying_cards.append(card)
	var duration := SettingsService.get_deal_card_duration()
	var destination_size := (
		Vector2(52.0, 74.0)
		if player_index == HUMAN_PLAYER_INDEX
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
	var duration := SettingsService.get_deal_card_duration() * 0.8
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


func _get_visible_hand_count(player_index: int) -> int:
	if not _dealing or player_index >= _deal_visible_counts.size():
		return _session.players[player_index].hand.size()
	return mini(
		_deal_visible_counts[player_index],
		_session.players[player_index].hand.size(),
	)


func _get_visible_human_hand() -> Array[CardData]:
	var result: Array[CardData] = []
	var hand := _session.players[HUMAN_PLAYER_INDEX].hand
	var visible_count := _get_visible_hand_count(HUMAN_PLAYER_INDEX)
	if not _dealing or _session.initial_deal_card_ids.is_empty():
		for index in range(visible_count):
			result.append(hand[index])
		return result
	var dealt_ids := {}
	var deal_order := _session.initial_deal_card_ids[HUMAN_PLAYER_INDEX]
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
		_schedule_auto_pass_if_needed()
	_refresh_hand()
	_refresh_actions()
	_refresh_status()
	_refresh_bonus_effect()
	_refresh_turn_indicator()
	_refresh_dice_prompt()
	if not _dealing:
		_schedule_ai_if_needed()


func _on_session_state_changed() -> void:
	_session_revision += 1
	if _session.phase == GameSession.Phase.FINISHED:
		SaveGameService.clear_save()
	else:
		SaveGameService.save_session(_session, _use_custom_seed)
	_play_round_start_if_needed()
	_refresh()


func _refresh_seats() -> void:
	header_title.text = _translated(
		&"UI_GAME_HEADER",
		{"mode": tr(&"UI_SINGLE_PLAYER"), "count": _player_count},
	)
	for seat_key in _seat_views:
		var view: Dictionary = _seat_views[seat_key]
		var player_index := _find_player_index(seat_key)
		var panel := view["panel"] as PanelContainer
		panel.visible = player_index != -1
		if player_index == -1:
			_seat_card_counts.erase(seat_key)
			continue

		var player := _session.players[player_index]
		(view["name"] as Label).text = tr(player.display_name)
		var visible_count := _get_visible_hand_count(player_index)
		(view["count"] as Label).text = str(visible_count)
		_set_active_border(panel, player_index == _session.roller_index)
		if int(_seat_card_counts.get(seat_key, -1)) != visible_count:
			_fill_card_backs(view["cards"] as HBoxContainer, visible_count)
			_seat_card_counts[seat_key] = visible_count

	hand_title.text = _translated(
		&"UI_HAND_TITLE",
		{"count": _get_visible_hand_count(HUMAN_PLAYER_INDEX)},
	)
	_set_active_border(hand_panel, _session.roller_index == HUMAN_PLAYER_INDEX)


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
	var hand_count := _session.players[HUMAN_PLAYER_INDEX].hand.size()
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
	var can_select := _can_human_act() and not _auto_pass_pending and not _dealing
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
		and not _auto_pass_pending
		and not _dealing
	)
	var must_play_bonus := (
		_session.is_bonus
		and _session.last_play_pattern == null
	)
	pass_button.visible = not must_play_bonus
	hint_button.disabled = not awaiting_action
	pass_button.disabled = not awaiting_action
	play_button.disabled = not awaiting_action
	dice_button.disabled = not _can_human_roll() or _rolling or _dealing
	dice_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not dice_button.disabled else Control.CURSOR_ARROW
	)
	_set_action_bar_visible(awaiting_action)


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
		message = tr(&"STATUS_DEALING")
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
				if _session.current_player_index == HUMAN_PLAYER_INDEX
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
	bonus_effect.visible = _session.is_bonus and bonus_owner == HUMAN_PLAYER_INDEX
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
	if _dealing:
		if event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
			skip_initial_deal()
			get_viewport().set_input_as_handled()
		return
	if event.button_index == MOUSE_BUTTON_LEFT and _can_human_roll():
		_on_dice_pressed()
		get_viewport().set_input_as_handled()
		return
	if (
		event.double_click
		and SettingsService.double_click_actions
		and _can_human_act()
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
	if not SettingsService.double_click_actions or not _can_human_act():
		return
	if button_index == MOUSE_BUTTON_RIGHT:
		_on_pass_pressed()
	elif button_index == MOUSE_BUTTON_LEFT and not _selected_card_ids.is_empty():
		_on_play_pressed()


func _on_dice_pressed() -> void:
	if not _can_human_roll() or _rolling:
		return
	_animate_roll_and_commit(HUMAN_PLAYER_INDEX, _game_serial)


func _animate_roll_and_commit(player_index: int, serial: int) -> void:
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
		await get_tree().create_timer(SettingsService.get_dice_step_duration()).timeout

	if serial != _game_serial:
		return
	_session.roll_dice(player_index)
	AudioService.play(&"dice_land")
	_rolling = false
	dice_button.rotation = 0.0
	_refresh()
	await get_tree().create_timer(SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.ACTION_PAUSE,
	)).timeout
	if serial != _game_serial:
		return
	_presentation_busy = false
	_refresh()


func _on_hint_pressed() -> void:
	_clear_transient()
	var recommendation := _session.get_recommended_play(HUMAN_PLAYER_INDEX)
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
	if not _can_human_act() or _auto_pass_pending:
		return
	_clear_transient()
	_selected_card_ids.clear()
	var serial := _game_serial
	_presentation_busy = true
	_refresh_actions()
	var hand_counts := _snapshot_hand_counts()
	_show_pass_feedback(HUMAN_PLAYER_INDEX)
	await get_tree().create_timer(SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.ACTION_PAUSE,
	)).timeout
	if serial != _game_serial:
		return
	if not _session.pass_turn(HUMAN_PLAYER_INDEX):
		_show_session_error()
	else:
		_animate_non_human_draws(hand_counts)
	_presentation_busy = false
	_refresh()


func _on_play_pressed() -> void:
	if not _can_human_act() or _auto_pass_pending or _selected_card_ids.is_empty():
		return
	_clear_transient()
	var interpretations := _session.get_legal_interpretations(
		HUMAN_PLAYER_INDEX,
		_selected_card_ids,
	)
	if interpretations.is_empty():
		if not _session.play_cards(HUMAN_PLAYER_INDEX, _selected_card_ids):
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
		_setup_single_button_motion(option)
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
	await get_tree().create_timer(SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.ACTION_PAUSE,
	)).timeout
	if serial != _game_serial:
		return
	if not _session.play_cards(
		HUMAN_PLAYER_INDEX,
		selected_ids,
		interpretation_key,
	):
		hand_view.set_cards_animation_hidden(selected_ids, false)
		_show_session_error()
	else:
		_selected_card_ids.clear()
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


func _schedule_auto_pass_if_needed() -> void:
	if (
		_auto_pass_pending
		or not SettingsService.auto_pass
		or not _can_human_act()
		or (_session.is_bonus and _session.last_play_pattern == null)
	):
		return
	if _auto_pass_checked_revision == _session_revision:
		return
	_auto_pass_checked_revision = _session_revision
	# An empty recommendation is conclusive: the exhaustive finder checked every
	# combination of the required size against the current public target.
	if not _session.get_recommended_play(HUMAN_PLAYER_INDEX).is_empty():
		return
	_auto_pass_pending = true
	_run_auto_pass.call_deferred(_game_serial, _session.current_player_index)


func _run_auto_pass(serial: int, player_index: int) -> void:
	await get_tree().create_timer(SettingsService.get_ui_animation_duration()).timeout
	_auto_pass_pending = false
	if (
		serial != _game_serial
		or player_index != HUMAN_PLAYER_INDEX
		or not SettingsService.auto_pass
		or not _can_human_act()
		or (_session.is_bonus and _session.last_play_pattern == null)
		or not _session.get_recommended_play(HUMAN_PLAYER_INDEX).is_empty()
	):
		_refresh()
		return
	_show_pass_feedback(HUMAN_PLAYER_INDEX)
	_presentation_busy = true
	_refresh_actions()
	await get_tree().create_timer(SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.ACTION_PAUSE,
	)).timeout
	if serial != _game_serial:
		return
	var hand_counts := _snapshot_hand_counts()
	if _session.pass_turn(HUMAN_PLAYER_INDEX):
		await _animate_non_human_draws(hand_counts)
	_presentation_busy = false
	_refresh()


func _schedule_ai_if_needed() -> void:
	if _ai_task_running or _presentation_busy or _session.phase == GameSession.Phase.FINISHED:
		return
	if _session.current_player_index == HUMAN_PLAYER_INDEX:
		return
	_ai_task_running = true
	_run_ai_until_human.call_deferred(_game_serial)


func _run_ai_until_human(serial: int) -> void:
	while (
		serial == _game_serial
		and _session.phase != GameSession.Phase.FINISHED
		and _session.current_player_index != HUMAN_PLAYER_INDEX
	):
		var player_index := _session.current_player_index
		var strategy := _strategies[player_index] as PlayerStrategy
		var context := _session.create_strategy_context(player_index)
		var decision := strategy.choose_action(context)
		await get_tree().create_timer(SettingsService.get_ai_think_delay()).timeout
		if serial != _game_serial or player_index != _session.current_player_index:
			return

		match decision.action:
			PlayerDecision.Action.ROLL:
				await _animate_roll_and_commit(player_index, serial)
			PlayerDecision.Action.PLAY:
				var play_hand_counts := _snapshot_hand_counts()
				await _animate_ai_card_play(player_index, decision.card_ids.size())
				if serial != _game_serial:
					return
				await get_tree().create_timer(SettingsService.get_gameplay_duration(
					SettingsService.GameplayTiming.ACTION_PAUSE,
				)).timeout
				if serial != _game_serial:
					return
				if not _session.play_cards(
					player_index,
					decision.card_ids,
					decision.interpretation_key,
				):
					_apply_ai_fallback(player_index)
				await _animate_non_human_draws(play_hand_counts)
			PlayerDecision.Action.PASS:
				_show_pass_feedback(player_index)
				await get_tree().create_timer(SettingsService.get_gameplay_duration(
					SettingsService.GameplayTiming.ACTION_PAUSE,
				)).timeout
				if serial != _game_serial:
					return
				var pass_hand_counts := _snapshot_hand_counts()
				if not _session.pass_turn(player_index):
					_apply_ai_fallback(player_index)
				await _animate_non_human_draws(pass_hand_counts)
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
		tween.tween_property(card, "size", Vector2(68.0, 96.0), travel_duration).set_delay(delay)
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
				SettingsService.get_gameplay_duration(
					SettingsService.GameplayTiming.CARD_REVEAL,
				) * 0.18,
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
	var tween := create_tween().set_parallel(true)
	var total_duration := SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.CARD_REVEAL,
	)
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
		tween.tween_property(card, "scale", Vector2.ONE, reveal_duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, reveal_duration * 0.55).set_delay(delay)


func _snapshot_hand_counts() -> PackedInt32Array:
	var counts := PackedInt32Array()
	for player in _session.players:
		counts.append(player.hand.size())
	return counts


func _animate_non_human_draws(previous_counts: PackedInt32Array) -> void:
	for player_index in range(1, mini(previous_counts.size(), _session.players.size())):
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
	if player_index == HUMAN_PLAYER_INDEX:
		var title_rect := hand_title.get_global_rect()
		label.position = Vector2(title_rect.position.x + 80.0, title_rect.position.y - 60.0) - global_position
	else:
		label.position = Vector2(rect.end.x - 100.0, rect.end.y + 5.0) - global_position
	_animate_pass_label(label)


func _show_center_feedback(key: StringName, color: Color) -> void:
	var label := _create_feedback_label(tr(key), color)
	label.size = Vector2(300.0, 88.0)
	label.add_theme_font_size_override("font_size", 52)
	label.position = get_global_rect().get_center() - global_position - label.size * 0.5
	played_panel.modulate.a = 0.0
	_animate_feedback_label(
		label,
		Vector2(0.0, -22.0),
		func() -> void:
			if is_instance_valid(played_panel):
				played_panel.modulate.a = 1.0
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
	var hold_duration := total_duration * 0.56
	var exit_duration := total_duration - enter_duration - hold_duration
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
	if _settings_tween != null:
		_settings_tween.kill()
	settings_panel.begin_edit()
	AudioService.play(&"ui_fade_in")
	settings_overlay.visible = true
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.modulate.a = 0.0
	settings_panel.scale = Vector2(0.96, 0.96)
	settings_panel.pivot_offset = settings_panel.size * 0.5
	_settings_tween = create_tween().set_parallel(true)
	_settings_tween.tween_property(settings_overlay, "modulate:a", 1.0, SettingsService.get_ui_animation_duration())
	_settings_tween.tween_property(settings_panel, "scale", Vector2.ONE, SettingsService.get_ui_animation_duration()).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _open_hand_types() -> void:
	if hand_types_overlay.visible:
		return
	if _hand_types_tween != null:
		_hand_types_tween.kill()
	AudioService.play(&"ui_fade_in")
	hand_types_overlay.visible = true
	hand_types_overlay.modulate.a = 0.0
	hand_types_dialog.scale = Vector2(0.97, 0.97)
	hand_types_dialog.pivot_offset = hand_types_dialog.size * 0.5
	_hand_types_tween = create_tween().set_parallel(true)
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
	_hand_types_tween = create_tween().set_parallel(true)
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
	)


func _close_settings() -> void:
	if not settings_overlay.visible:
		return
	if _settings_tween != null:
		_settings_tween.kill()
	AudioService.play(&"ui_fade_out")
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_tween = create_tween().set_parallel(true)
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
	)


func _on_settings_applied() -> void:
	_refresh()


func _on_settings_changed(_snapshot: Dictionary) -> void:
	_auto_pass_checked_revision = -1
	_refresh()


func _on_language_changed(_locale: String) -> void:
	_refresh()


func _on_return_to_menu_requested() -> void:
	if _session != null and _session.phase != GameSession.Phase.FINISHED:
		SaveGameService.save_session(_session, _use_custom_seed)
	settings_overlay.visible = false
	result_overlay.visible = false
	return_to_menu_requested.emit()


func _on_game_finished(player_index: int) -> void:
	SaveGameService.clear_save()
	AudioService.play(&"game_win" if player_index == HUMAN_PLAYER_INDEX else &"game_lose")
	winner_label.text = _translated(&"STATUS_WINNER", {"player": _player_name(player_index)})
	result_overlay.visible = true


func _on_public_action_resolved(public_action: Dictionary) -> void:
	for strategy in _strategies.values():
		(strategy as PlayerStrategy).observe_action(public_action.duplicate(true))


func _set_action_bar_visible(should_show: bool) -> void:
	if should_show == _actions_should_show:
		return
	_actions_should_show = should_show
	if _action_bar_tween != null:
		_action_bar_tween.kill()
	var duration := SettingsService.get_ui_animation_duration()
	if should_show:
		action_bar.visible = true
		action_bar.mouse_filter = Control.MOUSE_FILTER_PASS
		action_bar.position = Vector2(0.0, action_bar.size.y)
		action_bar.modulate.a = 0.0
		_action_bar_tween = create_tween().set_parallel(true)
		_action_bar_tween.tween_property(action_bar, "position", Vector2.ZERO, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_action_bar_tween.tween_property(action_bar, "modulate:a", 1.0, duration)
	else:
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_action_bar_tween = create_tween().set_parallel(true)
		_action_bar_tween.tween_property(action_bar, "position", Vector2(0.0, action_bar.size.y), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_action_bar_tween.tween_property(action_bar, "modulate:a", 0.0, duration)
		_action_bar_tween.chain().tween_callback(
			func() -> void:
				if not _actions_should_show:
					action_bar.visible = false
		)


func _setup_button_motion() -> void:
	for button in [
		settings_button,
		hand_types_button,
		hint_button,
		pass_button,
		play_button,
		restart_button,
		result_menu_button,
	]:
		_setup_single_button_motion(button)


func _setup_single_button_motion(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	button.mouse_entered.connect(func() -> void: _tween_button(button, Vector2(1.04, 1.04)))
	button.mouse_exited.connect(func() -> void: _tween_button(button, Vector2.ONE))
	button.button_down.connect(func() -> void: _tween_button(button, Vector2(0.96, 0.96)))
	button.button_up.connect(func() -> void: _tween_button(button, Vector2(1.04, 1.04)))


func _tween_button(button: Button, target_scale: Vector2) -> void:
	if _button_tweens.has(button):
		(_button_tweens[button] as Tween).kill()
	var tween := create_tween()
	tween.tween_property(
		button,
		"scale",
		target_scale,
		SettingsService.get_ui_animation_duration() * 0.55,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_button_tweens[button] = tween


func _on_dice_mouse_entered() -> void:
	_dice_hovered = true
	if not _rolling:
		_start_dice_hover()


func _on_dice_mouse_exited() -> void:
	_dice_hovered = false
	_refresh_dice_prompt()


func _on_draw_pile_mouse_entered() -> void:
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
	elif _can_human_roll():
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
	if _dealing or _session.phase == GameSession.Phase.FINISHED:
		turn_indicator.visible = false
		return
	var player_index := _session.current_player_index
	var panel := _get_player_panel(player_index)
	if panel == null or not panel.visible:
		turn_indicator.visible = false
		return
	turn_indicator.visible = true
	var panel_rect := panel.get_global_rect()
	var target_center: Vector2
	var facing_rotation: float
	if player_index == HUMAN_PLAYER_INDEX:
		var title_rect := hand_title.get_global_rect()
		target_center = Vector2(title_rect.position.x + 60.0, title_rect.position.y - 38.0) - global_position
		facing_rotation = PI
	else:
		target_center = Vector2(panel_rect.get_center().x, panel_rect.end.y + 28.0) - global_position
		facing_rotation = 0.0
	var moved_from_player := _indicator_player_index != -1 and _indicator_player_index != player_index
	turn_indicator.move_to(target_center, facing_rotation, _indicator_player_index == -1)
	if moved_from_player:
		AudioService.play(&"turn_change")
	_indicator_player_index = player_index


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
	var duration := SettingsService.get_ui_animation_duration()
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
	var duration := SettingsService.get_ui_animation_duration() * 0.84
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


func _get_player_panel(player_index: int) -> PanelContainer:
	if player_index < 0 or player_index >= _session.players.size():
		return null
	var seat_key := _session.players[player_index].display_name
	if not _seat_views.has(seat_key):
		return hand_panel if player_index == HUMAN_PLAYER_INDEX else null
	return (_seat_views[seat_key] as Dictionary)["panel"] as PanelContainer


func _get_selected_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id in _selected_card_ids:
		var index := _session.players[HUMAN_PLAYER_INDEX].find_card_index(card_id)
		if index != -1:
			cards.append(_session.players[HUMAN_PLAYER_INDEX].hand[index])
	return cards


func _can_human_roll() -> bool:
	return (
		_session != null
		and not _dealing
		and _session.current_player_index == HUMAN_PLAYER_INDEX
		and _session.phase == GameSession.Phase.AWAITING_ROLL
	)


func _can_human_act() -> bool:
	return (
		_session != null
		and not _dealing
		and _session.current_player_index == HUMAN_PLAYER_INDEX
		and _session.phase == GameSession.Phase.AWAITING_ACTION
		and not _rolling
		and not _presentation_busy
	)


func _dice_texture(value: int) -> Texture2D:
	return load(DICE_ROOT + "die_white_%d.png" % value) as Texture2D


func _player_name(player_index: int) -> String:
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
		if _session.players[HUMAN_PLAYER_INDEX].find_card_index(_selected_card_ids[index]) == -1:
			_selected_card_ids.remove_at(index)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
