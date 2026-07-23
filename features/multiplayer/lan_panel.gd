class_name LanPanel
extends PanelContainer

const LAN_PROTOCOL = preload("res://multiplayer/protocol/lan_protocol.gd")

signal game_requested(snapshot: Dictionary)
signal close_requested

@onready var setup_content: VBoxContainer = %SetupContent
@onready var lobby_content: VBoxContainer = %LobbyContent
@onready var host_settings: VBoxContainer = %HostSettings
@onready var join_settings: VBoxContainer = %JoinSettings
@onready var player_id_input: LineEdit = %PlayerIdInput
@onready var address_input: LineEdit = %AddressInput
@onready var host_port: SpinBox = %HostPort
@onready var join_port: SpinBox = %JoinPort
@onready var status_label: Label = %StatusLabel
@onready var members_list: VBoxContainer = %MembersList
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
var _hosting_mode := true
var _local_ready := false
var _game_signal_consumed := false
var _editing_room := false


func _ready() -> void:
	%HostModeButton.pressed.connect(func() -> void: _set_hosting_mode(true))
	%JoinModeButton.pressed.connect(func() -> void: _set_hosting_mode(false))
	%PlayerCount2.pressed.connect(func() -> void: _player_count = 2)
	%PlayerCount3.pressed.connect(func() -> void: _player_count = 3)
	%PlayerCount4.pressed.connect(func() -> void: _player_count = 4)
	%Timeout15.pressed.connect(func() -> void: _turn_timeout = 15)
	%Timeout30.pressed.connect(func() -> void: _turn_timeout = 30)
	%Timeout60.pressed.connect(func() -> void: _turn_timeout = 60)
	%CreateButton.pressed.connect(_create_room)
	%JoinButton.pressed.connect(_join_room)
	%BackButton.pressed.connect(_leave_or_close)
	%LobbyBackButton.pressed.connect(_leave_or_close)
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
	player_id_input.text = SettingsService.player_id
	host_port.value = LAN_PROTOCOL.DEFAULT_PORT
	join_port.value = LAN_PROTOCOL.DEFAULT_PORT
	include_jokers.button_pressed = true
	jokers_wild.button_pressed = true
	wildcard_finish.button_pressed = true
	_refresh_rule_dependencies(true)
	_refresh_seed_visibility(false)
	_set_hosting_mode(true)
	_show_setup()


func begin_open() -> void:
	_game_signal_consumed = false
	player_id_input.text = SettingsService.player_id
	if LanMultiplayerService.connection_state == LanMultiplayerService.ConnectionState.IN_LOBBY:
		_show_lobby()
		_on_lobby_updated(LanMultiplayerService.last_lobby_snapshot)
	else:
		_show_setup()


func _set_hosting_mode(hosting: bool) -> void:
	_hosting_mode = hosting
	host_settings.visible = hosting
	join_settings.visible = not hosting
	%HostModeButton.button_pressed = hosting
	%JoinModeButton.button_pressed = not hosting
	status_label.text = ""


func _create_room() -> void:
	if not _save_player_id():
		_show_error(&"LAN_ERROR_PLAYER_ID_REQUIRED")
		return
	var seed_text := (
		SeedCodec.sanitize(seed_input.text)
		if custom_seed.button_pressed
		else SeedCodec.generate_random_text()
	)
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
	if LanMultiplayerService.host_room(
		SettingsService.player_id,
		int(host_port.value),
		config,
	):
		_show_lobby()


func _join_room() -> void:
	if not _save_player_id():
		_show_error(&"LAN_ERROR_PLAYER_ID_REQUIRED")
		return
	status_label.text = tr(&"LAN_STATUS_CONNECTING")
	LanMultiplayerService.join_room(
		SettingsService.player_id,
		address_input.text,
		int(join_port.value),
	)


func _save_player_id() -> bool:
	return SettingsService.set_player_id(player_id_input.text)


func _build_rules() -> GameRules:
	var rules := GameRules.new()
	rules.include_jokers = include_jokers.button_pressed
	rules.jokers_are_wild = rules.include_jokers and jokers_wild.button_pressed
	rules.draw_two_on_wildcard_finish = (
		rules.jokers_are_wild and wildcard_finish.button_pressed
	)
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


func _show_setup() -> void:
	setup_content.visible = true
	lobby_content.visible = false
	player_id_input.editable = true
	_local_ready = false
	%ModeRow.visible = not _editing_room
	host_port.get_parent().visible = not _editing_room
	%CreateButton.text = tr(&"LAN_APPLY_ROOM") if _editing_room else tr(&"LAN_CREATE")


func _show_lobby() -> void:
	setup_content.visible = false
	lobby_content.visible = true
	player_id_input.editable = false
	%ModeRow.visible = true
	host_port.get_parent().visible = true
	%CreateButton.text = tr(&"LAN_CREATE")
	status_label.text = ""


func _on_connection_state_changed(state: LanMultiplayerService.ConnectionState) -> void:
	match state:
		LanMultiplayerService.ConnectionState.CONNECTING:
			status_label.text = tr(&"LAN_STATUS_CONNECTING")
		LanMultiplayerService.ConnectionState.IN_LOBBY:
			_show_lobby()
		LanMultiplayerService.ConnectionState.OFFLINE:
			if lobby_content.visible:
				_show_setup()


func _on_lobby_updated(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	_show_lobby()
	_clear_members()
	var config := snapshot.get("config", {}) as Dictionary
	%RoomSummary.text = tr(&"LAN_ROOM_SUMMARY").format({
		"count": int(config.get("player_count", 3)),
		"timeout": int(config.get("turn_timeout", 30)),
		"seed": str(config.get("seed_text", "")),
	})
	%RoomSummary.text += "\n" + _describe_rules(config.get("rules", {}) as Dictionary)
	if LanMultiplayerService.is_host:
		%RoomSummary.text += "\n" + tr(&"LAN_HOST_ENDPOINT").format({
			"address": _get_local_ipv4_addresses(),
			"port": int(host_port.value),
		})
	var local_member := LanMultiplayerService.get_local_member()
	_local_ready = bool(local_member.get("ready", false))
	ready_button.text = tr(&"LAN_UNREADY") if _local_ready else tr(&"LAN_READY")
	for member_value in snapshot.get("members", []) as Array:
		_add_member_row(member_value as Dictionary)
	var host := LanMultiplayerService.is_host
	add_ai_button.visible = host
	%EditRoomButton.visible = host
	start_button.visible = host
	start_button.disabled = not LanMultiplayerService.can_start_game()


func _add_member_row(member: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var state_key := &"LAN_MEMBER_READY" if bool(member.get("ready", false)) else &"LAN_MEMBER_NOT_READY"
	if bool(member.get("is_ai", false)):
		state_key = &"LAN_MEMBER_AI"
	name_label.text = "%s · %s · %s" % [
		tr(StringName(str(member.get("seat_key", "")))),
		str(member.get("player_id", "")),
		tr(state_key),
	]
	row.add_child(name_label)
	if (
		LanMultiplayerService.is_host
		and not bool(member.get("is_host", false))
	):
		var kick_button := Button.new()
		kick_button.text = tr(&"LAN_KICK")
		kick_button.custom_minimum_size = Vector2(74, 36)
		var seat_index := int(member.get("seat_index", -1))
		kick_button.pressed.connect(
			func() -> void: LanMultiplayerService.remove_member(seat_index)
		)
		row.add_child(kick_button)
	members_list.add_child(row)


func _clear_members() -> void:
	for child in members_list.get_children():
		child.queue_free()


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
	_set_hosting_mode(true)
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
	_show_setup()


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


func _get_local_ipv4_addresses() -> String:
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if ":" not in address and address != "127.0.0.1":
			addresses.append(address)
	return ", ".join(addresses) if not addresses.is_empty() else "127.0.0.1"


func _describe_rules(rules: Dictionary) -> String:
	var descriptions := PackedStringArray()
	if bool(rules.get("include_jokers", true)):
		descriptions.append(tr(&"RULE_INCLUDE_JOKERS"))
		descriptions.append(
			tr(&"RULE_JOKERS_WILD")
			if bool(rules.get("jokers_are_wild", true))
			else tr(&"RULE_JOKERS_NATURAL")
		)
		if bool(rules.get("jokers_are_wild", true)):
			descriptions.append(
				tr(&"RULE_WILDCARD_FINISH_DRAW")
				if bool(rules.get("draw_two_on_wildcard_finish", true))
				else tr(&"RULE_WILDCARD_FINISH_NO_DRAW")
			)
	else:
		descriptions.append(tr(&"RULE_EXCLUDE_JOKERS"))
	descriptions.append(
		tr(&"RULE_SEQUENCE_WITH_TWO")
		if bool(rules.get("allow_two_in_sequences", false))
		else tr(&"RULE_SEQUENCE_WITHOUT_TWO")
	)
	descriptions.append(
		tr(&"RULE_VARIABLE_DRAW")
		if bool(rules.get("draw_count_uses_dice", false))
		else tr(&"RULE_FIXED_DRAW")
	)
	return " · ".join(descriptions)


func _on_game_started(snapshot: Dictionary) -> void:
	if _game_signal_consumed:
		return
	_game_signal_consumed = true
	game_requested.emit(snapshot)


func _leave_or_close() -> void:
	if _editing_room:
		_editing_room = false
		_show_lobby()
		return
	if LanMultiplayerService.connection_state != LanMultiplayerService.ConnectionState.OFFLINE:
		LanMultiplayerService.close_connection()
	close_requested.emit()


func _show_error(error_key: StringName) -> void:
	status_label.text = tr(error_key)
