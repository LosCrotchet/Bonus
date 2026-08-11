class_name DefaultStrategy
extends PlayerStrategy

const WIN_SCORE := 100000.0
const BREAK_PASS_THRESHOLD := 22.0
const ROLLER_BREAK_PASS_THRESHOLD := 28.0

var _seen_card_ids: Dictionary = {}
var _seen_rank_counts: Dictionary = {}
var _memory_initialized := false
var _last_draw_pile_count := -1
var _last_discard_pile_count := -1


func get_strategy_id() -> StringName:
	return &"default"


func get_display_name_key() -> StringName:
	return &"AI_STRATEGY_DEFAULT"


func setup(p_player_index: int, p_player_count: int) -> void:
	super.setup(p_player_index, p_player_count)
	reset()


func reset() -> void:
	_seen_card_ids.clear()
	_seen_rank_counts.clear()
	_memory_initialized = false
	_last_draw_pile_count = -1
	_last_discard_pile_count = -1


func observe_action(public_action: Dictionary) -> void:
	if StringName(str(public_action.get("type", ""))) != &"play":
		return
	for value in public_action.get("cards", []) as Array:
		if value is Dictionary:
			_remember_snapshot(value as Dictionary)


func choose_action(context: StrategyContext) -> PlayerDecision:
	_sync_public_memory(context)
	if context.phase == StrategyContext.PHASE_ROLL:
		return PlayerDecision.create_roll()

	var allowed_counts: Array[int] = []
	if context.target_pattern != null:
		allowed_counts.append(context.target_pattern.card_count)
	elif context.is_bonus:
		for card_count in range(1, mini(6, context.own_hand.size()) + 1):
			allowed_counts.append(card_count)
	else:
		allowed_counts.append(context.dice_value)

	var moves := _find_candidate_moves(context, allowed_counts)
	if moves.is_empty():
		return PlayerDecision.create_pass()

	if context.is_bonus:
		moves = _bonus_candidate_pool(moves, context)
	var best_move := _choose_best_move(moves, context)
	if best_move.is_empty():
		return PlayerDecision.create_pass()
	if not _should_play(best_move, context):
		return PlayerDecision.create_pass()

	var card_ids: Array[int] = []
	card_ids.assign(best_move.get("card_ids", []) as Array)
	var pattern := best_move.get("pattern") as HandPattern
	return PlayerDecision.create_play(card_ids, pattern.get_key())


func _find_candidate_moves(
	context: StrategyContext,
	allowed_counts: Array[int],
) -> Array[Dictionary]:
	var groups := _group_cards(context.own_hand)
	var results: Array[Dictionary] = []
	for card_count in allowed_counts:
		if card_count < 1 or card_count > 6 or card_count > context.own_hand.size():
			continue
		var chosen: Array[CardData] = []
		_enumerate_group_choices(
			groups,
			0,
			card_count,
			chosen,
			context,
			results,
		)
	return results


func _group_cards(hand: Array[CardData]) -> Array[Array]:
	var cards_by_rank: Dictionary = {}
	for card in hand:
		var rank := card.get_natural_rank()
		if not cards_by_rank.has(rank):
			cards_by_rank[rank] = []
		(cards_by_rank[rank] as Array).append(card)

	var ranks: Array[int] = []
	for value in cards_by_rank.keys():
		ranks.append(int(value))
	ranks.sort()
	var groups: Array[Array] = []
	for rank in ranks:
		var group: Array[CardData] = []
		group.assign(cards_by_rank[rank] as Array)
		groups.append(group)
	return groups


func _enumerate_group_choices(
	groups: Array[Array],
	group_index: int,
	remaining: int,
	chosen: Array[CardData],
	context: StrategyContext,
	results: Array[Dictionary],
) -> void:
	if remaining == 0:
		_append_interpreted_moves(chosen, context, results)
		return
	if group_index >= groups.size():
		return

	var available_after := 0
	for index in range(group_index, groups.size()):
		available_after += groups[index].size()
	if available_after < remaining:
		return

	var group: Array[CardData] = []
	group.assign(groups[group_index])
	var maximum_take := mini(remaining, group.size())
	for take_count in range(maximum_take + 1):
		for card_index in range(take_count):
			chosen.append(group[card_index])
		_enumerate_group_choices(
			groups,
			group_index + 1,
			remaining - take_count,
			chosen,
			context,
			results,
		)
		for _card_index in range(take_count):
			chosen.pop_back()


func _append_interpreted_moves(
	cards: Array[CardData],
	context: StrategyContext,
	results: Array[Dictionary],
) -> void:
	for pattern in HandEvaluator.get_distinct_interpretations(cards, context.rules):
		if (
			context.target_pattern != null
			and not HandEvaluator.beats(pattern, context.target_pattern)
		):
			continue
		var card_ids: Array[int] = []
		for card in cards:
			card_ids.append(card.card_id)
		results.append({
			"card_ids": card_ids,
			"cards": cards.duplicate(),
			"pattern": pattern,
		})


func _bonus_candidate_pool(
	moves: Array[Dictionary],
	context: StrategyContext,
) -> Array[Dictionary]:
	var winning: Array[Dictionary] = []
	for move in moves:
		if _is_winning_move(move, context):
			winning.append(move)
	if not winning.is_empty():
		return winning

	# BONUS is the best time to remove a genuinely loose card without damaging a set.
	var isolated_singles: Array[Dictionary] = []
	for move in moves:
		if _is_isolated_single_move(move, context.own_hand):
			isolated_singles.append(move)
	return isolated_singles if not isolated_singles.is_empty() else moves


func _choose_best_move(
	moves: Array[Dictionary],
	context: StrategyContext,
) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for move in moves:
		var score := _score_move(move, context)
		if score > best_score or (
			is_equal_approx(score, best_score)
			and _is_deterministic_tiebreak_winner(move, best)
		):
			best = move
			best_score = score
	return best


func _score_move(move: Dictionary, context: StrategyContext) -> float:
	if _is_winning_move(move, context):
		return WIN_SCORE

	var cards := _move_cards(move)
	var pattern := move.get("pattern") as HandPattern
	var remaining := _remaining_hand(context.own_hand, cards)
	var breakage := _breakage_cost(context.own_hand, cards, pattern)
	var score := float(cards.size()) * 16.0
	score += _shape_score(remaining) * 1.4
	score -= breakage

	var joker_count := _joker_count(cards)
	score -= float(joker_count) * 18.0
	if pattern.uses_wildcard:
		score -= 8.0

	var urgent := _has_opponent_threat(context)
	var cover_risk := _estimate_cover_risk(pattern, context)
	if context.is_bonus:
		score += float(cards.size()) * 10.0
		score += float(pattern.main_rank) * 0.35
		score += (1.0 - cover_risk) * 8.0
	elif context.target_pattern != null:
		var overkill := maxi(0, pattern.main_rank - context.target_pattern.main_rank)
		score -= float(overkill) * (0.45 if urgent else 1.6)
		score += (1.0 - cover_risk) * (30.0 if urgent else 7.0)
		score -= cover_risk * (12.0 if urgent else 5.0)
	else:
		score += (1.0 - cover_risk) * (
			12.0 if context.player_index == context.roller_index else 4.0
		)
		score += float(pattern.main_rank) * 0.25
		if context.player_index != context.roller_index:
			score -= 18.0
	return score


func _should_play(move: Dictionary, context: StrategyContext) -> bool:
	if context.is_bonus or _is_winning_move(move, context):
		return true

	var cards := _move_cards(move)
	var pattern := move.get("pattern") as HandPattern
	var remaining_count := context.own_hand.size() - cards.size()
	var breakage := _breakage_cost(context.own_hand, cards, pattern)
	var joker_count := _joker_count(cards)
	var urgent := _has_opponent_threat(context)

	if context.target_pattern == null:
		# When another player passed their roll, taking the same dice value usually does
		# not improve our next-round position. Only intervene for a concrete tempo gain.
		if context.player_index != context.roller_index:
			if urgent:
				return breakage <= BREAK_PASS_THRESHOLD or remaining_count <= 2
			return remaining_count <= 1 and breakage < BREAK_PASS_THRESHOLD

		if remaining_count <= 2:
			return true
		if breakage >= ROLLER_BREAK_PASS_THRESHOLD:
			return false
		if joker_count > 0 and context.own_hand.size() > 6:
			return false
		return true

	if urgent:
		return breakage <= 36.0 or remaining_count <= 3
	if remaining_count <= 2 and breakage < BREAK_PASS_THRESHOLD:
		return true
	if breakage >= BREAK_PASS_THRESHOLD:
		return false
	if joker_count > 0 and context.own_hand.size() > 5:
		return false
	return _estimate_cover_risk(pattern, context) <= 0.78 or breakage <= 4.0


func _breakage_cost(
	hand: Array[CardData],
	played: Array[CardData],
	pattern: HandPattern,
) -> float:
	var hand_counts := _ordinary_rank_counts(hand)
	var played_counts := _ordinary_rank_counts(played)
	var cost := 0.0
	for value in played_counts.keys():
		var rank := int(value)
		var total := int(hand_counts.get(rank, 0))
		var used := int(played_counts[rank])
		var left := total - used
		if left == 1 and total >= 2:
			cost += 24.0 + float(maxi(0, total - 2)) * 5.0
		elif left > 0:
			cost += 7.0

		if left == 0 and pattern.type not in [
			HandPattern.Type.STRAIGHT,
			HandPattern.Type.PAIR_STRAIGHT,
		]:
			for neighbor in [rank - 1, rank + 1]:
				if neighbor < CardData.Rank.THREE or neighbor > CardData.Rank.ACE:
					continue
				var neighbor_count := int(hand_counts.get(neighbor, 0))
				if total >= 2 and neighbor_count >= 2:
					cost += 9.0
				elif total >= 1 and neighbor_count >= 1:
					cost += 3.0
	return cost


func _shape_score(cards: Array[CardData]) -> float:
	var counts := _ordinary_rank_counts(cards)
	var score := float(_joker_count(cards)) * 8.0
	for value in counts.values():
		var count := int(value)
		match count:
			1:
				score -= 1.5
			2:
				score += 5.0
			3:
				score += 11.0
			4:
				score += 18.0
			_:
				score += 18.0 + float(count - 4) * 7.0

	for rank in range(CardData.Rank.THREE, CardData.Rank.ACE):
		var count := int(counts.get(rank, 0))
		var next_count := int(counts.get(rank + 1, 0))
		if count > 0 and next_count > 0:
			score += float(mini(count, next_count)) * 2.0
		if (
			rank <= CardData.Rank.ACE - 2
			and count > 0
			and next_count > 0
			and int(counts.get(rank + 2, 0)) > 0
		):
			score += 3.0
	return score


func _estimate_cover_risk(pattern: HandPattern, context: StrategyContext) -> float:
	var opponent_cards := 0
	for summary in context.player_summaries:
		if int(summary.get("player_index", -1)) != context.player_index:
			opponent_cards += int(summary.get("hand_count", 0))
	if opponent_cards <= 0:
		return 0.0

	var unknown_pool := opponent_cards + context.draw_pile_count
	var opponent_share := float(opponent_cards) / float(maxi(1, unknown_pool))
	var required := _core_rank_count(pattern)
	var maximum_rank := (
		CardData.Rank.ACE
		if pattern.type in [HandPattern.Type.STRAIGHT, HandPattern.Type.PAIR_STRAIGHT]
		else CardData.Rank.TWO
	)
	var opportunities := 0.0
	for rank in range(pattern.main_rank + 1, maximum_rank + 1):
		var available := _remaining_unseen_count(rank, context)
		if available < required:
			continue
		var expected_in_hands := float(available) * opponent_share
		opportunities += clampf(
			pow(expected_in_hands / float(maxi(1, required)), required),
			0.0,
			1.0,
		)

	if pattern.type == HandPattern.Type.SINGLE and context.rules.include_jokers:
		for joker_rank in [16, 17]:
			if joker_rank <= pattern.main_rank:
				continue
			var available := _remaining_unseen_count(joker_rank, context)
			opportunities += clampf(float(available) * opponent_share, 0.0, 1.0)

	# A natural full-kind can cover any non-full pattern with four to six cards.
	if pattern.card_count >= 4 and not pattern.is_full_kind():
		for rank in range(CardData.Rank.THREE, CardData.Rank.TWO + 1):
			var available := _remaining_unseen_count(rank, context)
			if available >= pattern.card_count:
				var expected_in_hands := float(available) * opponent_share
				opportunities += clampf(
					pow(expected_in_hands / float(pattern.card_count), pattern.card_count),
					0.0,
					1.0,
				)
	return clampf(1.0 - exp(-opportunities * 0.65), 0.0, 0.97)


func _core_rank_count(pattern: HandPattern) -> int:
	match pattern.type:
		HandPattern.Type.PAIR, HandPattern.Type.PAIR_STRAIGHT:
			return 2
		HandPattern.Type.TRIPLE, HandPattern.Type.TRIPLE_WITH_ONE, HandPattern.Type.TRIPLE_WITH_PAIR, HandPattern.Type.TRIPLE_WITH_TRIPLE:
			return 3
		HandPattern.Type.FOUR_KIND, HandPattern.Type.FOUR_WITH_ONE, HandPattern.Type.FOUR_WITH_TWO:
			return 4
		HandPattern.Type.FIVE_KIND, HandPattern.Type.FIVE_WITH_ONE:
			return 5
		HandPattern.Type.SIX_KIND:
			return 6
	return 1


func _remaining_unseen_count(rank: int, context: StrategyContext) -> int:
	var total := 8
	if rank in [16, 17]:
		total = 2 if context.rules.include_jokers else 0
	var own_count := 0
	for card in context.own_hand:
		if card.get_natural_rank() == rank:
			own_count += 1
	return maxi(0, total - own_count - int(_seen_rank_counts.get(rank, 0)))


func _has_opponent_threat(context: StrategyContext) -> bool:
	for summary in context.player_summaries:
		if (
			int(summary.get("player_index", -1)) != context.player_index
			and int(summary.get("hand_count", 99)) <= 2
		):
			return true
	return false


func _is_winning_move(move: Dictionary, context: StrategyContext) -> bool:
	var cards := _move_cards(move)
	if cards.size() != context.own_hand.size():
		return false
	var pattern := move.get("pattern") as HandPattern
	return not (
		pattern.uses_wildcard
		and context.rules.draw_two_on_wildcard_finish
	)


func _is_isolated_single_move(
	move: Dictionary,
	hand: Array[CardData],
) -> bool:
	var cards := _move_cards(move)
	if cards.size() != 1 or cards[0].is_joker():
		return false
	var rank := cards[0].rank
	var counts := _ordinary_rank_counts(hand)
	if int(counts.get(rank, 0)) != 1:
		return false
	if rank > CardData.Rank.THREE and int(counts.get(rank - 1, 0)) > 0:
		return false
	if rank < CardData.Rank.ACE and int(counts.get(rank + 1, 0)) > 0:
		return false
	return true


func _ordinary_rank_counts(cards: Array[CardData]) -> Dictionary:
	var counts: Dictionary = {}
	for card in cards:
		if not card.is_joker():
			counts[card.rank] = int(counts.get(card.rank, 0)) + 1
	return counts


func _joker_count(cards: Array[CardData]) -> int:
	var count := 0
	for card in cards:
		if card.is_joker():
			count += 1
	return count


func _remaining_hand(
	hand: Array[CardData],
	played: Array[CardData],
) -> Array[CardData]:
	var played_ids: Dictionary = {}
	for card in played:
		played_ids[card.card_id] = true
	var remaining: Array[CardData] = []
	for card in hand:
		if not played_ids.has(card.card_id):
			remaining.append(card)
	return remaining


func _move_cards(move: Dictionary) -> Array[CardData]:
	var cards: Array[CardData] = []
	cards.assign(move.get("cards", []) as Array)
	return cards


func _is_deterministic_tiebreak_winner(
	candidate: Dictionary,
	incumbent: Dictionary,
) -> bool:
	if incumbent.is_empty():
		return true
	var candidate_ids: Array = candidate.get("card_ids", []) as Array
	var incumbent_ids: Array = incumbent.get("card_ids", []) as Array
	for index in range(mini(candidate_ids.size(), incumbent_ids.size())):
		if int(candidate_ids[index]) != int(incumbent_ids[index]):
			return int(candidate_ids[index]) < int(incumbent_ids[index])
	return candidate_ids.size() < incumbent_ids.size()


func _sync_public_memory(context: StrategyContext) -> void:
	if (
		_memory_initialized
		and context.discard_pile_count < _last_discard_pile_count
		and context.draw_pile_count > _last_draw_pile_count
	):
		# Discarded cards have re-entered the draw pile and are no longer unavailable.
		_seen_card_ids.clear()
		_seen_rank_counts.clear()
	for card in context.visible_table_cards:
		_remember_card(card)
	_memory_initialized = true
	_last_draw_pile_count = context.draw_pile_count
	_last_discard_pile_count = context.discard_pile_count


func _remember_snapshot(snapshot: Dictionary) -> void:
	var card_id := int(snapshot.get("card_id", -1))
	if card_id < 0 or _seen_card_ids.has(card_id):
		return
	var joker_kind := int(snapshot.get("joker_kind", CardData.JokerKind.NONE))
	var rank := int(snapshot.get("rank", 0))
	if joker_kind == CardData.JokerKind.SMALL:
		rank = 16
	elif joker_kind == CardData.JokerKind.BIG:
		rank = 17
	_seen_card_ids[card_id] = true
	_seen_rank_counts[rank] = int(_seen_rank_counts.get(rank, 0)) + 1


func _remember_card(card: CardData) -> void:
	if _seen_card_ids.has(card.card_id):
		return
	var rank := card.get_natural_rank()
	_seen_card_ids[card.card_id] = true
	_seen_rank_counts[rank] = int(_seen_rank_counts.get(rank, 0)) + 1
