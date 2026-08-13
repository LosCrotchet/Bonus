@tool
class_name GameSession
extends RefCounted

signal state_changed
signal game_finished(winner_index: int)
signal action_resolved(public_action: Dictionary)

enum Phase {
	READY,
	AWAITING_ROLL,
	AWAITING_ACTION,
	FINISHED,
}

const STARTING_HAND_SIZE := 17
const PASS_DRAW_COUNT := 3
const JOKER_FINISH_DRAW_COUNT := 2

var rules := GameRules.new()
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
var game_seed := 0
var game_seed_text := ""
var initial_deal_card_ids: Array[PackedInt32Array] = []
var last_error_key: StringName = &""
var last_error_args: Dictionary = {}
var event_key: StringName = &""
var event_args: Dictionary = {}

var _passes_since_play := 0
var _round_pass_count := 0
var _bonus_candidate := false
var _random_source := RandomNumberGenerator.new()


func start_game(
	player_names: Array[String],
	seed_value: int = 0,
	game_rules: GameRules = null,
	seed_text: String = "",
) -> bool:
	if player_names.size() < 2 or player_names.size() > 4:
		return _fail(&"ERROR_PLAYER_COUNT")

	rules = game_rules.clone() if game_rules != null else GameRules.new()
	players.clear()
	initial_deal_card_ids.clear()
	draw_pile = DeckFactory.create_two_deck(rules.include_jokers)
	discard_pile.clear()
	last_played_cards.clear()
	last_play_pattern = null
	current_player_index = 0
	roller_index = 0
	last_player_index = -1
	played_by_index = -1
	dice_value = 0
	winner_index = -1
	_clear_error()
	_set_event(&"EVENT_GAME_STARTED")
	_reset_round_tracking()

	if seed_value == 0:
		_random_source.randomize()
	else:
		_random_source.seed = seed_value
	game_seed = _random_source.seed
	game_seed_text = (
		SeedCodec.sanitize(seed_text)
		if SeedCodec.is_valid(seed_text)
		else SeedCodec.from_int(game_seed)
	)
	DeckFactory.shuffle_cards(draw_pile, _random_source)

	for index in range(player_names.size()):
		players.append(PlayerState.new(index, player_names[index]))
		initial_deal_card_ids.append(PackedInt32Array())

	for _round_index in range(STARTING_HAND_SIZE):
		for player_index in range(players.size()):
			var card: CardData = draw_pile.pop_back()
			players[player_index].add_card(card)
			initial_deal_card_ids[player_index].append(card.card_id)

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
		return _fail(&"ERROR_CANNOT_ROLL")
	if value < 1 or value > 6:
		return _fail(&"ERROR_DICE_RANGE")

	_discard_table_cards()
	dice_value = value
	last_player_index = -1
	phase = Phase.AWAITING_ACTION
	_clear_error()
	_set_event(&"EVENT_ROLLED", {"player": players[player_index].display_name, "value": value})
	_emit_public_action(&"roll", player_index, {"dice_value": value})
	state_changed.emit()
	return true


func play_cards(
	player_index: int,
	card_ids: Array[int],
	interpretation_key: String = "",
) -> bool:
	if not _can_current_player_act(player_index):
		return false
	if phase != Phase.AWAITING_ACTION:
		return _fail(&"ERROR_CANNOT_PLAY")
	if card_ids.is_empty():
		return _fail(&"ERROR_SELECT_CARDS")
	if not players[player_index].has_cards(card_ids):
		return _fail(&"ERROR_CARDS_NOT_IN_HAND")

	if last_play_pattern == null and not is_bonus and card_ids.size() != dice_value:
		return _fail(&"ERROR_CARD_COUNT")
	var interpretations := get_legal_interpretations(player_index, card_ids)
	if interpretations.is_empty():
		return _fail(
			&"ERROR_CANNOT_COVER" if last_play_pattern != null else &"ERROR_INVALID_HAND"
		)
	var selected_pattern := interpretations[0]
	if not interpretation_key.is_empty():
		selected_pattern = null
		for pattern in interpretations:
			if pattern.get_key() == interpretation_key:
				selected_pattern = pattern
				break
		if selected_pattern == null:
			return _fail(&"ERROR_INVALID_INTERPRETATION")

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

	_clear_error()
	_set_event(
		&"EVENT_PLAYED",
		{
			"player": players[player_index].display_name,
			"hand_type": selected_pattern.get_translation_key(),
		},
	)
	_emit_public_action(
		&"play",
		player_index,
		{
			"cards": _cards_to_snapshots(played_cards),
			"interpretation_key": selected_pattern.get_key(),
		},
	)

	# Victory is resolved only after a confirmed play changes the hand.
	if players[player_index].hand.is_empty():
		if selected_pattern.uses_wildcard and rules.draw_two_on_wildcard_finish:
			var drawn_count := draw_cards(player_index, JOKER_FINISH_DRAW_COUNT)
			_set_event(
				&"EVENT_JOKER_PENALTY",
				{"player": players[player_index].display_name, "count": drawn_count},
			)
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
		return _fail(&"ERROR_CANNOT_PASS")

	if is_bonus and last_play_pattern == null:
		return _fail(&"ERROR_BONUS_MUST_PLAY")

	_clear_error()
	_set_event(&"EVENT_PASSED", {"player": players[player_index].display_name})

	if last_play_pattern == null:
		_round_pass_count += 1
		if _round_pass_count >= players.size():
			var previous_roller := roller_index
			var draw_count := (
				maxi(0, 7 - dice_value)
				if rules.draw_count_uses_dice
				else PASS_DRAW_COUNT
			)
			var drawn_count := draw_cards(previous_roller, draw_count)
			_set_event(
				&"EVENT_ALL_PASSED",
				{"player": players[previous_roller].display_name, "count": drawn_count},
			)
			_begin_new_round(_next_player(previous_roller))
			_emit_public_action(&"pass", player_index)
			state_changed.emit()
			return true
		else:
			current_player_index = _next_player(player_index)
		_emit_public_action(&"pass", player_index)
		state_changed.emit()
		return true

	_passes_since_play += 1
	if _passes_since_play >= players.size() - 1:
		if _bonus_candidate and last_player_index == roller_index and not is_bonus:
			_start_bonus()
		else:
			var next_roller := last_player_index
			_set_event(&"EVENT_NEXT_ROLLER", {"player": players[next_roller].display_name})
			_begin_new_round(next_roller)
	else:
		current_player_index = _next_player(player_index)
	_emit_public_action(&"pass", player_index)
	state_changed.emit()
	return true


func get_pass_draw_count(player_index: int) -> int:
	if (
		phase != Phase.AWAITING_ACTION
		or player_index != current_player_index
		or last_play_pattern != null
		or _round_pass_count < players.size() - 1
	):
		return 0
	return maxi(0, 7 - dice_value) if rules.draw_count_uses_dice else PASS_DRAW_COUNT


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
		return LegalMoveFinder.find_play(
			hand,
			last_play_pattern.card_count,
			last_play_pattern,
			rules,
		)
	if is_bonus:
		return LegalMoveFinder.find_bonus_play(hand, rules)
	return LegalMoveFinder.find_play(hand, dice_value, null, rules)


func get_legal_interpretations(
	player_index: int,
	card_ids: Array[int],
) -> Array[HandPattern]:
	var results: Array[HandPattern] = []
	if (
		phase != Phase.AWAITING_ACTION
		or player_index != current_player_index
		or player_index < 0
		or player_index >= players.size()
		or card_ids.is_empty()
		or not players[player_index].has_cards(card_ids)
	):
		return results
	if last_play_pattern == null and not is_bonus and card_ids.size() != dice_value:
		return results

	var cards := _find_cards(players[player_index], card_ids)
	for pattern in HandEvaluator.get_distinct_interpretations(cards, rules):
		if last_play_pattern == null or HandEvaluator.beats(pattern, last_play_pattern):
			results.append(pattern)
	return results


func create_strategy_context(player_index: int) -> StrategyContext:
	if player_index < 0 or player_index >= players.size():
		return null
	var context := StrategyContext.new()
	context.player_index = player_index
	context.phase = (
		StrategyContext.PHASE_ROLL
		if phase == Phase.AWAITING_ROLL
		else StrategyContext.PHASE_ACTION
	)
	for card in players[player_index].hand:
		context.own_hand.append(card.clone())
	for index in range(players.size()):
		context.player_summaries.append(
			{
				"player_index": index,
				"display_name_key": players[index].display_name,
				"hand_count": players[index].hand.size(),
				"is_current": index == current_player_index,
				"is_roller": index == roller_index,
			}
		)
	context.draw_pile_count = draw_pile.size()
	context.discard_pile_count = discard_pile.size()
	context.dice_value = dice_value
	context.is_bonus = is_bonus
	context.roller_index = roller_index
	context.last_player_index = last_player_index
	context.target_pattern = last_play_pattern.clone() if last_play_pattern != null else null
	context.rules = rules.clone()
	for card in last_played_cards:
		context.visible_table_cards.append(card.clone())
	return context


func get_total_card_count() -> int:
	var total := draw_pile.size() + discard_pile.size() + last_played_cards.size()
	for player in players:
		total += player.hand.size()
	return total


func to_snapshot() -> Dictionary:
	var player_snapshots: Array[Dictionary] = []
	for player in players:
		player_snapshots.append({
			"player_id": player.player_id,
			"display_name": player.display_name,
			"hand": _cards_to_snapshots(player.hand),
		})
	var deal_order: Array[Array] = []
	for player_order in initial_deal_card_ids:
		var ids: Array = []
		for card_id in player_order:
			ids.append(card_id)
		deal_order.append(ids)
	return {
		"rules": _rules_to_snapshot(rules),
		"players": player_snapshots,
		"draw_pile": _cards_to_snapshots(draw_pile),
		"discard_pile": _cards_to_snapshots(discard_pile),
		"last_played_cards": _cards_to_snapshots(last_played_cards),
		"last_play_pattern": _pattern_to_snapshot(last_play_pattern),
		"current_player_index": current_player_index,
		"roller_index": roller_index,
		"last_player_index": last_player_index,
		"played_by_index": played_by_index,
		"dice_value": dice_value,
		"winner_index": winner_index,
		"phase": phase,
		"is_bonus": is_bonus,
		"game_seed": str(game_seed),
		"seed_text": game_seed_text,
		"rng_seed": str(_random_source.seed),
		"rng_state": str(_random_source.state),
		"passes_since_play": _passes_since_play,
		"round_pass_count": _round_pass_count,
		"bonus_candidate": _bonus_candidate,
		"event_key": str(event_key),
		"event_args": event_args.duplicate(true),
		"initial_deal_card_ids": deal_order,
	}


func restore_from_snapshot(snapshot: Dictionary) -> bool:
	var player_values_value: Variant = snapshot.get("players", null)
	var rules_value: Variant = snapshot.get("rules", null)
	if player_values_value is not Array or rules_value is not Dictionary:
		return false
	var player_values := player_values_value as Array
	if player_values.size() < 2 or player_values.size() > 4:
		return false
	var loaded_rules := _rules_from_snapshot(rules_value as Dictionary)
	var loaded_players: Array[PlayerState] = []
	var player_ids := {}
	for player_value in player_values:
		if player_value is not Dictionary:
			return false
		var player_snapshot := player_value as Dictionary
		var player_id := int(player_snapshot.get("player_id", -1))
		var hand_value: Variant = player_snapshot.get("hand", null)
		if hand_value is not Array:
			return false
		var hand_snapshots := hand_value as Array
		if player_id < 0 or player_id >= player_values.size() or player_ids.has(player_id):
			return false
		if not _are_card_snapshots_structurally_valid(hand_snapshots):
			return false
		player_ids[player_id] = true
		var player := PlayerState.new(
			player_id,
			str(player_snapshot.get("display_name", "")),
		)
		player.hand.assign(_cards_from_snapshots(hand_snapshots))
		loaded_players.append(player)

	var draw_value: Variant = snapshot.get("draw_pile", null)
	var discard_value: Variant = snapshot.get("discard_pile", null)
	var table_value: Variant = snapshot.get("last_played_cards", null)
	if draw_value is not Array or discard_value is not Array or table_value is not Array:
		return false
	var draw_snapshots := draw_value as Array
	var discard_snapshots := discard_value as Array
	var table_snapshots := table_value as Array
	if (
		not _are_card_snapshots_structurally_valid(draw_snapshots)
		or not _are_card_snapshots_structurally_valid(discard_snapshots)
		or not _are_card_snapshots_structurally_valid(table_snapshots)
	):
		return false
	var loaded_draw_pile := _cards_from_snapshots(draw_snapshots)
	var loaded_discard_pile := _cards_from_snapshots(discard_snapshots)
	var loaded_table_cards := _cards_from_snapshots(table_snapshots)
	var expected_count := 108 if loaded_rules.include_jokers else 104
	var canonical_cards := {}
	for card in DeckFactory.create_two_deck(loaded_rules.include_jokers):
		canonical_cards[card.card_id] = card
	var card_ids := {}
	var total_count := 0
	for card_list in [loaded_draw_pile, loaded_discard_pile, loaded_table_cards]:
		for card in card_list:
			if not _is_canonical_card(card, canonical_cards) or card_ids.has(card.card_id):
				return false
			card_ids[card.card_id] = true
			total_count += 1
	for player in loaded_players:
		for card in player.hand:
			if not _is_canonical_card(card, canonical_cards) or card_ids.has(card.card_id):
				return false
			card_ids[card.card_id] = true
			total_count += 1
	if total_count != expected_count:
		return false

	var pattern_snapshot: Variant = snapshot.get("last_play_pattern", null)
	var loaded_pattern := _pattern_from_snapshot(pattern_snapshot)
	if pattern_snapshot != null and loaded_pattern == null:
		return false
	if not _is_valid_table_pattern(loaded_table_cards, loaded_pattern, loaded_rules):
		return false

	var loaded_phase := int(snapshot.get("phase", Phase.READY))
	var loaded_current := int(snapshot.get("current_player_index", 0))
	var loaded_roller := int(snapshot.get("roller_index", 0))
	var loaded_last_player := int(snapshot.get("last_player_index", -1))
	var loaded_played_by := int(snapshot.get("played_by_index", -1))
	var loaded_dice := int(snapshot.get("dice_value", 0))
	var loaded_winner := int(snapshot.get("winner_index", -1))
	var loaded_passes := int(snapshot.get("passes_since_play", 0))
	var loaded_round_passes := int(snapshot.get("round_pass_count", 0))
	var player_count := loaded_players.size()
	if (
		loaded_phase < Phase.READY
		or loaded_phase > Phase.FINISHED
		or loaded_current < 0
		or loaded_current >= loaded_players.size()
		or loaded_roller < 0
		or loaded_roller >= player_count
		or not _is_optional_player_index(loaded_last_player, player_count)
		or not _is_optional_player_index(loaded_played_by, player_count)
		or not _is_optional_player_index(loaded_winner, player_count)
		or loaded_passes < 0
		or loaded_passes >= player_count
		or loaded_round_passes < 0
		or loaded_round_passes >= player_count
	):
		return false
	if loaded_phase == Phase.AWAITING_ACTION or loaded_phase == Phase.FINISHED:
		if loaded_dice < 1 or loaded_dice > 6:
			return false
	elif loaded_dice != 0:
		return false
	if (loaded_phase == Phase.FINISHED) != (loaded_winner != -1):
		return false
	if not loaded_table_cards.is_empty() and loaded_played_by == -1:
		return false
	if loaded_table_cards.is_empty() and loaded_played_by != -1:
		return false
	if bool(snapshot.get("is_bonus", false)) and loaded_phase != Phase.AWAITING_ACTION:
		return false
	var event_args_value: Variant = snapshot.get("event_args", {})
	if event_args_value is not Dictionary:
		return false
	var loaded_event_args := (event_args_value as Dictionary).duplicate(true)
	var deal_orders_value: Variant = snapshot.get("initial_deal_card_ids", [])
	if deal_orders_value is not Array:
		return false
	var loaded_deal_orders: Array[PackedInt32Array] = []
	for order_value in deal_orders_value as Array:
		if order_value is not Array:
			return false
		var order := PackedInt32Array()
		for card_id in order_value as Array:
			order.append(int(card_id))
		loaded_deal_orders.append(order)
	if loaded_deal_orders.size() > player_count:
		return false

	rules = loaded_rules
	players.assign(loaded_players)
	draw_pile.assign(loaded_draw_pile)
	discard_pile.assign(loaded_discard_pile)
	last_played_cards.assign(loaded_table_cards)
	last_play_pattern = loaded_pattern
	current_player_index = loaded_current
	roller_index = loaded_roller
	last_player_index = loaded_last_player
	played_by_index = loaded_played_by
	dice_value = loaded_dice
	winner_index = loaded_winner
	phase = loaded_phase as Phase
	is_bonus = bool(snapshot.get("is_bonus", false))
	game_seed = int(str(snapshot.get("game_seed", "0")))
	var loaded_seed_text := str(snapshot.get("seed_text", ""))
	game_seed_text = (
		SeedCodec.sanitize(loaded_seed_text)
		if SeedCodec.is_valid(loaded_seed_text)
		else SeedCodec.from_int(game_seed)
	)
	_random_source.seed = int(str(snapshot.get("rng_seed", str(game_seed))))
	_random_source.state = int(str(snapshot.get("rng_state", str(_random_source.state))))
	_passes_since_play = loaded_passes
	_round_pass_count = loaded_round_passes
	_bonus_candidate = bool(snapshot.get("bonus_candidate", false))
	event_key = StringName(str(snapshot.get("event_key", "")))
	event_args = loaded_event_args
	last_error_key = &""
	last_error_args.clear()
	initial_deal_card_ids.assign(loaded_deal_orders)
	while initial_deal_card_ids.size() < players.size():
		initial_deal_card_ids.append(PackedInt32Array())
	return true


func _start_bonus() -> void:
	_discard_table_cards()
	current_player_index = roller_index
	is_bonus = true
	_bonus_candidate = false
	_passes_since_play = 0
	_round_pass_count = 0
	_set_event(&"EVENT_BONUS", {"player": players[roller_index].display_name})


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
	_set_event(&"EVENT_WINNER", {"player": players[player_index].display_name})
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
		return _fail(&"ERROR_GAME_FINISHED")
	if player_index < 0 or player_index >= players.size():
		return _fail(&"ERROR_PLAYER_NOT_FOUND")
	if player_index != current_player_index:
		return _fail(&"ERROR_NOT_PLAYER_TURN")
	return true


func _fail(key: StringName, args: Dictionary = {}) -> bool:
	last_error_key = key
	last_error_args = args.duplicate(true)
	return false


func _clear_error() -> void:
	last_error_key = &""
	last_error_args.clear()


func _set_event(key: StringName, args: Dictionary = {}) -> void:
	event_key = key
	event_args = args.duplicate(true)


func _emit_public_action(
	action_type: StringName,
	player_index: int,
	extra: Dictionary = {},
) -> void:
	var action := {
		"type": action_type,
		"player_index": player_index,
		"hand_count": players[player_index].hand.size(),
	}
	action.merge(extra, true)
	action_resolved.emit(action)


func _cards_to_snapshots(cards: Array[CardData]) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for card in cards:
		snapshots.append(
			{
				"card_id": card.card_id,
				"rank": card.rank,
				"suit": card.suit,
				"joker_kind": card.joker_kind,
				"deck_index": card.deck_index,
			}
		)
	return snapshots


func _cards_from_snapshots(snapshots: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	for value in snapshots:
		if value is not Dictionary:
			continue
		var card := value as Dictionary
		cards.append(CardData.new(
			int(card.get("card_id", -1)),
			int(card.get("rank", 0)),
			int(card.get("suit", CardData.Suit.NONE)),
			int(card.get("joker_kind", CardData.JokerKind.NONE)),
			int(card.get("deck_index", 0)),
		))
	return cards


func _are_card_snapshots_structurally_valid(snapshots: Array) -> bool:
	for value in snapshots:
		if value is not Dictionary:
			return false
	return true


func _is_canonical_card(card: CardData, canonical_cards: Dictionary) -> bool:
	var expected := canonical_cards.get(card.card_id) as CardData
	return (
		expected != null
		and card.rank == expected.rank
		and card.suit == expected.suit
		and card.joker_kind == expected.joker_kind
		and card.deck_index == expected.deck_index
	)


func _is_valid_table_pattern(
	table_cards: Array[CardData],
	pattern: HandPattern,
	loaded_rules: GameRules,
) -> bool:
	if table_cards.is_empty():
		return pattern == null
	if pattern == null or pattern.card_count != table_cards.size():
		return false
	for candidate in HandEvaluator.evaluate_all(table_cards, loaded_rules):
		if (
			candidate.get_key() == pattern.get_key()
			and candidate.contains_joker == pattern.contains_joker
		):
			return true
	return false


func _is_optional_player_index(value: int, player_count: int) -> bool:
	return value == -1 or (value >= 0 and value < player_count)


func _rules_to_snapshot(value: GameRules) -> Dictionary:
	return {
		"include_jokers": value.include_jokers,
		"jokers_are_wild": value.jokers_are_wild,
		"draw_two_on_wildcard_finish": value.draw_two_on_wildcard_finish,
		"allow_two_in_sequences": value.allow_two_in_sequences,
		"draw_count_uses_dice": value.draw_count_uses_dice,
	}


func _rules_from_snapshot(snapshot: Dictionary) -> GameRules:
	var value := GameRules.new()
	value.include_jokers = bool(snapshot.get("include_jokers", true))
	value.jokers_are_wild = bool(snapshot.get("jokers_are_wild", true))
	value.draw_two_on_wildcard_finish = bool(
		snapshot.get("draw_two_on_wildcard_finish", true),
	)
	value.allow_two_in_sequences = bool(snapshot.get("allow_two_in_sequences", false))
	value.draw_count_uses_dice = bool(snapshot.get("draw_count_uses_dice", false))
	return value


func _pattern_to_snapshot(pattern: HandPattern) -> Variant:
	if pattern == null:
		return null
	return {
		"type": pattern.type,
		"card_count": pattern.card_count,
		"main_rank": pattern.main_rank,
		"contains_joker": pattern.contains_joker,
		"uses_wildcard": pattern.uses_wildcard,
	}


func _pattern_from_snapshot(value: Variant) -> HandPattern:
	if value is not Dictionary:
		return null
	var pattern := value as Dictionary
	var type_value := int(pattern.get("type", -1))
	var card_count := int(pattern.get("card_count", 0))
	var main_rank := int(pattern.get("main_rank", 0))
	if (
		type_value < HandPattern.Type.SINGLE
		or type_value > HandPattern.Type.TRIPLE_WITH_TRIPLE
		or card_count < 1
		or card_count > 6
		or main_rank < CardData.Rank.THREE
		or main_rank > CardData.JokerKind.BIG + CardData.Rank.TWO
	):
		return null
	return HandPattern.new(
		type_value as HandPattern.Type,
		card_count,
		main_rank,
		bool(pattern.get("contains_joker", false)),
		bool(pattern.get("uses_wildcard", false)),
	)
