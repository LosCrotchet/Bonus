extends Node

@export var GameController:Node
@export var RivalID:int

var hand = []
var now_dice = -1
var now_card_played = []
var run_owner = 0

signal RunFinished

#[card_play_statue, card_play_type, run_owner, run_statue, dice_result, now_card_played]
func run():
	if GameController.get_game_statue()[0] != RivalID:
		return
	hand = GameController.get_player_hand(RivalID)
	now_card_played = GameController.get_game_statue()[5]
	now_dice = GameController.get_game_statue()[4]
	run_owner = GameController.get_game_statue()[2]
	var result
	if run_owner == RivalID:
		result = deal_as_owner()
	else:
		result = deal_as_follower()
	
	if result == false:
		GameController.now_whos_turn = 0
		

# false as pass
func deal_as_owner():
	return false

func deal_as_follower():
	return false
	
