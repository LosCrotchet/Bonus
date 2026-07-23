extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var packed_scene := load("res://app/app.tscn") as PackedScene
	assert(packed_scene != null)
	var app := packed_scene.instantiate() as Control
	get_tree().root.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame

	assert((app.get_node("Version") as Label).text == "v0.5.4")
	var content := app.get_node("%Content") as Control
	var menu := content.get_child(0) as MainMenu
	assert(menu != null)
	assert((menu.get_node("%SinglePlayerButton") as Button).icon != null)
	assert((menu.get_node("%MenuPanel") as PanelContainer).size.y >= 700.0)
	assert(not (menu.get_node("%SinglePlayerPanel") as PanelContainer).visible)

	(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
	await get_tree().process_frame
	var single_panel := menu.get_node("%SinglePlayerPanel") as PanelContainer
	assert(single_panel.visible)
	assert((menu.get_node("%PlayerCountOption") as OptionButton).get_selected_id() == 3)
	assert((menu.get_node("%IncludeJokersToggle") as CheckButton).button_pressed)
	assert((menu.get_node("%JokersWildToggle") as CheckButton).button_pressed)
	assert((menu.get_node("%WildcardFinishToggle") as CheckButton).button_pressed)
	assert((menu.get_node("%JokersWildRow") as HBoxContainer).visible)
	assert((menu.get_node("%WildcardFinishRow") as HBoxContainer).visible)
	assert(not (menu.get_node("%SequencesIncludeTwoToggle") as CheckButton).button_pressed)
	assert(not (menu.get_node("%VariableDrawToggle") as CheckButton).button_pressed)
	var include_jokers := menu.get_node("%IncludeJokersToggle") as CheckButton
	var jokers_wild := menu.get_node("%JokersWildToggle") as CheckButton
	var wildcard_finish := menu.get_node("%WildcardFinishToggle") as CheckButton
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

	(menu.get_node("%SinglePlayerBackButton") as Button).pressed.emit()
	assert(await _wait_until(func() -> bool: return not single_panel.visible, 1.0))
	(menu.get_node("%SettingsButton") as Button).pressed.emit()
	var menu_settings := menu.get_node("%SettingsSidePanel") as AppSettingsPanel
	assert(await _wait_until(func() -> bool: return menu_settings.visible, 1.0))
	await get_tree().create_timer(0.35).timeout
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
	await get_tree().create_timer(0.35).timeout
	assert(single_panel.position == secondary_position)

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
	game.call("skip_initial_deal")
	await get_tree().process_frame
	var session := game.get("_session") as GameSession
	assert(session.players.size() == 3)
	assert(session.rules.include_jokers)
	assert(session.rules.jokers_are_wild)
	assert(session.rules.draw_two_on_wildcard_finish)
	assert(not session.rules.allow_two_in_sequences)
	assert(not session.rules.draw_count_uses_dice)

	(game.get_node("%SettingsButton") as Button).pressed.emit()
	await get_tree().process_frame
	var settings_panel := game.get_node("%SettingsPanel") as AppSettingsPanel
	(settings_panel.get_node("%ExitMenuButton") as Button).pressed.emit()
	assert((settings_panel.get_node("%ExitMenuConfirmation") as HBoxContainer).visible)
	(settings_panel.get_node("%ExitMenuYes") as Button).pressed.emit()
	assert(await _wait_until(
		func() -> bool:
			return content.get_child_count() == 1 and content.get_child(0).name == "MainMenu",
		2.5,
	))
	print("BONUS_TEST_APP_OK")
	app.queue_free()
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
