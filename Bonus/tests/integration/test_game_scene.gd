extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var original_settings := SettingsService.get_snapshot()
	var packed_scene := load("res://features/game/game_scene.tscn") as PackedScene
	assert(packed_scene != null)
	var game_scene := packed_scene.instantiate()
	get_tree().root.add_child(game_scene)

	await get_tree().process_frame
	await get_tree().process_frame
	var session := game_scene.get("_session") as GameSession
	var hand_view := game_scene.get_node("%HandView") as HandView
	var dice_button := game_scene.get_node("%DiceButton") as TextureButton
	var action_bar := game_scene.get_node("%ActionBar") as HBoxContainer
	var west_seat := game_scene.get_node("%WestSeat") as PanelContainer
	var east_seat := game_scene.get_node("%EastSeat") as PanelContainer
	var settings_button := game_scene.get_node("%SettingsButton") as Button
	var settings_overlay := game_scene.get_node("%SettingsOverlay") as Control
	var settings_panel := game_scene.get_node("%SettingsPanel") as AppSettingsPanel
	var settings_dismiss := game_scene.get_node("%SettingsDismissButton") as Button
	var pass_button := game_scene.get_node("%PassButton") as Button
	var played_panel := game_scene.get_node("%PlayedPanel") as PanelContainer
	var roll_panel := game_scene.get_node("%RollPanel") as PanelContainer
	var status_label := game_scene.get_node("%StatusLabel") as Label
	var selection_type := game_scene.get_node("%SelectionTypeLabel") as Label
	var interpretation_popup := game_scene.get_node("%InterpretationPopup") as PopupPanel
	assert(session.players.size() == 3)
	assert(session.draw_pile.size() == 57)
	assert(hand_view.get_child_count() == 17)
	assert(not dice_button.disabled)
	assert(not action_bar.visible)
	assert(west_seat.visible)
	assert(not east_seat.visible)
	assert(game_scene.size.x >= 1000.0)
	assert(game_scene.size.y >= 600.0)
	assert(played_panel.custom_minimum_size.x >= 480.0)
	assert(status_label.global_position.y < played_panel.global_position.y)
	assert(not selection_type.visible)
	var hand_panel := game_scene.get_node("%HandPanel") as PanelContainer
	var hand_height := hand_panel.size.y

	await _test_transactional_settings(
		settings_button,
		settings_overlay,
		settings_panel,
		settings_dismiss,
		status_label,
	)
	assert(_is_hand_sorted(session.players[0].hand))

	dice_button.pressed.emit()
	assert(await _wait_until(func() -> bool: return session.dice_value != 0, 2.0))
	assert(session.dice_value in [1, 2, 3, 4, 5, 6])
	assert(action_bar.visible)
	assert(not pass_button.disabled)

	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	Input.parse_input_event(mouse_down)
	await get_tree().process_frame
	var first_card := hand_view.get_child(0) as CardView
	var second_card := hand_view.get_child(1) as CardView
	first_card.left_pressed.emit(first_card.card_id)
	second_card.pointer_entered.emit(second_card.card_id)
	second_card.pointer_entered.emit(second_card.card_id)
	var selected_ids: Array[int] = game_scene.get("_selected_card_ids")
	assert(selected_ids.size() == 2)
	assert(selection_type.visible)
	assert(is_equal_approx(hand_panel.size.y, hand_height))

	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	Input.parse_input_event(mouse_up)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	Input.parse_input_event(right_click)
	await get_tree().process_frame
	selected_ids = game_scene.get("_selected_card_ids")
	assert(selected_ids.is_empty())
	assert(not selection_type.visible)

	_test_bonus_controls(game_scene, session, pass_button, roll_panel, played_panel)
	await get_tree().process_frame
	assert(not pass_button.visible)
	assert((roll_panel.get_node("FlowBorder") as ColorRect).visible)
	assert((played_panel.get_node("FlowBorder") as ColorRect).visible)

	_test_interpretation_popup(game_scene, session)
	await get_tree().process_frame
	assert(interpretation_popup.visible)
	assert(interpretation_popup.size.y <= 420)
	assert(game_scene.get_node("%InterpretationOptions").get_child_count() == 3)
	interpretation_popup.hide()
	await _test_conservative_auto_pass(game_scene, session)

	SettingsService.apply_settings(original_settings)
	print("BONUS_TEST_GAME_SCENE_OK")
	game_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _test_transactional_settings(
	settings_button: Button,
	settings_overlay: Control,
	settings_panel: AppSettingsPanel,
	settings_dismiss: Button,
	status_label: Label,
) -> void:
	var original_speed := SettingsService.game_speed
	settings_button.pressed.emit()
	await get_tree().process_frame
	assert(settings_overlay.visible)
	var speed_option := settings_panel.get_node("%GameSpeedOption") as OptionButton
	var draft_speed := (
		SettingsService.GameSpeed.FAST
		if original_speed != SettingsService.GameSpeed.FAST
		else SettingsService.GameSpeed.SLOW
	)
	_select_option_by_id(speed_option, draft_speed)
	settings_dismiss.pressed.emit()
	assert(await _wait_until(func() -> bool: return not settings_overlay.visible, 1.0))
	assert(not settings_overlay.visible)
	assert(SettingsService.game_speed == original_speed)

	settings_button.pressed.emit()
	await get_tree().process_frame
	(settings_panel.get_node("%StatusTextToggle") as CheckButton).button_pressed = false
	(settings_panel.get_node("%ApplyButton") as Button).pressed.emit()
	await get_tree().process_frame
	assert(settings_overlay.visible)
	assert(not status_label.visible)
	settings_dismiss.pressed.emit()
	assert(await _wait_until(func() -> bool: return not settings_overlay.visible, 1.0))

	settings_button.pressed.emit()
	await get_tree().process_frame
	var exit_menu_button := settings_panel.get_node("%ExitMenuButton") as Button
	var confirmation := settings_panel.get_node("%ExitMenuConfirmation") as HBoxContainer
	exit_menu_button.pressed.emit()
	assert(not exit_menu_button.visible and confirmation.visible)
	(settings_panel.get_node("%ExitMenuNo") as Button).pressed.emit()
	assert(exit_menu_button.visible and not confirmation.visible)
	(settings_panel.get_node("%StatusTextToggle") as CheckButton).button_pressed = true
	(settings_panel.get_node("%ApplyButton") as Button).pressed.emit()
	await get_tree().process_frame
	assert(settings_overlay.visible)
	assert(status_label.visible)
	settings_dismiss.pressed.emit()
	assert(await _wait_until(func() -> bool: return not settings_overlay.visible, 1.0))


func _select_option_by_id(option: OptionButton, item_id: int) -> void:
	for index in range(option.item_count):
		if option.get_item_id(index) == item_id:
			option.select(index)
			return
	assert(false)


func _is_hand_sorted(cards: Array[CardData]) -> bool:
	for index in range(1, cards.size()):
		if cards[index - 1].get_sort_value() > cards[index].get_sort_value():
			return false
	return true


func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return predicate.call()


func _test_bonus_controls(
	game_scene: Control,
	session: GameSession,
	pass_button: Button,
	roll_panel: PanelContainer,
	played_panel: PanelContainer,
) -> void:
	session.is_bonus = true
	session.last_play_pattern = null
	session.phase = GameSession.Phase.AWAITING_ACTION
	session.current_player_index = 0
	game_scene.call("_refresh")
	assert(not session.pass_turn(0))
	assert(session.last_error_key == &"ERROR_BONUS_MUST_PLAY")
	assert(not pass_button.visible)
	assert((roll_panel.get_node("FlowBorder") as ColorRect).visible)
	assert((played_panel.get_node("FlowBorder") as ColorRect).visible)


func _test_interpretation_popup(game_scene: Control, session: GameSession) -> void:
	var cards: Array[CardData] = [
		CardData.new(9001, CardData.Rank.THREE, CardData.Suit.CLUBS),
		CardData.new(9002, CardData.Rank.THREE, CardData.Suit.DIAMONDS),
		CardData.new(9003, CardData.Rank.FOUR, CardData.Suit.CLUBS),
		CardData.new(9004, CardData.Rank.FOUR, CardData.Suit.DIAMONDS),
		CardData.new(9005, 0, CardData.Suit.NONE, CardData.JokerKind.SMALL),
		CardData.new(9006, 0, CardData.Suit.NONE, CardData.JokerKind.BIG),
	]
	session.players[0].hand.assign(cards)
	session.is_bonus = true
	session.last_play_pattern = null
	session.phase = GameSession.Phase.AWAITING_ACTION
	session.current_player_index = 0
	var ids: Array[int] = []
	for card in cards:
		ids.append(card.card_id)
	game_scene.set("_selected_card_ids", ids)
	game_scene.call("_refresh")
	game_scene.call("_on_play_pressed")


func _test_conservative_auto_pass(game_scene: Control, session: GameSession) -> void:
	var snapshot := SettingsService.get_snapshot()
	snapshot["auto_pass"] = true
	assert(SettingsService.apply_settings(snapshot))
	session.players[0].hand = [
		CardData.new(9100, CardData.Rank.THREE, CardData.Suit.CLUBS),
	]
	session.is_bonus = true
	session.last_play_pattern = null
	session.phase = GameSession.Phase.AWAITING_ACTION
	session.current_player_index = 0
	game_scene.call("_refresh")
	await get_tree().create_timer(0.4).timeout
	assert(session.current_player_index == 0)

	session.is_bonus = false
	session.phase = GameSession.Phase.AWAITING_ROLL
	session.current_player_index = 0
	session.roller_index = 0
	session.dice_value = 0
	assert(session.accept_dice_result(0, 2))
	await get_tree().create_timer(0.4).timeout
	assert(session.current_player_index == 1)
