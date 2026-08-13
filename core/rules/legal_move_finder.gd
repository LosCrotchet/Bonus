class_name LegalMoveFinder
extends RefCounted


static func find_play(
	hand: Array[CardData],
	card_count: int,
	target: HandPattern = null,
	game_rules: GameRules = null,
) -> Array[int]:
	if card_count < 1 or card_count > 6 or hand.size() < card_count:
		return []
	var groups := _group_equivalent_cards(hand)
	var chosen: Array[CardData] = []
	var result: Array[int] = []
	_find_group_combination(groups, card_count, target, game_rules, 0, chosen, result)
	return result


static func find_bonus_play(
	hand: Array[CardData],
	game_rules: GameRules = null,
) -> Array[int]:
	for card_count in range(mini(6, hand.size()), 0, -1):
		var result := find_play(hand, card_count, null, game_rules)
		if not result.is_empty():
			return result
	return []


static func _find_group_combination(
	groups: Array[Array],
	remaining: int,
	target: HandPattern,
	game_rules: GameRules,
	group_index: int,
	chosen: Array[CardData],
	result: Array[int],
) -> bool:
	if remaining == 0:
		var pattern := (
			HandEvaluator.choose_lead_pattern(chosen, game_rules)
			if target == null
			else HandEvaluator.choose_cover_pattern(chosen, target, game_rules)
		)
		if pattern == null:
			return false
		for card in chosen:
			result.append(card.card_id)
		return true

	if group_index >= groups.size():
		return false
	var group := groups[group_index]
	var maximum_take := mini(remaining, group.size())
	for take_count in range(maximum_take, -1, -1):
		if remaining - take_count > _remaining_capacity(groups, group_index + 1):
			continue
		for card_index in range(take_count):
			chosen.append(group[card_index] as CardData)
		if _find_group_combination(
			groups,
			remaining - take_count,
			target,
			game_rules,
			group_index + 1,
			chosen,
			result,
		):
			return true
		for _card_index in range(take_count):
			chosen.pop_back()
	return false


static func _group_equivalent_cards(hand: Array[CardData]) -> Array[Array]:
	var cards_by_rank := {}
	for card in hand:
		var key := card.get_natural_rank()
		if not cards_by_rank.has(key):
			cards_by_rank[key] = []
		(cards_by_rank[key] as Array).append(card)
	var keys: Array = cards_by_rank.keys()
	keys.sort()
	var groups: Array[Array] = []
	for key in keys:
		groups.append(cards_by_rank[key] as Array)
	return groups


static func _remaining_capacity(groups: Array[Array], start_index: int) -> int:
	var capacity := 0
	for index in range(start_index, groups.size()):
		capacity += groups[index].size()
	return capacity
