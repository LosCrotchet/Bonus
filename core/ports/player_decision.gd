class_name PlayerDecision
extends RefCounted

enum Action {
	ROLL,
	PLAY,
	PASS,
}

var action: Action
var card_ids: Array[int] = []
var interpretation_key := ""


func _init(p_action: Action) -> void:
	action = p_action


static func create_roll() -> PlayerDecision:
	return PlayerDecision.new(Action.ROLL)


static func create_pass() -> PlayerDecision:
	return PlayerDecision.new(Action.PASS)


static func create_play(p_card_ids: Array[int], p_interpretation_key: String) -> PlayerDecision:
	var decision := PlayerDecision.new(Action.PLAY)
	decision.card_ids.assign(p_card_ids)
	decision.interpretation_key = p_interpretation_key
	return decision
