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
const JOKER_FINISH_DRAW_COUNT := 2

var players: Array[PlayerState] = []
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var last_played_cards: Array[CardData] = []
var last_play_pattern: HandPattern
var current_player_index := 0
var roller_index := 0
var last_player_index := -1
var played_by_index := -1
var dice_value := 0
var winner_index := -1
var phase := Phase.READY
var is_bonus := false
var last_error := ""
var event_message := ""

var _passes_since_play := 0
var _round_pass_count := 0
var _bonus_candidate := false
var _random_source := RandomNumberGenerator.new()


func start_game(player_names: Array[String], seed_value: int = 0) -> bool:
	if player_names.size() < 2 or player_names.size() > 4:
		return _fail("玩家人数必须为 2 至 4 人")

	players.clear()
	draw_pile = DeckFactory.create_two_deck()
	discard_pile.clear()
	last_played_cards.clear()
	last_play_pattern = null
	current_player_index = 0
	roller_index = 0
	last_player_index = -1
	played_by_index = -1
	dice_value = 0
	winner_index = -1
	last_error = ""
	event_message = "牌局开始，南家先手"
	_reset_round_tracking()

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
	return accept_dice_result(player_index, _random_source.randi_range(1, 6))


func accept_dice_result(player_index: int, value: int) -> bool:
	if not _can_current_player_act(player_index):
		return false
	if phase != Phase.AWAITING_ROLL:
		return _fail("当前阶段不能掷骰子")
	if value < 1 or value > 6:
		return _fail("骰子点数必须为 1 至 6")

	_discard_table_cards()
	dice_value = value
	last_player_index = -1
	phase = Phase.AWAITING_ACTION
	last_error = ""
	event_message = "%s 掷出了 %d 点" % [players[player_index].display_name, value]
	state_changed.emit()
	return true


func play_cards(player_index: int, card_ids: Array[int]) -> bool:
	if not _can_current_player_act(player_index):
		return false
	if phase != Phase.AWAITING_ACTION:
		return _fail("当前阶段不能出牌")
	if card_ids.is_empty():
		return _fail("请先选择要出的牌")
	if not players[player_index].has_cards(card_ids):
		return _fail("选中的牌不在当前手牌中")

	var selected_cards := _find_cards(players[player_index], card_ids)
	var selected_pattern: HandPattern
	if last_play_pattern == null:
		if not is_bonus and card_ids.size() != dice_value:
			return _fail("出牌数量必须等于骰子点数")
		selected_pattern = HandEvaluator.choose_lead_pattern(selected_cards)
		if selected_pattern == null:
			return _fail("所选牌不能组成合法牌型")
	else:
		selected_pattern = HandEvaluator.choose_cover_pattern(selected_cards, last_play_pattern)
		if selected_pattern == null:
			return _fail("所选牌型不能盖过当前出牌")

	var was_opening_play := last_play_pattern == null
	if not was_opening_play:
		_discard_table_cards()
		_bonus_candidate = false

	var played_cards := players[player_index].remove_cards(card_ids)
	last_played_cards.assign(played_cards)
	last_play_pattern = selected_pattern
	last_player_index = player_index
	played_by_index = player_index
	_passes_since_play = 0
	_round_pass_count = 0
	if was_opening_play:
		_bonus_candidate = player_index == roller_index and not is_bonus

	last_error = ""
	event_message = "%s 打出%s" % [players[player_index].display_name, selected_pattern.get_display_name()]

	# Victory is resolved only after a confirmed play changes the hand.
	if players[player_index].hand.is_empty():
		if selected_pattern.contains_joker:
			var drawn_count := draw_cards(player_index, JOKER_FINISH_DRAW_COUNT)
			event_message = "%s 最后一手含万能牌，摸了 %d 张" % [
				players[player_index].display_name,
				drawn_count,
			]
		else:
			_finish_game(player_index)
			return true

	current_player_index = _next_player(player_index)
	state_changed.emit()
	return true


func pass_turn(player_index: int) -> bool:
	if not _can_current_player_act(player_index):
		return false
	if phase != Phase.AWAITING_ACTION:
		return _fail("当前阶段不能选择不出")

	last_error = ""
	event_message = "%s 选择不出" % players[player_index].display_name

	if is_bonus and last_play_pattern == null:
		_begin_new_round(roller_index)
		state_changed.emit()
		return true

	if last_play_pattern == null:
		_round_pass_count += 1
		if _round_pass_count >= players.size():
			var previous_roller := roller_index
			var drawn_count := draw_cards(previous_roller, PASS_DRAW_COUNT)
			event_message = "本回合无人出牌，%s 摸了 %d 张" % [
				players[previous_roller].display_name,
				drawn_count,
			]
			_begin_new_round(_next_player(previous_roller))
		else:
			current_player_index = _next_player(player_index)
		state_changed.emit()
		return true

	_passes_since_play += 1
	if _passes_since_play >= players.size() - 1:
		if _bonus_candidate and last_player_index == roller_index and not is_bonus:
			_start_bonus()
		else:
			var next_roller := last_player_index
			event_message = "%s 获得下一次掷骰" % players[next_roller].display_name
			_begin_new_round(next_roller)
	else:
		current_player_index = _next_player(player_index)
	state_changed.emit()
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


func get_recommended_play(player_index: int) -> Array[int]:
	if (
		phase != Phase.AWAITING_ACTION
		or player_index != current_player_index
		or player_index < 0
		or player_index >= players.size()
	):
		return []
	var hand := players[player_index].hand
	if last_play_pattern != null:
		return LegalMoveFinder.find_play(hand, last_play_pattern.card_count, last_play_pattern)
	if is_bonus:
		return LegalMoveFinder.find_bonus_play(hand)
	return LegalMoveFinder.find_play(hand, dice_value)


func get_total_card_count() -> int:
	var total := draw_pile.size() + discard_pile.size() + last_played_cards.size()
	for player in players:
		total += player.hand.size()
	return total


func _start_bonus() -> void:
	_discard_table_cards()
	current_player_index = roller_index
	is_bonus = true
	_bonus_candidate = false
	_passes_since_play = 0
	_round_pass_count = 0
	event_message = "%s 获得 BONUS，可打出任意合法牌型" % players[roller_index].display_name


func _begin_new_round(next_roller: int) -> void:
	roller_index = next_roller
	current_player_index = next_roller
	dice_value = 0
	phase = Phase.AWAITING_ROLL
	is_bonus = false
	_reset_round_tracking()


func _reset_round_tracking() -> void:
	_passes_since_play = 0
	_round_pass_count = 0
	_bonus_candidate = false


func _finish_game(player_index: int) -> void:
	winner_index = player_index
	phase = Phase.FINISHED
	event_message = "%s 打完了全部手牌" % players[player_index].display_name
	state_changed.emit()
	game_finished.emit(winner_index)


func _discard_table_cards() -> void:
	if not last_played_cards.is_empty():
		discard_pile.append_array(last_played_cards)
	last_played_cards.clear()
	last_play_pattern = null
	played_by_index = -1


func _rebuild_draw_pile() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	DeckFactory.shuffle_cards(draw_pile, _random_source)


func _find_cards(player: PlayerState, card_ids: Array[int]) -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id in card_ids:
		var index := player.find_card_index(card_id)
		if index != -1:
			cards.append(player.hand[index])
	return cards


func _next_player(player_index: int) -> int:
	return (player_index + 1) % players.size()


func _can_current_player_act(player_index: int) -> bool:
	if phase == Phase.FINISHED:
		return _fail("游戏已经结束")
	if player_index < 0 or player_index >= players.size():
		return _fail("玩家不存在")
	if player_index != current_player_index:
		return _fail("还没有轮到该玩家")
	return true


func _fail(message: String) -> bool:
	last_error = message
	return false
