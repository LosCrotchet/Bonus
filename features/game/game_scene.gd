extends Control

const HUMAN_PLAYER_INDEX := 0
const DEFAULT_PLAYER_COUNT := 3
const DICE_ROOT := "res://assets/art/dice/"
const ACTIVE_BORDER_COLOR := Color(1.0, 0.78, 0.26, 1.0)
const INACTIVE_BORDER_COLOR := Color(0.25, 0.4, 0.36, 0.75)

@onready var settings_button: Button = %SettingsButton
@onready var settings_popup: PopupPanel = %SettingsPopup
@onready var player_count_option: OptionButton = %PlayerCountOption
@onready var game_speed_option: OptionButton = %GameSpeedOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var language_option: OptionButton = %LanguageOption
@onready var settings_new_game_button: Button = %SettingsNewGameButton
@onready var exit_button: Button = %ExitButton
@onready var status_label: Label = %StatusLabel
@onready var deck_count_label: Label = %DeckCountLabel
@onready var dice_button: TextureButton = %DiceButton
@onready var dice_value_label: Label = %DiceValue
@onready var played_panel: PanelContainer = %PlayedPanel
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
@onready var interpretation_popup: PopupPanel = %InterpretationPopup
@onready var interpretation_options: VBoxContainer = %InterpretationOptions
@onready var result_overlay: Control = %ResultOverlay
@onready var winner_label: Label = %WinnerLabel
@onready var restart_button: Button = %RestartButton

var _session: GameSession
var _selected_card_ids: Array[int] = []
var _player_count := DEFAULT_PLAYER_COUNT
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
var _action_bar_tween: Tween
var _button_tweens: Dictionary = {}


func _ready() -> void:
	settings_button.pressed.connect(_on_settings_pressed)
	settings_new_game_button.pressed.connect(_on_settings_new_game_pressed)
	exit_button.pressed.connect(get_tree().quit)
	game_speed_option.item_selected.connect(_on_game_speed_selected)
	resolution_option.item_selected.connect(_on_resolution_selected)
	window_mode_option.item_selected.connect(_on_window_mode_selected)
	language_option.item_selected.connect(_on_language_selected)
	dice_button.pressed.connect(_on_dice_pressed)
	dice_button.mouse_entered.connect(_on_dice_mouse_entered)
	dice_button.mouse_exited.connect(_on_dice_mouse_exited)
	hint_button.pressed.connect(_on_hint_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	play_button.pressed.connect(_on_play_pressed)
	restart_button.pressed.connect(_start_new_game)
	hand_view.selection_changed.connect(_on_hand_selection_changed)
	SettingsService.language_changed.connect(_on_language_changed)

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
	_populate_settings_options()
	_start_new_game()
	await get_tree().process_frame
	_dice_rest_position = dice_button.position
	dice_button.pivot_offset = dice_button.size * 0.5
	_setup_button_motion()
	_refresh_dice_prompt()


func _start_new_game() -> void:
	_game_serial += 1
	_ai_task_running = false
	_rolling = false
	_last_bonus_state = false
	_pending_interpretations.clear()
	_selected_card_ids.clear()
	_clear_transient()
	_stop_dice_prompt()
	interpretation_popup.hide()

	_session = GameSession.new()
	_session.state_changed.connect(_refresh)
	_session.game_finished.connect(_on_game_finished)
	_session.action_resolved.connect(_on_public_action_resolved)
	_session.start_game(_player_names_for_count(_player_count))
	_initialize_strategies()
	result_overlay.visible = false
	_refresh()


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


func _refresh() -> void:
	if _session == null or _session.players.is_empty():
		return
	_prune_selection()
	_refresh_seats()
	_refresh_center_table()
	_refresh_hand()
	_refresh_actions()
	_refresh_status()
	_refresh_bonus_effect()
	_refresh_dice_prompt()
	_schedule_ai_if_needed()


func _refresh_seats() -> void:
	for seat_key in _seat_views:
		var view: Dictionary = _seat_views[seat_key]
		var player_index := _find_player_index(seat_key)
		var panel := view["panel"] as PanelContainer
		panel.visible = player_index != -1
		if player_index == -1:
			continue

		var player := _session.players[player_index]
		(view["name"] as Label).text = tr(player.display_name)
		(view["count"] as Label).text = str(player.hand.size())
		_set_panel_highlight(panel, player_index == _session.current_player_index)
		_fill_card_backs(view["cards"] as HBoxContainer, player.hand.size())

	hand_title.text = _translated(
		&"UI_HAND_TITLE",
		{"count": _session.players[HUMAN_PLAYER_INDEX].hand.size()},
	)
	_set_panel_highlight(hand_panel, _session.current_player_index == HUMAN_PLAYER_INDEX)


func _refresh_center_table() -> void:
	deck_count_label.text = _translated(&"UI_DRAW_REMAINING", {"count": _session.draw_pile.size()})
	if not _rolling:
		if _session.dice_value == 0:
			dice_button.texture_normal = _dice_texture(1)
			dice_button.modulate = Color(1.0, 1.0, 1.0, 0.5)
			dice_value_label.text = tr(&"UI_DICE_CLICK") if _can_human_roll() else tr(&"UI_DICE_WAIT")
		else:
			dice_button.texture_normal = _dice_texture(_session.dice_value)
			dice_button.modulate = Color.WHITE
			dice_value_label.text = _translated(&"UI_DICE_VALUE", {"value": _session.dice_value})

	_clear_container(played_cards)
	if _session.last_played_cards.is_empty():
		played_caption.text = tr(&"UI_PLAY_AREA_EMPTY")
		return

	played_caption.text = _translated(
		&"UI_PLAY_AREA_PLAYED",
		{
			"player": _player_name(_session.played_by_index),
			"hand_type": _hand_type_name(_session.last_play_pattern),
		},
	)
	for card in _session.last_played_cards:
		var card_texture := TextureRect.new()
		card_texture.texture = CardTextureCatalog.get_texture(card)
		card_texture.custom_minimum_size = Vector2(68.0, 96.0)
		card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		played_cards.add_child(card_texture)


func _refresh_hand() -> void:
	var can_select := _can_human_act()
	hand_view.set_hand(
		_session.players[HUMAN_PLAYER_INDEX].hand,
		_selected_card_ids,
		can_select,
	)
	_refresh_selection_labels()


func _refresh_actions() -> void:
	var awaiting_action := _can_human_act() and not _rolling
	var must_play_bonus := (
		awaiting_action
		and _session.is_bonus
		and _session.last_play_pattern == null
	)
	pass_button.visible = not must_play_bonus
	hint_button.disabled = not awaiting_action
	pass_button.disabled = not awaiting_action
	play_button.disabled = not awaiting_action
	dice_button.disabled = not _can_human_roll() or _rolling
	dice_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not dice_button.disabled else Control.CURSOR_ARROW
	)
	_set_action_bar_visible(awaiting_action)


func _refresh_status() -> void:
	if not _transient_key.is_empty():
		status_label.text = _translated(_transient_key, _transient_args)
		return
	if _rolling:
		status_label.text = _translated(
			&"STATUS_ROLLING",
			{"player": _player_name(_session.current_player_index)},
		)
		return
	if _session.phase == GameSession.Phase.FINISHED:
		status_label.text = _translated(
			&"STATUS_WINNER",
			{"player": _player_name(_session.winner_index)},
		)
		return

	var current_name := _player_name(_session.current_player_index)
	if _session.phase == GameSession.Phase.AWAITING_ROLL:
		status_label.text = (
			tr(&"STATUS_CLICK_DICE")
			if _session.current_player_index == HUMAN_PLAYER_INDEX
			else _translated(&"STATUS_PREPARING_ROLL", {"player": current_name})
		)
	elif _session.is_bonus and _session.last_play_pattern == null:
		status_label.text = _translated(&"STATUS_BONUS", {"player": current_name})
	elif _session.last_play_pattern != null:
		status_label.text = _translated(
			&"STATUS_MUST_COVER",
			{
				"player": current_name,
				"hand_type": _hand_type_name(_session.last_play_pattern),
			},
		)
	else:
		status_label.text = _translated(
			&"STATUS_MUST_PLAY",
			{"player": current_name, "count": _session.dice_value},
		)


func _refresh_selection_labels() -> void:
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

	if _selected_card_ids.is_empty():
		selection_type_label.text = tr(&"UI_HAND_TYPE_NONE")
		return
	var interpretations := HandEvaluator.get_distinct_interpretations(_get_selected_cards())
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
	bonus_effect.visible = _session.is_bonus
	if _session.is_bonus and not _last_bonus_state:
		_show_center_feedback(&"UI_BONUS_FEEDBACK", Color(1.0, 0.76, 0.25))
	_last_bonus_state = _session.is_bonus


func _on_dice_pressed() -> void:
	if not _can_human_roll() or _rolling:
		return
	_animate_roll_and_commit(HUMAN_PLAYER_INDEX, _game_serial)


func _animate_roll_and_commit(player_index: int, serial: int) -> void:
	_rolling = true
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
	_rolling = false
	dice_button.rotation = 0.0
	_refresh()


func _on_hint_pressed() -> void:
	_clear_transient()
	var recommendation := _session.get_recommended_play(HUMAN_PLAYER_INDEX)
	if recommendation.is_empty():
		_set_transient(&"STATUS_NO_LEGAL_PLAY")
	else:
		_selected_card_ids.assign(recommendation)
		hand_view.set_selection(_selected_card_ids)
	_refresh_selection_labels()
	_refresh_status()


func _on_pass_pressed() -> void:
	_clear_transient()
	_selected_card_ids.clear()
	if not _session.pass_turn(HUMAN_PLAYER_INDEX):
		_show_session_error()
	_refresh()


func _on_play_pressed() -> void:
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
	interpretation_popup.popup_centered(Vector2i(440, 350))


func _commit_play(interpretation_key: String) -> void:
	interpretation_popup.hide()
	_pending_interpretations.clear()
	if not _session.play_cards(
		HUMAN_PLAYER_INDEX,
		_selected_card_ids,
		interpretation_key,
	):
		_show_session_error()
	else:
		_selected_card_ids.clear()
	_refresh()


func _on_hand_selection_changed(selected_ids: Array[int]) -> void:
	_clear_transient()
	_selected_card_ids.assign(selected_ids)
	_refresh_selection_labels()
	_refresh_status()


func _schedule_ai_if_needed() -> void:
	if _ai_task_running or _session.phase == GameSession.Phase.FINISHED:
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
				await _animate_ai_card_play(player_index, decision.card_ids.size())
				if serial != _game_serial:
					return
				if not _session.play_cards(
					player_index,
					decision.card_ids,
					decision.interpretation_key,
				):
					_apply_ai_fallback(player_index)
			PlayerDecision.Action.PASS:
				_show_pass_feedback(player_index)
				await get_tree().create_timer(SettingsService.get_feedback_duration() * 0.5).timeout
				if serial != _game_serial:
					return
				if not _session.pass_turn(player_index):
					_apply_ai_fallback(player_index)
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
	for index in range(card_count):
		var card_back := TextureRect.new()
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
		var delay := index * 0.035
		var destination: Vector2 = target - card_back.size * 0.5 + Vector2(index * 10.0, 0.0)
		tween.tween_property(
			card_back,
			"position",
			destination,
			SettingsService.get_card_travel_duration(),
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(card_back, "rotation", 0.08 * (index - card_count * 0.5), SettingsService.get_card_travel_duration()).set_delay(delay)
	await tween.finished
	for card_back in flying_cards:
		card_back.queue_free()


func _show_pass_feedback(player_index: int) -> void:
	var panel := _get_player_panel(player_index)
	if panel == null:
		return
	var label := _create_feedback_label(tr(&"UI_PASS_FEEDBACK"), Color(0.92, 0.94, 0.93))
	label.position = panel.get_global_rect().get_center() - global_position - Vector2(48.0, 16.0)
	_animate_feedback_label(label, Vector2(0.0, -22.0))


func _show_center_feedback(key: StringName, color: Color) -> void:
	var label := _create_feedback_label(tr(key), color)
	label.add_theme_font_size_override("font_size", 34)
	label.position = (
		status_label.global_position
		- global_position
		+ Vector2(status_label.size.x * 0.5 - 80.0, -42.0)
	)
	_animate_feedback_label(label, Vector2(0.0, -30.0))


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


func _animate_feedback_label(label: Label, offset: Vector2) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + offset, SettingsService.get_feedback_duration())
	tween.tween_property(label, "modulate:a", 0.0, SettingsService.get_feedback_duration()).set_delay(SettingsService.get_feedback_duration() * 0.35)
	tween.chain().tween_callback(label.queue_free)


func _on_settings_pressed() -> void:
	_sync_settings_options()
	settings_popup.popup_centered(Vector2i(430, 480))


func _on_settings_new_game_pressed() -> void:
	_player_count = player_count_option.get_selected_id()
	settings_popup.hide()
	_start_new_game()


func _on_game_speed_selected(item_index: int) -> void:
	SettingsService.set_game_speed(game_speed_option.get_item_id(item_index))


func _on_resolution_selected(item_index: int) -> void:
	SettingsService.set_resolution(resolution_option.get_item_metadata(item_index) as Vector2i)


func _on_window_mode_selected(item_index: int) -> void:
	SettingsService.set_window_mode(window_mode_option.get_item_id(item_index))


func _on_language_selected(item_index: int) -> void:
	SettingsService.set_locale(str(language_option.get_item_metadata(item_index)))


func _on_language_changed(_locale: String) -> void:
	_populate_settings_options()
	_refresh()


func _populate_settings_options() -> void:
	player_count_option.clear()
	for count in range(2, 5):
		player_count_option.add_item(
			_translated(&"UI_PLAYER_COUNT_OPTION", {"count": count}),
			count,
		)

	game_speed_option.clear()
	game_speed_option.add_item(tr(&"UI_SPEED_SLOW"), SettingsService.GameSpeed.SLOW)
	game_speed_option.add_item(tr(&"UI_SPEED_MEDIUM"), SettingsService.GameSpeed.MEDIUM)
	game_speed_option.add_item(tr(&"UI_SPEED_FAST"), SettingsService.GameSpeed.FAST)

	resolution_option.clear()
	for index in range(SettingsService.RESOLUTIONS.size()):
		var resolution: Vector2i = SettingsService.RESOLUTIONS[index]
		resolution_option.add_item(_resolution_label(resolution), index)
		resolution_option.set_item_metadata(index, resolution)

	window_mode_option.clear()
	window_mode_option.add_item(tr(&"UI_WINDOWED"), SettingsService.WindowMode.WINDOWED)
	window_mode_option.add_item(tr(&"UI_FULLSCREEN"), SettingsService.WindowMode.FULLSCREEN)

	language_option.clear()
	language_option.add_item(tr(&"UI_LANGUAGE_ZH_CN"), 0)
	language_option.set_item_metadata(0, "zh_CN")
	language_option.add_item(tr(&"UI_LANGUAGE_EN"), 1)
	language_option.set_item_metadata(1, "en")
	_sync_settings_options()


func _sync_settings_options() -> void:
	_select_option_by_id(game_speed_option, SettingsService.game_speed)
	_select_option_by_id(window_mode_option, SettingsService.window_mode)
	for index in range(resolution_option.item_count):
		if resolution_option.get_item_metadata(index) == SettingsService.resolution:
			resolution_option.select(index)
			break
	for index in range(language_option.item_count):
		if language_option.get_item_metadata(index) == SettingsService.locale:
			language_option.select(index)
			break
	for index in range(player_count_option.item_count):
		if player_count_option.get_item_id(index) == _player_count:
			player_count_option.select(index)
			break


func _select_option_by_id(option: OptionButton, item_id: int) -> void:
	for index in range(option.item_count):
		if option.get_item_id(index) == item_id:
			option.select(index)
			return


func _resolution_label(value: Vector2i) -> String:
	var suffixes := {
		Vector2i(1280, 720): "720p",
		Vector2i(1920, 1080): "1080p",
		Vector2i(2560, 1440): "2K",
		Vector2i(3840, 2160): "4K",
	}
	var suffix := suffixes.get(value, "") as String
	return "%d × %d%s" % [value.x, value.y, " (%s)" % suffix if not suffix.is_empty() else ""]


func _on_game_finished(player_index: int) -> void:
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
		hint_button,
		pass_button,
		play_button,
		settings_new_game_button,
		exit_button,
		restart_button,
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
		card_back.texture = CardTextureCatalog.get_card_back()
		card_back.custom_minimum_size = Vector2(38.0, 52.0)
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(card_back)


func _set_panel_highlight(panel: PanelContainer, active: bool) -> void:
	var source := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if source == null:
		return
	var style := source.duplicate() as StyleBoxFlat
	style.border_color = ACTIVE_BORDER_COLOR if active else INACTIVE_BORDER_COLOR
	var width := 3 if active else 2
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	panel.add_theme_stylebox_override("panel", style)


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
		and _session.current_player_index == HUMAN_PLAYER_INDEX
		and _session.phase == GameSession.Phase.AWAITING_ROLL
	)


func _can_human_act() -> bool:
	return (
		_session != null
		and _session.current_player_index == HUMAN_PLAYER_INDEX
		and _session.phase == GameSession.Phase.AWAITING_ACTION
		and not _rolling
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
	_set_transient(_session.last_error_key, _session.last_error_args)


func _prune_selection() -> void:
	for index in range(_selected_card_ids.size() - 1, -1, -1):
		if _session.players[HUMAN_PLAYER_INDEX].find_card_index(_selected_card_ids[index]) == -1:
			_selected_card_ids.remove_at(index)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
