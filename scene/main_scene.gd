extends Node2D

@export var GameMode:int = 0
# 0: Single Game
# 1: Multi Game(Server)
# 2: Multi Game(Client)

enum LOCATION {
	UP, DOWN, LEFT, RIGHT
}

var is_game_end = false

func _ready():
	$GameUI.visible = false
	$Dice.visible = false
	$Dice.change_statue(0)
	$WinnerLabel.visible = false
	$PlayerManager.visible = false
	$DeckCount.visible = false
	$RestartGameButton.visible = false
	$BacktoMenuButton.visible = false
	is_game_end = false
	
	print("MainScene ready.")
	
	if len(WebController.multiplayer.get_peers()) > 0:
		if WebController.multiplayer.get_unique_id() == 1:
			GameMode = 1
			$GameModeLabel.text = "多人游戏（主机）"
		else:
			GameMode = 2
			$GameModeLabel.text = "多人游戏（客户端）"
	else:
		GameMode = 0
		$GameModeLabel.text = "单人游戏"
	
	DeckManager.GameMode = GameMode
	$GameManager.game_mode = GameMode
	
	$PlayerManager.player_count = DeckManager.player_count
	$GameManager.player_count = DeckManager.player_count
	$GameModeLabel.text += " | 玩家数：" + str(DeckManager.player_count)

	DeckManager.init()
	$GameManager.init()
	$PlayerManager.init()

	#$Dice.visible = true
	$PlayerManager.visible = true
	$DeckCount.visible = true
	
	$GameManager.dealer = (1 - DeckManager.player_order + DeckManager.player_count) % DeckManager.player_count
	#GameStart.emit()
	#await get_tree().create_timer(0.5).timeout
	#$PlayerManager.GameStart.emit()
	$Dice.visible = true
	$Dice.position = Vector2(800, 400)
	
	if DeckManager.GameMode != 0:
		WebController.player_mainscene_ready.rpc_id(1)
	
	#if DeckManager.GameMode == 2:
	#	WebController.player_loaded.rpc()

func _process(delta):
	$DeckCount.text = str(len(DeckManager.deck))
	if is_game_end:
		if DeckManager.GameMode != 0:
			var can_start = true
			for i in range(DeckManager.player_count):
				var order = (i + DeckManager.player_order - 1) % DeckManager.player_count + 1
				for k in WebController.players.keys():
					if WebController.players[k]["order"] == order:
						if WebController.players[k]["is_ready"]:
							$PlayerManager.Players[i].set_emoji(99)
						else:
							$PlayerManager.Players[i].set_emoji(98)
							can_start = false
			if DeckManager.GameMode == 1:
				$RestartGameButton.disabled = not can_start
			
func _on_game_manager_game_signal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus):
	# 调整骰子位置以显示谁是庄家
	$Dice.visible = true
	var offset = Vector2(800, 600)
	var dice_position
	var dice_scale
	if now_whos_dice == 0:
		dice_position = Vector2(-260, 0) + offset
		dice_scale = Vector2(1, 1)
	else:
		match $PlayerManager.Players[now_whos_dice].location:
			LOCATION.UP:
				dice_position = Vector2(-100, -350) + offset
			LOCATION.LEFT:
				dice_position = Vector2(-450, -340) + offset
			LOCATION.RIGHT:
				dice_position = Vector2(400, -340) + offset
		dice_scale = Vector2(0.8, 0.8)
	if is_bonus:
		$Dice.change_statue(1)
		dice_scale = Vector2(1, 1)
	else:
		$Dice.change_statue(0)
	
	var dice_tween = get_tree().create_tween().set_trans(Tween.TRANS_QUINT).set_parallel(true)
	dice_tween.tween_property($Dice, "position", dice_position, 1)
	dice_tween.tween_property($Dice, "scale", dice_scale, 1)

func _on_player_manager_game_end(index):
	$DeckCount.visible = false
	$WinnerLabel.visible = true
	$WinnerLabel.text = $PlayerManager.Players[index].player_name + " 胜出！"
	$GameUI.visible = false
	await get_tree().create_timer(3).timeout
	
	is_game_end = true
	if DeckManager.GameMode == 2:
		$RestartGameButton.text = "准备"
	else:
		$RestartGameButton.text = "再开一把"
		if DeckManager.GameMode == 1:
			$RestartGameButton.disabled = true
	
	$GameUI.visible = false
	$RestartGameButton.visible = true
	$BacktoMenuButton.visible = true
	$WinnerLabel.visible = false
	#_ready()

func _on_restart_game_button_pressed():
	if DeckManager.GameMode == 2:
		if $RestartGameButton.text == "准备":
			WebController.get_ready(true)
			$RestartGameButton.text = "已准备"
		else:
			WebController.get_ready(false)
			$RestartGameButton.text = "准备"
	else:
		if DeckManager.GameMode == 1:
			get_tree().unload_current_scene()
			WebController.load_game.rpc("res://scene/main_scene.tscn")
		else:
			get_tree().reload_current_scene()
			#get_tree().change_scene_to_file("res://scene/main_scene.tscn")

func _on_backto_menu_button_pressed():
	get_tree().change_scene_to_file("res://scene/menu.tscn")
