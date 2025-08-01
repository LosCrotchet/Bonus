extends Node

var player_count = 2

var deck = []
var discard_deck = []
var all_type = []

var joker_result = []

func init():
	discard_deck.clear()
	all_type.clear()
	deck.clear()
	joker_result.clear()
	for rank in range(1, 14):
		for suit in range(4):
			all_type.append(Vector2i(suit, rank))
			for i in range(2):
				deck.append(Vector2i(suit, rank))
	#all_type.append(Vector2i(0, 0))
	#all_type.append(Vector2i(1, 0))
	#for i in range(2):
	#	deck.append(Vector2i(0, 0))
	#	deck.append(Vector2i(1, 0))
	#print(len(deck), deck)
	
	deck.shuffle()

func _ready():
	init()

func get_card():
	if len(deck) == 0:
		discard_deck.shuffle()
		deck = discard_deck.duplicate()
		discard_deck.clear()
	return deck.pop_back()

func discard(card:Vector2i):
	discard_deck.append(card)

func comp(a, b):
	var pa = 4*13 + a.x
	var pb = 4*13 + b.x
	if a.y != 0:
		pa = 4 * (a.y-1) + a.x
	if b.y != 0:
		pb = 4 * (b.y-1) + b.x
	return pa < pb

func what_type_without_joker(cards):
	if len(cards) == 1:
		return 0
	if len(cards) == 2:
		if cards[0].y == cards[1].y:
			return 0
	if len(cards) == 3:
		if cards[0].y == cards[2].y:
			return 0
		if cards[0].y == cards[1].y-1 and cards[1].y == cards[2].y-1 and cards[2].y != 13:
			return 1
	if len(cards) == 4:
		if cards[0].y == cards[3].y:
			return 0
		if cards[0].y == cards[1].y-1 and cards[1].y == cards[2].y-1 and\
		   cards[2].y == cards[3].y-1 and cards[3].y != 13:
			return 1
		if cards[0].y == cards[2].y or cards[1].y == cards[3].y:
			return 2
		if cards[0].y == cards[1].y and cards[2].y == cards[3].y and\
		   cards[1].y == cards[2].y-1 and cards[3].y != 13:
			return 3
	if len(cards) == 5:
		if cards[0].y == cards[4].y:
			return 0
		if cards[0].y == cards[1].y-1 and cards[1].y == cards[2].y-1 and\
		   cards[2].y == cards[3].y-1 and cards[3].y == cards[4].y-1 and cards[4].y != 13:
			return 1
		if cards[0].y == cards[3].y or cards[1].y == cards[4].y:
			return 2
		if (cards[0].y == cards[2].y and cards[3].y == cards[4].y) or\
		   (cards[2].y == cards[4].y and cards[0].y == cards[1].y):
			return 3
	if len(cards) == 6:
		if cards[0].y == cards[5].y:
			return 0
		if cards[0].y == cards[1].y-1 and cards[1].y == cards[2].y-1 and\
		   cards[2].y == cards[3].y-1 and cards[3].y == cards[4].y-1 and\
		   cards[4].y == cards[5].y-1 and cards[5].y != 13:
			return 1
		if cards[0].y == cards[4].y or cards[1].y == cards[5].y:
			return 2
		if cards[0].y == cards[3].y or cards[1].y == cards[4].y or cards[2].y == cards[5].y:
			return 3
		if cards[0].y == cards[2].y and cards[3].y == cards[5].y:
			return 4
		if cards[0].y == cards[1].y and cards[2].y == cards[3].y and\
		   cards[4].y == cards[5].y and cards[0].y == cards[5].y-2 and cards[5].y != 13:
			return 5
	return null

func type_comp(cardsA, cardsB, typeA, typeB):
	var numA = []
	var numB = []
	for item in cardsA:
		numA.append(item.y)
	for item in cardsB:
		numB.append(item.y)
	
	if len(cardsA) == 1:
		if typeA == 0:
			return cardsA[0].y > cardsB[0].y
	if len(cardsA) == 2:
		if typeA == 0:
			return cardsA[0].y > cardsB[0].y
	if len(cardsA) == 3:
		if typeA == 0:
			return cardsA[0].y > cardsB[0].y
		if typeA == 1:
			return cardsA[0].y > cardsB[0].y
	if len(cardsA) == 4:
		if typeA == 0 and typeB != 0:
			return true
		if typeB == 0 and typeA != 0:
			return false
		
		if typeA == 0:
			return cardsA[0].y > cardsB[0].y
		if typeA == 1:
			return cardsA[0].y > cardsB[0].y
		if typeA == 2:
			if numA.find(cardsA[0].y, 1) == -1:
				if numB.find(cardsB[0].y, 1) == -1:
					return cardsA[1].y > cardsB[1].y
				return cardsA[1].y > cardsB[0].y
			if numB.find(cardsB[0].y, 1) == -1:
				return cardsA[0].y > cardsB[1].y
			return cardsA[0].y > cardsB[0].y
		if typeA == 3:
			return cardsA[0].y > cardsB[0].y
	if len(cardsA) == 5:
		if typeA == 0 and typeB != 0:
			return true
		if typeB == 0 and typeA != 0:
			return false
		
		if typeA == 0:
			return cardsA[0].y > cardsB[0].y
		if typeA == 1:
			return cardsA[0].y > cardsB[0].y
		if typeA == 2:
			if numA.find(cardsA[0].y, 1) == -1:
				if numB.find(cardsB[0].y, 1) == -1:
					return cardsA[1].y > cardsB[1].y
				return cardsA[1].y > cardsB[0].y
			if numB.find(cardsB[0].y, 1) == -1:
				return cardsA[0].y > cardsB[1].y
			return cardsA[0].y > cardsB[0].y
		if typeA == 3:
			if numA.find(cardsA[1].y, 2) == -1:
				if numB.find(cardsB[1].y, 2) == -1:
					return cardsA[2].y > cardsB[2].y
				return cardsA[2].y > cardsB[0].y
			if numB.find(cardsB[1].y, 2) == -1:
				return cardsA[0].y > cardsB[2].y
			return cardsA[0].y > cardsB[0].y
	if len(cardsA) == 6:
		if typeA == 0 and typeB != 0:
			return true
		if typeB == 0 and typeA != 0:
			return false
		
		if typeA == 0:
			return cardsA[0].y > cardsB[0].y
		if typeA == 1:
			return cardsA[0].y > cardsB[0].y
		if typeA == 2:
			if numA.find(cardsA[0].y, 1) == -1:
				if numB.find(cardsB[0].y, 1) == -1:
					return cardsA[1].y > cardsB[1].y
				return cardsA[1].y > cardsB[0].y
			if numB.find(cardsB[0].y, 1) == -1:
				return cardsA[0].y > cardsB[1].y
			return cardsA[0].y > cardsB[0].y
		if typeA == 3:
			var nA = -1
			var nB = -1
			for i in range(len(cardsA)-3):
				if cardsA[i].y == cardsA[i+3].y:
					nA = cardsA[i].y
					break
			for i in range(len(cardsB)-3):
				if cardsB[i].y == cardsB[i+3].y:
					nB = cardsB[i].y
					break
			return nA > nB
		if typeA == 4:
			return cardsA[3].y > cardsB[3].y
		if typeA == 5:
			return cardsA[0].y > cardsB[0].y
	return false

# TODO: 之后可以用打表改进这个JOKER的轮询
func generate_joker_series(joker_num, cards, begin):
	var tmp_cards = cards.duplicate()
	if joker_num == 0:
		tmp_cards.sort_custom(comp)
		var tmp_result = what_type_without_joker(tmp_cards)
		if tmp_result != null and tmp_result not in joker_result:
			joker_result.append(tmp_result)
		return
		
	for i in range(begin, len(all_type)):
		tmp_cards.append(all_type[i])
		generate_joker_series(joker_num-1, tmp_cards, i)
		tmp_cards.pop_back()

func what_type(N_cards):
	# cards是一个包含Vector2i的Array
	var cards = N_cards.duplicate()
	cards.sort_custom(comp)
	#for i in range(len(cards)):
	#	if cards[i].y == 1 or cards[i].y == 2:
	#		cards[i].y += 13
	
	if Vector2i(0, 0) in cards or Vector2i(1, 0) in cards:
		# 有万能牌
		var result = []
		var joker_num = 0
		var new_cards = []
		
		for i in range(len(cards)):
			if cards[i].y != 0:
				new_cards.append(cards[i])
			else:
				joker_num += 1
		
		var tmp_cards = new_cards.duplicate()
		joker_result = []
		generate_joker_series(joker_num, tmp_cards, 0)
		return joker_result
	else:
		return [what_type_without_joker(cards)]
	
func whos_greater(cardsA, cardsB):
	var typeA = what_type(cardsA)
	var typeB = what_type(cardsB)
	
	if typeA != [null] and typeB != [null] and\
	   (typeA[0] == typeB[0] or (len(cardsA) > 3 and len(cardsB) > 3 and (typeA[0] == 0 or typeB[0] == 0))):
		return type_comp(cardsA, cardsB, typeA[0], typeB[0])
	return false

func find_type(hands, dice_result, type_to_find:int = -1, last_played:Array = []):
	if last_played != [] and type_to_find == -1:
		type_to_find = what_type(last_played)[0]
	var result = []
	if dice_result == 1:
		if type_to_find == 0:
			for item in hands:
				if len(last_played) == 0 or item.y > last_played[0].y:
					result.append([item])
	if dice_result == 2:
		if type_to_find == 0:
			for i in range(len(hands)-1):
				if hands[i].y == hands[i+1].y and (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1]])
	if dice_result == 3:
		if type_to_find == 0:
			for i in range(len(hands)-2):
				if hands[i].y == hands[i+2].y and (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2]])
		if type_to_find == 1:
			for i in range(len(hands)-2):
				if hands[i].y == hands[i+1].y-1 and hands[i+1].y == hands[i+2].y-1 and\
				   hands[i+2].y != 13 and (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2]])
	if dice_result == 4:
		if type_to_find == 0:
			for i in range(len(hands)-3):
				if hands[i].y == hands[i+3].y and (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2], hands[i+3]])
		if type_to_find == 1:
			for i in range(len(hands)-3):
				if hands[i].y == hands[i+1].y-1 and hands[i+1].y == hands[i+2].y-1 and \
				   hands[i+2].y == hands[i+3].y-1 and hands[i+3].y != 13 and\
				   (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2], hands[i+3]])
		if type_to_find == 2:
			var cmp_flag
			if len(last_played) == 0:
				cmp_flag = -1
			else:
				for i in range(len(last_played)-1):
					if last_played[i].y == last_played[i+1].y:
						cmp_flag = last_played[i].y
						break
			for i in range(len(hands)-2):
				if hands[i].y == hands[i+2].y and hands[i].y > cmp_flag:
					for j in range(len(hands)):
						if j < i:
							result.append([hands[j], hands[i], hands[i+1], hands[i+2]])
						if j > i + 2:
							result.append([hands[i], hands[i+1], hands[i+2], hands[j]])
		if type_to_find == 3:
			for i in range(len(hands)-3):
				if hands[i].y == hands[i+1].y and hands[i+2].y == hands[i+3].y and\
				   hands[i+1].y == hands[i+2].y-1 and hands[i+2].y != 13 and\
				   (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2], hands[i+3]])
	if dice_result == 5:
		if type_to_find == 0:
			for i in range(len(hands)-4):
				if hands[i].y == hands[i+4].y and\
				   (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2], hands[i+3], hands[i+4]])
		if type_to_find == 1:
			for i in range(len(hands)-4):
				if hands[i].y == hands[i+1].y-1 and hands[i+1].y == hands[i+2].y-1 and\
				   hands[i+2].y == hands[i+3].y-1 and hands[i+3].y == hands[i+4].y-1 and\
				   hands[i+4].y != 13 and (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2], hands[i+3], hands[i+4]])
		if type_to_find == 2:
			var cmp_flag
			if len(last_played) == 0:
				cmp_flag = -1
			else:
				for i in range(len(last_played)-1):
					if last_played[i].y == last_played[i+1].y:
						cmp_flag = last_played[i].y
						break
			for i in range(len(hands)-3):
				if hands[i].y == hands[i+3].y and hands[i].y > cmp_flag:
					for j in range(len(hands)):
						if j < i:
							result.append([hands[j], hands[i], hands[i+1], hands[i+2], hands[i+3]])
						if j > i + 3:
							result.append([hands[i], hands[i+1], hands[i+2], hands[i+3], hands[j]])
		if type_to_find == 3:
			var cmp_flag
			if len(last_played) == 0:
				cmp_flag = -1
			else:
				for i in range(len(last_played)-2):
					if last_played[i].y == last_played[i+2].y:
						cmp_flag = last_played[i].y
						break
			for i in range(len(hands)-2):
				if hands[i].y == hands[i+2].y and hands[i].y > cmp_flag:
					for j in range(len(hands)-1):
						if j < i and hands[j].y == hands[j+1].y:
							result.append([hands[j], hands[j+1], hands[i], hands[i+1], hands[i+2]])
						if j > i + 2 and hands[j].y == hands[j+1].y:
							result.append([hands[i], hands[i+1], hands[i+2], hands[j], hands[j+1]])
	if dice_result == 6:
		if type_to_find == 0:
			for i in range(len(hands)-5):
				if hands[i].y == hands[i+5].y and (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2], hands[i+3], hands[i+4], hands[i+5]])
		if type_to_find == 1:
			for i in range(len(hands)-5):
				if hands[i].y == hands[i+1].y-1 and hands[i+1].y == hands[i+2].y-1 and\
				   hands[i+2].y == hands[i+3].y-1 and hands[i+3].y == hands[i+4].y-1 and\
				   hands[i+4].y == hands[i+5].y-1 and hands[i+5].y != 13 and\
				   (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2], hands[i+3], hands[i+4], hands[i+5]])
		if type_to_find == 2:
			var cmp_flag
			if len(last_played) == 0:
				cmp_flag = -1
			else:
				for i in range(len(last_played)-1):
					if last_played[i].y == last_played[i+1].y:
						cmp_flag = last_played[i].y
						break
			for i in range(len(hands)-4):
				if hands[i].y == hands[i+4].y and hands[i].y > cmp_flag:
					for j in range(len(hands)):
						if j < i:
							result.append([hands[j], hands[i], hands[i+1], hands[i+2], hands[i+3], hands[i+4]])
						if j > i + 4:
							result.append([hands[i], hands[i+1], hands[i+2], hands[i+3], hands[i+4], hands[j]])
		if type_to_find == 3:
			var cmp_flag
			if len(last_played) == 0:
				cmp_flag = -1
			else:
				for i in range(len(last_played)-3):
					if last_played[i].y == last_played[i+3].y:
						cmp_flag = last_played[i].y
						break
			for i in range(len(hands)-3):
				if hands[i].y == hands[i+3].y and hands[i].y > cmp_flag:
					for j in range(len(hands)-1):
						if j < i and hands[j].y == hands[j+1].y:
							result.append([hands[j], hands[j+1], hands[i], hands[i+1], hands[i+2], hands[i+3]])
						if j > i + 3 and hands[j].y == hands[j+1].y:
							result.append([hands[i], hands[i+1], hands[i+2], hands[i+3], hands[j], hands[j+1]])
		if type_to_find == 4:
			for i in range(len(hands)-2):
				if hands[i].y == hands[i+2].y and (len(last_played) == 0 or hands[i].y > last_played[3].y):
					for j in range(len(hands)-2):
						if j < i and hands[j].y == hands[j+2].y:
							result.append([hands[j], hands[j+1], hands[j+2], hands[i], hands[i+1], hands[i+2]])
						if j > i + 2 and hands[j].y == hands[j+2].y:
							result.append([hands[i], hands[i+1], hands[i+2], hands[j], hands[j+1], hands[j+2]])
		if type_to_find == 5:
			for i in range(len(hands)-5):
				if hands[i].y == hands[i+1].y and hands[i+2].y == hands[i+3].y and\
				   hands[i+4].y == hands[i+5].y and hands[i].y == hands[i+2].y-1 and\
				   hands[i+3].y == hands[i+4].y-1 and hands[i+5].y != 13 and\
				   (len(last_played) == 0 or hands[i].y > last_played[0].y):
					result.append([hands[i], hands[i+1], hands[i+2], hands[i+3], hands[i+4], hands[i+5]])
	result.append([null])
	return result
	
