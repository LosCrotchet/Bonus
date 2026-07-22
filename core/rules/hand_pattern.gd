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


func _init(p_type: Type, p_card_count: int, p_main_rank: int, p_contains_joker: bool) -> void:
	type = p_type
	card_count = p_card_count
	main_rank = p_main_rank
	contains_joker = p_contains_joker


func is_full_kind() -> bool:
	return type in [Type.FOUR_KIND, Type.FIVE_KIND, Type.SIX_KIND]


func get_display_name() -> String:
	var names := {
		Type.SINGLE: "单张",
		Type.PAIR: "对子",
		Type.TRIPLE: "三条",
		Type.STRAIGHT: "%d张顺子" % card_count,
		Type.FOUR_KIND: "四条",
		Type.TRIPLE_WITH_ONE: "三带一",
		Type.PAIR_STRAIGHT: "二连对" if card_count == 4 else "三连对",
		Type.FIVE_KIND: "五条",
		Type.TRIPLE_WITH_PAIR: "三带二",
		Type.FOUR_WITH_ONE: "四带一",
		Type.SIX_KIND: "六条",
		Type.FIVE_WITH_ONE: "五带一",
		Type.FOUR_WITH_TWO: "四带二",
		Type.TRIPLE_WITH_TRIPLE: "三带三",
	}
	return names.get(type, "未知牌型")


func get_key() -> String:
	return "%d:%d:%d" % [type, card_count, main_rank]
