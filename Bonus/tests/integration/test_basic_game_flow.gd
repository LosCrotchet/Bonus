extends SceneTree


func _init() -> void:
	var session := GameSession.new()
	var names: Array[String] = ["南家", "北家", "西家"]
	assert(session.start_game(names, 20260722))
	assert(session.players.size() == 3)
	for player in session.players:
		assert(player.hand.size() == 17)
	assert(session.draw_pile.size() == 57)
	assert(session.get_total_card_count() == 108)

	var action_count := 0
	while session.phase != GameSession.Phase.FINISHED and action_count < 2000:
		var player_index := session.current_player_index
		if session.phase == GameSession.Phase.AWAITING_ROLL:
			assert(session.roll_dice(player_index))
		else:
			var card_ids := session.get_recommended_play(player_index)
			if card_ids.is_empty():
				assert(session.pass_turn(player_index))
			else:
				assert(session.play_cards(player_index, card_ids))
		action_count += 1

	assert(session.phase == GameSession.Phase.FINISHED)
	assert(session.winner_index in [0, 1, 2])
	assert(session.get_total_card_count() == 108)
	print("BONUS_TEST_BASIC_GAME_FLOW_OK actions=%d" % action_count)
	quit()
