extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scenario := load(
		"res://features/tutorial/content/default_tutorial.tres",
	) as TutorialScenario
	assert(scenario != null)
	assert(scenario.validate_graph().is_empty())
	assert(scenario.entry_step_id == &"welcome")
	assert(scenario.forced_first_human_roll == 5)
	_assert_storyboard_resources(scenario)

	var game := (load("res://features/game/game_scene.tscn") as PackedScene).instantiate() as Control
	game.call("configure_tutorial", true, scenario)
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var director := game.get("_tutorial_director") as TutorialDirector
	assert(is_equal_approx(
		float(game.call("_get_initial_deal_card_duration")),
		SettingsService.get_deal_card_duration() * 0.5,
	))
	assert(_step_id(director) == &"welcome")
	_advance_dialog(director)
	assert(_step_id(director) == &"intro_goal")
	_advance_dialog(director)
	await get_tree().process_frame
	assert(_step_id(director) == &"deal_and_ranks")
	assert(not bool(game.get("_tutorial_gameplay_locked")))
	game.call("_finish_initial_deal")
	await get_tree().process_frame
	assert(_step_id(director) == &"first_roll_intro")
	_advance_dialog(director)
	assert(_step_id(director) == &"wait_first_roll")

	game.call("_animate_roll_and_commit", 0, int(game.get("_game_serial")))
	assert(await _wait_until(
		func() -> bool:
			return (
				(game.get("_session") as GameSession).dice_value == 5
				and not bool(game.get("_rolling"))
			),
		5.0,
	))
	assert(_step_id(director) == &"rolled_five")
	assert(not (game.get_node("%ActionBar") as Control).visible)
	assert(not bool(game.get_node("%HandView").get("_interaction_enabled")))
	_advance_dialog(director)
	assert(_step_id(director) == &"action_help")
	assert(await _wait_until(
		func() -> bool:
			return (game.get_node("%ActionBar") as Control).visible,
		1.0,
	))
	assert(not (game.get_node("%PassButton") as Button).disabled)
	assert(bool(game.get_node("%HandView").get("_interaction_enabled")))

	# Step five is action-driven: clicking the dialog cannot advance it.
	_advance_dialog(director)
	assert(_step_id(director) == &"action_help")
	director.notify_event(&"action_play", {"player_index": 0})
	assert(_step_id(director) == &"covering_rules")
	assert((int(game.get("_tutorial_input_locks")) & TutorialStep.InputLock.AI) != 0)
	assert((int(game.get("_tutorial_input_locks")) & TutorialStep.InputLock.HAND) == 0)
	_advance_dialog(director)
	assert(_step_id(director) == &"joker_reminder")
	_advance_dialog(director)
	assert(_step_id(director) == &"post_tutorial_monitor")
	assert(bool(game.get("tutorial_core_explained")))
	assert(not bool(game.get("_tutorial_completion_requested")))

	# The first empty-round draw lesson remains available even when the player
	# did not pass during their first action.
	assert(director.notify_checkpoint(&"before_forced_draw", {
		"player_index": 1,
		"draw_count": 3,
	}))
	assert(_step_id(director) == &"forced_draw_other")
	_advance_dialog(director)
	assert(_step_id(director) == &"wait_next_player_checkpoint")
	assert(director.notify_checkpoint(&"before_next_player_roll", {"player_index": 1}))
	assert(_step_id(director) == &"next_player_intro")
	_advance_dialog(director)
	assert(_step_id(director) == &"post_tutorial_monitor")
	assert(bool(game.get("tutorial_draw_explained")))
	assert(not director.notify_checkpoint(&"before_forced_draw", {
		"player_index": 0,
		"draw_count": 3,
	}))
	assert(_step_id(director) == &"post_tutorial_monitor")

	director.notify_event(&"bonus_started", {"player_index": 1})
	assert(_step_id(director) == &"bonus_other")
	_advance_dialog(director)
	assert(_step_id(director) == &"post_tutorial_monitor")
	await get_tree().process_frame
	assert(_step_id(director) == &"tutorial_complete")
	_advance_dialog(director)
	assert(_step_id(director) == &"post_tutorial_monitor")
	assert(bool(game.get("tutorial_bonus_lesson_complete")))
	director.notify_event(&"bonus_started", {"player_index": 0})
	assert(_step_id(director) == &"post_tutorial_monitor")
	assert(not bool(game.get("_tutorial_gameplay_locked")))

	print("BONUS_TEST_TUTORIAL_STORYBOARD_OK")
	game.queue_free()
	await AudioService.shutdown()
	get_tree().quit()


func _assert_storyboard_resources(scenario: TutorialScenario) -> void:
	for step_id in [
		&"welcome",
		&"intro_goal",
		&"deal_and_ranks",
		&"first_roll_intro",
		&"rolled_five",
		&"action_help",
		&"covering_rules",
		&"joker_reminder",
		&"bonus_human",
		&"bonus_other",
		&"forced_draw",
		&"forced_draw_other",
		&"next_player_intro",
		&"tutorial_complete",
	]:
		assert(scenario.get_step(step_id) != null, "Missing tutorial step: %s" % step_id)
	var deal := scenario.get_step(&"deal_and_ranks")
	assert(deal.pointer_offset == Vector2(-100.0, -120.0))
	var first_roll := scenario.get_step(&"first_roll_intro")
	assert(first_roll.pointer_offset == Vector2(150.0, 0.0))
	assert(first_roll.normalized_dialog_rect.size.x >= 0.479)
	var rolled_five := scenario.get_step(&"rolled_five")
	assert(rolled_five.normalized_dialog_rect.size.x >= 0.459)
	assert(not rolled_five.dim_background)
	assert((rolled_five.input_locks & TutorialStep.InputLock.HAND) != 0)
	var action_help := scenario.get_step(&"action_help")
	assert(action_help.continue_mode == TutorialStep.ContinueMode.EVENT)
	assert(not action_help.blocks_gameplay)
	var action_events: Array[StringName] = []
	for transition in action_help.transitions:
		if transition != null:
			action_events.append(transition.event_key)
	assert(&"action_play" in action_events)
	assert(&"action_pass" in action_events)
	var monitor := scenario.get_step(&"post_tutorial_monitor")
	var forced_draw_targets: Array[StringName] = []
	for transition in monitor.transitions:
		if transition != null and transition.event_key == &"before_forced_draw":
			forced_draw_targets.append(transition.target_step_id)
	assert(&"forced_draw" in forced_draw_targets)
	assert(&"forced_draw_other" in forced_draw_targets)
	for bonus_step_id in [&"bonus_human", &"bonus_other"]:
		var bonus_step := scenario.get_step(bonus_step_id)
		assert(bonus_step.minimum_display_time == 4.0)
		assert(bonus_step.normalized_dialog_rect.position.y >= 0.6)


func _step_id(director: TutorialDirector) -> StringName:
	var step := director.get("_current_step") as TutorialStep
	return step.step_id if step != null else StringName()


func _advance_dialog(director: TutorialDirector) -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(640.0, 360.0)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	director.call("_input", event)
	var step := director.get("_current_step") as TutorialStep
	if step != null and not bool(director.get("_continue_ready")):
		director.set("_minimum_display_complete", true)
		director.call("_try_enable_continue")
	director.call("_input", event)


func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return predicate.call()
