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

var have_dealed_result = false

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
signal GameEnd(index:int)
signal GameStart
signal UpdateGameUI(now_whos_turn:int, now_whos_dice:int, dice_result:int, played_cards:Array, last_player:int, is_bonus:bool)

func _ready() -> void:
	DeckManager.deliver_card_to.connect(Callable(self, "_on_deck_manager_deliver_card_to"))
	DeckManager.player_finished.connect(Callable(self, "receive_player_finish"))
	DeckManager.game_end.connect(Callable(self, "receive_game_end"))
	DeckManager.mainscene_ready.connect(Callable(self, "start_to_deal"))
	DeckManager.player_disconnected.connect(_on_player_disconnected)

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
		Players[i].set_ring(0)
		if not Players[i].play_timer.timeout.is_connected(_on_play_timer_timeout):
			Players[i].play_timer.timeout.connect(_on_play_timer_timeout)
		if DeckManager.GameMode != 0:
			# Multigame
			var now_order = (DeckManager.player_order - 1 + i) % player_count + 1
			var is_player = false
			for k in WebController.players.keys():
				if now_order == WebController.players[k]["order"]:
					is_player = true
					Players[i].player_name = WebController.players[k]["name"]
					if WebController.players[k]["avatar"] in [0, 1, 2, 3]:
						Players[i].avatar_num = WebController.players[k]["avatar"]
					else:
						Players[i].avatar_num = -1
						Players[i].avatar = WebController.players[k]["avatar"]
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
	Players[0].position = Vector2(330, 600)
	Players[0].select_enable = true
	Players[0].is_player = true
	#Players[0].player_name = "你"
	match player_count:
		2:
			Players[1].location = LOCATION.UP
			Players[1].position = Vector2(620, 110)
		3:
			Players[2].location = LOCATION.LEFT
			Players[2].position = Vector2(150, 230)
			Players[1].location = LOCATION.UP
			Players[1].position = Vector2(620, 110)
		4:
			Players[3].location = LOCATION.LEFT
			Players[3].position = Vector2(150, 230)
			Players[2].location = LOCATION.UP
			Players[2].position = Vector2(620, 110)
			Players[1].location = LOCATION.RIGHT
			Players[1].position = Vector2(1450, 230)
	for item in Players:
		item.init()
	
	if DeckManager.GameMode == 0:
		start_to_deal()

func start_to_deal():
	for cnt in range(17):
		for i in range(player_count):
			if DeckManager.GameMode != 2:
				var result = DeckManager.get_card()
				#print(DeckManager.deliver_card_to.get_connections())
				DeckManager.deliver_card_to.emit(Players[i].order, result)
				#add_card_to(result, i)
				#Players[i].update_x_position()
				Players[i].add_card(result)
			#await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(0.15).timeout
	
	GameStart.emit()

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

func _on_game_end(index):
	play_sound(4)
	for j in range(player_count):
		Players[j].clean_the_discard()
		Players[j].flip_over()
		Players[j].set_emoji(5)
		Players[j].set_ring(0)
	Players[index].set_emoji(3)
	Players[index].set_ring(2)
	await get_tree().create_timer(3).timeout
	for j in range(player_count):
		Players[j].set_ring(0)
		if not Players[j].is_player or DeckManager.GameMode == 0:
			Players[j].set_emoji(99)
		else:
			Players[j].set_emoji(98)
	if DeckManager.GameMode == 2:
		WebController.get_ready(false)
	else:
		WebController.get_ready(true)

func receive_game_end(order):
	var index = (order - DeckManager.player_order + DeckManager.player_count) % DeckManager.player_count
	GameEnd.emit(index)

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
	
	# 设置提示环
	for i in range(player_count):
		Players[i].set_ring(0)
	if is_bonus:
		Players[now_turn].set_ring(2)
	else:
		Players[now_turn].set_ring(1)
	
	# 判断游戏是否结束
	for i in range(player_count):
		if len(Players[i].hand) == 0:
			if DeckManager.GameMode == 1:
				var order = (i + DeckManager.player_order - 1) % DeckManager.player_count + 1
				WebController.game_end_with.rpc(order)
				GameEnd.emit(i)
			return
	
	# UI更新与投骰子
	if now_whos_turn == now_whos_dice and len(played_cards) == 0 and now_dice_result == -1:
		for i in range(player_count):
			Players[i].show_pass_label(false)
			Players[i].clean_the_discard()
		if not now_bonus:
			Players[now_whos_turn].set_emoji(1)
			PlayerDiceRoll.emit()
			return
		#if now_bonus:
		#	Players[now_whos_turn].set_emoji(7)
	
	# 自动跳过
	if now_dice_result > len(Players[now_whos_turn].hand):
		if DeckManager.GameMode == 1:
			WebController.player_finished.rpc([null])
		if DeckManager.GameMode != 2:
			deal_result([null])
		return

	# 更新玩家UI
	if DeckManager.GameMode != 0:
		Players[now_whos_turn].set_timer(1)
	UpdateGameUI.emit(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus)
	
	# 客户端不参与后续计算
	if DeckManager.GameMode == 2:
		return
	
	await get_tree().create_timer(0.2).timeout
	
	# 电脑玩家计算策略
	var result
	if Players[now_whos_turn].is_player == false:
		result = Players[now_whos_turn].deal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, now_bonus)
	else:
		return
	
	# 电脑计算结果
	# p.s. 一个完整的结束信号应当包含：
	# 一、服务端发送
	if DeckManager.GameMode == 1:
		# rpc出去不包括自己
		WebController.player_finished.rpc(result)
	# 二、本地deal_result
	deal_result(result)
	# 如果是客户端请提交给服务端处理

func deal_result(result):
	print(DeckManager.player_order, " | deal the result: ", result, " (now turn:", now_turn, ")")
	#Players[now_turn].play_timer.timeout.disconnect(Callable(self, "_on_play_timer_timeout"))
	Players[now_turn].set_timer(0)
	if result == [null]:
		#await get_tree().create_timer(1).timeout
		Players[now_turn].clean_the_discard()
		Players[now_turn].show_pass_label(true)
		Players[now_turn].set_emoji(6)
		play_sound(3)
	else:
		var index = len(result) - 1
		for i in range(len(Players[now_turn].hand)-1, -1, -1):
			if Players[now_turn].hand[i] == result[index]:
				#Players[now_turn].select(i, true)
				DeckManager.discard(Players[now_turn].hand[i])
				Players[now_turn].play_the_card(i)
				index -= 1
				if index == -1:
					break
		Players[now_turn].show_hint(-len(result))
		#Players[now_turn].play_the_select()
		#Players[now_turn].update_x_position()
		#Players[now_turn].set_emoji(2)
		play_sound(2)
	
	Players[now_turn].set_ring(0)
	PlayerFinish.emit(result)

# 摸牌的信号
func _on_game_manager_draw_card(id, num):
	Players[id].show_hint(num)
	for i in range(num):
		var result = DeckManager.get_card()
		if DeckManager.GameMode == 1:
			DeckManager.deliver_card_to.emit(Players[id].order, result)
		#add_card_to(result, id)
		Players[id].add_card(result, 0.5)
		play_sound(1)
		#await get_tree().create_timer(0.1)

### 你的按钮事件处理

func _on_play_timer_timeout():
	print(DeckManager.player_order, " | Timer timeout!")
	Players[now_turn].set_timer(0)
	var result = [null]
	if now_bonus and len(last_played_cards) == 0:
		result = [Players[now_turn].hand[0]]
	if now_turn == 0: 
		Players[0].cancel_select()
	#DeckManager.timer_timeout.emit()
	
	if DeckManager.GameMode == 2:
		return
		#WebController.player_finished.rpc_id(1, result)
	elif DeckManager.GameMode == 1:
		WebController.player_finished.rpc(result)
		deal_result(result)
	elif DeckManager.GameMode == 0:
		receive_player_finish(result)

func _on_pass_button_pressed():
	# Pass信号发送在GameManager里
	print(DeckManager.player_order, " | Pass button pressed")
	Players[0].set_timer(0)
	Players[0].cancel_select()
	#Players[0].update_x_position()
	if DeckManager.GameMode == 2:
		WebController.player_finished.rpc_id(1, [null])
	elif DeckManager.GameMode == 1:
		WebController.player_finished.rpc([null])
		deal_result([null])
	elif DeckManager.GameMode == 0:
		deal_result([null])

func _on_play_button_pressed():
	print(DeckManager.player_order, " | PLAY button pressed")
	var select_cards = Players[0].get_select_cards()
	if DeckManager.what_type(select_cards) != [null] and (len(select_cards) == now_dice_result or now_bonus):
		if last_played_cards == [] or DeckManager.whos_greater(select_cards, last_played_cards):
			last_played_cards = select_cards
		else:
			Players[0].cancel_select()
			play_sound(3)
			play_button_pressed = false
			return

		#if DeckManager.GameMode != 2:
		#	deal_result(select_cards)
		
		Players[0].set_timer(0)
		if DeckManager.GameMode == 2:
			WebController.player_finished.rpc_id(1, select_cards)
		elif DeckManager.GameMode == 1:
			WebController.player_finished.rpc(select_cards)
			deal_result(select_cards)
		elif DeckManager.GameMode == 0:
			deal_result(select_cards)
		play_sound(2)
	else:
		Players[0].cancel_select()
		play_sound(3)


func receive_player_finish(action):
	print("[", DeckManager.player_order, "] | Receive acction: ", action)
	if DeckManager.GameMode == 1:
		WebController.player_finished.rpc(action)
	deal_result(action)

func _on_deck_manager_deliver_card_to(order: int, card: Variant) -> void:
	#print(order, card)
	if DeckManager.GameMode == 2:
		for i in range(player_count):
			if Players[i].order == order:
				#add_card_to(card, i)
				Players[i].add_card(card, 0.5)
				break

func _on_hint_button_pressed() -> void:
	var attempt = DeckManager.find_type(Players[0].hand, now_dice_result, -1, last_played_cards)
	if attempt != [null]:
		var choice = attempt[0]
		var index = 0
		Players[0].cancel_select()
		for i in range(len(Players[0].hand)):
			if Players[0].hand[i] == choice[index]:
				Players[0].select(i, true)
				index += 1
			if index == len(choice):
				break
		Players[0].update_y_position()

func _on_player_disconnected(order:int):
	for i in range(player_count):
		if Players[i].order == order:
			Players[i].is_player = false
			Players[i].disconnect_display()
			break
