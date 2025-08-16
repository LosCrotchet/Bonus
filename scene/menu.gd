extends Node2D

var main_tween = null
var next_tween = null
var single_tween = null
var client_tween = null
var server_tween = null
var multi_tween = null
var master_tween = null
const WAIT_TIME = 0.6

var now_state = 0
# 0: Main Buttons
# 1: Exit
# 2: Single Player 
# 3: Multi Player Client
# 4: Multi Player Server
# 5: Multi Game Client
# 6: Multi Game Server

const CHARACTER_POSITION = Vector2(800, 150)
const TITLE_POSITION = Vector2(540, 370)
const MAIN_BUTTONS_POSITION = Vector2(800, 450)
const YES_OR_NO_BUTTONS_POSITION = Vector2(1085, 450)
const SINGLE_PLAYER_SETTINGS_POSITION = Vector2(1085, 450)
const MULTIPLAYER_INFO_POSITION = Vector2(1050, 450)
const MULTIPLAYER_SETTINGS_CLIENT = Vector2(1050, 450)
const MULTIPLAYER_SETTINGS_SERVER = Vector2(1050, 450)

@onready var avatars = [preload("res://assets/avatar_default_1.png"),
						preload("res://assets/avatar_default_2.png"),
						preload("res://assets/avatar_default_3.png"),
						preload("res://assets/avatar_default_4.png")]

func _ready():
	$Character.position = CHARACTER_POSITION
	$Title.position = TITLE_POSITION
	$MainButtons.position = MAIN_BUTTONS_POSITION
	$YesOrNoButtons.position = YES_OR_NO_BUTTONS_POSITION
	$SinglePlayerSettings.position = SINGLE_PLAYER_SETTINGS_POSITION
	$MultiPlayerInfo.position = MULTIPLAYER_INFO_POSITION
	$MultiPlayerSettingsClient.position = MULTIPLAYER_SETTINGS_CLIENT
	$MultiPlayerSettingsServer.position = MULTIPLAYER_SETTINGS_SERVER
	
	$MultiPlayerInfo/PlayerInfo1.position = Vector2(210, -200)
	$MultiPlayerInfo/PlayerInfo2.position = Vector2(210, -35)
	$MultiPlayerInfo/PlayerInfo3.position = Vector2(210, 130)
	$MultiPlayerInfo/PlayerInfo4.position = Vector2(210, 295)
	
	$YesOrNoButtons.modulate = Color(1, 1, 1, 0)
	$YesOrNoButtons.visible = false
	$MainButtons.visible = true
	
	$SinglePlayerSettings.modulate = Color(1, 1, 1, 0)
	$SinglePlayerSettings.visible = false
	$MultiPlayerSettingsClient.visible = false
	$MultiPlayerSettingsServer.visible = false
	$MultiPlayerInfo.visible = false
	
	if WebController.ip_address != "":
		$MultiPlayerSettingsClient/IPInput.text = WebController.ip_address + ":" + str(WebController.port)
	$MultiPlayerSettingsClient/PlayerNameInput.text = WebController.player_info["name"]
	$MultiPlayerSettingsServer/PlayerNameInput.text = WebController.player_info["name"]
	$MultiPlayerSettingsServer/PortInput.text = str(WebController.port)
	if WebController.player_info["avatar"] in [0, 1, 2, 3]:
		$MultiPlayerSettingsClient/PlayerAvatar.texture = avatars[WebController.player_info["avatar"]]
	else:
		$MultiPlayerSettingsClient/PlayerAvatar.texture = WebController.player_info["avatar"]
	
	DeckManager.multi_load.connect(Callable(self, "_on_multi_game_start_to_load"))
	
	now_state = 0

func _process(delta):
	var _offset = $Background.material.get_shader_parameter("offset")
	$Background.material.set_shader_parameter("offset", _offset + Vector2(-0.1, 0.1))
	
	if len($MultiPlayerSettingsClient/PlayerNameInput.text) > 8:
		$MultiPlayerSettingsClient/PlayerNameInput.text = $MultiPlayerSettingsClient/PlayerNameInput.text.substr(0, 8)
	if len($MultiPlayerSettingsServer/PlayerNameInput.text) > 8:
		$MultiPlayerSettingsServer/PlayerNameInput.text = $MultiPlayerSettingsServer/PlayerNameInput.text.substr(0, 8)
	
	if now_state == 3:
		if WebController.player_info["avatar"] in [0, 1, 2, 3]:
			$MultiPlayerSettingsClient/PlayerAvatar.texture = avatars[WebController.player_info["avatar"]]
		else:
			$MultiPlayerSettingsClient/PlayerAvatar.texture = WebController.player_info["avatar"]
	if now_state == 4:
		if WebController.player_info["avatar"] in [0, 1, 2, 3]:
			$MultiPlayerSettingsServer/PlayerAvatar.texture = avatars[WebController.player_info["avatar"]]
		else:
			$MultiPlayerSettingsServer/PlayerAvatar.texture = WebController.player_info["avatar"]
	
	if now_state in [5, 6]:
		
		$MultiPlayerInfo/MultiPlayerInfoDisplay.text = \
			"游戏人数：" + str(DeckManager.player_count) + "\n"\
			+ "Order：" + str(WebController.player_info["order"]) + "\n"
		
		match DeckManager.player_count:
			0:
				$MultiPlayerInfo/PlayerInfo1.visible = false
				$MultiPlayerInfo/PlayerInfo2.visible = false
				$MultiPlayerInfo/PlayerInfo3.visible = false
				$MultiPlayerInfo/PlayerInfo4.visible = false
			1:
				$MultiPlayerInfo/PlayerInfo1.visible = true
				$MultiPlayerInfo/PlayerInfo2.visible = false
				$MultiPlayerInfo/PlayerInfo3.visible = false
				$MultiPlayerInfo/PlayerInfo4.visible = false
			2:
				$MultiPlayerInfo/PlayerInfo1.visible = true
				$MultiPlayerInfo/PlayerInfo2.visible = true
				$MultiPlayerInfo/PlayerInfo3.visible = false
				$MultiPlayerInfo/PlayerInfo4.visible = false
			3:
				$MultiPlayerInfo/PlayerInfo1.visible = true
				$MultiPlayerInfo/PlayerInfo2.visible = true
				$MultiPlayerInfo/PlayerInfo3.visible = true
				$MultiPlayerInfo/PlayerInfo4.visible = false
			4:
				$MultiPlayerInfo/PlayerInfo1.visible = true
				$MultiPlayerInfo/PlayerInfo2.visible = true
				$MultiPlayerInfo/PlayerInfo3.visible = true
				$MultiPlayerInfo/PlayerInfo4.visible = true
		
		var can_start_game = true
		for i in range(DeckManager.player_count):
			var is_ai = true
			for k in WebController.players.keys():
				var index = WebController.players[k]["order"] - 1
				if index == i:
					$MultiPlayerInfo.get_child(index).get_child(0).text = WebController.players[k]["name"]
					if WebController.players[k]["avatar"] in [0, 1, 2, 3]:
						$MultiPlayerInfo.get_child(index).get_child(3).texture = avatars[WebController.players[k]["avatar"]]
					else:
						$MultiPlayerInfo.get_child(index).get_child(3).texture = WebController.players[k]["avatar"]
					if WebController.players[k]["is_ready"]:
						$MultiPlayerInfo.get_child(index).get_child(1).text = "已准备"
					else:
						$MultiPlayerInfo.get_child(index).get_child(1).text = "未准备"
						can_start_game = false
					if index == 0:
						$MultiPlayerInfo.get_child(index).get_child(1).text = "房主"
					$MultiPlayerInfo.get_child(index).get_child(2).visible = false if now_state == 5 else true
					if now_state == 6 and index == 0:
						$MultiPlayerInfo.get_child(index).get_child(2).visible = false
					is_ai = false
					break
			if is_ai:
				$MultiPlayerInfo.get_child(i).get_child(0).text = "玩家" + str(i+1)
				$MultiPlayerInfo.get_child(i).get_child(1).text = "人机"
				$MultiPlayerInfo.get_child(i).get_child(2).visible = false
		
		if now_state == 6:
			$MultiPlayerInfo/MultiGameStart.disabled = not can_start_game
		
		if len(WebController.multiplayer.get_peers()) == 0 and now_state == 5:
			$MultiPlayerInfo/MultiGameStart.disabled = true
			$MultiPlayerInfo/MultiGameStart.text = "暂未连接"
			DeckManager.player_count = 0
		elif len(WebController.multiplayer.get_peers()) > 0 and now_state == 5:
			$MultiPlayerInfo/MultiGameStart.disabled = false
			if $MultiPlayerInfo/MultiGameStart.text == "暂未连接":
				$MultiPlayerInfo/MultiGameStart.text = "准备"
		
func update_state(to_state:int):
	print(now_state, " ", to_state)
	if now_state == to_state:
		return
	if to_state in [0, 1, 2]:
		$MainButtons/MultiGame.text = "多人游戏"
	match now_state:
		0:
			$FaderCompenent.fade($MainButtons)
			
			if main_tween:
				main_tween.kill()
			main_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			main_tween.tween_property($Character, "position:x", CHARACTER_POSITION.x-450, WAIT_TIME)
			main_tween.tween_property($Title, "position:x", TITLE_POSITION.x-450, WAIT_TIME)
			main_tween.tween_property($MainButtons, "position:x", MAIN_BUTTONS_POSITION.x-450, WAIT_TIME)
			var tmp = func():
				main_tween = null
			main_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		1:
			if to_state != 0:
				$FaderCompenent.fade($MainButtons)
			
			if next_tween:
				next_tween.kill()
			$Character.set_mouse(1)
			$YesOrNoButtons/Yes.disabled = true
			$YesOrNoButtons/No.disabled = true
			next_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			next_tween.tween_property($YesOrNoButtons, "modulate", Color(1, 1, 1, 0), WAIT_TIME)
			next_tween.tween_property($YesOrNoButtons, "position:x", YES_OR_NO_BUTTONS_POSITION.x+500, WAIT_TIME)
			var tmp = func():
				next_tween = null
				$YesOrNoButtons.visible = false
				$Character.set_mouse(-1)
			next_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		2:
			if to_state != 0:
				$FaderCompenent.fade($MainButtons)
			
			if single_tween:
				single_tween.kill()
			single_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			single_tween.tween_property($SinglePlayerSettings, "modulate", Color(1, 1, 1, 0), WAIT_TIME)
			single_tween.tween_property($SinglePlayerSettings, "position:x", SINGLE_PLAYER_SETTINGS_POSITION.x+500, WAIT_TIME)
			var tmp = func():
				$SinglePlayerSettings.visible = false
				single_tween = null
			single_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		3:
			if to_state != 0:
				$FaderCompenent.fade($MainButtons)
			
			if client_tween:
				client_tween.kill()
			client_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			client_tween.tween_property($MultiPlayerSettingsClient, "modulate", Color(1, 1, 1, 0), WAIT_TIME)
			client_tween.tween_property($MultiPlayerSettingsClient, "position:x", MULTIPLAYER_SETTINGS_CLIENT.x+500, WAIT_TIME)
			var tmp = func():
				$MultiPlayerSettingsClient.visible = false
				client_tween = null
			client_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		4:
			if to_state != 0:
				$FaderCompenent.fade($MainButtons)
			
			if server_tween:
				server_tween.kill()
			server_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			server_tween.tween_property($MultiPlayerSettingsServer, "modulate", Color(1, 1, 1, 0), WAIT_TIME)
			server_tween.tween_property($MultiPlayerSettingsServer, "position:x", MULTIPLAYER_SETTINGS_SERVER.x+500, WAIT_TIME)
			var tmp = func():
				$MultiPlayerSettingsServer.visible = false
				server_tween = null
			server_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		5, 6:
			if to_state != 0:
				$FaderCompenent.fade($MainButtons)
			
			$MultiPlayerSettingsClient/Connect.text = "连接"
			$MultiPlayerSettingsServer/StartServer.text = "创建房间"
			WebController.remove_multiplayer_peer()
			
			if multi_tween:
				multi_tween.kill()
			multi_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			multi_tween.tween_property($MultiPlayerInfo, "modulate", Color(1, 1, 1, 0), WAIT_TIME)
			multi_tween.tween_property($MultiPlayerInfo, "position:x", MULTIPLAYER_INFO_POSITION.x+500, WAIT_TIME)
			var tmp = func():
				multi_tween = null
				$MultiPlayerInfo.visible = false
			multi_tween.tween_callback(tmp).set_delay(WAIT_TIME)
			
	match to_state:
		0:
			$FaderCompenent.defade($MainButtons, WAIT_TIME)
			
			if main_tween:
				main_tween.kill()
			main_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			main_tween.tween_property($Character, "position:x", CHARACTER_POSITION.x, WAIT_TIME)
			main_tween.tween_property($Title, "position:x", TITLE_POSITION.x, WAIT_TIME)
			main_tween.tween_property($MainButtons, "position:x", MAIN_BUTTONS_POSITION.x, WAIT_TIME)
			var tmp = func():
				main_tween = null
			main_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		1:
			if next_tween:
				next_tween.kill()
			$Character.set_mouse(0)
			$YesOrNoButtons/Yes.disabled = false
			$YesOrNoButtons/No.disabled = false
			$YesOrNoButtons.visible = true
			$YesOrNoButtons.modulate = Color(1, 1, 1, 0)
			$YesOrNoButtons.position.x = YES_OR_NO_BUTTONS_POSITION.x + 500
			next_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			next_tween.tween_property($YesOrNoButtons, "modulate", Color(1, 1, 1, 1), WAIT_TIME)
			next_tween.tween_property($YesOrNoButtons, "position:x", YES_OR_NO_BUTTONS_POSITION.x, WAIT_TIME)
			var tmp = func():
				next_tween = null
			next_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		2:
			if single_tween:
				single_tween.kill()
			$SinglePlayerSettings.visible = true
			$SinglePlayerSettings.modulate = Color(1, 1, 1, 0)
			$SinglePlayerSettings.position.x = SINGLE_PLAYER_SETTINGS_POSITION.x+500
			single_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			single_tween.tween_property($SinglePlayerSettings, "modulate", Color(1, 1, 1, 1), WAIT_TIME)
			single_tween.tween_property($SinglePlayerSettings, "position:x", SINGLE_PLAYER_SETTINGS_POSITION.x, WAIT_TIME)
			var tmp = func():
				single_tween = null
			single_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		3:
			if client_tween:
				client_tween.kill()
			$MultiPlayerSettingsClient.visible = true
			$MultiPlayerSettingsClient.position.x = MULTIPLAYER_SETTINGS_CLIENT.x+500
			$MultiPlayerSettingsClient.modulate = Color(1, 1, 1, 0)
			client_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			client_tween.tween_property($MultiPlayerSettingsClient, "modulate", Color(1, 1, 1, 1), WAIT_TIME)
			client_tween.tween_property($MultiPlayerSettingsClient, "position:x", MULTIPLAYER_SETTINGS_CLIENT.x, WAIT_TIME)
			var tmp = func():
				client_tween = null
				$MultiPlayerSettingsClient.visible = true
			client_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		4:
			if server_tween:
				server_tween.kill()
			$MultiPlayerSettingsServer.visible = true
			$MultiPlayerSettingsServer.position.x = MULTIPLAYER_SETTINGS_SERVER.x+500
			$MultiPlayerSettingsServer.modulate = Color(1, 1, 1, 0)
			server_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			server_tween.tween_property($MultiPlayerSettingsServer, "modulate", Color(1, 1, 1, 1), WAIT_TIME)
			server_tween.tween_property($MultiPlayerSettingsServer, "position:x", MULTIPLAYER_SETTINGS_SERVER.x, WAIT_TIME)
			var tmp = func():
				server_tween = null
			server_tween.tween_callback(tmp).set_delay(WAIT_TIME)
		5, 6:
			if multi_tween:
				multi_tween.kill()
			$MultiPlayerInfo.visible = true
			$MultiPlayerInfo.position.x = MULTIPLAYER_INFO_POSITION.x+500
			$MultiPlayerInfo.modulate = Color(1, 1, 1, 0)
			multi_tween = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_parallel()
			multi_tween.tween_property($MultiPlayerInfo, "modulate", Color(1, 1, 1, 1), WAIT_TIME)
			multi_tween.tween_property($MultiPlayerInfo, "position:x", MULTIPLAYER_INFO_POSITION.x, WAIT_TIME)
			var tmp = func():
				multi_tween = null
			multi_tween.tween_callback(tmp).set_delay(WAIT_TIME)
	now_state = to_state

func _on_quit_pressed():
	update_state(1)

func _on_no_pressed():
	update_state(0)

func _on_yes_pressed():
	get_tree().quit()

func _on_single_game_pressed():
	if now_state == 2:
		update_state(0)
	else:
		DeckManager.player_count = 2
		$SinglePlayerSettings/PlayersOf2.button_pressed = true
		update_state(2)

func _on_start_game_pressed():
	get_tree().change_scene_to_file("res://scene/main_scene.tscn")

func _on_multi_game_pressed():
	if now_state in [0, 1, 2]:
		update_state(3)
		$MainButtons/MultiGame.text = "加入房间"
	elif now_state == 3:
		update_state(4)
		$MainButtons/MultiGame.text = "创建房间"
	elif now_state == 4:
		update_state(3)
		$MainButtons/MultiGame.text = "加入房间"

func _on_connect_pressed():
	if now_state != 5:
		if ":" not in $MultiPlayerSettingsClient/IPInput.text:
			return
		WebController.remove_multiplayer_peer()
		WebController.ip_address = $MultiPlayerSettingsClient/IPInput.text.split(":")[0]
		WebController.port = int($MultiPlayerSettingsClient/IPInput.text.split(":")[1])
		WebController.player_info["name"] = $MultiPlayerSettingsClient/PlayerNameInput.text
		WebController.player_info["is_ready"] = false
		DeckManager.player_count = 0
		var error = WebController.join_game()
		if error:
			print(error)
			return
		
		$MultiPlayerInfo/MultiGameStart.disabled = true
		#$MultiPlayerSettingsClient/Connect.text = "返回"
		#$MultiPlayerInfo/MultiGameStart.text = "暂未连接"
		
		#DeckManager.player_count = WebController.max_connections
		update_state(5)
	else:
		#DeckManager.player_count = WebController.max_connections
		WebController.remove_multiplayer_peer()
		$MultiPlayerSettingsClient/Connect.text = "连接"
		update_state(3)

func _on_start_server_pressed():
	if now_state != 6:
		WebController.remove_multiplayer_peer()
		WebController.ip_address = "127.0.0.1"
		WebController.port = int($MultiPlayerSettingsServer/PortInput.text)
		WebController.player_info["name"] = $MultiPlayerSettingsServer/PlayerNameInput.text
		WebController.player_info["is_ready"] = true
		WebController.max_connections = DeckManager.player_count
		var error = WebController.create_game()
		if error:
			print(error)
			return

		$MultiPlayerInfo/MultiGameStart.disabled = false
		#$MultiPlayerSettingsServer/StartServer.text = "解散房间"
		$MultiPlayerInfo/MultiGameStart.text = "开始游戏"
		update_state(6)
	else:
		WebController.remove_multiplayer_peer()
		$MultiPlayerSettingsServer/StartServer.text = "创建房间"
		update_state(4)

func _on_multi_game_start_pressed():
	if now_state == 5:
		if WebController.player_info["is_ready"] == false:
			WebController.get_ready(true)
			$MultiPlayerInfo/MultiGameStart.text = "已准备"
		else:
			WebController.get_ready(false)
			$MultiPlayerInfo/MultiGameStart.text = "准备"
	if now_state == 6:
		WebController.player_start_to_load.rpc()
		#WebController.load_game.rpc("res://scene/main_scene.tscn")

func _on_multi_game_start_to_load():
	WebController.player_loaded.rpc()

func _on_player_2_enable_pressed():
	if now_state == 6:
		var index = WebController.multiplayer.get_peers()[0]
		WebController.multiplayer.multiplayer_peer.disconnect_peer(index)

func _on_player_3_enable_pressed():
	if now_state == 6:
		var index = WebController.multiplayer.get_peers()[1]
		WebController.multiplayer.multiplayer_peer.disconnect_peer(index)

func _on_player_4_enable_pressed():
	if now_state == 6:
		var index = WebController.multiplayer.get_peers()[2]
		WebController.multiplayer.multiplayer_peer.disconnect_peer(index)

func _on_back_pressed():
	match now_state:
		6:
			update_state(4)
			WebController.remove_multiplayer_peer()
		5:
			update_state(3)
			WebController.remove_multiplayer_peer()
		4, 3, 2:
			update_state(0)

func _on_players_of_2_toggled(toggled_on):
	if toggled_on:
		DeckManager.player_count = 2

func _on_players_of_3_toggled(toggled_on):
	if toggled_on:
		DeckManager.player_count = 3

func _on_players_of_4_toggled(toggled_on):
	if toggled_on:
		DeckManager.player_count = 4

func _on_left_icon_pressed() -> void:
	if WebController.player_info["avatar"] in [0, 1, 2, 3]:
		WebController.player_info["avatar"] = (WebController.player_info["avatar"] + 3) % 4

func _on_right_icon_pressed() -> void:
	if WebController.player_info["avatar"] in [0, 1, 2, 3]:
		WebController.player_info["avatar"] = (WebController.player_info["avatar"] + 1) % 4

func _on_select_avatar_pressed() -> void:
	#DisplayServer.file_dialog_show("选择头像", )
	pass
