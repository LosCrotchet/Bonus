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
	var scenario := load(
		"res://features/tutorial/content/default_tutorial.tres",
	) as TutorialScenario
	assert(session.players.size() == 3)
	assert(session.game_seed_text == scenario.seed_text)
	assert(session.game_seed == SeedCodec.to_int(scenario.seed_text))
	assert((game.get_node("%HeaderTitle") as Label).text.contains(tr(&"UI_TUTORIAL")))
	assert((game.get_node("%HeaderSeed") as Label).text.contains(scenario.seed_text))
	var director := game.get("_tutorial_director") as TutorialDirector
	assert(director != null)
	assert(scenario.steps.size() >= 2)
	var current_step := director.get("_current_step") as TutorialStep
	assert(current_step == scenario.steps[0])
	assert(current_step.blocks_gameplay)
	assert((director.get_node("%Message") as Label).text == current_step.get_message(director))
	assert((director.get_node("%Emoji") as TextureRect).texture != null)
	var continue_indicator := director.get_node("%ContinueIndicator") as TextureRect
	assert(continue_indicator.visible)
	assert(director.get("_continue_float_tween") is Tween)
	var hand_border := (game.get("_flow_borders") as Dictionary)[
		game.get_node("%HandPanel")
	] as ColorRect
	assert(director.z_index > hand_border.z_index)
	assert(bool(game.get("_tutorial_gameplay_locked")))
	assert(bool(game.get("_dealing")))
	assert(not bool(game.get_node("%HandView").get("_interaction_enabled")))
	for automation_button_name in [
		"%AutoRollButton",
		"%AutoSkipButton",
		"%AutoPlayButton",
	]:
		assert((game.get_node(automation_button_name) as TextureButton).disabled)
	assert(not (game.get_node("%SettingsButton") as Button).disabled)
	assert(not (game.get_node("%HandTypesButton") as Button).disabled)

	var blocked_skip := _double_click(
		game.get_node("%PlayedPanel").get_global_rect().get_center(),
	)
	game.call("_input", blocked_skip)
	game.call("skip_initial_deal")
	await get_tree().process_frame
	assert(bool(game.get("_dealing")))
	assert(not bool(game.get("_deal_animation_running")))
	assert(director.get("_current_step") == scenario.steps[0])
	director.call("_input", blocked_skip)
	assert(director.get("_current_step") == scenario.steps[0])

	var settings_point := (game.get_node("%SettingsButton") as Control).get_global_rect().get_center()
	director.call("_input", _left_click(settings_point))
	assert(director.get("_current_step") == scenario.steps[0])

	director.call("_input", _left_click(Vector2(640.0, 360.0)))
	await get_tree().process_frame
	current_step = director.get("_current_step") as TutorialStep
	assert(current_step == scenario.steps[1])
	assert(bool(game.get("_tutorial_gameplay_locked")))
	assert(not bool(game.get("_deal_animation_running")))

	while director.get("_current_step") != null:
		current_step = director.get("_current_step") as TutorialStep
		assert(current_step.continue_mode == TutorialStep.ContinueMode.BUTTON)
		director.call("_input", _left_click(Vector2(640.0, 360.0)))
		await get_tree().process_frame
	assert(director.get("_current_step") == null)
	assert(not bool(game.get("_tutorial_gameplay_locked")))
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

	var custom_scenario := TutorialScenario.new()
	custom_scenario.include_jokers = false
	custom_scenario.jokers_are_wild = true
	var rules := custom_scenario.build_rules()
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


func _left_click(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _double_click(position: Vector2) -> InputEventMouseButton:
	var event := _left_click(position)
	event.double_click = true
	return event
