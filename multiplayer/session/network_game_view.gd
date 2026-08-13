class_name NetworkGameView
extends RefCounted

const LAN_PROTOCOL = preload("res://multiplayer/protocol/lan_protocol.gd")
const PUBLIC_GAME_SNAPSHOT = preload("res://multiplayer/protocol/public_game_snapshot.gd")


static func apply_snapshot(session: GameSession, snapshot: Dictionary) -> bool:
	var player_values := snapshot.get("players", []) as Array
	var local_player_index := int(snapshot.get("local_player_index", -1))
	if (
		player_values.size() < 2
		or player_values.size() > 4
		or local_player_index < 0
		or local_player_index >= player_values.size()
	):
		return false

	var players: Array[PlayerState] = []
	for index in range(player_values.size()):
		var value := player_values[index] as Dictionary
		var player := PlayerState.new(index, str(value.get("display_name", "")))
		if index == local_player_index:
			player.hand.assign(PUBLIC_GAME_SNAPSHOT.cards_from_dictionaries(
				value.get("hand", []) as Array,
			))
		elif value.has("revealed_hand"):
			player.hand.assign(PUBLIC_GAME_SNAPSHOT.cards_from_dictionaries(
				value.get("revealed_hand", []) as Array,
			))
		else:
			for hidden_index in range(int(value.get("hand_count", 0))):
				player.hand.append(CardData.new(
					-10000 - index * 100 - hidden_index,
					CardData.Rank.THREE,
					CardData.Suit.NONE,
				))
		players.append(player)

	session.players.assign(players)
	session.rules = LAN_PROTOCOL.rules_from_dictionary(snapshot.get("rules", {}) as Dictionary)
	session.draw_pile.clear()
	for draw_index in range(int(snapshot.get("draw_pile_count", 0))):
		session.draw_pile.append(CardData.new(
			-20000 - draw_index,
			CardData.Rank.THREE,
			CardData.Suit.NONE,
		))
	session.discard_pile.clear()
	for discard_index in range(int(snapshot.get("discard_pile_count", 0))):
		session.discard_pile.append(CardData.new(
			-30000 - discard_index,
			CardData.Rank.THREE,
			CardData.Suit.NONE,
		))
	session.last_played_cards.assign(PUBLIC_GAME_SNAPSHOT.cards_from_dictionaries(
		snapshot.get("last_played_cards", []) as Array,
	))
	session.last_play_pattern = PUBLIC_GAME_SNAPSHOT.pattern_from_dictionary(
		snapshot.get("last_play_pattern", null),
	)
	session.current_player_index = int(snapshot.get("current_player_index", 0))
	session.roller_index = int(snapshot.get("roller_index", 0))
	session.last_player_index = int(snapshot.get("last_player_index", -1))
	session.played_by_index = int(snapshot.get("played_by_index", -1))
	session.dice_value = int(snapshot.get("dice_value", 0))
	session.winner_index = int(snapshot.get("winner_index", -1))
	session.phase = int(snapshot.get("phase", GameSession.Phase.READY)) as GameSession.Phase
	session.is_bonus = bool(snapshot.get("is_bonus", false))
	session.game_seed_text = str(snapshot.get("seed_text", ""))
	session.event_key = StringName(str(snapshot.get("event_key", "")))
	session.event_args = (snapshot.get("event_args", {}) as Dictionary).duplicate(true)
	return true
