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


func get_sort_value() -> int:
	if joker_kind == JokerKind.SMALL:
		return 16
	if joker_kind == JokerKind.BIG:
		return 17
	return rank


func get_display_name() -> String:
	if joker_kind == JokerKind.SMALL:
		return "小王"
	if joker_kind == JokerKind.BIG:
		return "大王"

	var rank_names := {
		Rank.JACK: "J",
		Rank.QUEEN: "Q",
		Rank.KING: "K",
		Rank.ACE: "A",
		Rank.TWO: "2",
	}
	var suit_names := {
		Suit.CLUBS: "梅花",
		Suit.DIAMONDS: "方块",
		Suit.HEARTS: "红心",
		Suit.SPADES: "黑桃",
	}
	return "%s%s" % [suit_names.get(suit, ""), rank_names.get(rank, str(rank))]
