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

	assert((app.get_node("Version") as Label).text == "v0.5.0")
	var content := app.get_node("%Content") as Control
	var menu := content.get_child(0) as MainMenu
	assert(menu != null)
	assert((menu.get_node("%MenuPanel") as PanelContainer).size.y >= 700.0)
	assert(not (menu.get_node("%SinglePlayerPanel") as PanelContainer).visible)

	(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
	await get_tree().process_frame
	var single_panel := menu.get_node("%SinglePlayerPanel") as PanelContainer
	assert(single_panel.visible)
	assert((menu.get_node("%PlayerCountOption") as OptionButton).get_selected_id() == 3)
	assert((menu.get_node("%IncludeJokersToggle") as CheckButton).button_pressed)
	assert((menu.get_node("%JokersWildToggle") as CheckButton).button_pressed)
	assert(not (menu.get_node("%SequencesIncludeTwoToggle") as CheckButton).button_pressed)
	assert(not (menu.get_node("%VariableDrawToggle") as CheckButton).button_pressed)

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
	var session := game.get("_session") as GameSession
	assert(session.players.size() == 3)
	assert(session.rules.include_jokers)
	assert(session.rules.jokers_are_wild)
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
