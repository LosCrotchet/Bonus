extends SceneTree

var _next_card_id := 2000


func _init() -> void:
	_test_following_and_turn_resolution()
	_test_bonus_once()
	_test_explicit_wildcard_interpretation()
	_test_all_pass_draws_three()
	_test_variable_pass_draw_count()
	_test_joker_finish_penalty()
	_test_optional_joker_finish_penalty()
	_test_natural_joker_finish()
	_test_winner_resolution()
	print("BONUS_TEST_RULE_GAME_FLOW_OK")
	quit()


func _test_following_and_turn_resolution() -> void:
	var session := _session_with_hands([
		[6, 6, 6, 9],
		[7, 7, 7, 3],
		[8, 10],
	])
	assert(session.accept_dice_result(0, 3))
	assert(session.play_cards(0, _first_ids(session, 0, 3)))
	assert(session.current_player_index == 1)
	assert(session.last_play_pattern.type == HandPattern.Type.TRIPLE)
	assert(session.play_cards(1, _first_ids(session, 1, 3)))
	assert(session.last_play_pattern.main_rank == 7)
	assert(session.pass_turn(2))
	assert(session.current_player_index == 0)
	assert(session.pass_turn(0))
	assert(session.phase == GameSession.Phase.AWAITING_ROLL)
	assert(session.roller_index == 1)


func _test_bonus_once() -> void:
	var session := _session_with_hands([
		[6, 6, 6, 9, 9, 12],
		[3, 4, 10],
		[3, 5, 11],
	])
	assert(session.accept_dice_result(0, 3))
	assert(session.play_cards(0, _first_ids(session, 0, 3)))
	assert(session.pass_turn(1))
	assert(session.pass_turn(2))
	assert(session.is_bonus)
	assert(session.current_player_index == 0)
	assert(session.last_play_pattern == null)
	assert(not session.pass_turn(0))
	assert(session.last_error_key == &"ERROR_BONUS_MUST_PLAY")

	var pair_ids: Array[int] = [session.players[0].hand[0].card_id, session.players[0].hand[1].card_id]
	assert(session.play_cards(0, pair_ids))
	assert(session.last_play_pattern.type == HandPattern.Type.PAIR)
	assert(session.pass_turn(1))
	assert(session.pass_turn(2))
	assert(not session.is_bonus)
	assert(session.phase == GameSession.Phase.AWAITING_ROLL)
	assert(session.roller_index == 0)


func _test_explicit_wildcard_interpretation() -> void:
	var session := _session_with_hands([
		[3, 3, 4, 4],
		[5],
		[6],
	])
	session.players[0].hand.append(_joker())
	session.players[0].hand.append(_joker())
	assert(session.accept_dice_result(0, 6))
	var ids := _first_ids(session, 0, 6)
	var interpretations := session.get_legal_interpretations(0, ids)
	assert(interpretations.size() == 3)
	var triple_with_triple: HandPattern
	for pattern in interpretations:
		if pattern.type == HandPattern.Type.TRIPLE_WITH_TRIPLE:
			triple_with_triple = pattern
	assert(triple_with_triple != null)
	assert(session.play_cards(0, ids, triple_with_triple.get_key()))
	assert(session.last_play_pattern.type == HandPattern.Type.TRIPLE_WITH_TRIPLE)


func _test_all_pass_draws_three() -> void:
	var session := _session_with_hands([
		[3, 4],
		[5, 6],
		[7, 8],
	])
	var before := session.players[0].hand.size()
	assert(session.accept_dice_result(0, 6))
	assert(session.pass_turn(0))
	assert(session.pass_turn(1))
	assert(session.pass_turn(2))
	assert(session.players[0].hand.size() == before + 3)
	assert(session.phase == GameSession.Phase.AWAITING_ROLL)
	assert(session.roller_index == 1)
	assert(session.current_player_index == session.roller_index)


func _test_variable_pass_draw_count() -> void:
	var rules := GameRules.new()
	rules.draw_count_uses_dice = true
	var session := _session_with_hands([
		[3],
		[4],
		[5],
	], rules)
	var before := session.players[0].hand.size()
	assert(session.accept_dice_result(0, 1))
	assert(session.pass_turn(0))
	assert(session.pass_turn(1))
	assert(session.pass_turn(2))
	assert(session.players[0].hand.size() == before + 6)


func _test_joker_finish_penalty() -> void:
	var session := _session_with_hands([
		[5],
		[5],
		[6],
	])
	session.players[0].hand.append(_joker())
	assert(session.accept_dice_result(0, 2))
	assert(session.play_cards(0, _first_ids(session, 0, 2)))
	assert(session.phase != GameSession.Phase.FINISHED)
	assert(session.players[0].hand.size() == 2)
	assert(session.last_play_pattern.uses_wildcard)


func _test_optional_joker_finish_penalty() -> void:
	var rules := GameRules.new()
	rules.draw_two_on_wildcard_finish = false
	var session := _session_with_hands([
		[5],
		[5],
		[6],
	], rules)
	session.players[0].hand.append(_joker())
	assert(session.accept_dice_result(0, 2))
	assert(session.play_cards(0, _first_ids(session, 0, 2)))
	assert(session.phase == GameSession.Phase.FINISHED)
	assert(session.winner_index == 0)


func _test_natural_joker_finish() -> void:
	var session := _session_with_hands([
		[],
		[5],
		[6],
	])
	session.players[0].hand.append(_joker(CardData.JokerKind.BIG))
	assert(session.accept_dice_result(0, 1))
	assert(session.play_cards(0, [session.players[0].hand[0].card_id]))
	assert(session.phase == GameSession.Phase.FINISHED)
	assert(session.winner_index == 0)
	assert(not session.last_play_pattern.uses_wildcard)


func _test_winner_resolution() -> void:
	var session := _session_with_hands([
		[3],
		[5],
		[6],
	])
	assert(session.accept_dice_result(0, 1))
	assert(session.play_cards(0, [session.players[0].hand[0].card_id]))
	assert(session.phase == GameSession.Phase.FINISHED)
	assert(session.winner_index == 0)


func _session_with_hands(
	rank_groups: Array,
	rules: GameRules = null,
) -> GameSession:
	var session := GameSession.new()
	var names: Array[String] = ["南家", "北家", "西家"]
	assert(session.start_game(names, 12345, rules))
	for player_index in range(rank_groups.size()):
		session.players[player_index].hand = _cards(rank_groups[player_index])
	return session


func _first_ids(session: GameSession, player_index: int, count: int) -> Array[int]:
	var ids: Array[int] = []
	for index in range(count):
		ids.append(session.players[player_index].hand[index].card_id)
	return ids


func _cards(ranks: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for rank in ranks:
		cards.append(CardData.new(_take_id(), rank, CardData.Suit.CLUBS))
	return cards


func _joker(kind: CardData.JokerKind = CardData.JokerKind.SMALL) -> CardData:
	return CardData.new(
		_take_id(),
		0,
		CardData.Suit.NONE,
		kind,
	)


func _take_id() -> int:
	var result := _next_card_id
	_next_card_id += 1
	return result
