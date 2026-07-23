class_name HandPattern
extends RefCounted

enum Type {
	SINGLE,
	PAIR,
	TRIPLE,
	STRAIGHT,
	FOUR_KIND,
	TRIPLE_WITH_ONE,
	PAIR_STRAIGHT,
	FIVE_KIND,
	TRIPLE_WITH_PAIR,
	FOUR_WITH_ONE,
	SIX_KIND,
	FIVE_WITH_ONE,
	FOUR_WITH_TWO,
	TRIPLE_WITH_TRIPLE,
}

var type: Type
var card_count: int
var main_rank: int
var contains_joker: bool
var uses_wildcard: bool


func _init(
	p_type: Type,
	p_card_count: int,
	p_main_rank: int,
	p_contains_joker: bool,
	p_uses_wildcard: bool = false,
) -> void:
	type = p_type
	card_count = p_card_count
	main_rank = p_main_rank
	contains_joker = p_contains_joker
	uses_wildcard = p_uses_wildcard


func is_full_kind() -> bool:
	return type in [Type.TRIPLE, Type.FOUR_KIND, Type.FIVE_KIND, Type.SIX_KIND]


func clone() -> HandPattern:
	return HandPattern.new(type, card_count, main_rank, contains_joker, uses_wildcard)


func get_translation_key() -> StringName:
	var keys := {
		Type.SINGLE: &"HAND_SINGLE",
		Type.PAIR: &"HAND_PAIR",
		Type.TRIPLE: &"HAND_TRIPLE",
		Type.FOUR_KIND: &"HAND_FOUR_KIND",
		Type.TRIPLE_WITH_ONE: &"HAND_TRIPLE_WITH_ONE",
		Type.FIVE_KIND: &"HAND_FIVE_KIND",
		Type.TRIPLE_WITH_PAIR: &"HAND_TRIPLE_WITH_PAIR",
		Type.FOUR_WITH_ONE: &"HAND_FOUR_WITH_ONE",
		Type.SIX_KIND: &"HAND_SIX_KIND",
		Type.FIVE_WITH_ONE: &"HAND_FIVE_WITH_ONE",
		Type.FOUR_WITH_TWO: &"HAND_FOUR_WITH_TWO",
		Type.TRIPLE_WITH_TRIPLE: &"HAND_TRIPLE_WITH_TRIPLE",
	}
	if type == Type.STRAIGHT:
		return &"HAND_STRAIGHT_%d" % card_count
	if type == Type.PAIR_STRAIGHT:
		return &"HAND_PAIR_STRAIGHT_2" if card_count == 4 else &"HAND_PAIR_STRAIGHT_3"
	return keys.get(type, &"HAND_UNKNOWN")


func get_key() -> String:
	return "%d:%d:%d:%d" % [type, card_count, main_rank, int(uses_wildcard)]
