extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	SaveGameService.clear_save()
	var packed_scene := load("res://app/app.tscn") as PackedScene
	assert(packed_scene != null)
	var app := packed_scene.instantiate() as Control
	get_tree().root.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame

	assert((app.get_node("Version") as Label).text == "v0.5.20")
	var content := app.get_node("%Content") as Control
	var menu := content.get_child(0) as MainMenu
	assert(menu != null)
	var single_player_panel := menu.get_node("%SinglePlayerPanel") as PanelContainer
	var cartoon_theme := load("res://assets/themes/cartoon_ui/controls.tres") as Theme
	assert(single_player_panel.theme == cartoon_theme)
	for variation: StringName in [
		&"Button",
		&"WideButton",
		&"SquareButton",
		&"BlueButton",
		&"RedButton",
		&"GreenButton",
	]:
		assert(cartoon_theme.has_stylebox(&"hover_pressed", variation))
		assert(cartoon_theme.get_stylebox(&"focus", variation) is StyleBoxEmpty)
	for button_path: NodePath in [
		^"%PlayerCount2",
		^"%PlayerCount3",
		^"%PlayerCount4",
	]:
		var button := menu.get_node(button_path) as Button
		assert(button.theme_type_variation == &"SquareButton")
		assert(not button.has_theme_stylebox_override(&"normal"))
	var info_button := single_player_panel.get_node(
		"Layout/VariableDrawRow/VariableDrawInfo",
	) as Button
	assert(info_button.theme_type_variation.is_empty())
	assert(info_button.has_theme_stylebox_override(&"normal"))
	assert(bool(info_button.get_meta(&"control_motion_disabled", false)))
	var info_rest_position := info_button.position
	info_button.mouse_entered.emit()
	await get_tree().create_timer(0.15).timeout
	assert(info_button.position.is_equal_approx(info_rest_position))
	var settings_side_panel := menu.get_node("%SettingsSidePanel") as Control
	var lan_panel := menu.get_node("%LanPanel") as Control
	assert(is_equal_approx(single_player_panel.position.x, 330.0))
	assert(is_equal_approx(settings_side_panel.position.x, 330.0))
	assert(is_equal_approx(lan_panel.position.x, 330.0))
	var button_texture := load(
		"res://assets/themes/cartoon_ui/black/button wider idle.png",
	) as Texture2D
	assert(button_texture.get_size() == Vector2(213.0, 40.0))
	var hover_button := menu.get_node("%SinglePlayerButton") as Button
	var hover_rest_position := hover_button.position
	hover_button.mouse_entered.emit()
	await get_tree().create_timer(0.15).timeout
	assert(hover_button.position.y <= hover_rest_position.y - 3.5)
	hover_button.mouse_exited.emit()
	await get_tree().create_timer(0.15).timeout
	assert(hover_button.position.is_equal_approx(hover_rest_position))
	assert(AudioService.get("_music_track") == &"menu")
	assert((menu.get_node("%SinglePlayerButton") as Button).icon != null)
	assert((menu.get_node("%TutorialButton") as Button).icon != null)
	assert((menu.get_node("%MenuPanel") as PanelContainer).size.y >= 700.0)
	assert(not (menu.get_node("%SinglePlayerPanel") as PanelContainer).visible)

	(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
	await get_tree().process_frame
	var single_panel := menu.get_node("%SinglePlayerPanel") as PanelContainer
	assert(single_panel.visible)
	assert((menu.get_node("%PlayerCount3") as Button).button_pressed)
	assert(not (menu.get_node("%PlayerCount2") as Button).button_pressed)
	assert((menu.get_node("%StartGameButton") as Button).icon == null)
	assert((menu.get_node("%SinglePlayerBackButton") as Button).icon == null)
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	menu.call("_on_language_changed", "en")
	assert((menu.get_node("%PlayerCount2") as Button).text == "2P")
	assert((menu.get_node("%PlayerCount3") as Button).text == "3P")
	assert((menu.get_node("%PlayerCount4") as Button).text == "4P")
	TranslationServer.set_locale(original_locale)
	menu.call("_on_language_changed", original_locale)
	assert((menu.get_node("%IncludeJokersToggle") as CheckBox).button_pressed)
	assert((menu.get_node("%JokersWildToggle") as CheckBox).button_pressed)
	assert((menu.get_node("%WildcardFinishToggle") as CheckBox).button_pressed)
	assert((menu.get_node("%JokersWildRow") as HBoxContainer).visible)
	assert((menu.get_node("%WildcardFinishRow") as HBoxContainer).visible)
	assert(not (menu.get_node("%SequencesIncludeTwoToggle") as CheckBox).button_pressed)
	assert(not (menu.get_node("%VariableDrawToggle") as CheckBox).button_pressed)
	var include_jokers := menu.get_node("%IncludeJokersToggle") as CheckBox
	var jokers_wild := menu.get_node("%JokersWildToggle") as CheckBox
	var wildcard_finish := menu.get_node("%WildcardFinishToggle") as CheckBox
	include_jokers.button_pressed = false
	assert(not jokers_wild.button_pressed)
	assert(not wildcard_finish.button_pressed)
	assert(not (menu.get_node("%JokersWildRow") as HBoxContainer).visible)
	assert(not (menu.get_node("%WildcardFinishRow") as HBoxContainer).visible)
	include_jokers.button_pressed = true
	assert((menu.get_node("%JokersWildRow") as HBoxContainer).visible)
	assert(not (menu.get_node("%WildcardFinishRow") as HBoxContainer).visible)
	jokers_wild.button_pressed = true
	wildcard_finish.button_pressed = true
	assert((menu.get_node("%WildcardFinishRow") as HBoxContainer).visible)
	await get_tree().create_timer(0.35).timeout
	var secondary_position := single_panel.position
	var secondary_size := single_panel.size
	(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
	assert(await _wait_until(func() -> bool: return not single_panel.visible, 1.0))
	(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
	assert(await _wait_until(func() -> bool: return single_panel.visible, 1.0))
	await get_tree().create_timer(0.35).timeout
	assert(single_panel.position.is_equal_approx(secondary_position))

	(menu.get_node("%SinglePlayerBackButton") as Button).pressed.emit()
	assert(await _wait_until(func() -> bool: return not single_panel.visible, 1.0))
	(menu.get_node("%SettingsButton") as Button).pressed.emit()
	var menu_settings := menu.get_node("%SettingsSidePanel") as AppSettingsPanel
	assert(await _wait_until(func() -> bool: return menu_settings.visible, 1.0))
	await get_tree().create_timer(0.35).timeout
	assert(not menu_settings.has_node(^"%AutoPassToggle"))
	var double_click_info := menu_settings.get_node("%DoubleClickInfo") as Button
	assert(double_click_info.tooltip_text == "UI_DOUBLE_CLICK_HINT")
	assert(bool(double_click_info.get_meta(&"control_motion_disabled", false)))
	assert(
		menu_settings.position.is_equal_approx(secondary_position),
		"Secondary panel positions differ: %s vs %s" % [menu_settings.position, secondary_position],
	)
	assert(
		menu_settings.size.is_equal_approx(secondary_size),
		"Secondary panel sizes differ: %s vs %s" % [menu_settings.size, secondary_size],
	)
	(menu_settings.get_node("%ApplyButton") as Button).pressed.emit()
	await get_tree().process_frame
	assert(menu_settings.visible)
	(menu_settings.get_node("%CancelButton") as Button).pressed.emit()
	assert(await _wait_until(func() -> bool: return not menu_settings.visible, 1.0))

	(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
	assert(await _wait_until(func() -> bool: return single_panel.visible, 1.0))
	(menu.get_node("%ExitGameButton") as Button).pressed.emit()
	assert(await _wait_until(
		func() -> bool: return not single_panel.visible and (menu.get_node("%ExitConfirmation") as HBoxContainer).visible,
		1.0,
	))
	(menu.get_node("%ExitNoButton") as Button).pressed.emit()

	(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
	assert(await _wait_until(func() -> bool: return single_panel.visible, 1.0))
	await get_tree().create_timer(0.35).timeout
	assert(single_panel.position == secondary_position)
	var custom_seed := menu.get_node("%CustomSeedToggle") as CheckBox
	custom_seed.button_pressed = true
	var seed_input := menu.get_node("%SeedInput") as LineEdit
	seed_input.text = "bonus123"
	assert((menu.get_node("%SeedInputRow") as HBoxContainer).visible)

	(menu.get_node("%StartGameButton") as Button).pressed.emit()
	assert(await _wait_until(
		func() -> bool:
			return (
				content.get_child_count() == 1
				and content.get_child(0).name == "GameScene"
				and not bool(app.get("_transitioning"))
			),
		2.5,
	))
	var game := content.get_child(0) as Control
	assert(AudioService.get("_music_track") == &"game")
	game.call("skip_initial_deal")
	await get_tree().process_frame
	var session := game.get("_session") as GameSession
	assert(session.players.size() == 3)
	assert(session.rules.include_jokers)
	assert(session.rules.jokers_are_wild)
	assert(session.rules.draw_two_on_wildcard_finish)
	assert(not session.rules.allow_two_in_sequences)
	assert(not session.rules.draw_count_uses_dice)
	assert(session.game_seed == SeedCodec.to_int("bonus123"))
	assert(session.game_seed_text == "bonus123")
	var saved_hand_ids := PackedInt32Array()
	for card in session.players[0].hand:
		saved_hand_ids.append(card.card_id)
	assert(session.accept_dice_result(0, 1))
	var action_bar := game.get_node("%ActionBar") as HBoxContainer
	assert(await _wait_until(func() -> bool: return action_bar.visible, 1.0))
	await get_tree().create_timer(0.3).timeout
	var expected_action_bar_position := action_bar.position

	(game.get_node("%SettingsButton") as Button).pressed.emit()
	await get_tree().process_frame
	var settings_panel := game.get_node("%SettingsPanel") as AppSettingsPanel
	(settings_panel.get_node("%ExitMenuButton") as Button).pressed.emit()
	assert((settings_panel.get_node("%ExitMenuConfirmation") as HBoxContainer).visible)
	(settings_panel.get_node("%ExitMenuYes") as Button).pressed.emit()
	assert(await _wait_until(
		func() -> bool:
			return (
				content.get_child_count() == 1
				and content.get_child(0).name == "MainMenu"
				and not bool(app.get("_transitioning"))
			),
		2.5,
	))
	menu = content.get_child(0) as MainMenu
	(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
	assert(await _wait_until(
		func() -> bool: return (menu.get_node("%ResumePrompt") as VBoxContainer).visible,
		1.0,
	))
	assert(not (menu.get_node("%StartGameButton") as Button).visible)
	var resume_details := (menu.get_node("%ResumeDetails") as Label).text
	assert(resume_details.contains("3"))
	assert(resume_details.contains("bonus123"))
	assert(resume_details.contains(menu.tr(&"RULE_JOKERS_WILD")))
	(menu.get_node("%ContinueGameButton") as Button).pressed.emit()
	assert(await _wait_until(
		func() -> bool:
			return (
				content.get_child_count() == 1
				and content.get_child(0).name == "GameScene"
				and not bool(app.get("_transitioning"))
			),
		2.5,
	))
	game = content.get_child(0) as Control
	session = game.get("_session") as GameSession
	assert(session.game_seed == SeedCodec.to_int("bonus123"))
	assert(session.game_seed_text == "bonus123")
	var resumed_hand_ids := PackedInt32Array()
	for card in session.players[0].hand:
		resumed_hand_ids.append(card.card_id)
	assert(resumed_hand_ids == saved_hand_ids)
	action_bar = game.get_node("%ActionBar") as HBoxContainer
	assert(action_bar.visible)
	assert(
		action_bar.position.is_equal_approx(expected_action_bar_position),
		"Resumed action bar shifted from %s to %s"
		% [expected_action_bar_position, action_bar.position],
	)
	SaveGameService.clear_save()
	print("BONUS_TEST_APP_OK")
	app.queue_free()
	await AudioService.shutdown()
	get_tree().quit()


func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return predicate.call()
