extends SceneTree


func _init() -> void:
	var session := GameSession.new()
	var names: Array[String] = ["玩家", "对手"]
	assert(session.start_game(names, 20260722))
	assert(session.players.size() == 2)
	assert(session.players[0].hand.size() == 17)
	assert(session.players[1].hand.size() == 17)
	assert(session.draw_pile.size() == 74)
	assert(session.get_total_card_count() == 108)

	var action_count := 0
	while session.phase != GameSession.Phase.FINISHED and action_count < 1000:
		var player_index := session.current_player_index
		assert(session.roll_dice(player_index))
		var hand := session.players[player_index].hand
		if hand.size() >= session.dice_value:
			var card_ids: Array[int] = []
			for index in range(session.dice_value):
				card_ids.append(hand[index].card_id)
			assert(session.play_cards(player_index, card_ids))
		else:
			assert(session.pass_turn(player_index))
		action_count += 1

	assert(session.phase == GameSession.Phase.FINISHED)
	assert(session.winner_index in [0, 1])
	assert(session.get_total_card_count() == 108)
	print("BONUS_TEST_BASIC_GAME_FLOW_OK actions=%d" % action_count)
	quit()
