class_name LegalMoveFinder
extends RefCounted


static func find_play(
	hand: Array[CardData],
	card_count: int,
	target: HandPattern = null,
) -> Array[int]:
	if card_count < 1 or card_count > 6 or hand.size() < card_count:
		return []
	var chosen: Array[CardData] = []
	var result: Array[int] = []
	_find_combination(hand, card_count, target, 0, chosen, result)
	return result


static func find_bonus_play(hand: Array[CardData]) -> Array[int]:
	for card_count in range(mini(6, hand.size()), 0, -1):
		var result := find_play(hand, card_count)
		if not result.is_empty():
			return result
	return []


static func _find_combination(
	hand: Array[CardData],
	remaining: int,
	target: HandPattern,
	start_index: int,
	chosen: Array[CardData],
	result: Array[int],
) -> bool:
	if remaining == 0:
		var pattern := (
			HandEvaluator.choose_lead_pattern(chosen)
			if target == null
			else HandEvaluator.choose_cover_pattern(chosen, target)
		)
		if pattern == null:
			return false
		for card in chosen:
			result.append(card.card_id)
		return true

	var last_start := hand.size() - remaining
	for index in range(start_index, last_start + 1):
		chosen.append(hand[index])
		if _find_combination(hand, remaining - 1, target, index + 1, chosen, result):
			return true
		chosen.pop_back()
	return false
