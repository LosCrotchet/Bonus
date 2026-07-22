class_name DeckFactory
extends RefCounted

const DECK_COPIES := 2


static func create_two_deck(include_jokers: bool = true) -> Array[CardData]:
	var cards: Array[CardData] = []
	var next_card_id := 0

	for deck_index in range(DECK_COPIES):
		for suit in [
			CardData.Suit.CLUBS,
			CardData.Suit.DIAMONDS,
			CardData.Suit.HEARTS,
			CardData.Suit.SPADES,
		]:
			for rank in range(CardData.Rank.THREE, CardData.Rank.TWO + 1):
				cards.append(CardData.new(next_card_id, rank, suit, CardData.JokerKind.NONE, deck_index))
				next_card_id += 1

		if include_jokers:
			cards.append(
				CardData.new(
					next_card_id,
					0,
					CardData.Suit.NONE,
					CardData.JokerKind.SMALL,
					deck_index,
				)
			)
			next_card_id += 1
			cards.append(
				CardData.new(
					next_card_id,
					0,
					CardData.Suit.NONE,
					CardData.JokerKind.BIG,
					deck_index,
				)
			)
			next_card_id += 1

	return cards


static func shuffle_cards(cards: Array[CardData], random_source: RandomNumberGenerator) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := random_source.randi_range(0, index)
		var temporary := cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = temporary
