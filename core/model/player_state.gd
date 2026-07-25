@tool
class_name PlayerState
extends RefCounted

var player_id: int
var display_name: String
var hand: Array[CardData] = []


func _init(p_player_id: int, p_display_name: String) -> void:
	player_id = p_player_id
	display_name = p_display_name


func add_card(card: CardData) -> void:
	hand.append(card)


func sort_hand() -> void:
	hand.sort_custom(_is_card_less)


func has_cards(card_ids: Array[int]) -> bool:
	var unique_ids := {}
	for card_id in card_ids:
		if unique_ids.has(card_id):
			return false
		unique_ids[card_id] = true
		if find_card_index(card_id) == -1:
			return false
	return true


func remove_cards(card_ids: Array[int]) -> Array[CardData]:
	var removed: Array[CardData] = []
	for card_id in card_ids:
		var index := find_card_index(card_id)
		if index == -1:
			continue
		removed.append(hand[index])
		hand.remove_at(index)
	return removed


func find_card_index(card_id: int) -> int:
	for index in range(hand.size()):
		if hand[index].card_id == card_id:
			return index
	return -1


func _is_card_less(left: CardData, right: CardData) -> bool:
	if left.get_sort_value() == right.get_sort_value():
		if left.suit == right.suit:
			return left.deck_index < right.deck_index
		return left.suit < right.suit
	return left.get_sort_value() < right.get_sort_value()
