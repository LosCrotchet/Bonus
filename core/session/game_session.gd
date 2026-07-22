class_name GameSession
extends RefCounted

signal state_changed
signal game_finished(winner_index: int)

enum Phase {
	READY,
	AWAITING_ROLL,
	AWAITING_ACTION,
	FINISHED,
}

const STARTING_HAND_SIZE := 17
const PASS_DRAW_COUNT := 3

var players: Array[PlayerState] = []
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var last_played_cards: Array[CardData] = []
var current_player_index := 0
var dice_value := 0
var winner_index := -1
var phase := Phase.READY
var last_error := ""

var _random_source := RandomNumberGenerator.new()


func start_game(player_names: Array[String], seed_value: int = 0) -> bool:
	if player_names.size() < 2 or player_names.size() > 4:
		return _fail("玩家人数必须为 2 至 4 人")

	players.clear()
	draw_pile = DeckFactory.create_two_deck()
	discard_pile.clear()
	last_played_cards.clear()
	current_player_index = 0
	dice_value = 0
	winner_index = -1
	last_error = ""

	if seed_value == 0:
		_random_source.randomize()
	else:
		_random_source.seed = seed_value
	DeckFactory.shuffle_cards(draw_pile, _random_source)

	for index in range(player_names.size()):
		players.append(PlayerState.new(index, player_names[index]))

	for _round_index in range(STARTING_HAND_SIZE):
		for player in players:
			player.add_card(draw_pile.pop_back())

	for player in players:
		player.sort_hand()

	phase = Phase.AWAITING_ROLL
	state_changed.emit()
	return true


func roll_dice(player_index: int) -> bool:
	if not _can_current_player_act(player_index):
		return false
	if phase != Phase.AWAITING_ROLL:
		return _fail("当前阶段不能掷骰子")

	dice_value = _random_source.randi_range(1, 6)
	phase = Phase.AWAITING_ACTION
	last_error = ""
	state_changed.emit()
	return true


func play_cards(player_index: int, card_ids: Array[int]) -> bool:
	if not _can_current_player_act(player_index):
		return false
	if phase != Phase.AWAITING_ACTION:
		return _fail("请先掷骰子")
	if card_ids.size() != dice_value:
		return _fail("出牌数量必须等于骰子点数")
	if not players[player_index].has_cards(card_ids):
		return _fail("选中的牌不在当前手牌中")

	var played_cards := players[player_index].remove_cards(card_ids)
	discard_pile.append_array(played_cards)
	last_played_cards.clear()
	last_played_cards.append_array(played_cards)
	last_error = ""

	if players[player_index].hand.is_empty():
		winner_index = player_index
		phase = Phase.FINISHED
		state_changed.emit()
		game_finished.emit(winner_index)
		return true

	_advance_turn()
	return true


func pass_turn(player_index: int) -> bool:
	if not _can_current_player_act(player_index):
		return false
	if phase != Phase.AWAITING_ACTION:
		return _fail("请先掷骰子")

	draw_cards(player_index, PASS_DRAW_COUNT)
	last_played_cards.clear()
	last_error = ""
	_advance_turn()
	return true


func draw_cards(player_index: int, count: int) -> int:
	var drawn_count := 0
	for _card_index in range(count):
		if draw_pile.is_empty():
			_rebuild_draw_pile()
		if draw_pile.is_empty():
			break
		players[player_index].add_card(draw_pile.pop_back())
		drawn_count += 1
	players[player_index].sort_hand()
	return drawn_count


func get_total_card_count() -> int:
	var total := draw_pile.size() + discard_pile.size()
	for player in players:
		total += player.hand.size()
	return total


func _advance_turn() -> void:
	current_player_index = (current_player_index + 1) % players.size()
	dice_value = 0
	phase = Phase.AWAITING_ROLL
	state_changed.emit()


func _rebuild_draw_pile() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	DeckFactory.shuffle_cards(draw_pile, _random_source)


func _can_current_player_act(player_index: int) -> bool:
	if phase == Phase.FINISHED:
		return _fail("游戏已经结束")
	if player_index != current_player_index:
		return _fail("还没有轮到该玩家")
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false
