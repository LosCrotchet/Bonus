extends Node

func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var packed_scene := load("res://features/game/game_scene.tscn") as PackedScene
	assert(packed_scene != null)
	var game_scene := packed_scene.instantiate()
	get_tree().root.add_child(game_scene)

	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()

	var session := game_scene.get("_session") as GameSession
	var hand_view := game_scene.get_node("%HandView") as Control
	var dice_button := game_scene.get_node("%DiceButton") as TextureButton
	var action_bar := game_scene.get_node("%ActionBar") as HBoxContainer
	var west_seat := game_scene.get_node("%WestSeat") as PanelContainer
	var east_seat := game_scene.get_node("%EastSeat") as PanelContainer
	var settings_button := game_scene.get_node("%SettingsButton") as Button
	var settings_popup := game_scene.get_node("%SettingsPopup") as PopupPanel
	var player_count_option := game_scene.get_node("%PlayerCountOption") as OptionButton
	var game_speed_option := game_scene.get_node("%GameSpeedOption") as OptionButton
	var resolution_option := game_scene.get_node("%ResolutionOption") as OptionButton
	var window_mode_option := game_scene.get_node("%WindowModeOption") as OptionButton
	var language_option := game_scene.get_node("%LanguageOption") as OptionButton
	var pass_button := game_scene.get_node("%PassButton") as Button
	var played_panel := game_scene.get_node("%PlayedPanel") as PanelContainer
	var status_label := game_scene.get_node("%StatusLabel") as Label
	var interpretation_popup := game_scene.get_node("%InterpretationPopup") as PopupPanel
	var new_game_button := game_scene.get_node("%SettingsNewGameButton") as Button
	assert(session.players.size() == 3)
	assert(session.draw_pile.size() == 57)
	assert(hand_view.get_child_count() == 17)
	assert(not dice_button.disabled)
	assert(not action_bar.visible)
	assert(west_seat.visible)
	assert(not east_seat.visible)
	assert(game_scene.size.x >= 1000.0)
	assert(game_scene.size.y >= 600.0)
	assert(player_count_option.item_count == 3)
	assert(game_speed_option.item_count == 3)
	assert(resolution_option.item_count == SettingsService.RESOLUTIONS.size())
	assert(window_mode_option.item_count == 2)
	assert(language_option.item_count == 2)
	assert(played_panel.custom_minimum_size.x >= 480.0)
	assert(status_label.global_position.y < played_panel.global_position.y)

	settings_button.pressed.emit()
	await get_tree().process_frame
	assert(settings_popup.visible)
	settings_popup.hide()

	player_count_option.select(0)
	new_game_button.pressed.emit()
	await get_tree().process_frame
	session = game_scene.get("_session") as GameSession
	assert(session.players.size() == 2)
	assert(not west_seat.visible and not east_seat.visible)

	player_count_option.select(2)
	new_game_button.pressed.emit()
	await get_tree().process_frame
	session = game_scene.get("_session") as GameSession
	assert(session.players.size() == 4)
	assert(session.players[1].display_name == "SEAT_EAST")
	assert(west_seat.visible and east_seat.visible)

	player_count_option.select(1)
	new_game_button.pressed.emit()
	await get_tree().process_frame
	session = game_scene.get("_session") as GameSession
	assert(session.players.size() == 3)

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

	_test_bonus_controls(game_scene, session, pass_button)
	await get_tree().process_frame
	assert(not pass_button.visible)

	_test_interpretation_popup(game_scene, session)
	await get_tree().process_frame
	assert(interpretation_popup.visible)
	assert(interpretation_popup.size.y <= 420)
	assert(game_scene.get_node("%InterpretationOptions").get_child_count() == 3)
	interpretation_popup.hide()

	print("BONUS_TEST_GAME_SCENE_OK")
	game_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return predicate.call()


func _test_bonus_controls(game_scene: Control, session: GameSession, pass_button: Button) -> void:
	session.is_bonus = true
	session.last_play_pattern = null
	session.phase = GameSession.Phase.AWAITING_ACTION
	session.current_player_index = 0
	game_scene.call("_refresh")
	assert(not session.pass_turn(0))
	assert(session.last_error_key == &"ERROR_BONUS_MUST_PLAY")
	assert(not pass_button.visible)


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
