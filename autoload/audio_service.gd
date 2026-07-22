extends Node

const SOUND_STREAMS := {
	&"card_draw": preload("res://assets/audio/card_draw_1.wav"),
	&"card_fan": preload("res://assets/audio/card_fan_2.wav"),
	&"dice_roll": preload("res://assets/audio/dice_roll_2.wav"),
	&"ui_hover": preload("res://assets/audio/sci_fi_hover.wav"),
	&"ui_confirm": preload("res://assets/audio/sci_fi_confirm.wav"),
	&"ui_cancel": preload("res://assets/audio/sci_fi_cancel.wav"),
	&"ui_disallow": preload("res://assets/audio/sci_fi_disallow.wav"),
	&"ui_select": preload("res://assets/audio/sci_fi_select.wav"),
}

const MAX_SIMULTANEOUS_SOUNDS := 12

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_bind_existing_buttons.call_deferred()


func play(sound_name: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream := SOUND_STREAMS.get(sound_name) as AudioStream
	if stream == null:
		push_warning("Unknown sound: %s" % sound_name)
		return
	var player := _get_available_player()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func play_ui_hover() -> void:
	play(&"ui_hover", -9.0, 1.08)


func play_ui_confirm() -> void:
	play(&"ui_confirm", -7.0)


func play_ui_cancel() -> void:
	play(&"ui_cancel", -7.0)


func play_ui_disallow() -> void:
	play(&"ui_disallow", -7.0)


func play_ui_select() -> void:
	play(&"ui_select", -10.0, 1.08)


func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	if _players.size() >= MAX_SIMULTANEOUS_SOUNDS:
		return _players[0]
	var player := AudioStreamPlayer.new()
	add_child(player)
	_players.append(player)
	return player


func _bind_existing_buttons() -> void:
	_bind_buttons_in(get_tree().root)


func _bind_buttons_in(node: Node) -> void:
	_bind_button(node)
	for child in node.get_children():
		_bind_buttons_in(child)


func _on_node_added(node: Node) -> void:
	_bind_button(node)


func _bind_button(node: Node) -> void:
	if node is not BaseButton or node.has_meta(&"audio_service_bound"):
		return
	var button := node as BaseButton
	button.set_meta(&"audio_service_bound", true)
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_hovered(button: BaseButton) -> void:
	if button.visible and not button.disabled:
		play_ui_hover()


func _on_button_pressed(button: BaseButton) -> void:
	var sound_name := StringName(button.get_meta(&"ui_sound", &"ui_confirm"))
	if sound_name == &"none":
		return
	play(sound_name, -7.0)
