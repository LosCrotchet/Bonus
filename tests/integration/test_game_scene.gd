extends SceneTree

const CAPTURE_PATH := "res://tests/game_scene_capture.png"


func _init() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var packed_scene := load("res://features/game/game_scene.tscn") as PackedScene
	assert(packed_scene != null)
	var game_scene := packed_scene.instantiate()
	root.add_child(game_scene)

	await process_frame
	await process_frame
	RenderingServer.force_draw()

	var hand_view := game_scene.get_node("%HandView") as Control
	var roll_button := game_scene.get_node("%RollButton") as Button
	var hint_button := game_scene.get_node("%HintButton") as Button
	var play_button := game_scene.get_node("%PlayButton") as Button
	assert(hand_view.get_child_count() == 17)
	assert(not roll_button.disabled)
	assert(play_button.disabled)
	assert(game_scene.size.x >= 1000.0)
	assert(game_scene.size.y >= 600.0)

	if "--capture" in OS.get_cmdline_user_args():
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Viewport capture is unavailable with the current display driver")
			quit(1)
			return
		assert(image.save_png(CAPTURE_PATH) == OK)
		print("BONUS_GAME_SCENE_CAPTURED %dx%d" % [image.get_width(), image.get_height()])

	roll_button.pressed.emit()
	await process_frame
	var session := game_scene.get("_session") as GameSession
	assert(session.dice_value in [1, 2, 3, 4, 5, 6])
	assert(not hint_button.disabled)
	assert(not play_button.disabled)

	var hand_size_before := session.players[0].hand.size()
	hint_button.pressed.emit()
	await process_frame
	var selected_ids: Array[int] = game_scene.get("_selected_card_ids")
	assert(selected_ids.size() == session.dice_value)
	var played_count := session.dice_value
	play_button.pressed.emit()
	await process_frame
	assert(session.players[0].hand.size() == hand_size_before - played_count)
	assert(session.current_player_index == 1)

	await create_timer(1.3).timeout
	assert(session.current_player_index == 0 or session.phase == GameSession.Phase.FINISHED)

	print("BONUS_TEST_GAME_SCENE_OK")
	game_scene.queue_free()
	await process_frame
	quit()
