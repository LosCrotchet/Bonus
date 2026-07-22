extends Node


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
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

	var app := (load("res://app/app.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(app)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().root.size = requested_size
	await get_tree().process_frame
	var content := app.get_node("%Content") as Control
	var menu := content.get_child(0) as MainMenu
	if state == "settings":
		(menu.get_node("%SettingsButton") as Button).pressed.emit()
		await get_tree().create_timer(0.35).timeout
	if state in ["single", "game", "game_settings", "bonus"]:
		(menu.get_node("%SinglePlayerButton") as Button).pressed.emit()
		await get_tree().create_timer(0.35).timeout
	if state in ["game", "game_settings", "bonus"]:
		(menu.get_node("%StartGameButton") as Button).pressed.emit()
		while bool(app.get("_transitioning")) or content.get_child(0).name != "GameScene":
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		var game := content.get_child(0) as Control
		if state == "game_settings":
			(game.get_node("%SettingsButton") as Button).pressed.emit()
			await get_tree().create_timer(0.3).timeout
		elif state == "bonus":
			var session := game.get("_session") as GameSession
			session.is_bonus = true
			session.last_play_pattern = null
			session.phase = GameSession.Phase.AWAITING_ACTION
			session.current_player_index = 0
			game.call("_refresh")
			await get_tree().create_timer(0.35).timeout

	await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_tree().root.get_texture().get_image()
	if image == null:
		push_error("The active renderer does not expose a viewport texture")
		get_tree().quit(1)
		return
	var output_path := "res://.godot/visual/%s_%d.png" % [state, image.get_width()]
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save UI capture: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("BONUS_CAPTURE_OK %s" % output_path)
	get_tree().quit()
