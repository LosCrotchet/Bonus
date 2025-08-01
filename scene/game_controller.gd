extends Node

var card_deck = []
var players_number = 2
var players_hand = []

var card_play_type = ""		# 所出牌型，在card_play_statue为1时有效
var run_owner = 0		# 此轮出牌的发起者
var run_statue = 0		# 0：投骰子；1：出牌与盖牌
var now_whos_turn = 0
var dice_result = 0
var now_card_played = []

func _ready():
	for i in range(4):	# Number of suits
		for j in range(13):	#Number of nums
			card_deck.append(Vector2i(j, i))
			card_deck.append(Vector2i(j, i))
	card_deck.shuffle()
	
	for i in range(players_number):
		players_hand.append([])

func init(start_player:int = 0):
	card_play_type = ""		# 所出牌型，在card_play_statue为1时有效
	run_owner = start_player		# 此轮出牌的发起者
	run_statue = -1		# 0：投骰子；1：出牌与盖牌

func comp(a, b):
	a.x = (a.x+12) % 13
	b.x = (b.x+12) % 13
	a.y = [2, 0, 1, 3][a.y]
	b.y = [2, 0, 1, 3][b.y]
	return a.x < b.x or (a.x == b.x and a.y < b.y)

func able_to_dice():
	if run_statue == 0:
		run_statue = 1
		dice_result = randi_range(1, 6)
		return dice_result
	return false

func get_cards(num, id:int = 0):
	var cards = []
	for i in range(num):
		if len(card_deck) == 0:
			break
		cards.append(card_deck.pop_back())
		players_hand[id].append(cards[-1])
		players_hand[id].sort_custom(comp)
	return cards

func get_game_statue():
	return [now_whos_turn, card_play_type, run_owner, run_statue, dice_result, now_card_played]

func play_cards(lst, id:int = 0):
	for item in lst:
		players_hand[id].pop_at(players_hand[id].find(item))
	now_card_played = lst

func get_player_hand(id):
	return players_hand[id]

func get_deck():
	return card_deck
