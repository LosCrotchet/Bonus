extends Node

@export var player_count:int
@export var dealer:int
@export var game_mode:int

var now_whos_turn:int = -1
var now_whos_dice:int = -1
var dice_result:int = -1
var is_bonus:bool = false
var played_cards:Array = []
var last_player:int = -1
var is_anyone_cover:bool = false

var is_passed = false

signal GameSignal(now_whos_turn:int, now_whos_dice:int, dice_result:int, played_cards:Array, last_player:int, is_bonus:bool)
signal DrawCard(id:int, num:int)

@onready var button_sound = preload("res://assets/sound/button.ogg")
@onready var cancel_sound = preload("res://assets/sound/cancel.ogg")
@onready var card_1 = preload("res://assets/sound/card1.ogg")
@onready var card_fan_2 = preload("res://assets/sound/cardFan2.ogg")
@onready var card_3 = preload("res://assets/sound/card3.ogg")
@onready var card_slide_1 = preload("res://assets/sound/cardSlide1.ogg")
@onready var card_slide_2 = preload("res://assets/sound/cardSlide2.ogg")
@onready var generic_1 = preload("res://assets/sound/generic1.ogg")
@onready var other_1 = preload("res://assets/sound/other1.ogg")
@onready var win_sound = preload("res://assets/sound/win.ogg")
@onready var foil_1 = preload("res://assets/sound/foil1.ogg")
@onready var foil_2 = preload("res://assets/sound/foil2.ogg")

func _ready() -> void:
	DeckManager.receive_game_signal.connect(Callable(self, "_on_receive_game_signal"))

func init():
	now_whos_turn = -1
	now_whos_dice = -1
	dice_result = -1
	is_bonus = false
	played_cards.clear()
	last_player = -1
	is_passed = false

func play_sound(id:int):
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	if id == 1:
		audio_player.stream = [foil_1, foil_2][randi_range(0, 1)]
	audio_player.play()
	await audio_player.finished
	remove_child(audio_player)

func _on_pass_button_pressed():
	await get_tree().create_timer(0.1).timeout
	_on_player_manager_player_finish([null])
	if DeckManager.GameMode != 0:
		WebController.player_finished.rpc([null])

# TODO: 继续完成该函数的信号同步
func _on_player_manager_player_finish(action):
	if DeckManager.GameMode == 2:
		return
	await get_tree().create_timer(0.5).timeout
	if action == [null]:
		now_whos_turn = (now_whos_turn+1) % player_count
		if last_player == now_whos_turn:
			# 出了一圈牌无人压过
			if now_whos_turn == now_whos_dice and not is_bonus and not is_anyone_cover:
				is_bonus = true	
			else:
				is_bonus = false
			now_whos_dice = now_whos_turn
			dice_result = -1
			last_player = -1
			is_anyone_cover = false
			played_cards = []
		elif now_whos_dice == now_whos_turn and last_player == -1:
			# 玩家跳过骰子，摸牌
			DrawCard.emit(now_whos_dice, 7-dice_result)
			now_whos_turn = (now_whos_turn+1) % player_count
			now_whos_dice = (now_whos_dice+1) % player_count
			dice_result = -1
			last_player = -1
			is_anyone_cover = false
			played_cards = []
	else:
		# 这里默认action是合法的
		played_cards = action.duplicate()
		last_player = now_whos_turn
		if now_whos_turn != now_whos_dice:
			is_anyone_cover = true
		now_whos_turn = (now_whos_turn+1) % player_count
	processed_game_signal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus)
	if is_bonus and len(played_cards) == 0 and now_whos_turn == now_whos_dice:
		await get_tree().create_timer(0.1).timeout
		play_sound(1)

func processed_game_signal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus):
	if DeckManager.GameMode != 2:
		GameSignal.emit(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus)
		if DeckManager.GameMode == 1:
			now_whos_turn = (now_whos_turn + DeckManager.player_order - 1) % DeckManager.player_count + 1
			now_whos_dice = (now_whos_dice + DeckManager.player_order - 1) % DeckManager.player_count + 1
			WebController.update_game_signal.rpc(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus)

func _on_game_start():
	dice_result = -1
	last_player = -1
	now_whos_turn = dealer
	now_whos_dice = dealer
	
	processed_game_signal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus)

func _on_receive_game_signal(now_whos_turn:int, now_whos_dice:int, dice_result:int, played_cards:Array, last_player:int, is_bonus:bool):
	now_whos_turn = (now_whos_turn - DeckManager.player_order + DeckManager.player_count) % DeckManager.player_count
	now_whos_dice = (now_whos_dice - DeckManager.player_order + DeckManager.player_count) % DeckManager.player_count
	GameSignal.emit(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus)

func _on_dice_dice_timeout(result):
	dice_result = result
	if DeckManager.GameMode == 1:
		WebController.send_dice_result.rpc(result)
	processed_game_signal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus)

func _on_player_manager_game_end(player_name):
	init()
