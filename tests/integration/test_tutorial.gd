extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var packed := load("res://app/app.tscn") as PackedScene
	assert(packed != null)
	var app := packed.instantiate() as Control
	get_tree().root.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	var content := app.get_node("%Content") as Control
	var menu := content.get_child(0) as MainMenu
	var tutorial_button := menu.get_node("%TutorialButton") as Button
	assert(tutorial_button.icon != null)
	assert(tutorial_button.get_index() == 0)
	tutorial_button.pressed.emit()
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
	assert(bool(game.get("_tutorial_mode")))
	var session := game.get("_session") as GameSession
	assert(session.players.size() == 3)
	assert(session.game_seed_text == "teach001")
	assert(session.game_seed == SeedCodec.to_int("teach001"))
	assert((game.get_node("%HeaderTitle") as Label).text.contains(tr(&"UI_TUTORIAL")))
	assert((game.get_node("%HeaderSeed") as Label).text.contains("teach001"))
	assert(game.get("_tutorial_director") is TutorialDirector)
	for strategy in (game.get("_strategies") as Dictionary).values():
		assert(strategy is TutorialStrategy)

	game.call("skip_initial_deal")
	await get_tree().process_frame
	game.call("queue_tutorial_ai_command", 1, {
		"phase": "awaiting_roll",
		"action": "roll",
	})
	var tutorial_strategy := (game.get("_strategies") as Dictionary)[1] as TutorialStrategy
	assert(tutorial_strategy.choose_action(
		session.create_strategy_context(1),
	).action == PlayerDecision.Action.ROLL)
	game.call("set_tutorial_gameplay_locked", true)
	await get_tree().process_frame
	assert(bool(game.get("_tutorial_gameplay_locked")))
	game.call("set_tutorial_gameplay_locked", false)

	var scenario := TutorialScenario.new()
	scenario.include_jokers = false
	scenario.jokers_are_wild = true
	var rules := scenario.build_rules()
	assert(not rules.include_jokers)
	assert(not rules.jokers_are_wild)

	print("BONUS_TEST_TUTORIAL_OK")
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
