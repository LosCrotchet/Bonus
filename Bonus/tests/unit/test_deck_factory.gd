extends SceneTree


func _init() -> void:
	var cards := DeckFactory.create_two_deck()
	assert(cards.size() == 108)

	var card_ids := {}
	var small_jokers := 0
	var big_jokers := 0
	for card in cards:
		assert(not card_ids.has(card.card_id))
		card_ids[card.card_id] = true
		if card.joker_kind == CardData.JokerKind.SMALL:
			small_jokers += 1
		elif card.joker_kind == CardData.JokerKind.BIG:
			big_jokers += 1

	assert(small_jokers == 2)
	assert(big_jokers == 2)

	var cards_without_jokers := DeckFactory.create_two_deck(false)
	assert(cards_without_jokers.size() == 104)
	assert(cards_without_jokers.all(func(card: CardData) -> bool: return not card.is_joker()))
	print("BONUS_TEST_DECK_FACTORY_OK")
	quit()
