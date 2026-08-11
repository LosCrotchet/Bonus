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
	var expected_initial_step := (
		scenario.get_step(scenario.entry_step_id)
		if scenario.uses_graph()
		else scenario.steps[0]
	)
	assert(current_step.step_id == expected_initial_step.step_id)
	assert(current_step.blocks_gameplay)
	var message_label := director.get_node("%Message") as Label
	assert(message_label.text == current_step.get_message(director))
	assert((director.get_node("%Emoji") as TextureRect).texture != null)
	var continue_indicator := director.get_node("%ContinueIndicator") as TextureRect
	if message_label.visible_characters != -1:
		assert(not continue_indicator.visible)
		assert(not bool(director.get("_continue_ready")))
		director.call("_input", _left_click(Vector2(640.0, 360.0)))
	assert((director.get("_current_step") as TutorialStep).step_id == current_step.step_id)
	assert(message_label.visible_characters == -1)
	assert(continue_indicator.visible)
	assert(bool(director.get("_continue_ready")))
	assert(director.get("_continue_indicator_tween") is Tween)
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
	assert((director.get("_current_step") as TutorialStep).step_id == current_step.step_id)
	director.call("_input", blocked_skip)
	assert((director.get("_current_step") as TutorialStep).step_id == current_step.step_id)

	var settings_point := (game.get_node("%SettingsButton") as Control).get_global_rect().get_center()
	director.call("_input", _left_click(settings_point))
	assert((director.get("_current_step") as TutorialStep).step_id == current_step.step_id)

	director.call("_input", _left_click(Vector2(640.0, 360.0)))
	await get_tree().process_frame
	current_step = director.get("_current_step") as TutorialStep
	assert(current_step.step_id != expected_initial_step.step_id)
	assert(bool(game.get("_tutorial_gameplay_locked")))
	assert(not bool(game.get("_deal_animation_running")))

	director.call("_finish_current_step")
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

	var graph_scenario := TutorialScenario.new()
	var graph_a := TutorialStep.new()
	graph_a.step_id = &"graph_a"
	graph_a.fallback_message = "AReallyLongUnbrokenTutorialSentenceWithoutSpaces".repeat(8)
	graph_a.use_custom_dialog_rect = true
	graph_a.normalized_dialog_rect = Rect2(0.1, 0.12, 0.3, 0.24)
	graph_a.input_locks = TutorialStep.InputLock.DOUBLE_CLICK
	graph_a.pointer_emoji = expected_initial_step.emoji
	graph_a.pointer_target_path = game.get_path_to(game.get_node("%SettingsButton"))
	graph_a.pointer_offset = Vector2(24.0, -16.0)
	graph_a.type_sound_every_characters = 3
	assert(graph_a.type_sound_every_characters == 3)
	var hide_pass := TutorialControlDirective.new()
	hide_pass.target_path = game.get_path_to(game.get_node("%PassButton"))
	hide_pass.mode = TutorialControlDirective.Mode.HIDE
	graph_a.control_directives.append(hide_pass)
	var to_b := TutorialTransition.new()
	to_b.target_step_id = &"graph_b"
	graph_a.transitions.append(to_b)
	var graph_b := TutorialStep.new()
	graph_b.step_id = &"graph_b"
	graph_b.continue_mode = TutorialStep.ContinueMode.EVENT
	var to_c := TutorialTransition.new()
	to_c.trigger_mode = TutorialTransition.TriggerMode.EVENT
	to_c.event_key = &"branch_event"
	to_c.target_step_id = &"graph_c"
	var branch_condition := TutorialCondition.new()
	branch_condition.property_path = "choice"
	branch_condition.compare_value = "yes"
	to_c.conditions.append(branch_condition)
	graph_b.transitions.append(to_c)
	var graph_c := TutorialStep.new()
	graph_c.step_id = &"graph_c"
	graph_c.fallback_message = "Graph C"
	graph_scenario.steps.assign([graph_a, graph_b, graph_c])
	graph_scenario.entry_step_id = graph_a.step_id
	assert(graph_scenario.validate_graph().is_empty())
	assert(graph_scenario.get_initial_hands_debug().size() == 3)
	var example := load(
		"res://features/tutorial/examples/branching_example.tres",
	) as TutorialScenario
	assert(example != null)
	assert(example.validate_graph().is_empty())
	director.setup(game, graph_scenario)
	director.restart()
	assert(not (game.get_node("%PassButton") as Button).visible)
	await get_tree().process_frame
	assert(director.get("_current_step") == graph_a)
	await get_tree().create_timer(0.32).timeout
	var graph_visible_characters := (
		(director.get_node("%Message") as Label).visible_characters
	)
	assert(graph_visible_characters >= 1)
	assert(graph_visible_characters <= 4)
	var graph_dialog := director.get_node("%Dialog") as PanelContainer
	var expected_dialog_size := director.size * graph_a.normalized_dialog_rect.size
	assert(
		graph_dialog.size.is_equal_approx(expected_dialog_size),
		"Dialog size %s != configured size %s" % [graph_dialog.size, expected_dialog_size],
	)
	var pointer := director.get_node("%PointerEmoji") as TextureRect
	var target_rect := (game.get_node("%SettingsButton") as Control).get_global_rect()
	var pointer_size := pointer.size
	var desired_pointer_position := Vector2(
		target_rect.end.x - pointer_size.x - 42.0,
		target_rect.position.y + 24.0,
	) + graph_a.pointer_offset
	var viewport_rect := director.get_viewport_rect().grow(-12.0)
	var expected_pointer_position := Vector2(
		clampf(
			desired_pointer_position.x,
			viewport_rect.position.x,
			viewport_rect.end.x - pointer_size.x,
		),
		clampf(
			desired_pointer_position.y,
			viewport_rect.position.y,
			viewport_rect.end.y - pointer_size.y,
		),
	)
	assert(pointer.global_position.is_equal_approx(expected_pointer_position))
	director.call("_input", _left_click(Vector2(640.0, 360.0)))
	assert(director.get("_current_step") == graph_a)
	assert((director.get_node("%Message") as Label).visible_characters == -1)
	assert((director.get_node("%Message") as Label).get_line_count() > 1)
	director.call("_input", _left_click(Vector2(640.0, 360.0)))
	assert(director.get("_current_step") == graph_b)
	director.notify_event(&"branch_event", {"choice": "no"})
	assert(director.get("_current_step") == graph_b)
	director.notify_event(&"branch_event", {"choice": "yes"})
	assert(director.get("_current_step") == graph_c)

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
