extends SceneTree

var _next_card_id := 1000


func _init() -> void:
	_test_every_declared_pattern()
	_test_sequence_boundaries()
	_test_comparison_rules()
	_test_wildcards()
	_test_distinct_wildcard_interpretations()
	print("BONUS_TEST_HAND_EVALUATOR_OK")
	quit()


func _test_every_declared_pattern() -> void:
	_assert_pattern([7], HandPattern.Type.SINGLE, 7)
	_assert_pattern([7, 7], HandPattern.Type.PAIR, 7)
	_assert_pattern([7, 7, 7], HandPattern.Type.TRIPLE, 7)
	_assert_pattern([3, 4, 5], HandPattern.Type.STRAIGHT, 5)
	_assert_pattern([7, 7, 7, 7], HandPattern.Type.FOUR_KIND, 7)
	_assert_pattern([7, 7, 7, 9], HandPattern.Type.TRIPLE_WITH_ONE, 7)
	_assert_pattern([7, 7, 8, 8], HandPattern.Type.PAIR_STRAIGHT, 8)
	_assert_pattern([7, 7, 7, 7, 7], HandPattern.Type.FIVE_KIND, 7)
	_assert_pattern([7, 7, 7, 9, 9], HandPattern.Type.TRIPLE_WITH_PAIR, 7)
	_assert_pattern([7, 7, 7, 7, 9], HandPattern.Type.FOUR_WITH_ONE, 7)
	_assert_pattern([7, 7, 7, 7, 7, 7], HandPattern.Type.SIX_KIND, 7)
	_assert_pattern([7, 7, 7, 7, 7, 9], HandPattern.Type.FIVE_WITH_ONE, 7)
	_assert_pattern([7, 7, 7, 7, 9, 9], HandPattern.Type.FOUR_WITH_TWO, 7)
	_assert_pattern([7, 7, 7, 9, 9, 9], HandPattern.Type.TRIPLE_WITH_TRIPLE, 9)
	_assert_pattern([7, 7, 8, 8, 9, 9], HandPattern.Type.PAIR_STRAIGHT, 9)


func _test_sequence_boundaries() -> void:
	_assert_pattern([12, 13, 14], HandPattern.Type.STRAIGHT, 14)
	assert(HandEvaluator.evaluate_all(_cards([13, 14, 15])).is_empty())
	assert(HandEvaluator.evaluate_all(_cards([14, 15, 3])).is_empty())
	assert(HandEvaluator.evaluate_all(_cards([14, 14, 15, 15])).is_empty())


func _test_comparison_rules() -> void:
	var low_triple := _pattern([6, 6, 6], HandPattern.Type.TRIPLE)
	var high_triple := _pattern([7, 7, 7], HandPattern.Type.TRIPLE)
	assert(HandEvaluator.beats(high_triple, low_triple))
	assert(not HandEvaluator.beats(low_triple, high_triple))
	assert(not HandEvaluator.beats(high_triple, high_triple))

	var low_body := _pattern([6, 6, 6, 14], HandPattern.Type.TRIPLE_WITH_ONE)
	var high_body := _pattern([7, 7, 7, 3], HandPattern.Type.TRIPLE_WITH_ONE)
	assert(HandEvaluator.beats(high_body, low_body))

	var straight := _pattern([6, 7, 8, 9], HandPattern.Type.STRAIGHT)
	var four_kind := _pattern([3, 3, 3, 3], HandPattern.Type.FOUR_KIND)
	assert(HandEvaluator.beats(four_kind, straight))
	assert(not HandEvaluator.beats(straight, four_kind))


func _test_wildcards() -> void:
	var joker_pair := _cards([7])
	joker_pair.append(_joker())
	_assert_contains_pattern(joker_pair, HandPattern.Type.PAIR, 7)

	var joker_straight := _cards([4, 6])
	joker_straight.append(_joker())
	_assert_contains_pattern(joker_straight, HandPattern.Type.STRAIGHT, 6)

	var target := _pattern([8, 8, 8], HandPattern.Type.TRIPLE)
	var wildcard_cover := _cards([9, 9])
	wildcard_cover.append(_joker())
	var cover := HandEvaluator.choose_cover_pattern(wildcard_cover, target)
	assert(cover != null)
	assert(cover.type == HandPattern.Type.TRIPLE)
	assert(cover.main_rank == 9)


func _test_distinct_wildcard_interpretations() -> void:
	var cards := _cards([3, 3, 4, 4])
	cards.append(_joker())
	cards.append(_joker())
	var interpretations := HandEvaluator.get_distinct_interpretations(cards)
	assert(interpretations.size() == 3)
	assert(_find_type(interpretations, HandPattern.Type.PAIR_STRAIGHT).main_rank == 5)
	assert(_find_type(interpretations, HandPattern.Type.TRIPLE_WITH_TRIPLE).main_rank == 4)
	assert(_find_type(interpretations, HandPattern.Type.FOUR_WITH_TWO).main_rank == 4)


func _find_type(patterns: Array[HandPattern], type: HandPattern.Type) -> HandPattern:
	for pattern in patterns:
		if pattern.type == type:
			return pattern
	return null


func _assert_pattern(ranks: Array[int], type: HandPattern.Type, main_rank: int) -> void:
	_assert_contains_pattern(_cards(ranks), type, main_rank)


func _assert_contains_pattern(cards: Array[CardData], type: HandPattern.Type, main_rank: int) -> void:
	assert(_pattern_from_cards(cards, type, main_rank) != null)


func _pattern(ranks: Array[int], type: HandPattern.Type) -> HandPattern:
	var cards := _cards(ranks)
	for pattern in HandEvaluator.evaluate_all(cards):
		if pattern.type == type:
			return pattern
	return null


func _pattern_from_cards(
	cards: Array[CardData],
	type: HandPattern.Type,
	main_rank: int,
) -> HandPattern:
	for pattern in HandEvaluator.evaluate_all(cards):
		if pattern.type == type and pattern.main_rank == main_rank:
			return pattern
	return null


func _cards(ranks: Array[int]) -> Array[CardData]:
	var cards: Array[CardData] = []
	for rank in ranks:
		cards.append(CardData.new(_take_id(), rank, CardData.Suit.CLUBS))
	return cards


func _joker() -> CardData:
	return CardData.new(
		_take_id(),
		0,
		CardData.Suit.NONE,
		CardData.JokerKind.SMALL,
	)


func _take_id() -> int:
	var result := _next_card_id
	_next_card_id += 1
	return result
