extends Control

class_name Player

enum LOCATION {
	UP, DOWN, LEFT, RIGHT
}
@export var location:LOCATION = LOCATION.DOWN
@export var select_enable:bool = false
@export var player_name:String

@onready var card_1 = preload("res://assets/sound/card1.ogg")
@onready var card_fan_2 = preload("res://assets/sound/cardFan2.ogg")
@onready var card_3 = preload("res://assets/sound/card3.ogg")
@onready var card_slide_1 = preload("res://assets/sound/cardSlide1.ogg")
@onready var card_slide_2 = preload("res://assets/sound/cardSlide2.ogg")

@onready var avatars = [preload("res://assets/avatar_default_1.png"),
						preload("res://assets/avatar_default_2.png"),
						preload("res://assets/avatar_default_3.png"),
						preload("res://assets/avatar_default_4.png")]

var hand = []
var is_selecting = false
var last_select = -1

func init():
	$Info/Avatar.texture = avatars[randi_range(0, 3)]
	$Info/Name.text = player_name
	$Info.visible = true
	$Info/Hint.modulate = Color(255, 255, 255, 0)
	
	hand = []
	var children = $HandArea.get_children()
	for item in children:
		$HandArea.remove_child(item)
		item.queue_free()
	clean_the_discard()
	
	is_selecting = false
	last_select = -1
	$DiscardArea.scale = Vector2(0.7, 0.7)
	match location:
		LOCATION.UP:
			$HandArea.rotation = deg_to_rad(0)
			$HandArea.position = Vector2(-80, 0)
			$Info.position = Vector2(400, 0)
			$DiscardArea.position = Vector2(100, 160)
			$HandArea.scale = Vector2(0.8, 0.8)
		LOCATION.DOWN:
			$HandArea.rotation = deg_to_rad(0)
			$Info.position = Vector2(-600, 0)
			$HandArea.position = Vector2(90, 0)
			$DiscardArea.position = Vector2(0, -270)
		LOCATION.LEFT:
			$Info.position = Vector2(180, -270)
			$HandArea.rotation = deg_to_rad(90)
			$HandArea.scale = Vector2(0.8, 0.8)
			$DiscardArea.position = Vector2(250, -90)
		LOCATION.RIGHT:
			$Info.position = Vector2(-300, 110)
			$HandArea.rotation = deg_to_rad(-90)
			$HandArea.scale = Vector2(0.8, 0.8)
			$DiscardArea.position = Vector2(-280, -20)

func comp(a, b):
	var pa = 4*13 + a.x
	var pb = 4*13 + b.x
	if a.y != 0:
		pa = 4 * (a.y-1) + a.x
	if b.y != 0:
		pb = 4 * (b.y-1) + b.x
	return pa < pb

func play_sound():
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = [card_slide_1, card_slide_2][randi_range(0, 1)]
	audio_player.play()
	await audio_player.finished
	remove_child(audio_player)

func update_x_position():
	var children = $HandArea.get_children()
	hand.sort_custom(comp)
	var card_count = len(children)
	var gap = 1550 / (card_count + 20)
	for i in range(card_count):
		children[i].position.x = (-0.5*(card_count-1)+i)*gap
		children[i].suit = hand[i].x
		children[i].rank = hand[i].y
	
	children = $DiscardArea.get_children()
	#orders = GameController.get_player_hand(id)
	card_count = len(children)-1
	gap = 1750 / (card_count + 25)
	for i in range(0, card_count):
		children[i+1].position.x = (-0.5*(card_count-1)+i)*gap
		#children[i].face_position = orders[i]
	
	$Info/Rest.text = "余 " + str(len(hand)) + " 张"

func update_y_position():
	var mouse_position = get_global_mouse_position()
	var children = $HandArea.get_children()
	var card_count = len(children)
	for i in range(card_count):
		if i == last_select:
			continue
		var now_position = children[i].position + position + $HandArea.position
		if i != card_count - 1:
			var next_position = children[i+1].position + position + $HandArea.position
			if mouse_position.x >= now_position.x - 70 and mouse_position.x <= next_position.x - 72 and\
			   mouse_position.y <= now_position.y + 95 and mouse_position.y >= now_position.y - 95:
				if children[i].is_selected:
					children[i].position.y = 0
				else:
					children[i].position.y = -30
				children[i].is_selected = not children[i].is_selected
				last_select = i
				play_sound()
		else:
			if mouse_position.x >= now_position.x - 70 and mouse_position.x <= now_position.x + 71 and\
			   mouse_position.y <= now_position.y + 95 and mouse_position.y >= now_position.y - 95:
				if children[i].is_selected:
					children[i].position.y = 0
				else:
					children[i].position.y = -30
				children[i].is_selected = not children[i].is_selected
				last_select = i
				play_sound()

func cancel_select():
	if select_enable:
		var children = $HandArea.get_children()
		var card_count = len(children)
		for i in range(card_count):
			children[i].position.y = 0
			children[i].is_selected = false
		last_select = -1

func clean_the_discard():
	var children = $DiscardArea.get_children()
	var card_count = len(children)
	for i in range(card_count-1, 0, -1):
		var now_child = $DiscardArea.get_child(i)
		$DiscardArea.remove_child(now_child)
		now_child.queue_free()

func show_pass_label(flag:bool):
	$DiscardArea/PassLabel.visible = flag

func show_info(flag:bool):
	$Info.visible = flag

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

func get_select_cards():
	var result = []
	var children = $HandArea.get_children()
	var card_count = len(children)
	for i in range(card_count):
		if children[i].is_selected:
			result.append(Vector2i(children[i].suit, children[i].rank))
	return result

func play_the_select():
	var discard_length = $DiscardArea.get_child_count()
	for i in range(discard_length-1, 0, -1):
		var now_child = $DiscardArea.get_child(i)
		$DiscardArea.remove_child(now_child)
		now_child.queue_free()
	
	var children = $HandArea.get_children()
	var card_count = len(children)
	var discard_add = []
	for i in range(card_count-1, -1, -1):
		if children[i].is_selected:
			var the_child = $HandArea.get_child(i)
			$HandArea.remove_child(the_child)
			hand.pop_at(i)
			discard_add.append(the_child)
	
	discard_add.reverse()
	for item in discard_add:
		item.is_folded = false
		$DiscardArea.add_child(item)

func select(id:int, flag:bool):
	var children = $HandArea.get_children()
	children[id].is_selected = flag

func flip_over():
	var children = $HandArea.get_children()
	for item in children:
		item.is_folded = false

func show_hint(num:int):
	var now_hint = int($Info/Hint.text)
	$Info/Hint.modulate = Color(1, 1, 1, 0)
	$Info/Hint.position = Vector2(170, -20)
	$Info/Hint.text = str(num)
	if num > 0:
		$Info/Hint.text = "+" + str(num)
	var hint_tween = get_tree().create_tween().set_trans(Tween.TRANS_QUINT).set_parallel(true)
	
	hint_tween.tween_property($Info/Hint, "modulate", Color(1, 1, 1, 1), 1)
	hint_tween.tween_property($Info/Hint, "position", Vector2(170, -4), 1)
	
	await get_tree().create_timer(1).timeout
	hint_tween.stop()
	hint_tween.tween_property($Info/Hint, "modulate", Color(1, 1, 1, 0), 2)
	hint_tween.play()
	

func _process(delta):
	if select_enable and is_selecting:
		update_y_position()
	

func _input(event):
	if event.is_action_pressed("select"):
		last_select = -1
		is_selecting = true
	if event.is_action_released("select"):
		is_selecting = false
		last_select = -1
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
			if randi_range(1, 10) % 2 == 0:
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
	print(attempt)
	if len(attempt) > 0:
		var choice = randf_range(1.01, exp(1)**len(attempt)-0.01)
		choice = len(attempt) - floor(log(choice)) - 1
		return attempt[choice]
	return [null]
