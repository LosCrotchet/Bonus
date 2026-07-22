class_name PlayerStrategy
extends RefCounted

var controlled_player_index := -1
var player_count := 0


func get_strategy_id() -> StringName:
	return &"base"


func get_display_name_key() -> StringName:
	return &"AI_STRATEGY_BASE"


func setup(p_player_index: int, p_player_count: int) -> void:
	controlled_player_index = p_player_index
	player_count = p_player_count


func choose_action(_context: StrategyContext) -> PlayerDecision:
	return PlayerDecision.create_pass()


func observe_action(_public_action: Dictionary) -> void:
	pass


func reset() -> void:
	pass
