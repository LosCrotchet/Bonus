extends Node

@export var player_count:int
@export var visible:bool

@onready var CARD = preload("res://card.tscn")

enum LOCATION {
	UP, DOWN, LEFT, RIGHT
}
var Players = []
var last_player_select = []
var now_turn = -1
var now_dice = -1
var now_dice_result = -1
var now_bonus = false
var last_played_cards = []
var last_player_id = -1

var play_button_pressed = false
var pass_button_pressed = false

var type_name = [["单张"],
				 ["对子"],
				 ["三条", "顺子"],
				 ["四条", "顺子", "三带一", "二连对"],
				 ["五条", "顺子", "四带一", "三带二"],
				 ["六条", "顺子", "五带一", "四带二", "三带三", "三连对"]]

@onready var card_1 = preload("res://assets/sound/card1.ogg")
@onready var card_fan_2 = preload("res://assets/sound/cardFan2.ogg")
@onready var card_3 = preload("res://assets/sound/card3.ogg")
@onready var card_slide_1 = preload("res://assets/sound/cardSlide1.ogg")
@onready var card_slide_2 = preload("res://assets/sound/cardSlide2.ogg")
@onready var cancel_sound = preload("res://assets/sound/cancel.ogg")
@onready var win_sound = preload("res://assets/sound/win.ogg")

signal PlayerFinish(action)
signal PlayerSelectUpdate(type:String)
signal PlayerHandCountUpdate(count:int)
signal PlayerDiceRoll
signal GameEnd(player_name:String)
signal GameStart

func _ready() -> void:
	DeckManager.deliver_card_to.connect(Callable(self, "_on_deck_manager_deliver_card_to"))

func _process(delta):
	#print(GameManager.now_whos_turn, GameManager.game_started)
	for item in Players:
		item.visible = visible
	if now_turn == 0:
		PlayerHandCountUpdate.emit(len(Players[0].hand))
		var player_select = Players[0].get_select_cards()
		#print(player_select, " ", last_player_select)
		if player_select != last_player_select:
			last_player_select = player_select
			var result = DeckManager.what_type(player_select)
			#print(player_select, " ", last_player_select)
			if result == [null]:
				PlayerSelectUpdate.emit(" ")
			else:
				if len(result) == 1:
					PlayerSelectUpdate.emit(type_name[len(player_select)-1][result[0]])
				else:
					var result_string = type_name[len(player_select)-1][result[0]]
					for i in range(1, len(result)):
						result_string += ("/" + type_name[len(player_select)-1][result[i]])
					PlayerSelectUpdate.emit(result_string)

func init():
	Players.clear()
	var children = get_children()
	if DeckManager.GameMode != 0:
		DeckManager.player_order = WebController.player_info["order"]
	for i in range(player_count):
		Players.append(children[i])
		Players[i].visible = true
		if DeckManager.GameMode != 0:
			# Multigame
			var now_order = (DeckManager.player_order - 1 + i) % player_count + 1
			var is_player = false
			for k in WebController.players.keys():
				if now_order == WebController.players[k]["order"]:
					is_player = true
					Players[i].player_name = WebController.players[k]["name"]
					break
			if not is_player:
				Players[i].player_name = "[AI]玩家" + str(now_order)
			Players[i].order = now_order
			Players[i].is_player = is_player
		else:
			# Singlegame
			Players[i].player_name = "玩家 " + str(i)
			Players[i].order = i + 1
			Players[i].is_player = false
		Players[i].set_emoji(1)
	Players[0].location = LOCATION.DOWN
	Players[0].position = Vector2(800, 760)
	Players[0].select_enable = true
	Players[0].is_player = true
	#Players[0].player_name = "你"
	match player_count:
		2:
			Players[1].location = LOCATION.UP
			Players[1].position = Vector2(800, 90)
		3:
			Players[2].location = LOCATION.LEFT
			Players[2].position = Vector2(0, 450)
			Players[1].location = LOCATION.UP
			Players[1].position = Vector2(800, 90)
		4:
			Players[3].location = LOCATION.LEFT
			Players[3].position = Vector2(0, 450)
			Players[2].location = LOCATION.UP
			Players[2].position = Vector2(800, 90)
			Players[1].location = LOCATION.RIGHT
			Players[1].position = Vector2(1600, 450)
	for item in Players:
		item.init()
	
	print("GameMode: ", DeckManager.GameMode)
	if DeckManager.GameMode != 2:
		for cnt in range(17):
			for i in range(player_count):
				var result = DeckManager.get_card()
				#print(DeckManager.deliver_card_to.get_connections())
				DeckManager.deliver_card_to.emit(Players[i].order, result)
				add_card_to(result, i)
				Players[i].update_x_position()
				#await get_tree().create_timer(0.1).timeout


func play_sound(id:int):
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	if id == 1:
		audio_player.stream = [card_1, card_3][randi_range(0, 1)]
	if id == 2:
		audio_player.stream = card_fan_2
	if id == 3:
		audio_player.stream = cancel_sound
	if id == 4:
		audio_player.stream = win_sound
	audio_player.play()
	await audio_player.finished
	remove_child(audio_player)
	
func add_card_to(card:Vector2i, id:int):
	var new_card = CARD.instantiate()
	new_card.suit = card.x
	new_card.rank = card.y
	if id != 0:
		new_card.is_folded = true
	#new_card.is_folded = false
	Players[id].get_child(0).add_child(new_card)
	Players[id].hand.append(card)
	Players[id].update_x_position()
	

func discard_to(cards, id:int):
	for item in cards:
		var new_card = CARD.instantiate()
		new_card.suit = item.x
		new_card.rank = item.y
		new_card.is_folded = false
		Players[id].get_child(1).add_child(new_card)
		Players[id].update_x_position()

# 收到相应回合开始的信号后，进入对应Player进行处理
func _on_game_manager_game_signal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus):
	now_turn = now_whos_turn
	now_dice = now_whos_dice
	now_dice_result = dice_result
	now_bonus = is_bonus
	last_played_cards = played_cards.duplicate()
	last_player_id = last_player
	Players[now_turn].show_pass_label(false)
	Players[now_turn].clean_the_discard()

	for i in range(player_count):
		if len(Players[i].hand) == 0:
			GameEnd.emit(Players[i].player_name)
			play_sound(4)
			for j in range(player_count):
				Players[j].clean_the_discard()
				Players[j].flip_over()
				#Players[j].show_info(false)
				Players[j].set_emoji(5)
			Players[i].set_emoji(3)
			#await get_tree().create_timer(3).timeout
			#for j in range(player_count):
			#	Players[j].init()
			return
	
	#await get_tree().create_timer(0.2).timeout
	
	if now_whos_turn == now_whos_dice and len(played_cards) == 0 and now_dice_result == -1:
		for i in range(player_count):
			Players[i].show_pass_label(false)
			Players[i].clean_the_discard()
		if not now_bonus:
			Players[now_whos_turn].set_emoji(1)
			PlayerDiceRoll.emit()
			return
		if now_bonus:
			Players[now_whos_turn].set_emoji(7)
	
	#if now_dice_result != -1 and not is_bonus and len(Players[now_whos_turn].hand) < now_dice_result:
	#	await get_tree().create_timer(0.5).timeout
	#	Players[now_whos_turn].clean_the_discard()
	#	Players[now_whos_turn].show_pass_label(true)
	#	Players[now_whos_turn].set_emoji(6)
	#	play_sound(3)
	#	PlayerFinish.emit([null])
	
	await get_tree().create_timer(0.1).timeout
	
	Players[now_whos_turn].set_emoji(1)
	var result
	if now_whos_turn != 0 and Players[now_whos_turn].is_player == false:
		result = Players[now_whos_turn].deal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, now_bonus)
	else:
		# 你的情况单独判断
		return
	
	await get_tree().create_timer(0.1).timeout
	
	if result == [null]:
		#await get_tree().create_timer(1).timeout
		Players[now_whos_turn].clean_the_discard()
		Players[now_whos_turn].show_pass_label(true)
		Players[now_whos_turn].set_emoji(6)
		play_sound(3)
	else:
		var index = 0
		for i in range(len(Players[now_whos_turn].hand)):
			if Players[now_whos_turn].hand[i] == result[index]:
				#Players[now_whos_turn].hand[i].is_selected = true
				Players[now_whos_turn].select(i, true)
				DeckManager.discard(Players[now_whos_turn].hand[i])
				#Players[now_whos_turn].update_y_position()
				index += 1
				#await get_tree().create_timer(0.5).timeout
				if index == len(result):
					break
		Players[now_whos_turn].show_hint(-len(result))
		Players[now_whos_turn].play_the_select()
		Players[now_whos_turn].update_x_position()
		Players[now_whos_turn].set_emoji(2)
		play_sound(2)
	await get_tree().create_timer(0.1).timeout
	# 返回finish信号
	PlayerFinish.emit(result)

# 摸牌的信号
func _on_game_manager_draw_card(id, num):
	Players[id].show_hint(num)
	for i in range(num):
		var result = DeckManager.get_card()
		if DeckManager.GameMode == 1:
			DeckManager.deliver_card_to.emit(Players[id].order, result)
		add_card_to(result, id)
		play_sound(1)
		#await get_tree().create_timer(0.1)

### 你的按钮事件处理

func _on_pass_button_pressed():
	Players[0].show_pass_label(true)
	Players[0].clean_the_discard()
	Players[0].cancel_select()
	Players[0].update_x_position()
	Players[0].set_emoji(6)
	play_sound(3)
	await get_tree().create_timer(0.1).timeout

func _on_play_button_pressed():
	var select_cards = Players[0].get_select_cards()
	if DeckManager.what_type(select_cards) != [null] and (len(select_cards) == now_dice_result or now_bonus):
		if last_played_cards == [] or DeckManager.whos_greater(select_cards, last_played_cards):
			last_played_cards = select_cards
		else:
			Players[0].cancel_select()
			play_sound(3)
			await get_tree().create_timer(0.1).timeout
			play_button_pressed = false
			return
		#discard_to(select_cards, 0)
		for item in select_cards:
			DeckManager.discard(item)
		Players[0].play_the_select()
		Players[0].show_hint(-len(select_cards))
		Players[0].set_emoji(2)
		Players[0].update_x_position()
		
		if len(Players[0].hand) == 0:
			GameEnd.emit(Players[0].player_name)
			play_sound(4)
			for j in range(player_count):
				Players[j].clean_the_discard()
				Players[j].flip_over()
				#Players[j].show_info(false)
				Players[j].set_emoji(5)
			Players[0].set_emoji(3)
			await get_tree().create_timer(0.1).timeout
			play_button_pressed = false
			return
		
		PlayerFinish.emit(select_cards)
		play_sound(2)
	else:
		Players[0].cancel_select()
		play_sound(3)
	
	await get_tree().create_timer(0.1).timeout

func _on_deck_manager_deliver_card_to(order: int, card: Variant) -> void:
	print(order, card)
	if DeckManager.GameMode == 2:
		for i in range(player_count):
			if Players[i].order == order:
				add_card_to(card, i)
				break
