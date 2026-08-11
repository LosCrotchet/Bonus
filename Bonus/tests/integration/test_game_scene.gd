extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	SaveGameService.clear_save()
	var original_settings := SettingsService.get_snapshot()
	var packed_scene := load("res://features/game/game_scene.tscn") as PackedScene
	assert(packed_scene != null)
	var game_scene := packed_scene.instantiate()
	get_tree().root.add_child(game_scene)

	await get_tree().process_frame
	await get_tree().process_frame
	var session := game_scene.get("_session") as GameSession
	assert(AudioService.get("_music_track") == &"game")
	assert(bool(game_scene.get("_dealing")))
	var deal_counts := game_scene.get("_deal_visible_counts") as PackedInt32Array
	deal_counts[0] = 5
	game_scene.set("_deal_visible_counts", deal_counts)
	var visible_deal_hand: Array[CardData] = game_scene.call("_get_visible_human_hand")
	assert(visible_deal_hand.size() == 5)
	var expected_dealt_ids := {}
	for index in range(5):
		expected_dealt_ids[session.initial_deal_card_ids[0][index]] = true
	for card in visible_deal_hand:
		assert(expected_dealt_ids.has(card.card_id))
	assert(_is_hand_sorted(visible_deal_hand))
	game_scene.call("skip_initial_deal")
	await get_tree().process_frame
	var hand_view := game_scene.get_node("%HandView") as HandView
	var dice_button := game_scene.get_node("%DiceButton") as TextureButton
	var draw_pile := game_scene.get_node("%DrawPile") as TextureRect
	var action_bar := game_scene.get_node("%ActionBar") as HBoxContainer
	var west_seat := game_scene.get_node("%WestSeat") as PanelContainer
	var east_seat := game_scene.get_node("%EastSeat") as PanelContainer
	var settings_button := game_scene.get_node("%SettingsButton") as Button
	var settings_overlay := game_scene.get_node("%SettingsOverlay") as Control
	var settings_panel := game_scene.get_node("%SettingsPanel") as AppSettingsPanel
	var settings_dismiss := game_scene.get_node("%SettingsDismissButton") as Button
	var pass_button := game_scene.get_node("%PassButton") as Button
	var played_panel := game_scene.get_node("%PlayedPanel") as PanelContainer
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
	assert(hand_types_button.icon != null)
	assert(not hand_types_button.expand_icon)
	assert(hand_types_button.icon.get_size() == Vector2(32.0, 32.0))
	assert(hand_types_button.custom_minimum_size.x >= 170.0)
	assert(settings_button.icon != null)
	assert(not settings_button.expand_icon)
	assert(settings_button.icon.get_size() == Vector2(32.0, 32.0))
	assert(settings_button.custom_minimum_size.x >= 140.0)
	var instruction_hint := game_scene.get_node("%InstructionHint") as Control
	assert(instruction_hint.visible)
	assert((game_scene.get_node("%SelectHintText") as Label).text == tr(&"UI_CARD_SELECT_HINT"))
	assert((game_scene.get_node("%ClearHintText") as Label).text == tr(&"UI_CARD_CLEAR_HINT"))
	var auto_roll_button := game_scene.get_node("%AutoRollButton") as TextureButton
	var auto_skip_button := game_scene.get_node("%AutoSkipButton") as TextureButton
	var auto_play_button := game_scene.get_node("%AutoPlayButton") as TextureButton
	for automation_button in [auto_roll_button, auto_skip_button, auto_play_button]:
		assert(automation_button.custom_minimum_size == Vector2(32.0, 32.0))
		assert(automation_button.texture_normal is AtlasTexture)
	var auto_controls := game_scene.get_node("%AutoControls") as VBoxContainer
	assert(is_equal_approx(
		auto_controls.get_global_rect().end.x,
		(game_scene.get_node("%HandPanel") as Control).get_global_rect().end.x,
	))
	assert(auto_controls.global_position.y >= table_band.get_global_rect().end.y)
	assert(auto_controls.get_global_rect().end.y <= (game_scene.get_node("%HandPanel") as Control).global_position.y)
	assert(not (game_scene.get_node("%AutoRollCheck") as Label).visible)
	assert(not (game_scene.get_node("%AutoSkipCheck") as Label).visible)
	assert(not (game_scene.get_node("%AutoPlayCheck") as Label).visible)
	auto_roll_button.mouse_entered.emit()
	await get_tree().create_timer(0.1).timeout
	assert(auto_roll_button.scale.x > 1.0)
	auto_roll_button.mouse_exited.emit()
	await get_tree().create_timer(0.12).timeout
	assert(auto_roll_button.scale.is_equal_approx(Vector2.ONE))
	var hand_types_overlay := game_scene.get_node("%HandTypesOverlay") as Control
	var hand_types_dialog := game_scene.get_node("%HandTypesDialog") as HandTypesDialog
	assert(session.players.size() == 3)
	assert(session.draw_pile.size() == 57)
	assert(hand_view.get_child_count() == 17)
	for card_node in hand_view.get_children():
		var card_view := card_node as CardView
		assert(card_view != null)
		assert(bool(card_view.get_meta(&"control_motion_disabled", false)))
		assert(not bool(card_view.get_meta(&"motion_bound", false)))
	var hover_card := hand_view.get_child(0) as CardView
	hand_view.set_interaction_enabled(true)
	hover_card.call("_animate_transform", true)
	var hover_rest_position := hover_card.position
	hover_card.call("_on_mouse_entered")
	await get_tree().create_timer(CardView.INTERACTION_DURATION + 0.03).timeout
	assert(hover_card.position.y < hover_rest_position.y)
	hand_view.set_interaction_enabled(false)
	await get_tree().create_timer(CardView.INTERACTION_DURATION + 0.03).timeout
	assert(hover_card.position.is_equal_approx(hover_rest_position))
	hand_view.set_interaction_enabled(true)
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
	assert(draw_pile.get_parent().name == "DrawPileArea")
	assert(dice_button.get_global_rect().position.x - draw_pile.get_global_rect().end.x >= 20.0)
	var draw_pile_position := draw_pile.global_position
	dice_button.mouse_entered.emit()
	await get_tree().create_timer(0.18).timeout
	assert(draw_pile.global_position.is_equal_approx(draw_pile_position))
	dice_button.mouse_exited.emit()
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
	var turn_timer := game_scene.get_node("%TurnTimer") as PanelContainer
	assert(not turn_timer.visible)
	assert((turn_timer.get_node("Layout/ClockIcon") as TextureRect).texture != null)
	assert(
		turn_timer.get_theme_stylebox(&"panel").get_content_margin(SIDE_LEFT) >= 8.0
	)
	var clock_now := Time.get_ticks_msec()
	LanMultiplayerService.connection_state = (
		LanMultiplayerService.ConnectionState.IN_GAME
	)
	LanMultiplayerService.last_game_snapshot = {
		"turn_deadline_ms": clock_now + 30_000,
		"server_time_ms": clock_now,
		"received_at_ms": clock_now,
	}
	game_scene.set("_network_mode", true)
	game_scene.call("_refresh_turn_indicator")
	assert(turn_timer.visible)
	assert(turn_timer.modulate.a < 1.0)
	await get_tree().create_timer(0.3).timeout
	assert(is_equal_approx(turn_timer.modulate.a, 1.0))
	LanMultiplayerService.last_game_snapshot["turn_deadline_ms"] = 0
	game_scene.call("_refresh_turn_indicator")
	assert(not turn_timer.visible)
	game_scene.set("_network_mode", false)
	LanMultiplayerService.last_game_snapshot.clear()
	LanMultiplayerService.connection_state = (
		LanMultiplayerService.ConnectionState.OFFLINE
	)
	game_scene.call("_set_panel_disconnected", west_seat, true)
	game_scene.call("_show_disconnect_icon", west_seat)
	assert(west_seat.material is ShaderMaterial)
	assert((west_seat.get_node("Layout") as CanvasItem).use_parent_material)
	var disconnect_badge := (
		game_scene.get("_disconnect_icons") as Dictionary
	)[west_seat] as PanelContainer
	assert(disconnect_badge.visible)
	assert(disconnect_badge.size == Vector2(76.0, 76.0))
	assert(
		disconnect_badge.get_global_rect().get_center().is_equal_approx(
			west_seat.get_global_rect().get_center(),
		),
	)
	var disconnect_icon := disconnect_badge.get_child(0) as TextureRect
	assert(disconnect_icon.custom_minimum_size == Vector2(56.0, 56.0))
	assert(disconnect_icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	game_scene.call("_hide_disconnect_icon", west_seat)
	game_scene.call("_set_panel_disconnected", west_seat, false)
	assert(west_seat.material == null)
	assert(not (west_seat.get_node("Layout") as CanvasItem).use_parent_material)

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
		instruction_hint,
	)
	assert(_is_hand_sorted(session.players[0].hand))

	dice_button.pressed.emit()
	assert(await _wait_until(
		func() -> bool: return session.dice_value != 0 and action_bar.visible,
		2.5,
	))
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
	hand_view.set("_press_origin", Vector2(-100.0, -100.0))
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

	# A drag can begin outside the hand and still select each entered card once.
	Input.parse_input_event(mouse_down)
	await get_tree().process_frame
	first_card.pointer_entered.emit(first_card.card_id)
	first_card.pointer_entered.emit(first_card.card_id)
	second_card.pointer_entered.emit(second_card.card_id)
	selected_ids = game_scene.get("_selected_card_ids")
	assert(selected_ids.size() == 2)
	Input.parse_input_event(mouse_up)
	Input.parse_input_event(right_click)
	await get_tree().process_frame
	selected_ids = game_scene.get("_selected_card_ids")
	assert(selected_ids.is_empty())

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
	await _test_auto_play(game_scene)
	await _test_auto_roll(game_scene)
	await _test_global_double_clicks(game_scene)

	SettingsService.apply_settings(original_settings)
	SettingsService.set_master_volume(float(original_settings["master_volume"]))
	SettingsService.set_sfx_volume(float(original_settings["sfx_volume"]))
	SettingsService.set_music_volume(float(original_settings["music_volume"]))
	SaveGameService.clear_save()
	print("BONUS_TEST_GAME_SCENE_OK")
	game_scene.queue_free()
	await AudioService.shutdown()
	get_tree().quit()


func _test_transactional_settings(
	settings_button: Button,
	settings_overlay: Control,
	settings_panel: AppSettingsPanel,
	settings_dismiss: Button,
	status_label: Label,
	instruction_hint: Control,
) -> void:
	var original_speed := SettingsService.game_speed
	var original_master := SettingsService.master_volume
	var original_simplified := SettingsService.use_simplified_cards
	var instruction_rect := instruction_hint.get_global_rect()
	settings_button.pressed.emit()
	await get_tree().process_frame
	assert(settings_overlay.visible)
	var master_slider := settings_panel.get_node("%MasterVolumeSlider") as HSlider
	var live_master := 0.31 if original_master > 0.5 else 0.79
	master_slider.value = live_master
	await get_tree().process_frame
	assert(is_equal_approx(SettingsService.master_volume, live_master))
	var draft_speed := (
		SettingsService.GameSpeed.FAST
		if original_speed != SettingsService.GameSpeed.FAST
		else SettingsService.GameSpeed.SLOW
	)
	var speed_buttons: Array[Button] = [
		settings_panel.get_node("%SpeedSlowButton") as Button,
		settings_panel.get_node("%SpeedMediumButton") as Button,
		settings_panel.get_node("%SpeedFastButton") as Button,
	]
	speed_buttons[draft_speed].button_pressed = true
	settings_dismiss.pressed.emit()
	assert(await _wait_until(func() -> bool: return not settings_overlay.visible, 1.0))
	assert(not settings_overlay.visible)
	assert(SettingsService.game_speed == original_speed)
	assert(is_equal_approx(SettingsService.master_volume, live_master))

	settings_button.pressed.emit()
	await get_tree().process_frame
	(settings_panel.get_node("%StatusTextToggle") as CheckBox).button_pressed = false
	(settings_panel.get_node("%SimplifiedCardsToggle") as CheckBox).button_pressed = true
	(settings_panel.get_node("%ApplyButton") as Button).pressed.emit()
	await get_tree().create_timer(0.25).timeout
	assert(settings_overlay.visible)
	assert(not status_label.visible)
	assert(SettingsService.use_simplified_cards)
	assert(instruction_hint.visible)
	assert(instruction_hint.modulate.a < 0.01)
	assert(instruction_hint.get_global_rect().is_equal_approx(instruction_rect))
	var sample_card := CardData.new(9998, CardData.Rank.ACE, CardData.Suit.CLUBS)
	assert(CardTextureCatalog.get_texture_path(sample_card).ends_with(
		"simple/simplecard_club_1.png",
	))
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
	(settings_panel.get_node("%StatusTextToggle") as CheckBox).button_pressed = true
	(settings_panel.get_node("%SimplifiedCardsToggle") as CheckBox).button_pressed = original_simplified
	(settings_panel.get_node("%ApplyButton") as Button).pressed.emit()
	await get_tree().create_timer(0.25).timeout
	assert(settings_overlay.visible)
	assert(status_label.visible)
	assert(instruction_hint.modulate.a > 0.99)
	settings_dismiss.pressed.emit()
	assert(await _wait_until(func() -> bool: return not settings_overlay.visible, 1.0))


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
	assert(int(game_scene.get("_bonus_sound_step")) == 1)
	game_scene.set("_bonus_dice_frame", 0)
	game_scene.call("_process", 0.15)
	var random_frame := int(game_scene.get("_bonus_dice_frame"))
	assert(random_frame != 0)
	game_scene.call("_process", 0.15)
	assert(int(game_scene.get("_bonus_dice_frame")) != random_frame)

	session.roller_index = 1
	session.current_player_index = 1
	game_scene.call("_refresh")
	var active_hand_view := game_scene.get_node("%HandView") as HandView
	for card_node in active_hand_view.get_children():
		assert((card_node as CardView).interaction_enabled)
	assert(int(game_scene.get("_bonus_sound_step")) == 1)
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
	var auto_skip_button := game_scene.get_node("%AutoSkipButton") as TextureButton
	auto_skip_button.button_pressed = true
	assert(bool(game_scene.get("_auto_skip_enabled")))
	assert((game_scene.get_node("%AutoSkipCheck") as Label).visible)
	session.players[0].hand = [
		CardData.new(9100, CardData.Rank.THREE, CardData.Suit.CLUBS),
	]
	session.is_bonus = true
	session.last_play_pattern = null
	session.phase = GameSession.Phase.AWAITING_ACTION
	session.current_player_index = 0
	game_scene.call("_refresh")
	await get_tree().create_timer(0.22).timeout
	assert((game_scene.get_node("%InstructionHint") as Control).visible)
	var auto_pass_wait := SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.ACTION_PAUSE,
	) + 0.35
	await get_tree().create_timer(auto_pass_wait).timeout
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
	await get_tree().create_timer(auto_pass_wait).timeout
	assert(session.current_player_index == 1)
	auto_skip_button.button_pressed = false
	assert(not bool(game_scene.get("_auto_skip_enabled")))


func _test_auto_play(game_scene: Control) -> void:
	game_scene.call("_start_new_game")
	await get_tree().process_frame
	game_scene.call("skip_initial_deal")
	await get_tree().process_frame
	var session := game_scene.get("_session") as GameSession
	var card := CardData.new(9150, CardData.Rank.THREE, CardData.Suit.CLUBS)
	session.players[0].hand = [card]
	session.phase = GameSession.Phase.AWAITING_ACTION
	session.current_player_index = 0
	session.roller_index = 0
	session.dice_value = 1
	session.last_play_pattern = null
	var auto_play_button := game_scene.get_node("%AutoPlayButton") as TextureButton
	auto_play_button.button_pressed = true
	game_scene.call("_refresh")
	assert(await _wait_until(
		func() -> bool: return session.phase == GameSession.Phase.FINISHED,
		5.0,
	))
	assert(session.winner_index == 0)
	auto_play_button.button_pressed = false


func _test_auto_roll(game_scene: Control) -> void:
	game_scene.call("_start_new_game")
	await get_tree().process_frame
	game_scene.call("skip_initial_deal")
	await get_tree().process_frame
	var session := game_scene.get("_session") as GameSession
	assert(session.phase == GameSession.Phase.AWAITING_ROLL)
	var auto_roll_button := game_scene.get_node("%AutoRollButton") as TextureButton
	auto_roll_button.button_pressed = true
	game_scene.call("_refresh")
	assert(await _wait_until(
		func() -> bool: return bool(game_scene.get("_rolling")),
		1.0,
	))
	assert(await _wait_until(
		func() -> bool: return session.phase != GameSession.Phase.AWAITING_ROLL,
		4.0,
	))
	auto_roll_button.button_pressed = false
	assert(await _wait_until(
		func() -> bool: return not bool(game_scene.get("_presentation_busy")),
		3.0,
	))


func _test_global_double_clicks(game_scene: Control) -> void:
	var snapshot := SettingsService.get_snapshot()
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
	assert(await _wait_until(func() -> bool: return session.current_player_index != 0, 1.5))


func _double_click(button_index: int, position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.position = position
	event.pressed = true
	event.double_click = true
	return event
