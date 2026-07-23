extends SceneTree

const SettingsServiceScript := preload("res://autoload/settings_service.gd")


func _init() -> void:
	_test_default_speed()
	_test_speed_profiles_are_ordered_and_ui_is_fixed()
	_test_strategy_context_is_public_and_detached()
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
		0.5,
	))
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


func _test_default_strategy_completes_a_legal_game() -> void:
	var session := GameSession.new()
	assert(session.start_game(["SEAT_SOUTH", "SEAT_NORTH", "SEAT_WEST"], 271828))
	var strategies: Array[PlayerStrategy] = []
	for player_index in range(session.players.size()):
		var strategy := StrategyRegistry.create(&"default")
		strategy.setup(player_index, session.players.size())
		strategies.append(strategy)

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
