class_name HandEvaluator
extends RefCounted


static func evaluate_all(cards: Array[CardData]) -> Array[HandPattern]:
	var results: Array[HandPattern] = []
	if cards.is_empty() or cards.size() > 6:
		return results

	var ordinary_ranks: Array[int] = []
	var joker_count := 0
	for card in cards:
		if card.is_joker():
			joker_count += 1
		else:
			ordinary_ranks.append(card.rank)

	if joker_count == 0:
		return _classify_ranks(ordinary_ranks, false)

	var assignments: Array[Array] = []
	_generate_assignments(joker_count, CardData.Rank.THREE, [], assignments)
	var seen := {}
	for assignment in assignments:
		var ranks := ordinary_ranks.duplicate()
		for rank in assignment:
			ranks.append(rank)
		for pattern in _classify_ranks(ranks, true):
			if not seen.has(pattern.get_key()):
				seen[pattern.get_key()] = true
				results.append(pattern)

	results.sort_custom(_is_pattern_preferred)
	return results


static func choose_lead_pattern(cards: Array[CardData]) -> HandPattern:
	var patterns := evaluate_all(cards)
	return patterns[0] if not patterns.is_empty() else null


static func choose_cover_pattern(cards: Array[CardData], target: HandPattern) -> HandPattern:
	var candidates: Array[HandPattern] = []
	for pattern in evaluate_all(cards):
		if beats(pattern, target):
			candidates.append(pattern)
	if candidates.is_empty():
		return null

	# Use the least expensive legal interpretation when a wildcard has several choices.
	candidates.sort_custom(_is_weaker_pattern)
	return candidates[0]


static func beats(candidate: HandPattern, target: HandPattern) -> bool:
	if candidate == null or target == null or candidate.card_count != target.card_count:
		return false
	if candidate.is_full_kind() and not target.is_full_kind():
		return true
	if target.is_full_kind() and not candidate.is_full_kind():
		return false
	return candidate.type == target.type and candidate.main_rank > target.main_rank


static func _classify_ranks(ranks: Array[int], contains_joker: bool) -> Array[HandPattern]:
	var results: Array[HandPattern] = []
	var sorted_ranks := ranks.duplicate()
	sorted_ranks.sort()
	var frequencies := {}
	for rank in sorted_ranks:
		frequencies[rank] = frequencies.get(rank, 0) + 1

	var unique_ranks: Array[int] = []
	for rank in frequencies.keys():
		unique_ranks.append(rank)
	unique_ranks.sort()
	var card_count := sorted_ranks.size()

	match card_count:
		1:
			_add_pattern(results, HandPattern.Type.SINGLE, card_count, sorted_ranks[0], contains_joker)
		2:
			if unique_ranks.size() == 1:
				_add_pattern(results, HandPattern.Type.PAIR, card_count, unique_ranks[0], contains_joker)
		3:
			if unique_ranks.size() == 1:
				_add_pattern(results, HandPattern.Type.TRIPLE, card_count, unique_ranks[0], contains_joker)
			if _is_consecutive(unique_ranks, card_count):
				_add_pattern(results, HandPattern.Type.STRAIGHT, card_count, unique_ranks[-1], contains_joker)
		4:
			if unique_ranks.size() == 1:
				_add_pattern(results, HandPattern.Type.FOUR_KIND, card_count, unique_ranks[0], contains_joker)
			if _is_consecutive(unique_ranks, card_count):
				_add_pattern(results, HandPattern.Type.STRAIGHT, card_count, unique_ranks[-1], contains_joker)
			var triple_rank := _find_rank_with_count(frequencies, 3)
			if triple_rank != -1 and unique_ranks.size() == 2:
				_add_pattern(results, HandPattern.Type.TRIPLE_WITH_ONE, card_count, triple_rank, contains_joker)
			if unique_ranks.size() == 2 and _all_counts_equal(frequencies, 2) and _is_consecutive(unique_ranks, 2):
				_add_pattern(results, HandPattern.Type.PAIR_STRAIGHT, card_count, unique_ranks[-1], contains_joker)
		5:
			if unique_ranks.size() == 1:
				_add_pattern(results, HandPattern.Type.FIVE_KIND, card_count, unique_ranks[0], contains_joker)
			if _is_consecutive(unique_ranks, card_count):
				_add_pattern(results, HandPattern.Type.STRAIGHT, card_count, unique_ranks[-1], contains_joker)
			var four_rank := _find_rank_with_count(frequencies, 4)
			if four_rank != -1 and unique_ranks.size() == 2:
				_add_pattern(results, HandPattern.Type.FOUR_WITH_ONE, card_count, four_rank, contains_joker)
			var triple_rank := _find_rank_with_count(frequencies, 3)
			if triple_rank != -1 and _find_rank_with_count(frequencies, 2) != -1:
				_add_pattern(results, HandPattern.Type.TRIPLE_WITH_PAIR, card_count, triple_rank, contains_joker)
		6:
			if unique_ranks.size() == 1:
				_add_pattern(results, HandPattern.Type.SIX_KIND, card_count, unique_ranks[0], contains_joker)
			if _is_consecutive(unique_ranks, card_count):
				_add_pattern(results, HandPattern.Type.STRAIGHT, card_count, unique_ranks[-1], contains_joker)
			var five_rank := _find_rank_with_count(frequencies, 5)
			if five_rank != -1 and unique_ranks.size() == 2:
				_add_pattern(results, HandPattern.Type.FIVE_WITH_ONE, card_count, five_rank, contains_joker)
			var four_rank := _find_rank_with_count(frequencies, 4)
			if four_rank != -1 and unique_ranks.size() >= 2:
				_add_pattern(results, HandPattern.Type.FOUR_WITH_TWO, card_count, four_rank, contains_joker)
			if unique_ranks.size() == 2 and _all_counts_equal(frequencies, 3):
				_add_pattern(results, HandPattern.Type.TRIPLE_WITH_TRIPLE, card_count, unique_ranks[-1], contains_joker)
			if unique_ranks.size() == 3 and _all_counts_equal(frequencies, 2) and _is_consecutive(unique_ranks, 3):
				_add_pattern(results, HandPattern.Type.PAIR_STRAIGHT, card_count, unique_ranks[-1], contains_joker)

	return results


static func _generate_assignments(
	remaining: int,
	minimum_rank: int,
	current: Array[int],
	results: Array[Array],
) -> void:
	if remaining == 0:
		results.append(current.duplicate())
		return
	for rank in range(minimum_rank, CardData.Rank.TWO + 1):
		current.append(rank)
		_generate_assignments(remaining - 1, rank, current, results)
		current.pop_back()


static func _is_consecutive(unique_ranks: Array[int], expected_size: int) -> bool:
	if unique_ranks.size() != expected_size or unique_ranks[-1] > CardData.Rank.ACE:
		return false
	for index in range(1, unique_ranks.size()):
		if unique_ranks[index] != unique_ranks[index - 1] + 1:
			return false
	return true


static func _find_rank_with_count(frequencies: Dictionary, count: int) -> int:
	for rank in frequencies:
		if frequencies[rank] == count:
			return rank
	return -1


static func _all_counts_equal(frequencies: Dictionary, count: int) -> bool:
	for value in frequencies.values():
		if value != count:
			return false
	return true


static func _add_pattern(
	results: Array[HandPattern],
	type: HandPattern.Type,
	card_count: int,
	main_rank: int,
	contains_joker: bool,
) -> void:
	results.append(HandPattern.new(type, card_count, main_rank, contains_joker))


static func _is_pattern_preferred(left: HandPattern, right: HandPattern) -> bool:
	if left.is_full_kind() != right.is_full_kind():
		return left.is_full_kind()
	if left.type != right.type:
		return left.type < right.type
	return left.main_rank > right.main_rank


static func _is_weaker_pattern(left: HandPattern, right: HandPattern) -> bool:
	if left.is_full_kind() != right.is_full_kind():
		return not left.is_full_kind()
	if left.main_rank != right.main_rank:
		return left.main_rank < right.main_rank
	return left.type < right.type
