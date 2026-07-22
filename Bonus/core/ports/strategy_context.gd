class_name StrategyContext
extends RefCounted

const PHASE_ROLL := &"awaiting_roll"
const PHASE_ACTION := &"awaiting_action"

var player_index: int
var phase: StringName
var own_hand: Array[CardData] = []
var player_summaries: Array[Dictionary] = []
var draw_pile_count: int
var discard_pile_count: int
var dice_value: int
var is_bonus: bool
var roller_index: int
var last_player_index: int
var target_pattern: HandPattern
var visible_table_cards: Array[CardData] = []
var rules: GameRules


func get_player_summary(index: int) -> Dictionary:
	for summary in player_summaries:
		if summary.get("player_index", -1) == index:
			return summary.duplicate(true)
	return {}
