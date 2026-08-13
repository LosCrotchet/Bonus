extends Node


func _ready() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	SaveGameService.clear_save()
	var names: Array[String] = ["SEAT_SOUTH", "SEAT_NORTH", "SEAT_WEST"]
	var first := GameSession.new()
	var second := GameSession.new()
	var seed_text := "bonus123"
	var seed_value := SeedCodec.to_int(seed_text)
	assert(first.start_game(names, seed_value, null, seed_text))
	assert(second.start_game(names, seed_value, null, seed_text))
	assert(_session_card_signature(first) == _session_card_signature(second))
	assert(first.initial_deal_card_ids == second.initial_deal_card_ids)
	assert(first.game_seed_text == seed_text)
	var random_session := GameSession.new()
	assert(random_session.start_game(names))
	assert(SeedCodec.is_valid(random_session.game_seed_text))

	var saved_match_statistics := {
		"play_actions": 2,
		"cards_played": 7,
		"dice_rolls": 3,
		"bonus_triggers": 1,
	}
	assert(SaveGameService.save_session(first, true, saved_match_statistics))
	assert(SaveGameService.save_session(first, true))
	assert(not FileAccess.file_exists("user://bonus_save.tmp"))
	assert(not FileAccess.file_exists("user://bonus_save.backup"))
	assert(SaveGameService.has_unfinished_game())
	var payload := SaveGameService.load_game()
	assert(bool(payload["custom_seed"]))
	# The second save intentionally replaces the optional snapshot.
	assert((payload["match_statistics"] as Dictionary).is_empty())
	assert(SaveGameService.save_session(first, true, saved_match_statistics))
	payload = SaveGameService.load_game()
	assert(payload["match_statistics"] == saved_match_statistics)
	var restored := GameSession.new()
	assert(restored.restore_from_snapshot(payload["session"] as Dictionary))
	assert(_session_card_signature(restored) == _session_card_signature(first))
	assert(restored.get_total_card_count() == first.get_total_card_count())
	assert(restored.game_seed == first.game_seed)
	assert(restored.game_seed_text == seed_text)
	assert(restored.to_snapshot()["rng_state"] == first.to_snapshot()["rng_state"])

	assert(first.roll_dice(0))
	assert(restored.roll_dice(0))
	assert(restored.dice_value == first.dice_value)
	SaveGameService.clear_save()
	assert(not SaveGameService.has_unfinished_game())
	print("BONUS_TEST_SAVE_GAME_SERVICE_OK")
	await AudioService.shutdown()
	get_tree().quit()


func _session_card_signature(session: GameSession) -> String:
	var parts := PackedStringArray()
	for player in session.players:
		parts.append(_cards_signature(player.hand))
	parts.append(_cards_signature(session.draw_pile))
	parts.append(_cards_signature(session.discard_pile))
	parts.append(_cards_signature(session.last_played_cards))
	return "|".join(parts)


func _cards_signature(cards: Array[CardData]) -> String:
	var values := PackedStringArray()
	for card in cards:
		values.append("%d:%d:%d:%d:%d" % [
			card.card_id,
			card.rank,
			card.suit,
			card.joker_kind,
			card.deck_index,
		])
	return ",".join(values)
