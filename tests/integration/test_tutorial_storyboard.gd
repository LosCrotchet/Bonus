extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scenario := load(
		"res://features/tutorial/content/default_tutorial.tres",
	) as TutorialScenario
	assert(scenario != null)
	assert(scenario.validate_graph().is_empty())
	assert(scenario.forced_first_human_roll == 5)
	var action_help := scenario.get_step(&"action_help")
	assert(action_help != null)
	assert(action_help.get_message(self).contains("\n"))
	for step_id in [
		&"intro_goal",
		&"deal_and_ranks",
		&"first_roll_intro",
		&"rolled_five",
		&"action_help",
		&"bonus_human",
		&"forced_draw",
		&"next_player_intro",
		&"covering_rules",
		&"joker_reminder",
		&"tutorial_complete",
	]:
		assert(scenario.get_step(step_id) != null, "Missing tutorial step: %s" % step_id)

	var game := (load("res://features/game/game_scene.tscn") as PackedScene).instantiate() as Control
	game.call("configure_tutorial", true, scenario)
	get_tree().root.add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var director := game.get("_tutorial_director") as TutorialDirector
	assert((director.get("_current_step") as TutorialStep).step_id == &"intro_goal")
	_advance_dialog(director)
	await get_tree().process_frame
	assert((director.get("_current_step") as TutorialStep).step_id == &"deal_and_ranks")
	assert(not bool(game.get("_tutorial_gameplay_locked")))
	game.call("_finish_initial_deal")
	await get_tree().process_frame
	assert((director.get("_current_step") as TutorialStep).step_id == &"first_roll_intro")
	_advance_dialog(director)
	await get_tree().process_frame
	assert((director.get("_current_step") as TutorialStep).step_id == &"wait_first_roll")

	game.call("_animate_roll_and_commit", 0, int(game.get("_game_serial")))
	assert(await _wait_until(
		func() -> bool:
			return (
				(game.get("_session") as GameSession).dice_value == 5
				and not bool(game.get("_rolling"))
			),
		5.0,
	))
	assert((director.get("_current_step") as TutorialStep).step_id == &"rolled_five")
	assert(not (game.get_node("%ActionBar") as Control).visible)
	assert(bool(game.get_node("%HandView").get("_interaction_enabled")))
	_advance_dialog(director)
	assert((director.get("_current_step") as TutorialStep).step_id == &"action_help")
	assert(not (game.get_node("%ActionBar") as Control).visible)
	_advance_dialog(director)
	assert((director.get("_current_step") as TutorialStep).step_id == &"wait_first_outcome")
	assert(director.notify_checkpoint(&"before_forced_draw", {
		"player_index": 0,
		"draw_count": 3,
	}))
	assert((director.get("_current_step") as TutorialStep).step_id == &"forced_draw")
	_advance_dialog(director)
	await get_tree().process_frame
	assert((director.get("_current_step") as TutorialStep).step_id == &"wait_next_player_checkpoint")
	assert(director.notify_checkpoint(&"before_next_player_roll", {"player_index": 1}))
	assert((director.get("_current_step") as TutorialStep).step_id == &"next_player_intro")
	_advance_dialog(director)
	await get_tree().process_frame
	assert((director.get("_current_step") as TutorialStep).step_id == &"wait_second_round")
	assert(director.notify_checkpoint(&"second_round_finished", {"player_index": 1}))
	assert((director.get("_current_step") as TutorialStep).step_id == &"covering_rules")
	_advance_dialog(director)
	assert((director.get("_current_step") as TutorialStep).step_id == &"joker_reminder")
	_advance_dialog(director)
	assert((director.get("_current_step") as TutorialStep).step_id == &"tutorial_complete")
	_advance_dialog(director)
	await get_tree().process_frame
	assert((director.get("_current_step") as TutorialStep).step_id == &"post_tutorial_monitor")
	assert(not bool(game.get("_tutorial_gameplay_locked")))
	assert(int(game.get("_tutorial_input_locks")) == 0)
	director.notify_event(&"bonus_started", {"player_index": 1})
	assert((director.get("_current_step") as TutorialStep).step_id == &"bonus_other_late")
	assert(bool(game.get("tutorial_bonus_explained")))
	_advance_dialog(director)
	assert((director.get("_current_step") as TutorialStep).step_id == &"post_tutorial_monitor")
	director.notify_event(&"bonus_started", {"player_index": 0})
	assert((director.get("_current_step") as TutorialStep).step_id == &"post_tutorial_monitor")

	print("BONUS_TEST_TUTORIAL_STORYBOARD_OK")
	game.queue_free()
	await AudioService.shutdown()
	get_tree().quit()


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
