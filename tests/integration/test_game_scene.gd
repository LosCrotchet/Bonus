extends Node

const CAPTURE_PATH := "res://tests/game_scene_capture.png"


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var packed_scene := load("res://features/game/game_scene.tscn") as PackedScene
	assert(packed_scene != null)
	var game_scene := packed_scene.instantiate()
	get_tree().root.add_child(game_scene)

	await get_tree().process_frame
	await get_tree().process_frame
	RenderingServer.force_draw()

	var session := game_scene.get("_session") as GameSession
	var hand_view := game_scene.get_node("%HandView") as Control
	var dice_button := game_scene.get_node("%DiceButton") as TextureButton
	var action_bar := game_scene.get_node("%ActionBar") as HBoxContainer
	var west_seat := game_scene.get_node("%WestSeat") as PanelContainer
	var east_seat := game_scene.get_node("%EastSeat") as PanelContainer
	var settings_button := game_scene.get_node("%SettingsButton") as Button
	var settings_popup := game_scene.get_node("%SettingsPopup") as PopupPanel
	var player_count_option := game_scene.get_node("%PlayerCountOption") as OptionButton
	var new_game_button := game_scene.get_node("%SettingsNewGameButton") as Button
	assert(session.players.size() == 3)
	assert(session.draw_pile.size() == 57)
	assert(hand_view.get_child_count() == 17)
	assert(not dice_button.disabled)
	assert(not action_bar.visible)
	assert(west_seat.visible)
	assert(not east_seat.visible)
	assert(game_scene.size.x >= 1000.0)
	assert(game_scene.size.y >= 600.0)

	settings_button.pressed.emit()
	await get_tree().process_frame
	assert(settings_popup.visible)
	settings_popup.hide()

	player_count_option.select(0)
	new_game_button.pressed.emit()
	await get_tree().process_frame
	session = game_scene.get("_session") as GameSession
	assert(session.players.size() == 2)
	assert(not west_seat.visible and not east_seat.visible)

	player_count_option.select(2)
	new_game_button.pressed.emit()
	await get_tree().process_frame
	session = game_scene.get("_session") as GameSession
	assert(session.players.size() == 4)
	assert(session.players[1].display_name == "东家")
	assert(west_seat.visible and east_seat.visible)

	player_count_option.select(1)
	new_game_button.pressed.emit()
	await get_tree().process_frame
	session = game_scene.get("_session") as GameSession
	assert(session.players.size() == 3)

	dice_button.pressed.emit()
	await get_tree().create_timer(0.7).timeout
	assert(session.dice_value in [1, 2, 3, 4, 5, 6])
	assert(action_bar.visible)

	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	Input.parse_input_event(mouse_down)
	await get_tree().process_frame
	var first_card := hand_view.get_child(0) as CardView
	var second_card := hand_view.get_child(1) as CardView
	first_card.left_pressed.emit(first_card.card_id)
	second_card.pointer_entered.emit(second_card.card_id)
	second_card.pointer_entered.emit(second_card.card_id)
	var selected_ids: Array[int] = game_scene.get("_selected_card_ids")
	assert(selected_ids.size() == 2)

	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	Input.parse_input_event(mouse_up)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	Input.parse_input_event(right_click)
	await get_tree().process_frame
	selected_ids = game_scene.get("_selected_card_ids")
	assert(selected_ids.is_empty())

	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		var image := get_tree().root.get_texture().get_image()
		if image != null and not image.is_empty():
			assert(image.save_png(CAPTURE_PATH) == OK)
			print("BONUS_GAME_SCENE_CAPTURED %dx%d" % [image.get_width(), image.get_height()])

	var recommendation := session.get_recommended_play(0)
	if recommendation.is_empty():
		assert(session.pass_turn(0))
	else:
		var hand_size_before := session.players[0].hand.size()
		assert(session.play_cards(0, recommendation))
		assert(session.players[0].hand.size() < hand_size_before or session.phase == GameSession.Phase.FINISHED)

	print("BONUS_TEST_GAME_SCENE_OK")
	game_scene.queue_free()
	await get_tree().process_frame
	get_tree().quit()
