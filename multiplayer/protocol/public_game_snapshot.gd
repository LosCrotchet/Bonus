class_name PublicGameSnapshot
extends RefCounted

const LAN_PROTOCOL = preload("res://multiplayer/protocol/lan_protocol.gd")


static func build(
	session: GameSession,
	recipient_seat_index: int,
	room_snapshot: Dictionary,
	revision: int,
	turn_deadline_ms: int,
	public_action: Dictionary = {},
) -> Dictionary:
	var players: Array[Dictionary] = []
	var room_members := room_snapshot.get("members", []) as Array
	for player_index in range(session.players.size()):
		var player := session.players[player_index]
		var member := _member_for_seat(room_members, player_index)
		var player_value := {
			"player_index": player_index,
			"display_name": player.display_name,
			"player_id": str(member.get("player_id", player.display_name)),
			"hand_count": player.hand.size(),
			"connected": bool(member.get("connected", true)),
			"is_ai": bool(member.get("is_ai", false)),
			"ai_takeover": bool(member.get("ai_takeover", false)),
		}
		if player_index == recipient_seat_index:
			player_value["hand"] = cards_to_dictionaries(player.hand)
		elif session.phase == GameSession.Phase.FINISHED and bool(member.get("is_ai", false)):
			# AI hands become public only after the authoritative match has ended.
			player_value["revealed_hand"] = cards_to_dictionaries(player.hand)
		players.append(player_value)

	return {
		"revision": revision,
		"local_player_index": recipient_seat_index,
		"players": players,
		"draw_pile_count": session.draw_pile.size(),
		"discard_pile_count": session.discard_pile.size(),
		"last_played_cards": cards_to_dictionaries(session.last_played_cards),
		"last_play_pattern": pattern_to_dictionary(session.last_play_pattern),
		"current_player_index": session.current_player_index,
		"roller_index": session.roller_index,
		"last_player_index": session.last_player_index,
		"played_by_index": session.played_by_index,
		"dice_value": session.dice_value,
		"winner_index": session.winner_index,
		"phase": session.phase,
		"is_bonus": session.is_bonus,
		"seed_text": session.game_seed_text,
		"rules": LAN_PROTOCOL.rules_to_dictionary(session.rules),
		"event_key": str(session.event_key),
		"event_args": session.event_args.duplicate(true),
		"turn_deadline_ms": turn_deadline_ms,
		"server_time_ms": Time.get_ticks_msec(),
		"public_action": public_action.duplicate(true),
	}


static func cards_to_dictionaries(cards: Array[CardData]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in cards:
		result.append({
			"card_id": card.card_id,
			"rank": card.rank,
			"suit": card.suit,
			"joker_kind": card.joker_kind,
			"deck_index": card.deck_index,
		})
	return result


static func cards_from_dictionaries(values: Array) -> Array[CardData]:
	var result: Array[CardData] = []
	for value in values:
		if value is not Dictionary:
			continue
		var card := value as Dictionary
		result.append(CardData.new(
			int(card.get("card_id", -1)),
			int(card.get("rank", 0)),
			int(card.get("suit", CardData.Suit.NONE)),
			int(card.get("joker_kind", CardData.JokerKind.NONE)),
			int(card.get("deck_index", 0)),
		))
	return result


static func pattern_to_dictionary(pattern: HandPattern) -> Variant:
	if pattern == null:
		return null
	return {
		"type": pattern.type,
		"card_count": pattern.card_count,
		"main_rank": pattern.main_rank,
		"contains_joker": pattern.contains_joker,
		"uses_wildcard": pattern.uses_wildcard,
	}


static func pattern_from_dictionary(value: Variant) -> HandPattern:
	if value is not Dictionary:
		return null
	var pattern := value as Dictionary
	return HandPattern.new(
		int(pattern.get("type", HandPattern.Type.SINGLE)) as HandPattern.Type,
		int(pattern.get("card_count", 1)),
		int(pattern.get("main_rank", 0)),
		bool(pattern.get("contains_joker", false)),
		bool(pattern.get("uses_wildcard", false)),
	)


static func contains_private_information(
	snapshot: Dictionary,
	recipient_seat_index: int,
) -> bool:
	if snapshot.has("draw_pile") or snapshot.has("rng_state") or snapshot.has("rng_seed"):
		return true
	for player_value in snapshot.get("players", []) as Array:
		if player_value is not Dictionary:
			continue
		var player := player_value as Dictionary
		if int(player.get("player_index", -1)) != recipient_seat_index and player.has("hand"):
			return true
		if (
			player.has("revealed_hand")
			and int(snapshot.get("phase", GameSession.Phase.READY))
			!= GameSession.Phase.FINISHED
		):
			return true
	return false


static func _member_for_seat(members: Array, seat_index: int) -> Dictionary:
	for value in members:
		if value is Dictionary and int(value.get("seat_index", -1)) == seat_index:
			return value as Dictionary
	return {}
