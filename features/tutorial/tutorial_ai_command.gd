@tool
class_name TutorialAICommand
extends Resource

enum Phase {
	ANY,
	AWAITING_ROLL,
	AWAITING_ACTION,
}

enum Action {
	ROLL,
	PLAY,
	PASS,
}

@export_range(1, 3, 1) var player_index := 1
@export var phase := Phase.ANY
@export var action := Action.PASS
@export_range(0, 6, 1) var forced_dice_value := 0
@export var card_ids: Array[int] = []
@export var ranks: Array[int] = []
@export var interpretation_key := ""


func to_command() -> Dictionary:
	var phase_names := ["", "awaiting_roll", "awaiting_action"]
	var action_names := ["roll", "play", "pass"]
	return {
		"player_index": player_index,
		"phase": phase_names[phase],
		"action": action_names[action],
		"forced_dice_value": forced_dice_value,
		"card_ids": card_ids.duplicate(),
		"ranks": ranks.duplicate(),
		"interpretation_key": interpretation_key,
	}


func get_summary() -> String:
	var action_names := ["Roll", "Play", "Pass"]
	if action == Action.PLAY:
		return "P%d %s ids=%s ranks=%s" % [player_index, action_names[action], card_ids, ranks]
	if action == Action.ROLL and forced_dice_value > 0:
		return "P%d Roll %d" % [player_index, forced_dice_value]
	return "P%d %s" % [player_index, action_names[action]]
