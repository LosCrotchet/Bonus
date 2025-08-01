extends Node

var single = ["单张"]
var double = ["对子"]
var triple = ["三条", "顺子"]
var quadruple = ["四条", "顺子", "三带一", "二连对"]
var quintuple = ["五条", "顺子", "四带一", "三带二"]
var sextuple = ["六条", "顺子", "五带一", "四带二", "三带三", "三连对"]

func cmp(a, b):
	return a.x < b.x

func what_type(cards):
	var card_proc = []
	for item in cards:
		card_proc.append(Vector2i((item.x+12)%13, item.y))
	card_proc.sort_custom(cmp)
	
	if len(cards) == 1:
		return single[0]
	if len(cards) == 2:
		if card_proc[0].x == card_proc[1].x:
			return double[0]
	if len(cards) == 3:
		if card_proc[0].x == card_proc[2].x:
			return triple[0]
		if card_proc[0].x == card_proc[1].x-1 and card_proc[1].x == card_proc[2].x-1:
			return triple[1]
		return null
	if len(cards) == 4:
		if card_proc[0].x == card_proc[3].x:
			return quadruple[0]
		if card_proc[0].x == card_proc[1].x-1 and card_proc[1].x == card_proc[2].x-1 and card_proc[2].x == card_proc[3].x-1:
			return quadruple[1]
		if card_proc[0].x == card_proc[2].x or card_proc[1].x == card_proc[3].x:
			return quadruple[2]
		if card_proc[0].x == card_proc[1].x and card_proc[2].x == card_proc[3].x and card_proc[1].x == card_proc[2].x-1:
			return quadruple[3]
		return null
	if len(cards) == 5:
		if card_proc[0].x == card_proc[4].x:
			return quintuple[0]
		if card_proc[0].x == card_proc[1].x-1 and card_proc[1].x == card_proc[2].x-1 and\
		   card_proc[2].x == card_proc[3].x-1 and card_proc[3].x == card_proc[4].x-1:
			return quintuple[1]
		if card_proc[0].x == card_proc[3].x or card_proc[1].x == card_proc[4].x:
			return quintuple[2]
		if (card_proc[0].x == card_proc[2].x and card_proc[3].x == card_proc[4].x) or\
		   (card_proc[2].x == card_proc[4].x and card_proc[0].x == card_proc[1].x):
			return quintuple[3]
		return null
	if len(cards) == 6:
		if card_proc[0].x == card_proc[5].x:
			return sextuple[0]
		if card_proc[0].x == card_proc[1].x-1 and card_proc[1].x == card_proc[2].x-1 and\
		   card_proc[2].x == card_proc[3].x-1 and card_proc[3].x == card_proc[4].x-1 and card_proc[4].x == card_proc[5].x-1:
			return sextuple[1]
		if card_proc[0].x == card_proc[4].x or card_proc[1].x == card_proc[5].x:
			return sextuple[2]
		if card_proc[0].x == card_proc[3].x or card_proc[1].x == card_proc[4].x or card_proc[2].x == card_proc[5].x:
			return sextuple[3]
		if card_proc[0].x == card_proc[2].x and card_proc[3].x == card_proc[5].x:
			return sextuple[4]
		if card_proc[0].x == card_proc[1].x and card_proc[2].x == card_proc[3].x and\
		   card_proc[4].x == card_proc[5].x and card_proc[0].x == card_proc[5].x-2:
			return sextuple[5]
		return null
