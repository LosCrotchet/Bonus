extends Node2D

@export var GameMode:int = 0
# 0: Single Game
# 1: Multi Game(Server)
# 2: Multi Game(Client)

signal GameStart()

enum LOCATION {
	UP, DOWN, LEFT, RIGHT
}

func _ready():
	$GameUI.visible = false
	$Dice.visible = false
	$WinnerLabel.visible = false
	$PlayerManager.visible = false
	$DeckCount.visible = false
	$RestartGameButton.visible = false
	$BacktoMenuButton.visible = false
	
	print("MainScene ready.")
	
	if len(WebController.multiplayer.get_peers()) > 0:
		if WebController.multiplayer.is_server():
			GameMode = 1
		else:
			GameMode = 2
	else:
		GameMode = 0
	
	GameStart.emit()

func _process(delta):
	$DeckCount.text = str(len(DeckManager.deck))

func _on_game_manager_game_signal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus):
	# 调整骰子位置以显示谁是庄家
	var offset = Vector2(800, 600)
	var dice_position
	var dice_scale
	if now_whos_dice == 0:
		dice_position = Vector2(-260, 0) + offset
		dice_scale = Vector2(1, 1)
	else:
		match $PlayerManager.Players[now_whos_dice].location:
			LOCATION.UP:
				dice_position = Vector2(-200, -350) + offset
			LOCATION.LEFT:
				dice_position = Vector2(-550, -80) + offset
			LOCATION.RIGHT:
				dice_position = Vector2(500, -300) + offset
		dice_scale = Vector2(0.8, 0.8)
	if is_bonus:
		$Dice.change_statue(1)
		dice_scale = Vector2(1, 1)
	else:
		$Dice.change_statue(0)
	
	var dice_tween = get_tree().create_tween().set_trans(Tween.TRANS_QUINT).set_parallel(true)
	dice_tween.tween_property($Dice, "position", dice_position, 1)
	dice_tween.tween_property($Dice, "scale", dice_scale, 1)

func _on_player_manager_game_end(player_name):
	$DeckCount.visible = false
	$WinnerLabel.visible = true
	$WinnerLabel.text = player_name + " 胜出！"
	await get_tree().create_timer(3).timeout
	$RestartGameButton.visible = true
	$BacktoMenuButton.visible = true
	$WinnerLabel.visible = false
	#_ready()

func _on_game_start():
	$PlayerManager.player_count = DeckManager.player_count
	$GameManager.player_count = DeckManager.player_count

	$Dice.visible = true
	$PlayerManager.visible = true
	$DeckCount.visible = true

	if GameMode != 2:
		$GameManager.dealer = 0
		
		$DeckManager.init()
		$GameManager.init()
		
		if GameMode == 1:
			WebController.update_deck(DeckManager.deck)
	else:
		for i in range(len(WebController.players.keys())):
			if WebController.players.keys()[i] == 1:
				$GameManager.dealer = i
				break
	
	$PlayerManager.init(GameMode)

func _on_restart_game_button_pressed():
	$GameUI.visible = false
	$Dice.visible = false
	$WinnerLabel.visible = false
	$PlayerManager.visible = false
	$DeckCount.visible = false
	$RestartGameButton.visible = false
	$BacktoMenuButton.visible = false
	
	GameStart.emit()

func _on_backto_menu_button_pressed():
	get_tree().change_scene_to_file("res://scene/menu.tscn")
