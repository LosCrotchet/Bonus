extends Node2D

@onready var PlayerHand = [$PlayerHand0, $PlayerHand1]
@onready var PlayerPlayed = [$PlayerPlayed0, $PlayerPlayed1]
@onready var CardUnit = preload("res://scene/card.tscn")

@onready var MouseAction = $MouseAction
@onready var CardDealer = $CardDealer
#@onready var CardFlipper = $CardFlipper
@onready var GameController = $GameController
@onready var DisplayController = $DisplayController
@onready var Rival = [$Rival01, $Rival02]

@onready var DiceDisplay = $Display/DiceDisplay
@onready var CardCountDisplay = $Display/CardCount
@onready var CardTypeDisplay = $Display/CardPlayType
@onready var DEBUG = $DEBUG

signal DealTimerTimeout
var deal_card_num = 17

func _ready():
	MouseAction.offset = PlayerHand[0].position
	MouseAction.target = PlayerHand[0]
	MouseAction.dice = $Buttons/Dice2
	MouseAction.dice_offset = $Buttons.position
	MouseAction.GameController = GameController
	
	DisplayController.GameController = GameController
	DisplayController.Display = $Display
	DisplayController.CardDealer = CardDealer
	DisplayController.player_hand.append($PlayerHand0)
	DisplayController.player_hand.append($PlayerHand1)
	DisplayController.player_played.append($PlayerPlayed0)
	DisplayController.player_played.append($PlayerPlayed1)
	DisplayController.init()
	
	Rival[0].GameController = GameController
	Rival[0].RivalID = 1
	Rival[1].GameController = GameController
	Rival[1].RivalID = 2
	#CardFlipper.target = PlayerHand0
	
	$GameStart.visible = true
	$Buttons.visible = false
	$Display.visible = false
	

func _process(delta):
	# DEBUG文本
	DEBUG.text = str(GameController.get_player_hand(0)) + "\n" + \
				 str(GameController.get_player_hand(1)) + "\n"
	var game_statue = GameController.get_game_statue()
	for i in range(len(game_statue)-1):
		DEBUG.text += str(game_statue[i]) + ", "
	DEBUG.text += '\n'
	for item in game_statue[-1]:
		DEBUG.text += str(item.x) + ", " + str(item.y) + ', '
	DEBUG.text += '\n'
	for item in PlayerHand[0].get_children():
		DEBUG.text += str(item.face_position) + ", "
	DEBUG.text += '\n'
	for item in GameController.players_hand[0]:
		DEBUG.text += str(item) + ", "
	DEBUG.text += '\n'
	
	if GameController.now_whos_turn == 0:
		$Buttons/Pass.visible = true
		$Buttons/Play.visible = true
	else:
		$Buttons/Pass.visible = false
		$Buttons/Play.visible = false

func deal_card_to(id):
	var new_card = CardUnit.instantiate()
	new_card.face_position = GameController.get_cards(1, id)[0]
	if id == 0:
		new_card.background_position = Vector2i(1, 0)
		new_card.face_enable = true
	else:
		#new_card.background_position = Vector2i(0, 0)
		#new_card.face_enable = false
		new_card.flip = true
		new_card.background_position = Vector2i(1, 0)
		new_card.face_enable = true
	PlayerHand[id].add_child(new_card)
	DisplayController.update_position(id)

func show_card_in(lst, id):
	for item in lst:
		var new_card = CardUnit.instantiate()
		new_card.face_position = item
		new_card.background_position = Vector2i(1, 0)
		new_card.face_enable = true
		PlayerPlayed[id].add_child(new_card)
	DisplayController.update_position(id)

func _on_pass_pressed():
	if GameController.run_statue == 0:
		return
	for i in range(3):
		deal_card_to(0)
	GameController.run_owner = 1
	GameController.now_whos_turn = 1
	GameController.card_play_type = "PASS"
	MouseAction.cancel_select()
	
	Rival[0].run()
	#$DealTimer.start()

func _on_play_pressed():
	if GameController.run_statue != 1 or GameController.now_whos_turn != 0:
		return
	var children = PlayerHand[0].get_children()
	var play_lst = []
	var lst_in_node = []
	for i in range(len(children)):
		if children[i].is_selected:
			play_lst.append(children[i].face_position)
			lst_in_node.append(i)
	
	if CardDealer.what_type(play_lst) == null:
		print("Invalid play.")
		MouseAction.cancel_select()
		return
	if len(play_lst) != GameController.dice_result:
		print("Invalid match to the dice.")
		MouseAction.cancel_select()
		return
	#if GameController.run_owner == 0:
	print(play_lst, lst_in_node)
	for i in lst_in_node:
		PlayerHand[0].remove_child(PlayerHand[0].get_child(i))
		#PlayerHand[0].get_child(i).queue_free()
	await get_tree().create_timer(0.1).timeout
	GameController.play_cards(play_lst, 0)
	show_card_in(play_lst, 0)
	$Buttons/Pass.visible = false
	$Buttons/Play.visible = false
	MouseAction.cancel_select()
	
	GameController.now_whos_turn = 1
	Rival[0].run()
	#DisplayController.update_position(0)

func _on_game_start_pressed():
	GameController.init(0)
	$GameStart.visible = false
	#$Buttons.visible = true
	#$Display.visible = true
	$DealTimer.start()
	
	await  DealTimerTimeout
	$Buttons.visible = true
	$Display.visible = true
	$Buttons/Pass.visible = false
	$Buttons/Play.visible = false
	GameController.run_statue = 0	# Dice
	GameController.run_owner = 0
	deal_card_num = 3

func _on_deal_timer_timeout():
	var flag = false
	for i in range(2):
		if len(GameController.get_player_hand(i)) < deal_card_num:
			deal_card_to(i)
			flag = true
	if not flag:
		$DealTimer.stop()
		DealTimerTimeout.emit()
		
func _on_mouse_action_dice_play_timeout():
	$Buttons/Pass.visible = true
	$Buttons/Play.visible = true
	GameController.run_statue = 1
