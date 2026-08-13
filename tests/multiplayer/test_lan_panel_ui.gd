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
	var detail_panel := panel.get_node("%DetailPanel") as PanelContainer
	var menu_panel := panel.get_node("MenuPanel") as PanelContainer
	assert(menu_panel.size.x <= 300.0, "Menu width: %s" % menu_panel.size.x)
	assert(detail_panel.size.x <= 425.0, "Detail width: %s" % detail_panel.size.x)
	assert(is_equal_approx(menu_panel.get_global_rect().end.x, detail_panel.global_position.x))
	assert(
		panel.get_global_rect().end.x <= menu.get_global_rect().end.x - 200.0,
		"Panel end: %s, menu end: %s" % [
			panel.get_global_rect().end.x,
			menu.get_global_rect().end.x,
		],
	)
	assert(not detail_panel.visible)
	(panel.get_node("%CreateRoomButton") as Button).pressed.emit()
	await get_tree().create_timer(0.3).timeout
	assert(detail_panel.visible)
	assert((panel.get_node("%HostSettings") as VBoxContainer).visible)
	assert(not (panel.get_node("%JoinSettings") as VBoxContainer).visible)
	assert(int((panel.get_node("%HostPort") as SpinBox).value) == 9077)
	assert((panel.get_node("%PlayerCount3") as Button).button_pressed)
	assert((panel.get_node("%Timeout30") as Button).button_pressed)
	panel.call("_show_error", &"LAN_ERROR_ROOM_FULL")
	var setup_status := panel.get_node("%SetupStatusLabel") as Label
	var create_button := panel.get_node("%CreateButton") as Button
	assert(setup_status.visible)
	assert(setup_status.text == tr(&"LAN_ERROR_ROOM_FULL"))
	assert(setup_status.global_position.y < create_button.global_position.y)
	assert(setup_status.global_position.y > (panel.get_node("%DetailTitle") as Label).global_position.y + 100.0)
	(panel.get_node("%CreateRoomButton") as Button).pressed.emit()
	await get_tree().create_timer(0.25).timeout
	assert(not detail_panel.visible)
	(panel.get_node("%JoinRoomButton") as Button).pressed.emit()
	await get_tree().create_timer(0.3).timeout
	assert(detail_panel.visible)
	assert((panel.get_node("%JoinSettings") as VBoxContainer).visible)
	panel.call("_show_error", &"LAN_ERROR_ROOM_FULL")
	var join_button := panel.get_node("%JoinButton") as Button
	assert(setup_status.global_position.y < join_button.global_position.y)
	(panel.get_node("%DetailBackButton") as Button).pressed.emit()
	await get_tree().create_timer(0.25).timeout
	assert(not detail_panel.visible)
	var lobby_snapshot := {
		"room_id": "room-test",
		"config": {
			"player_count": 4,
			"turn_timeout": 30,
			"seed_text": "roomtest",
			"rules": LanProtocol.rules_to_dictionary(GameRules.new()),
		},
		"members": [
			_member("SEAT_SOUTH", 0, "Host", true, true),
			_member("SEAT_EAST", 1, "East", true, false),
			_member("SEAT_NORTH", 2, "North", false, false),
			_member("SEAT_WEST", 3, "AI 1", true, false, true),
		],
		"game_started": false,
	}
	LanMultiplayerService.is_host = true
	LanMultiplayerService.last_lobby_snapshot = lobby_snapshot
	panel.call("_on_lobby_updated", lobby_snapshot)
	await get_tree().process_frame
	assert(detail_panel.size.x <= 425.0)
	assert(not (panel.get_node("%SetupScroll") as ScrollContainer).visible)
	var lobby_view := panel.get_node("%LobbyView") as VBoxContainer
	assert(lobby_view.visible)
	assert(lobby_view.get_global_rect().end.y <= detail_panel.get_global_rect().end.y)
	assert((panel.get_node("%LobbyBackButton") as Button).get_global_rect().end.y <= detail_panel.get_global_rect().end.y)
	var lobby_scroll := panel.get_node("DetailPanel/Layout/LobbyView/LobbyScroll") as ScrollContainer
	assert(not lobby_scroll.get_v_scroll_bar().visible)
	var lobby_content := panel.get_node("%LobbyContent") as VBoxContainer
	assert(
		lobby_content.size.y <= lobby_scroll.size.y + 1.0,
		"Lobby content: %s, viewport: %s" % [lobby_content.size.y, lobby_scroll.size.y],
	)
	var room_rules := (panel.get_node("%RoomRules") as Label).text
	assert(room_rules.contains(tr(&"UI_PLAYER_COUNT_SHORT").format({"count": 4})))
	assert(room_rules.contains(tr(&"RULE_SHORT_JOKERS")))
	assert(room_rules.contains(tr(&"RULE_SHORT_WILDCARD")))
	assert(room_rules.contains(tr(&"RULE_SHORT_FINISH_LIMIT")))
	assert(room_rules.contains(tr(&"LAN_SECONDS_SHORT").format({"seconds": 30})))
	assert(not room_rules.contains(tr(&"RULE_SHORT_SEQUENCE_TWO")))
	assert(not room_rules.contains(tr(&"RULE_SHORT_VARIABLE_DRAW")))
	assert((panel.get_node("%MembersTitle") as Label).text == tr(&"LAN_MEMBERS_COUNT").format({
		"current": 4,
		"capacity": 4,
	}))
	var north := panel.get_node("%NorthSlot") as PanelContainer
	var south := panel.get_node("%SouthSlot") as PanelContainer
	var west := panel.get_node("%WestSlot") as PanelContainer
	var east := panel.get_node("%EastSlot") as PanelContainer
	assert(north.visible and south.visible and west.visible and east.visible)
	assert(is_equal_approx(south.global_position.y, north.global_position.y))
	assert(is_equal_approx(west.global_position.y, east.global_position.y))
	assert(south.global_position.x < north.global_position.x)
	assert(west.global_position.x < east.global_position.x)
	assert(south.global_position.y < west.global_position.y)
	for seat in [north, east, south, west]:
		assert(seat.size.is_equal_approx(north.size))
	var seat_rects: Array[Rect2] = [
		north.get_global_rect(),
		south.get_global_rect(),
		west.get_global_rect(),
		east.get_global_rect(),
	]
	for first_index in range(seat_rects.size()):
		for second_index in range(first_index + 1, seat_rects.size()):
			assert(not seat_rects[first_index].intersects(seat_rects[second_index]))
	assert((north.get_node("Layout/HeaderRow/Seat") as Label).text == tr(&"SEAT_NORTH"))
	assert((north.get_node("Layout/HeaderRow/State") as Label).text == tr(&"LAN_MEMBER_NOT_READY"))
	assert((north.get_node("Layout/PlayerRow/Player") as Label).text == "North")
	assert((west.get_node("Layout/HeaderRow/Seat") as Label).text == "%s · AI" % tr(&"SEAT_WEST"))
	assert((west.get_node("Layout/HeaderRow/State") as Label).text == tr(&"LAN_MEMBER_READY"))
	var north_kick := north.get_node("Layout/PlayerRow/Kick") as TextureButton
	assert(north_kick.visible)
	assert(north_kick.texture_normal != null)
	panel.call("_show_error", &"LAN_ERROR_ROOM_FULL")
	var lobby_status := panel.get_node("%LobbyStatusLabel") as Label
	assert(lobby_status.visible)
	assert(lobby_status.text == tr(&"LAN_ERROR_ROOM_FULL"))
	assert(lobby_status.global_position.y < (panel.get_node("%ReadyButton") as Button).global_position.y)
	var compact_snapshot := lobby_snapshot.duplicate(true)
	compact_snapshot["config"]["player_count"] = 2
	compact_snapshot["members"] = [
		_member("SEAT_SOUTH", 0, "Host", true, true),
		_member("SEAT_NORTH", 1, "North", false, false),
	]
	panel.call("_on_lobby_updated", compact_snapshot)
	await get_tree().process_frame
	for seat in [south, north, west, east]:
		assert(seat.size.is_equal_approx(south.size))
	assert(is_equal_approx(west.modulate.a, 0.0))
	assert(is_equal_approx(east.modulate.a, 0.0))
	assert(not (panel.get_node("%RoomEndpoint") as Label).text.contains(","))
	assert((panel.get_node("%HostActionRow") as HBoxContainer).visible)
	(panel.get_node("%LobbyBackButton") as Button).pressed.emit()
	await get_tree().create_timer(0.25).timeout
	assert(panel.visible)
	assert(not detail_panel.visible)
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


func _member(
	seat_key: String,
	seat_index: int,
	player_id: String,
	ready: bool,
	is_host: bool,
	is_ai: bool = false,
) -> Dictionary:
	return {
		"seat_key": seat_key,
		"seat_index": seat_index,
		"player_id": player_id,
		"ready": ready,
		"is_host": is_host,
		"is_ai": is_ai,
		"connected": true,
	}
