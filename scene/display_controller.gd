extends Node

@export var player_hand = []
@export var player_played = []
@export var GameController:Node
@export var Display:Node
@export var CardDealer:Node

var CardCount:Node
var CardPlayType:Node
var OwnerIndicate:Node
var DiceDisplay:Node

func init():
	DiceDisplay = Display.get_child(0)
	OwnerIndicate = Display.get_child(1)
	CardCount = Display.get_child(2)
	CardPlayType = Display.get_child(3)

func update_position(id):
	var children = player_hand[id].get_children()
	var orders = GameController.get_player_hand(id)
	var card_count = len(children)
	var gap = 1750 / (card_count + 25)
	for i in range(card_count):
		children[i].position.x = (-0.5*(card_count-1)+i)*gap
		children[i].face_position = orders[i]
	
	children = player_played[id].get_children()
	#orders = GameController.get_player_hand(id)
	card_count = len(children)-1
	gap = 1750 / (card_count + 25)
	for i in range(1, card_count+1):
		children[i].position.x = (-0.5*(card_count-1)+i)*gap
		#children[i].face_position = orders[i]

func _process(delta):
	var children = player_hand[0].get_children()
	var card_count = len(children)
	var select_num = 0

	for i in range(card_count):
		if children[i].is_selected:
			select_num += 1
	
	# 手牌数量/牌堆数量文本
	var deck_len = len(GameController.get_deck())
	CardCount.text = str(card_count) + " / " + str(deck_len)
	
	# 牌型提示文本
	if select_num > 0:
		var select_cards = []
		for item in player_hand[0].get_children():
			if item.is_selected:
				select_cards.append(item.face_position)
		var result = CardDealer.what_type(select_cards)
		if result:
			CardPlayType.text = result
		else:
			CardPlayType.text = ""
	else:
		CardPlayType.text = ""
	
	var now_whos_turn = GameController.get_game_statue()[0]
	if now_whos_turn == 0:
		OwnerIndicate.position = Vector2(-150, -10)
	if now_whos_turn == 1:
		OwnerIndicate.position = Vector2(-150, -560)
	
	if GameController.get_game_statue()[1] == "PASS":
		player_played[(GameController.get_game_statue()[0]+1)%2].get_child(0).visible = true
	else:
		player_played[(GameController.get_game_statue()[0]+1)%2].get_child(0).visible = false
