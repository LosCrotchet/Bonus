class_name LanPanel
extends Control

const LAN_PROTOCOL = preload("res://multiplayer/protocol/lan_protocol.gd")

signal game_requested(snapshot: Dictionary)
signal close_requested

enum DetailMode {
	NONE,
	HOST,
	JOIN,
	LOBBY,
}

@onready var detail_panel: PanelContainer = %DetailPanel
@onready var setup_scroll: ScrollContainer = %SetupScroll
@onready var setup_content: VBoxContainer = %SetupContent
@onready var setup_actions: VBoxContainer = %SetupActions
@onready var lobby_content: VBoxContainer = %LobbyView
@onready var host_settings: VBoxContainer = %HostSettings
@onready var join_settings: VBoxContainer = %JoinSettings
@onready var player_id_input: LineEdit = %PlayerIdInput
@onready var address_input: LineEdit = %AddressInput
@onready var host_port: SpinBox = %HostPort
@onready var join_port: SpinBox = %JoinPort
@onready var status_label: Label = %SetupStatusLabel
@onready var lobby_status_label: Label = %LobbyStatusLabel
@onready var ready_button: Button = %ReadyButton
@onready var add_ai_button: Button = %AddAiButton
@onready var start_button: Button = %StartButton
@onready var include_jokers: CheckBox = %IncludeJokers
@onready var jokers_wild: CheckBox = %JokersWild
@onready var wildcard_finish: CheckBox = %WildcardFinish
@onready var allow_two: CheckBox = %AllowTwo
@onready var variable_draw: CheckBox = %VariableDraw
@onready var custom_seed: CheckBox = %CustomSeed
@onready var seed_input: LineEdit = %SeedInput

var _player_count := 3
var _turn_timeout := 30
var _detail_mode := DetailMode.NONE
var _local_ready := false
var _game_signal_consumed := false
var _editing_room := false
var _detail_target := Vector2.ZERO
var _detail_tween: Tween
var _seat_slots: Dictionary = {}


func _ready() -> void:
	%CreateRoomButton.pressed.connect(_open_host_setup)
	%JoinRoomButton.pressed.connect(_open_join_setup)
	%MenuBackButton.pressed.connect(func() -> void: close_requested.emit())
	%DetailBackButton.pressed.connect(_back_from_detail)
	%PlayerCount2.pressed.connect(func() -> void: _player_count = 2)
	%PlayerCount3.pressed.connect(func() -> void: _player_count = 3)
	%PlayerCount4.pressed.connect(func() -> void: _player_count = 4)
	%Timeout15.pressed.connect(func() -> void: _turn_timeout = 15)
	%Timeout30.pressed.connect(func() -> void: _turn_timeout = 30)
	%Timeout60.pressed.connect(func() -> void: _turn_timeout = 60)
	%CreateButton.pressed.connect(_create_room)
	%JoinButton.pressed.connect(_join_room)
	%LobbyBackButton.pressed.connect(_leave_room)
	%EditRoomButton.pressed.connect(_edit_room)
	ready_button.pressed.connect(_toggle_ready)
	add_ai_button.pressed.connect(_add_ai)
	start_button.pressed.connect(_start_game)
	include_jokers.toggled.connect(_refresh_rule_dependencies)
	jokers_wild.toggled.connect(_refresh_rule_dependencies)
	custom_seed.toggled.connect(_refresh_seed_visibility)
	player_id_input.text_submitted.connect(func(_value: String) -> void: _save_player_id())
	LanMultiplayerService.lobby_updated.connect(_on_lobby_updated)
	LanMultiplayerService.connection_state_changed.connect(_on_connection_state_changed)
	LanMultiplayerService.network_error.connect(_show_error)
	LanMultiplayerService.game_started.connect(_on_game_started)
	_seat_slots = {
		"SEAT_NORTH": %NorthSlot,
		"SEAT_SOUTH": %SouthSlot,
		"SEAT_WEST": %WestSlot,
		"SEAT_EAST": %EastSlot,
	}
	player_id_input.text = SettingsService.player_id
	host_port.value = LAN_PROTOCOL.DEFAULT_PORT
	join_port.value = LAN_PROTOCOL.DEFAULT_PORT
	include_jokers.button_pressed = true
	jokers_wild.button_pressed = true
	wildcard_finish.button_pressed = true
	_refresh_rule_dependencies(true)
	_refresh_seed_visibility(false)
	detail_panel.visible = false
	ControlMotion.bind_buttons(self)
	await get_tree().process_frame
	_detail_target = detail_panel.position


func begin_open() -> void:
	_game_signal_consumed = false
	player_id_input.text = SettingsService.player_id
	if LanMultiplayerService.connection_state == LanMultiplayerService.ConnectionState.IN_LOBBY:
		_show_lobby()
		_on_lobby_updated(LanMultiplayerService.last_lobby_snapshot)
	else:
		_hide_detail(true)


func handle_back() -> bool:
	if detail_panel.visible:
		_back_from_detail()
		return true
	return false


func _open_host_setup() -> void:
	if _detail_mode == DetailMode.HOST and detail_panel.visible and not _editing_room:
		_hide_detail()
		return
	_editing_room = false
	_show_setup(true)


func _open_join_setup() -> void:
	if _detail_mode == DetailMode.JOIN and detail_panel.visible:
		_hide_detail()
		return
	_editing_room = false
	_show_setup(false)


func _show_setup(hosting: bool) -> void:
	_detail_mode = DetailMode.HOST if hosting else DetailMode.JOIN
	setup_scroll.visible = true
	setup_content.visible = true
	setup_actions.visible = true
	lobby_content.visible = false
	host_settings.visible = hosting
	join_settings.visible = not hosting
	%CreateButton.visible = hosting
	%JoinButton.visible = not hosting
	%DetailTitle.text = tr(&"LAN_CREATE_ROOM") if hosting else tr(&"LAN_JOIN_ROOM")
	%CreateButton.text = tr(&"LAN_APPLY_ROOM") if _editing_room else tr(&"LAN_CREATE")
	status_label.text = ""
	status_label.visible = true
	lobby_status_label.visible = false
	_show_detail()


func _show_lobby() -> void:
	var already_visible := _detail_mode == DetailMode.LOBBY and detail_panel.visible
	_detail_mode = DetailMode.LOBBY
	setup_scroll.visible = false
	setup_content.visible = false
	setup_actions.visible = false
	lobby_content.visible = true
	%DetailTitle.text = tr(&"LAN_ROOM_TITLE")
	status_label.text = ""
	status_label.visible = false
	lobby_status_label.text = ""
	lobby_status_label.visible = false
	if not already_visible:
		_show_detail()


func _show_detail() -> void:
	if _detail_tween != null:
		_detail_tween.kill()
	detail_panel.position = _detail_target + Vector2(-28.0, 0.0)
	detail_panel.modulate.a = 0.0
	detail_panel.visible = true
	AudioService.play(&"ui_fade_in")
	_detail_tween = create_tween().set_parallel(true)
	_detail_tween.tween_property(detail_panel, "position", _detail_target, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_detail_tween.tween_property(detail_panel, "modulate:a", 1.0, 0.18)


func _hide_detail(immediate: bool = false) -> void:
	_detail_mode = DetailMode.NONE
	_editing_room = false
	if _detail_tween != null:
		_detail_tween.kill()
	detail_panel.position = _detail_target
	detail_panel.modulate.a = 1.0
	if immediate or not detail_panel.visible:
		detail_panel.visible = false
		return
	AudioService.play(&"ui_fade_out")
	_detail_tween = create_tween().set_parallel(true)
	_detail_tween.tween_property(detail_panel, "position", _detail_target + Vector2(-24.0, 0.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_detail_tween.tween_property(detail_panel, "modulate:a", 0.0, 0.15)
	_detail_tween.chain().tween_callback(
		func() -> void:
			detail_panel.visible = false
			detail_panel.position = _detail_target
			detail_panel.modulate.a = 1.0
	)


func _create_room() -> void:
	if not _save_player_id():
		_show_error(&"LAN_ERROR_PLAYER_ID_REQUIRED")
		return
	var seed_text := SeedCodec.sanitize(seed_input.text) if custom_seed.button_pressed else SeedCodec.generate_random_text()
	if not SeedCodec.is_valid(seed_text):
		_show_error(&"LAN_ERROR_INVALID_SEED")
		return
	var config := {
		"player_count": _player_count,
		"turn_timeout": _turn_timeout,
		"seed_text": seed_text,
		"use_custom_seed": custom_seed.button_pressed,
		"rules": _build_rules(),
	}
	if _editing_room:
		if LanMultiplayerService.update_room_config(config):
			_editing_room = false
			_show_lobby()
		return
	if LanMultiplayerService.host_room(SettingsService.player_id, int(host_port.value), config):
		_show_lobby()


func _join_room() -> void:
	if not _save_player_id():
		_show_error(&"LAN_ERROR_PLAYER_ID_REQUIRED")
		return
	status_label.text = tr(&"LAN_STATUS_CONNECTING")
	LanMultiplayerService.join_room(SettingsService.player_id, address_input.text, int(join_port.value))


func _save_player_id() -> bool:
	return SettingsService.set_player_id(player_id_input.text)


func _build_rules() -> GameRules:
	var rules := GameRules.new()
	rules.include_jokers = include_jokers.button_pressed
	rules.jokers_are_wild = rules.include_jokers and jokers_wild.button_pressed
	rules.draw_two_on_wildcard_finish = rules.jokers_are_wild and wildcard_finish.button_pressed
	rules.allow_two_in_sequences = allow_two.button_pressed
	rules.draw_count_uses_dice = variable_draw.button_pressed
	return rules


func _refresh_rule_dependencies(_unused: bool = false) -> void:
	%JokersWildRow.visible = include_jokers.button_pressed
	if not include_jokers.button_pressed:
		jokers_wild.set_pressed_no_signal(false)
	%WildcardFinishRow.visible = include_jokers.button_pressed and jokers_wild.button_pressed
	if not jokers_wild.button_pressed:
		wildcard_finish.set_pressed_no_signal(false)


func _refresh_seed_visibility(_unused: bool = false) -> void:
	%SeedInputRow.visible = custom_seed.button_pressed


func _on_connection_state_changed(state: LanMultiplayerService.ConnectionState) -> void:
	match state:
		LanMultiplayerService.ConnectionState.CONNECTING:
			status_label.text = tr(&"LAN_STATUS_CONNECTING")
		LanMultiplayerService.ConnectionState.IN_LOBBY:
			_show_lobby()
		LanMultiplayerService.ConnectionState.OFFLINE:
			if _detail_mode == DetailMode.LOBBY:
				_hide_detail()


func _on_lobby_updated(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	_show_lobby()
	var config := snapshot.get("config", {}) as Dictionary
	var player_capacity := int(config.get("player_count", 3))
	var members := snapshot.get("members", []) as Array
	%RoomSeed.text = str(config.get("seed_text", ""))
	%RoomRules.text = _describe_rules(
		config.get("rules", {}) as Dictionary,
		player_capacity,
		int(config.get("turn_timeout", 30)),
	)
	%MembersTitle.text = tr(&"LAN_MEMBERS_COUNT").format({
		"current": members.size(),
		"capacity": player_capacity,
	})
	%EndpointRow.visible = LanMultiplayerService.is_host
	if LanMultiplayerService.is_host:
		%RoomEndpoint.text = "%s:%d" % [_get_preferred_local_ipv4(), int(host_port.value)]
	var local_member := LanMultiplayerService.get_local_member()
	_local_ready = bool(local_member.get("ready", false))
	ready_button.text = tr(&"LAN_UNREADY") if _local_ready else tr(&"LAN_READY")
	_clear_seat_slots()
	for member_value in members:
		_update_seat_slot(member_value as Dictionary)
	var host := LanMultiplayerService.is_host
	add_ai_button.visible = host
	%EditRoomButton.visible = host
	%HostActionRow.visible = host
	start_button.visible = host
	start_button.disabled = not LanMultiplayerService.can_start_game()


func _clear_seat_slots() -> void:
	for seat_key in _seat_slots:
		var slot := _seat_slots[seat_key] as PanelContainer
		# Keep every grid cell in layout so the compass positions never collapse.
		slot.visible = true
		slot.modulate.a = 0.0
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(slot.get_node("Layout/PlayerRow/Player") as Label).text = ""
		(slot.get_node("Layout/HeaderRow/State") as Label).text = ""
		(slot.get_node("Layout/PlayerRow/Kick") as TextureButton).visible = false


func _update_seat_slot(member: Dictionary) -> void:
	var seat_key := str(member.get("seat_key", ""))
	if not _seat_slots.has(seat_key):
		return
	var slot := _seat_slots[seat_key] as PanelContainer
	slot.visible = true
	slot.modulate.a = 1.0
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	var is_ai := bool(member.get("is_ai", false))
	var seat_text := tr(StringName(seat_key))
	if is_ai:
		seat_text += " · AI"
	(slot.get_node("Layout/HeaderRow/Seat") as Label).text = seat_text
	(slot.get_node("Layout/PlayerRow/Player") as Label).text = str(member.get("player_id", ""))
	var state_key := &"LAN_MEMBER_READY" if bool(member.get("ready", false)) else &"LAN_MEMBER_NOT_READY"
	(slot.get_node("Layout/HeaderRow/State") as Label).text = tr(state_key)
	var kick := slot.get_node("Layout/PlayerRow/Kick") as TextureButton
	kick.visible = LanMultiplayerService.is_host and not bool(member.get("is_host", false))
	for connection in kick.pressed.get_connections():
		kick.pressed.disconnect(connection.callable)
	var seat_index := int(member.get("seat_index", -1))
	kick.pressed.connect(func() -> void: LanMultiplayerService.remove_member(seat_index))


func _toggle_ready() -> void:
	LanMultiplayerService.set_ready(not _local_ready)


func _add_ai() -> void:
	LanMultiplayerService.add_ai()


func _start_game() -> void:
	LanMultiplayerService.start_game()


func _edit_room() -> void:
	if not LanMultiplayerService.is_host:
		return
	var config := LanMultiplayerService.last_lobby_snapshot.get("config", {}) as Dictionary
	_editing_room = true
	_set_player_count(int(config.get("player_count", 3)))
	_set_turn_timeout(int(config.get("turn_timeout", 30)))
	var rules := config.get("rules", {}) as Dictionary
	include_jokers.button_pressed = bool(rules.get("include_jokers", true))
	jokers_wild.button_pressed = bool(rules.get("jokers_are_wild", true))
	wildcard_finish.button_pressed = bool(rules.get("draw_two_on_wildcard_finish", true))
	allow_two.button_pressed = bool(rules.get("allow_two_in_sequences", false))
	variable_draw.button_pressed = bool(rules.get("draw_count_uses_dice", false))
	custom_seed.button_pressed = bool(config.get("use_custom_seed", false))
	seed_input.text = str(config.get("seed_text", ""))
	_refresh_rule_dependencies()
	_refresh_seed_visibility()
	_show_setup(true)


func _set_player_count(value: int) -> void:
	_player_count = clampi(value, 2, 4)
	%PlayerCount2.button_pressed = _player_count == 2
	%PlayerCount3.button_pressed = _player_count == 3
	%PlayerCount4.button_pressed = _player_count == 4


func _set_turn_timeout(value: int) -> void:
	_turn_timeout = value if value in [15, 30, 60] else 30
	%Timeout15.button_pressed = _turn_timeout == 15
	%Timeout30.button_pressed = _turn_timeout == 30
	%Timeout60.button_pressed = _turn_timeout == 60


func _get_preferred_local_ipv4() -> String:
	var candidates := PackedStringArray()
	for address in IP.get_local_addresses():
		if ":" in address or address == "127.0.0.1" or address.begins_with("169.254."):
			continue
		candidates.append(address)
	for address in candidates:
		if address.begins_with("192.168."):
			return address
	for address in candidates:
		if address.begins_with("10.") or _is_private_172(address):
			return address
	return candidates[0] if not candidates.is_empty() else "127.0.0.1"


func _is_private_172(address: String) -> bool:
	if not address.begins_with("172."):
		return false
	var parts := address.split(".")
	return parts.size() == 4 and int(parts[1]) >= 16 and int(parts[1]) <= 31


func _describe_rules(rules: Dictionary, player_count: int, turn_timeout: int) -> String:
	var descriptions := PackedStringArray([
		tr(&"UI_PLAYER_COUNT_SHORT").format({"count": player_count}),
	])
	if bool(rules.get("include_jokers", true)):
		descriptions.append(tr(&"RULE_SHORT_JOKERS"))
		if bool(rules.get("jokers_are_wild", true)):
			descriptions.append(tr(&"RULE_SHORT_WILDCARD"))
			if bool(rules.get("draw_two_on_wildcard_finish", true)):
				descriptions.append(tr(&"RULE_SHORT_FINISH_LIMIT"))
	if bool(rules.get("allow_two_in_sequences", false)):
		descriptions.append(tr(&"RULE_SHORT_SEQUENCE_TWO"))
	if bool(rules.get("draw_count_uses_dice", false)):
		descriptions.append(tr(&"RULE_SHORT_VARIABLE_DRAW"))
	descriptions.append(tr(&"LAN_SECONDS_SHORT").format({"seconds": turn_timeout}))
	return " · ".join(descriptions)


func _on_game_started(snapshot: Dictionary) -> void:
	if _game_signal_consumed:
		return
	_game_signal_consumed = true
	game_requested.emit(snapshot)


func _back_from_detail() -> void:
	if _editing_room:
		_editing_room = false
		_show_lobby()
	else:
		_hide_detail()


func _leave_room() -> void:
	LanMultiplayerService.close_connection()
	_hide_detail()


func _show_error(error_key: StringName) -> void:
	var target := lobby_status_label if _detail_mode == DetailMode.LOBBY else status_label
	target.text = tr(error_key)
	target.visible = true
