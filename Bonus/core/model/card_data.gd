class_name CardData
extends RefCounted

enum Suit {
	CLUBS,
	DIAMONDS,
	HEARTS,
	SPADES,
	NONE,
}

enum Rank {
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
	SIX = 6,
	SEVEN = 7,
	EIGHT = 8,
	NINE = 9,
	TEN = 10,
	JACK = 11,
	QUEEN = 12,
	KING = 13,
	ACE = 14,
	TWO = 15,
}

enum JokerKind {
	NONE,
	SMALL,
	BIG,
}

var card_id: int
var rank: int
var suit: int
var joker_kind: int
var deck_index: int


func _init(
	p_card_id: int,
	p_rank: int,
	p_suit: int,
	p_joker_kind: int = JokerKind.NONE,
	p_deck_index: int = 0,
) -> void:
	card_id = p_card_id
	rank = p_rank
	suit = p_suit
	joker_kind = p_joker_kind
	deck_index = p_deck_index


func is_joker() -> bool:
	return joker_kind != JokerKind.NONE


func clone() -> CardData:
	return CardData.new(card_id, rank, suit, joker_kind, deck_index)


func get_sort_value() -> int:
	if joker_kind == JokerKind.SMALL:
		return 16
	if joker_kind == JokerKind.BIG:
		return 17
	return rank


func get_natural_rank() -> int:
	return get_sort_value()


func get_name_translation_key() -> StringName:
	if joker_kind == JokerKind.SMALL:
		return &"CARD_JOKER_SMALL"
	if joker_kind == JokerKind.BIG:
		return &"CARD_JOKER_BIG"
	return get_suit_translation_key()


func get_rank_label() -> String:
	return rank_to_label(rank)


static func rank_to_label(value: int) -> String:
	var rank_names := {
		Rank.JACK: "J",
		Rank.QUEEN: "Q",
		Rank.KING: "K",
		Rank.ACE: "A",
		Rank.TWO: "2",
	}
	return rank_names.get(value, str(value))


func get_suit_translation_key() -> StringName:
	var suit_keys := {
		Suit.CLUBS: &"CARD_SUIT_CLUBS",
		Suit.DIAMONDS: &"CARD_SUIT_DIAMONDS",
		Suit.HEARTS: &"CARD_SUIT_HEARTS",
		Suit.SPADES: &"CARD_SUIT_SPADES",
	}
	return suit_keys.get(suit, &"")
