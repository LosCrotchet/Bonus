extends Control

class_name Player

enum LOCATION {
	UP, DOWN, LEFT, RIGHT
}
@export var location:LOCATION = LOCATION.DOWN
@export var select_enable:bool = false
@export var player_name:String
@export var order:int
@export var is_player:bool
@export var wait_time:float = 3
@export var avatar_num:int = 0
@export var avatar:CompressedTexture2D

@onready var CARD = preload("res://game/entities/card/card.tscn")

@onready var card_1 = preload("res://assets/sound/card1.ogg")
@onready var card_fan_2 = preload("res://assets/sound/cardFan2.ogg")
@onready var card_3 = preload("res://assets/sound/card3.ogg")
@onready var card_slide_1 = preload("res://assets/sound/cardSlide1.ogg")
@onready var card_slide_2 = preload("res://assets/sound/cardSlide2.ogg")

@onready var avatars = [preload("res://assets/icon/avatar_default_1.png"),
						preload("res://assets/icon/avatar_default_2.png"),
						preload("res://assets/icon/avatar_default_3.png"),
						preload("res://assets/icon/avatar_default_4.png")]

@onready var ring_shader = preload("res://game/entities/player/assets/player_border.gdshader")

var hand = []
var is_selecting = false
var last_select = -1

@onready var play_timer = $PlayTimer

func init():
	if avatar_num != -1:
		$Info/Avatar.texture = avatars[avatar_num]
	elif avatar != null:
		$Info/Avatar.texture = avatar
	$Info/Name.text = player_name
	$Info.visible = true
	$Info/Hint.modulate = Color(255, 255, 255, 0)
	$Info/Avatar.modulate = Color(1, 1, 1, 1)
	$Info/DisconnectIcon.visible = false
	$Info/Emoji.visible = false
	
	hand = []
	var children = $HandArea.get_children()
	for item in children:
		$HandArea.remove_child(item)
		item.queue_free()
	clean_the_discard()
	
	is_selecting = false
	last_select = -1
	$DiscardArea.scale = Vector2(0.8, 0.8)
	match location:
		LOCATION.UP:
			#$HandArea.rotation = deg_to_rad(0)
			#$HandArea.position = Vector2(-80, 0)
			$Info.position = Vector2(100, -20)
			$DiscardArea.position = Vector2(130, 70)
			#$DiscardArea.scale = Vector2(0.8, 0.8)
			#$HandArea.scale = Vector2(0.8, 0.8)
			$HandArea.visible = false
		LOCATION.DOWN:
			$HandArea.rotation = deg_to_rad(0)
			$Info.position = Vector2(0, 0)
			$HandArea.position = Vector2(450, 120)
			$DiscardArea.position = Vector2(540, -130)
			$HandArea.visible = true
		LOCATION.LEFT:
			$Info.position = Vector2(0, 0)
			#$HandArea.rotation = deg_to_rad(90)
			#$HandArea.scale = Vector2(0.8, 0.8)
			$DiscardArea.position = Vector2(100, 120)
			#$DiscardArea.scale = Vector2(0.8, 0.8)
			$HandArea.visible = false
		LOCATION.RIGHT:
			$Info.position = Vector2(0, 0)
			#$HandArea.rotation = deg_to_rad(-90)
			#$HandArea.scale = Vector2(0.8, 0.8)
			$DiscardArea.position = Vector2(-200, 120)
			#$DiscardArea.scale = Vector2(0.8, 0.8)
			$HandArea.visible = false

func comp(a, b):
	# b 比 a 大返回true
	var pa = 4*13 + a.x
	var pb = 4*13 + b.x
	if a.y != 0:
		pa = 4 * (a.y-1) + a.x
	if b.y != 0:
		pb = 4 * (b.y-1) + b.x
	return pa < pb

func update_x_position():
	var children = $HandArea.get_children()
	var card_count = len(children)
	var gap = 2100 / (card_count + 20)
	var _tween = get_tree().create_tween().set_parallel(true)
	for i in range(card_count):
		_tween.tween_property(children[i], "position:x", (-0.5*(card_count-1)+i)*gap, 0.1)

func add_card(card:Vector2i, time:float = DeckManager.WAIT_TIME):
	var children = $HandArea.get_children()
	var card_count = len(children)

	var new_card = CARD.instantiate()
	new_card.suit = card.x
	new_card.rank = card.y
	new_card.set_enable(select_enable)
	var index
	
	if card_count == 0:
		$HandArea.add_child(new_card)
		hand.append(card)
		index = 0
	else:
		var is_last = true
		for i in range(card_count):
			if comp(card, hand[i]):
				hand.insert(i, card)
				$HandArea.add_child(new_card)
				$HandArea.move_child(new_card, i)
				index = i
				is_last = false
				break
		if is_last:
			hand.append(card)
			$HandArea.add_child(new_card)
			#$HandArea.move_child(new_card, card_count)
			index = card_count
	
	$Info/RestDisplay.text = str(len(hand))
	if location != LOCATION.DOWN:
		return
	
	children = $HandArea.get_children()
	card_count = len(children)
	var gap = 2100 / (card_count + 20)
	for i in range(card_count):
		#if i == index:
		#	children[i].position.x = 0
		#	continue
		children[i].position.x = (-0.5*(card_count-1)+i)*gap
	children[index].position.y = -500
	children[index].scale = Vector2(0.01, 0.01)
	children[index].modulate = Color(1, 1, 1, 0)
	
	var insert_tween = get_tree().create_tween().set_parallel(true)
	insert_tween.tween_property(children[index], "position:y", 0, time)
	#insert_tween.tween_property(children[index], "position:x", (-0.5*(card_count-1)+index)*gap, time)
	insert_tween.tween_property(children[index], "scale", Vector2(0.3, 0.3), time)
	insert_tween.tween_property(children[index], "modulate", Color(1, 1, 1, 1), time / 2)

func play_the_card(index:int):
	var children = $HandArea.get_children()
	hand.pop_at(index)
	$HandArea.remove_child(children[index])
	children[index].set_enable(false)
	$DiscardArea.add_child(children[index])
	$DiscardArea.move_child(children[index], 2)
	$Info/RestDisplay.text = str(len(hand))
	
	children = $HandArea.get_children()
	var card_count = len(children)
	var gap = 2100 / (card_count + 20)
	
	for i in range(card_count):
		children[i].position.x = (-0.5*(card_count-1)+i)*gap
	
	children = $DiscardArea.get_children()
	card_count = len(children)
	gap = 1900 / (card_count + 25)
	for i in range(2, card_count):
		children[i].position.x = (-0.5*(card_count-3)+i-2)*gap

func cancel_select():
	if select_enable:
		var children = $HandArea.get_children()
		var card_count = len(children)
		for i in range(card_count):
			children[i].force_cancel()

func clean_the_discard():
	var children = $DiscardArea.get_children()
	var card_count = len(children)
	if card_count == 2:
		# 只有Pass label
		return
	for i in range(card_count-1, 1, -1):
		var now_child = $DiscardArea.get_child(i)
		$DiscardArea.remove_child(now_child)
		now_child.queue_free()

func show_pass_label(flag:bool):
	$DiscardArea/PassLabel.visible = flag

func show_info(flag:bool):
	$Info.visible = flag

func set_timer(statue:int):
	if statue == 1:
		$DiscardArea/TimeLeft.visible = true
		$PlayTimer.start(wait_time)
	if statue == 0:
		$DiscardArea/TimeLeft.visible = false
		$PlayTimer.stop()

func set_ring(mode:int):
	match mode:
		0:
			#$Info/ColorRect.color = Color("00000098")
			$Info/Ring.visible = false
		1:
			#$Info/ColorRect.color = Color("2B457898")
			$Info/Ring.visible = true
			$Info/Ring.material.set_shader_parameter("color", Color("DFDFDF"))
		2:
			#$Info/ColorRect.color = Color("CCBC2498")
			$Info/Ring.visible = true
			$Info/Ring.material.set_shader_parameter("color", Color("CCBC24"))

func set_emoji(statue:int):
	match statue:
		1:
			$Info/Emoji.text = "🤔"
		2:
			$Info/Emoji.text = "😃"
		3:
			$Info/Emoji.text = "😎"
		4:
			$Info/Emoji.text = "😡"
		5:
			$Info/Emoji.text = "😭"
		6:
			$Info/Emoji.text = "🤨"
		7:
			$Info/Emoji.text = "😋"
		98:
			$Info/Emoji.text = "❌"
			$Info/Emoji.visible = true
		99:
			$Info/Emoji.text = "✔️"
			$Info/Emoji.visible = true

func get_select_cards():
	var result = []
	var children = $HandArea.get_children()
	var card_count = len(children)
	for i in range(card_count):
		if children[i].is_selected:
			result.append(Vector2i(children[i].suit, children[i].rank))
	return result

func select(id:int, flag:bool):
	var children = $HandArea.get_children()
	if flag:
		children[id].force_select()
	else:
		children[id].force_cancel()

func flip_over():
	var children = $HandArea.get_children()
	for item in children:
		item.is_folded = false

func show_hint(num:int):
	var now_hint = int($Info/Hint.text)
	$Info/Hint.modulate = Color(1, 1, 1, 1)
	$Info/Hint.position = Vector2(100, -4)
	$Info/Hint.text = str(num)
	if num > 0:
		$Info/Hint.text = "+" + str(num)
	var hint_tween = get_tree().create_tween().set_trans(Tween.TRANS_QUINT).set_parallel(true)

	hint_tween.tween_property($Info/Hint, "modulate", Color(1, 1, 1, 0), 1).set_delay(2)
	

func _process(delta):
	if not $PlayTimer.is_stopped():
		$DiscardArea/TimeLeft.text = str(int($PlayTimer.time_left)+1)
	
	var children = $HandArea.get_children()
	var card_count = len(children)
	for i in range(card_count):
		children[i].is_drag_select = is_selecting

func _input(event):
	if event.is_action_pressed("select"):
		is_selecting = true
	if event.is_action_released("select"):
		is_selecting = false
	if event.is_action_released("cancel_select"):
		cancel_select()

func deal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus):
	var attempt = []
	if now_whos_dice == now_whos_turn and len(played_cards) == 0:
		# Deal as Owner
		if is_bonus:
			for j in range(6, 0, -1):
				for i in range(0, 6):
					var try = DeckManager.find_type(hand, j, i)
					for item in try:
						if item == [null]:
							continue
						attempt.append(item)
		else:
			for i in range(0, 6):
				var try = DeckManager.find_type(hand, dice_result, i)
				for item in try:
					if item == [null]:
						continue
					attempt.append(item)
				attempt.append([null])
	else:
		if len(played_cards) == 0:
			if randi_range(1, 7) == 1:
				# 有概率在无人出牌时出牌
				for i in range(0, 6):
					var try = DeckManager.find_type(hand, dice_result, i)
					for item in try:
						if item == [null]:
							continue
						attempt.append(item)
			else:
				attempt.append([null])
		else:
			if is_bonus:
				dice_result = len(played_cards)
			var try = DeckManager.find_type(hand, dice_result, -1, played_cards)
			for item in try:
				if item == [null]:
					continue
				attempt.append(item)
	#print(attempt)
	if len(attempt) > 0:
		var choice = randf_range(1.01, exp(1)**len(attempt)-0.01)
		choice = len(attempt) - floor(log(choice)) - 1
		return attempt[choice]
	return [null]

func disconnect_display():
	$Info/Avatar.modulate = Color(1, 1, 1, 0.2)
	$Info/DisconnectIcon.visible = true
