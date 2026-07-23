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
	assert(bool(game_scene.get("_dealing")))
	game_scene.call("skip_initial_deal")
	await get_tree().process_frame
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
	var table_band := game_scene.get_node("%TableBand") as PanelContainer
	var table_bonus := game_scene.get_node("%TableBonusEffect") as ColorRect
	var hand_bonus := game_scene.get_node("%BonusEffect") as ColorRect
	var status_label := game_scene.get_node("%StatusLabel") as Label
	var action_slot := game_scene.get_node("%ActionSlot") as Control
	var selection_type := game_scene.get_node("%SelectionTypeLabel") as Label
	var interpretation_popup := game_scene.get_node("%InterpretationPopup") as PopupPanel
	var turn_indicator := game_scene.get_node("%TurnIndicator") as Control
	var hand_title := game_scene.get_node("%HandTitle") as Label
	var north_cards := game_scene.get_node("%NorthCards") as HBoxContainer
	var header_title := game_scene.get_node("%HeaderTitle") as Label
	var hand_types_button := game_scene.get_node("%HandTypesButton") as Button
	var hand_types_overlay := game_scene.get_node("%HandTypesOverlay") as Control
	var hand_types_dialog := game_scene.get_node("%HandTypesDialog") as HandTypesDialog
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
	assert(is_equal_approx(table_band.size.y, 156.0))
	assert(table_band.get_global_rect().position.x <= 1.0)
	assert(table_band.get_global_rect().end.x >= game_scene.get_global_rect().end.x - 1.0)
	assert(status_label.get_global_rect().position.y >= table_band.get_global_rect().end.y)
	assert(status_label.get_global_rect().end.y <= action_slot.get_global_rect().position.y)
	assert(not selection_type.visible)
	assert(header_title.text.begins_with("BONUS |"))
	assert(int(game_scene.get("_indicator_player_index")) == 0)
	var indicator_layout_center: Vector2 = (
		game_scene.get_global_rect().position
		+ turn_indicator.position
		+ turn_indicator.size * 0.5
	)
	assert(
		indicator_layout_center.y < hand_title.get_global_rect().position.y,
		"South indicator must stay above the hand title: center=%s title=%s"
		% [indicator_layout_center, hand_title.get_global_rect()],
	)
	assert(
		indicator_layout_center.x < hand_title.get_global_rect().get_center().x,
		"South indicator must stay left of the hand title center: center=%s title=%s"
		% [indicator_layout_center, hand_title.get_global_rect()],
	)
	assert(north_cards.get_child_count() == 8)
	assert(north_cards.get_child(7) is Label)
	assert(AudioServer.get_bus_index(&"SFX") != -1)
	assert(AudioServer.get_bus_index(&"Music") != -1)
	var hand_panel := game_scene.get_node("%HandPanel") as PanelContainer
	var hand_height := hand_panel.size.y
	var flow_borders := game_scene.get("_flow_borders") as Dictionary
	var hand_border := flow_borders[hand_panel] as ColorRect
	assert(hand_border.get_global_rect().position.is_equal_approx(hand_panel.get_global_rect().position))
	assert(hand_border.get_global_rect().size.is_equal_approx(hand_panel.get_global_rect().size))

	hand_types_button.pressed.emit()
	await get_tree().process_frame
	assert(hand_types_overlay.visible)
	assert((hand_types_dialog.get_node("%Rows") as VBoxContainer).get_child_count() == 6)
	var preview_cards := hand_types_dialog.find_children("*", "TextureRect", true, false)
	assert(not preview_cards.is_empty())
	var preview := preview_cards[0] as TextureRect
	assert(preview.custom_minimum_size == Vector2(48.0, 65.0))
	assert(preview.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	hand_types_dialog.close_requested.emit()
	assert(await _wait_until(func() -> bool: return not hand_types_overlay.visible, 1.0))

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
	assert(selection_type.global_position.x > (game_scene.get_node("%PlayButton") as Button).get_global_rect().end.x)
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

	_test_bonus_controls(game_scene, session, pass_button, table_bonus, hand_bonus)
	await get_tree().process_frame
	assert(not pass_button.visible)
	assert(table_bonus.visible)
	assert(not hand_bonus.visible)

	_test_interpretation_popup(game_scene, session)
	await get_tree().process_frame
	assert(interpretation_popup.visible)
	assert(interpretation_popup.size.y <= 420)
	assert(game_scene.get_node("%InterpretationOptions").get_child_count() == 3)
	interpretation_popup.hide()
	await _test_conservative_auto_pass(game_scene, session)
	await _test_global_double_clicks(game_scene)

	SettingsService.apply_settings(original_settings)
	SettingsService.set_master_volume(float(original_settings["master_volume"]))
	SettingsService.set_sfx_volume(float(original_settings["sfx_volume"]))
	SettingsService.set_music_volume(float(original_settings["music_volume"]))
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
	var original_master := SettingsService.master_volume
	settings_button.pressed.emit()
	await get_tree().process_frame
	assert(settings_overlay.visible)
	var master_slider := settings_panel.get_node("%MasterVolumeSlider") as HSlider
	var live_master := 0.31 if original_master > 0.5 else 0.79
	master_slider.value = live_master
	await get_tree().process_frame
	assert(is_equal_approx(SettingsService.master_volume, live_master))
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
	assert(is_equal_approx(SettingsService.master_volume, live_master))

	settings_button.pressed.emit()
	await get_tree().process_frame
	(settings_panel.get_node("%StatusTextToggle") as CheckButton).button_pressed = false
	(settings_panel.get_node("%ApplyButton") as Button).pressed.emit()
	await get_tree().process_frame
	assert(settings_overlay.visible)
	assert(not status_label.visible)
	var apply_status := settings_panel.get_node("%ApplyStatus") as Label
	assert(apply_status.visible)
	assert(not settings_panel.get_node("Layout").is_ancestor_of(apply_status))
	assert(apply_status.get_global_rect().position.x >= settings_panel.get_global_rect().end.x)
	assert(settings_panel.find_child("ExitGameButton", true, false) == null)
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
	table_bonus: ColorRect,
	hand_bonus: ColorRect,
) -> void:
	session.is_bonus = true
	session.last_play_pattern = null
	session.phase = GameSession.Phase.AWAITING_ACTION
	session.current_player_index = 0
	game_scene.call("_refresh")
	assert(not session.pass_turn(0))
	assert(session.last_error_key == &"ERROR_BONUS_MUST_PLAY")
	assert(not pass_button.visible)
	assert(table_bonus.visible)
	assert(hand_bonus.visible)

	session.roller_index = 1
	session.current_player_index = 1
	game_scene.call("_refresh")
	assert(not hand_bonus.visible)
	var north_panel := game_scene.get_node("%NorthSeat") as PanelContainer
	var flow_borders := game_scene.get("_flow_borders") as Dictionary
	var north_border := flow_borders[north_panel] as ColorRect
	assert(north_border.visible)
	assert(bool((north_border.material as ShaderMaterial).get_shader_parameter("bonus_mode")))


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
	var action_bar := game_scene.get_node("%ActionBar") as HBoxContainer
	var play_button := game_scene.get_node("%PlayButton") as Button
	assert(not action_bar.visible or play_button.disabled)
	await get_tree().create_timer(0.4).timeout
	assert(session.current_player_index == 1)


func _test_global_double_clicks(game_scene: Control) -> void:
	var snapshot := SettingsService.get_snapshot()
	snapshot["auto_pass"] = false
	snapshot["double_click_actions"] = true
	assert(SettingsService.apply_settings(snapshot))
	game_scene.call("_start_new_game")
	await get_tree().process_frame
	game_scene.call("skip_initial_deal")
	await get_tree().process_frame
	var session := game_scene.get("_session") as GameSession
	var card := CardData.new(9200, CardData.Rank.THREE, CardData.Suit.CLUBS)
	session.players[0].hand = [card]
	session.phase = GameSession.Phase.AWAITING_ACTION
	session.current_player_index = 0
	session.roller_index = 0
	session.dice_value = 1
	session.last_play_pattern = null
	var selected_ids: Array[int] = [card.card_id]
	game_scene.set("_selected_card_ids", selected_ids)
	game_scene.call("_refresh")
	await get_tree().process_frame

	var header_event := _double_click(MOUSE_BUTTON_LEFT, (game_scene.get_node("%Header") as Control).get_global_rect().get_center())
	game_scene.call("_input", header_event)
	await get_tree().process_frame
	assert(session.players[0].hand.size() == 1)

	var panel_event := _double_click(MOUSE_BUTTON_LEFT, (game_scene.get_node("%PlayedPanel") as Control).get_global_rect().get_center())
	game_scene.call("_input", panel_event)
	assert(await _wait_until(func() -> bool: return session.phase == GameSession.Phase.FINISHED, 1.5))
	assert(session.winner_index == 0)

	game_scene.call("_start_new_game")
	await get_tree().process_frame
	game_scene.call("skip_initial_deal")
	await get_tree().process_frame
	session = game_scene.get("_session") as GameSession
	session.phase = GameSession.Phase.AWAITING_ACTION
	session.current_player_index = 0
	session.roller_index = 0
	session.dice_value = 1
	selected_ids = [session.players[0].hand[0].card_id]
	game_scene.set("_selected_card_ids", selected_ids)
	game_scene.call("_refresh")
	var label_event := _double_click(MOUSE_BUTTON_RIGHT, (game_scene.get_node("%StatusLabel") as Control).get_global_rect().get_center())
	game_scene.call("_input", label_event)
	assert(session.current_player_index != 0)


func _double_click(button_index: int, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.position = position
	event.pressed = true
	event.double_click = true
	return event
