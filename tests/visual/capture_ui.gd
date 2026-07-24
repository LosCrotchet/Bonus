extends Node


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	SaveGameService.clear_save()
	var state := "menu"
	var requested_size := Vector2i(1280, 720)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("state="):
			state = argument.trim_prefix("state=")
		elif argument.begins_with("size="):
			var parts := argument.trim_prefix("size=").split("x")
			if parts.size() == 2:
				requested_size = Vector2i(int(parts[0]), int(parts[1]))
	get_tree().root.size = requested_size
	if state == "resume":
		var saved_session := GameSession.new()
		assert(saved_session.start_game(
			["SEAT_SOUTH", "SEAT_NORTH", "SEAT_WEST"],
			20260723,
		))
		assert(saved_session.accept_dice_result(0, 1))
		assert(SaveGameService.save_session(saved_session, true))

	var app := (load("res://app/app.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().root.size = requested_size
	await get_tree().process_frame
	var content := app.get_node("%Content") as Control
	var menu := content.get_child(0) as MainMenu
	if state in ["tutorial_welcome", "tutorial_hand"]:
		(menu.get_node("%TutorialButton") as Button).pressed.emit()
		while bool(app.get("_transitioning")) or content.get_child(0).name != "GameScene":
			await get_tree().process_frame
		var tutorial_director := content.get_child(0).get("_tutorial_director") as TutorialDirector
		if state == "tutorial_hand":
			(tutorial_director.get_node("%ContinueButton") as Button).pressed.emit()
		await get_tree().create_timer(0.3).timeout
	if state in ["settings", "settings_applied"]:
		(menu.get_node("%SettingsButton") as Button).pressed.emit()
		await get_tree().create_timer(0.35).timeout
		if state == "settings_applied":
			var panel := menu.get_node("%SettingsSidePanel") as AppSettingsPanel
			(panel.get_node("%ApplyButton") as Button).pressed.emit()
			await get_tree().create_timer(0.18).timeout
	var game_states := [
		"dealing",
		"game",
		"selected",
		"game_settings",
		"user_bonus",
		"ai_bonus",
		"hand_types",
	]
	if state in ["single", "resume"] or state in game_states:
		(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
		await get_tree().create_timer(0.35).timeout
	if state in game_states:
		(menu.get_node("%StartGameButton") as Button).pressed.emit()
		while bool(app.get("_transitioning")) or content.get_child(0).name != "GameScene":
			await get_tree().process_frame
		var game := content.get_child(0) as Control
		if state == "dealing":
			await get_tree().create_timer(0.35).timeout
		else:
			game.call("skip_initial_deal")
			await get_tree().create_timer(0.35).timeout
		if state == "game_settings":
			(game.get_node("%SettingsButton") as Button).pressed.emit()
			await get_tree().create_timer(0.3).timeout
		elif state in ["user_bonus", "ai_bonus"]:
			var session := game.get("_session") as GameSession
			session.is_bonus = true
			session.last_play_pattern = null
			session.phase = GameSession.Phase.AWAITING_ACTION
			session.current_player_index = 0 if state == "user_bonus" else 1
			session.roller_index = session.current_player_index
			game.call("_refresh")
			await get_tree().create_timer(0.35).timeout
		elif state == "hand_types":
			(game.get_node("%HandTypesButton") as Button).pressed.emit()
			await get_tree().create_timer(0.25).timeout
		elif state == "selected":
			var session := game.get("_session") as GameSession
			session.accept_dice_result(0, 1)
			var selected_ids: Array[int] = [session.players[0].hand[0].card_id]
			game.set("_selected_card_ids", selected_ids)
			game.call("_refresh")
			await get_tree().create_timer(0.25).timeout

	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_tree().root.get_texture().get_image()
	if image == null:
		push_error("The active renderer does not expose a viewport texture")
		get_tree().quit(1)
		return
	var output_path := "res://.godot/visual/%s_%dx%d.png" % [
		state,
		image.get_width(),
		image.get_height(),
	]
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save UI capture: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("BONUS_CAPTURE_OK %s" % output_path)
	SaveGameService.clear_save()
	get_tree().quit()
