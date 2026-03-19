extends Node2D

var settings_tween = null
const WAIT_TIME = 0.6

func _ready():
	# Add SettingsMenu to the scene
	var settings_menu = preload("res://scenes/menu/settings_menu.tscn").instantiate()
	add_child(settings_menu)

	# Connect Settings button
	$MainButtons/Settings.pressed.connect(_on_settings_pressed)

	# Connect Back button in settings
	$SettingsMenu/Back.pressed.connect(_on_back_pressed)

	# Connect volume sliders
	$SettingsMenu/VolumeSlider.value_changed.connect(_on_volume_changed)
	$SettingsMenu/MasterVolumeSlider.value_changed.connect(_on_master_volume_changed)
	$SettingsMenu/MusicVolumeSlider.value_changed.connect(_on_music_volume_changed)
	$SettingsMenu/SFXVolumeSlider.value_changed.connect(_on_sfx_volume_changed)

func _on_settings_pressed():
	if now_state == 7:  # Settings state
		update_state(0)
	else:
		update_state(7)

func update_state(to_state: int):
	print(now_state, " ", to_state)
	if now_state == to_state:
		return
	if to_state in [0, 1, 2]:
		$MainButtons/MultiGame.text = "多人游戏"

	# Handle leaving settings state
	if now_state == 7:
		if settings_tween:
			settings_tween.kill()
		settings_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
		settings_tween.tween_property($SettingsMenu, "modulate", Color(1, 1, 1, 0), WAIT_TIME)
		settings_tween.tween_property($SettingsMenu, "position:x", $SettingsMenu.position.x + 500, WAIT_TIME)
		var tmp = func():
			settings_tween = null
			$SettingsMenu.visible = false
		settings_tween.tween_callback(tmp).set_delay(WAIT_TIME)

	# Handle entering settings state
	if to_state == 7:
		if settings_tween:
			settings_tween.kill()
		$SettingsMenu.visible = true
		$SettingsMenu.modulate = Color(1, 1, 1, 0)
		$SettingsMenu.position.x = $SettingsMenu.position.x + 500
		settings_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
		settings_tween.tween_property($SettingsMenu, "modulate", Color(1, 1, 1, 1), WAIT_TIME)
		settings_tween.tween_property($SettingsMenu, "position:x", $SettingsMenu.position.x - 500, WAIT_TIME)
		var tmp = func():
			settings_tween = null
		settings_tween.tween_callback(tmp).set_delay(WAIT_TIME)

	now_state = to_state

func _on_back_pressed():
	if now_state == 7:  # Settings state
		update_state(0)
	else:
		match now_state:
			6:
				update_state(4)
				WebController.remove_multiplayer_peer()
			5:
				update_state(3)
				WebController.remove_multiplayer_peer()
			4, 3, 2:
				update_state(0)

func _on_volume_changed(value: float):
	$SettingsMenu/VolumeDisplay.text = str(int(value * 100)) + "%"
	# Apply volume change to AudioServer
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_master_volume_changed(value: float):
	$SettingsMenu/MasterVolumeDisplay.text = str(int(value * 100)) + "%"
	# Apply master volume change
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_music_volume_changed(value: float):
	$SettingsMenu/MusicVolumeDisplay.text = str(int(value * 100)) + "%"
	# Apply music volume change (assuming music is on bus 1)
	AudioServer.set_bus_volume_db(1, linear_to_db(value))

func _on_sfx_volume_changed(value: float):
	$SettingsMenu/SFXVolumeDisplay.text = str(int(value * 100)) + "%"
	# Apply SFX volume change (assuming SFX is on bus 2)
	AudioServer.set_bus_volume_db(2, linear_to_db(value))
