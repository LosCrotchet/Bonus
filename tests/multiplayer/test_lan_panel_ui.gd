extends Node


func _ready() -> void:
	var packed := load("res://features/main_menu/main_menu.tscn") as PackedScene
	assert(packed != null)
	var menu := packed.instantiate() as MainMenu
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var multiplayer_button := menu.get_node("%MultiplayerButton") as Button
	var panel := menu.get_node("%LanPanel") as Control
	multiplayer_button.pressed.emit()
	await get_tree().create_timer(0.35).timeout
	assert(panel.visible)
	assert((panel.get_node("%HostModeButton") as Button).button_pressed)
	assert(not (panel.get_node("%JoinModeButton") as Button).button_pressed)
	assert(int((panel.get_node("%HostPort") as SpinBox).value) == 9077)
	assert((panel.get_node("%PlayerCount3") as Button).button_pressed)
	assert((panel.get_node("%Timeout30") as Button).button_pressed)
	var stable_position := panel.position
	multiplayer_button.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	assert(not panel.visible)
	multiplayer_button.pressed.emit()
	await get_tree().create_timer(0.35).timeout
	assert(panel.visible)
	assert(panel.position.is_equal_approx(stable_position))
	print("BONUS_TEST_LAN_PANEL_UI_OK")
	menu.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await AudioService.shutdown()
	get_tree().quit()
