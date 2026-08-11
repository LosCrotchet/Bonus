extends SceneTree

const SettingsServiceScript := preload("res://autoload/settings_service.gd")

var _next_card_id := 9000


func _init() -> void:
	_test_default_speed()
	_test_speed_profiles_are_ordered_and_ui_is_fixed()
	_test_strategy_context_is_public_and_detached()
	_test_passes_an_inherited_unimportant_dice_value()
	_test_takes_an_inherited_dice_value_to_win()
	_test_pair_play_preserves_triples_and_pair_sequences()
	_test_cover_prefers_an_isolated_pair()
	_test_bonus_sheds_an_isolated_single()
	_test_opponent_threat_overrides_structure_preservation()
	_test_card_memory_avoids_unnecessary_overkill()
	_test_natural_big_joker_finishes_without_false_cover_pressure()
	_test_default_strategy_completes_a_legal_game()
	print("BONUS_TEST_AI_STRATEGY_OK")
	quit()


func _test_default_speed() -> void:
	assert(
		SettingsServiceScript.DEFAULT_GAME_SPEED
		== SettingsServiceScript.GameSpeed.SLOW
	)


func _test_speed_profiles_are_ordered_and_ui_is_fixed() -> void:
	var settings := SettingsServiceScript.new()
	var durations := {}
	for timing in SettingsServiceScript.GameplayTiming.values():
		durations[timing] = []
		for speed in SettingsServiceScript.GameSpeed.values():
			settings.game_speed = speed
			(durations[timing] as Array).append(settings.get_gameplay_duration(timing))
		var values := durations[timing] as Array
		assert(values[SettingsServiceScript.GameSpeed.SLOW] > values[SettingsServiceScript.GameSpeed.MEDIUM])
		assert(values[SettingsServiceScript.GameSpeed.MEDIUM] > values[SettingsServiceScript.GameSpeed.FAST])
	assert(is_equal_approx(
		SettingsServiceScript.SPEED_MULTIPLIERS[SettingsServiceScript.GameSpeed.FAST],
		0.75,
	))
	settings.game_speed = SettingsServiceScript.GameSpeed.FAST
	assert(
		settings.get_gameplay_duration(SettingsServiceScript.GameplayTiming.ACTION_PAUSE)
		>= 0.5
	)
	settings.game_speed = SettingsServiceScript.GameSpeed.SLOW
	var slow_ui_duration := settings.get_ui_animation_duration()
	settings.game_speed = SettingsServiceScript.GameSpeed.FAST
	assert(is_equal_approx(settings.get_ui_animation_duration(), slow_ui_duration))
	settings.free()


func _test_strategy_context_is_public_and_detached() -> void:
	var session := GameSession.new()
	assert(session.start_game(["SEAT_SOUTH", "SEAT_NORTH", "SEAT_WEST"], 314159))
	var context := session.create_strategy_context(1)
	assert(context != null)
	assert(context.own_hand.size() == session.players[1].hand.size())
	assert(context.player_summaries.size() == session.players.size())
	assert(context.rules != null)
	assert(context.rules.jokers_are_wild)

	var opponent_card_ids: Array[int] = []
	for player_index in [0, 2]:
		for card in session.players[player_index].hand:
			opponent_card_ids.append(card.card_id)
	for card in context.own_hand:
		assert(not opponent_card_ids.has(card.card_id))
	for summary in context.player_summaries:
		for key in summary.keys():
			assert(key in ["player_index", "display_name_key", "hand_count", "is_current", "is_roller"])

	var original_rank := session.players[1].hand[0].rank
	context.own_hand[0].rank = (
		CardData.Rank.THREE
		if original_rank != CardData.Rank.THREE
		else CardData.Rank.ACE
	)
	assert(session.players[1].hand[0].rank == original_rank)


func _test_passes_an_inherited_unimportant_dice_value() -> void:
	var strategy := _strategy(1, 3)
	var context := _context(
		[3, 3, 5, 5, 8, 8, 11],
		2,
		1,
		0,
	)
	assert(strategy.choose_action(context).action == PlayerDecision.Action.PASS)


func _test_takes_an_inherited_dice_value_to_win() -> void:
	var strategy := _strategy(1, 3)
	var context := _context([4, 4], 2, 1, 0)
	var decision := strategy.choose_action(context)
	assert(decision.action == PlayerDecision.Action.PLAY)
	assert(_decision_ranks(context, decision) == [4, 4])


func _test_pair_play_preserves_triples_and_pair_sequences() -> void:
	var strategy := _strategy(0, 3)
	var context := _context(
		[3, 3, 3, 5, 5, 6, 6, 8, 8, 11, 12, 13],
		2,
		0,
		0,
	)
	var decision := strategy.choose_action(context)
	assert(decision.action == PlayerDecision.Action.PLAY)
	assert(_decision_ranks(context, decision) == [8, 8])


func _test_cover_prefers_an_isolated_pair() -> void:
	var strategy := _strategy(0, 3)
	var target := HandPattern.new(HandPattern.Type.PAIR, 2, 4, false)
	var context := _context(
		[5, 5, 5, 8, 8, 11, 12],
		2,
		0,
		1,
		target,
	)
	var decision := strategy.choose_action(context)
	assert(decision.action == PlayerDecision.Action.PLAY)
	assert(_decision_ranks(context, decision) == [8, 8])


func _test_bonus_sheds_an_isolated_single() -> void:
	var strategy := _strategy(0, 3)
	var context := _context(
		[3, 3, 4, 4, 7, 11, 11],
		2,
		0,
		0,
		null,
		true,
	)
	var decision := strategy.choose_action(context)
	assert(decision.action == PlayerDecision.Action.PLAY)
	assert(_decision_ranks(context, decision) == [7])


func _test_opponent_threat_overrides_structure_preservation() -> void:
	var strategy := _strategy(0, 3)
	var target := HandPattern.new(HandPattern.Type.PAIR, 2, 4, false)
	var context := _context(
		[5, 5, 5, 7, 9, 11, 13],
		2,
		0,
		1,
		target,
		false,
		null,
		[1, 8],
	)
	var decision := strategy.choose_action(context)
	assert(decision.action == PlayerDecision.Action.PLAY)
	assert(_decision_ranks(context, decision) == [5, 5])


func _test_card_memory_avoids_unnecessary_overkill() -> void:
	var rules := GameRules.new()
	rules.include_jokers = false
	var target := HandPattern.new(HandPattern.Type.SINGLE, 1, 12, false)
	var context := _context(
		[3, 3, 13, 15],
		1,
		0,
		1,
		target,
		false,
		rules,
		[1, 8],
	)

	var uninformed := _strategy(0, 3)
	var forceful_decision := uninformed.choose_action(context)
	assert(forceful_decision.action == PlayerDecision.Action.PLAY)
	assert(_decision_ranks(context, forceful_decision) == [15])

	var informed := _strategy(0, 3)
	var seen_cards: Array[Dictionary] = []
	for rank in [14, 15]:
		for copy_index in range(8):
			seen_cards.append({
				"card_id": 20000 + rank * 10 + copy_index,
				"rank": rank,
				"suit": copy_index % 4,
				"joker_kind": CardData.JokerKind.NONE,
			})
	informed.observe_action({"type": &"play", "cards": seen_cards})
	var measured_decision := informed.choose_action(context)
	assert(measured_decision.action == PlayerDecision.Action.PLAY)
	assert(_decision_ranks(context, measured_decision) == [13])


func _test_natural_big_joker_finishes_without_false_cover_pressure() -> void:
	var strategy := _strategy(0, 3)
	var context := _context([3], 1, 0, 0)
	context.own_hand.clear()
	context.own_hand.append(CardData.new(
		_take_card_id(),
		0,
		CardData.Suit.NONE,
		CardData.JokerKind.BIG,
	))
	var decision := strategy.choose_action(context)
	assert(decision.action == PlayerDecision.Action.PLAY)
	assert(decision.card_ids == [context.own_hand[0].card_id])


func _test_default_strategy_completes_a_legal_game() -> void:
	var session := GameSession.new()
	assert(session.start_game(["SEAT_SOUTH", "SEAT_NORTH", "SEAT_WEST"], 271828))
	var strategies: Array[PlayerStrategy] = []
	for player_index in range(session.players.size()):
		var strategy := StrategyRegistry.create(&"default")
		strategy.setup(player_index, session.players.size())
		strategies.append(strategy)
	session.action_resolved.connect(
		func(action: Dictionary) -> void:
			for strategy in strategies:
				strategy.observe_action(action.duplicate(true))
	)

	var action_count := 0
	while session.phase != GameSession.Phase.FINISHED and action_count < 1000:
		var player_index := session.current_player_index
		var decision := strategies[player_index].choose_action(
			session.create_strategy_context(player_index)
		)
		assert(decision != null)
		match decision.action:
			PlayerDecision.Action.ROLL:
				assert(session.phase == GameSession.Phase.AWAITING_ROLL)
				assert(session.roll_dice(player_index))
			PlayerDecision.Action.PLAY:
				var interpretations := session.get_legal_interpretations(
					player_index,
					decision.card_ids,
				)
				assert(not interpretations.is_empty())
				assert(
					decision.interpretation_key.is_empty()
					or _contains_interpretation(interpretations, decision.interpretation_key)
				)
				assert(
					session.play_cards(
						player_index,
						decision.card_ids,
						decision.interpretation_key,
					)
				)
			PlayerDecision.Action.PASS:
				assert(not (session.is_bonus and session.last_play_pattern == null))
				assert(session.pass_turn(player_index))
			_:
				assert(false, "Default strategy returned an unknown action")
		action_count += 1

	assert(session.phase == GameSession.Phase.FINISHED)
	assert(session.winner_index >= 0)


func _contains_interpretation(patterns: Array[HandPattern], key: String) -> bool:
	for pattern in patterns:
		if pattern.get_key() == key:
			return true
	return false


func _strategy(player_index: int, count: int) -> DefaultStrategy:
	var strategy := DefaultStrategy.new()
	strategy.setup(player_index, count)
	return strategy


func _context(
	ranks: Array,
	dice: int,
	player_index: int,
	roller_index: int,
	target: HandPattern = null,
	is_bonus: bool = false,
	rules: GameRules = null,
	opponent_counts: Array = [8, 8],
) -> StrategyContext:
	var context := StrategyContext.new()
	context.player_index = player_index
	context.phase = StrategyContext.PHASE_ACTION
	context.own_hand = _cards(ranks)
	context.draw_pile_count = 30
	context.discard_pile_count = 0
	context.dice_value = dice
	context.is_bonus = is_bonus
	context.roller_index = roller_index
	context.last_player_index = (player_index + 1) % (opponent_counts.size() + 1)
	context.target_pattern = target
	context.rules = rules if rules != null else GameRules.new()

	var opponent_cursor := 0
	for index in range(opponent_counts.size() + 1):
		var hand_count := context.own_hand.size()
		if index != player_index:
			hand_count = int(opponent_counts[opponent_cursor])
			opponent_cursor += 1
		context.player_summaries.append({
			"player_index": index,
			"display_name_key": "SEAT_%d" % index,
			"hand_count": hand_count,
			"is_current": index == player_index,
			"is_roller": index == roller_index,
		})
	return context


func _cards(ranks: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for rank in ranks:
		cards.append(CardData.new(
			_take_card_id(),
			int(rank),
			CardData.Suit.CLUBS,
		))
	return cards


func _decision_ranks(
	context: StrategyContext,
	decision: PlayerDecision,
) -> Array[int]:
	var ranks: Array[int] = []
	for card in context.own_hand:
		if decision.card_ids.has(card.card_id):
			ranks.append(card.get_natural_rank())
	ranks.sort()
	return ranks


func _take_card_id() -> int:
	var result := _next_card_id
	_next_card_id += 1
	return result
