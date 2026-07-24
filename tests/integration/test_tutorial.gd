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
	var current_step := director.get("_current_step") as TutorialStep
	assert(current_step.step_id == &"welcome")
	assert(current_step.placement == TutorialStep.Placement.BOTTOM)
	assert(current_step.blocks_gameplay)
	assert((director.get_node("%Message") as Label).text == tr(&"TUTORIAL_WELCOME"))
	assert((director.get_node("%Emoji") as TextureRect).texture != null)
	assert(bool(game.get("_tutorial_gameplay_locked")))
	assert(bool(game.get("_dealing")))

	(director.get_node("%ContinueButton") as Button).pressed.emit()
	await get_tree().process_frame
	current_step = director.get("_current_step") as TutorialStep
	assert(current_step.step_id == &"initial_hand")
	assert(current_step.placement == TutorialStep.Placement.RIGHT)
	assert(current_step.pointer_target_path == NodePath("SafeArea/MainLayout/HandPanel"))
	assert((director.get_node("%Message") as Label).text == tr(&"TUTORIAL_INITIAL_HAND"))
	assert((director.get_node("%Emoji") as TextureRect).texture != null)
	var pointer := director.get_node("%PointerEmoji") as TextureRect
	var hand_panel := game.get_node("%HandPanel") as PanelContainer
	assert(pointer.visible)
	assert(pointer.texture != null)
	assert(hand_panel.get_global_rect().has_point(pointer.get_global_rect().get_center()))
	assert(pointer.get_global_rect().get_center().x > hand_panel.get_global_rect().get_center().x)
	assert((director.get_node("%Highlight") as Panel).visible)
	assert(bool(game.get("_tutorial_gameplay_locked")))
	assert(not bool(game.get("_deal_animation_running")))

	(director.get_node("%ContinueButton") as Button).pressed.emit()
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
