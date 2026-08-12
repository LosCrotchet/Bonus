@tool
class_name TutorialScenario
extends Resource

@export_category("Match")
@export_range(2, 4, 1) var player_count := 3
@export var seed_text := "teach001"
@export_range(0, 6, 1) var forced_first_human_roll := 0

@export_category("Rules")
@export var include_jokers := true
@export var jokers_are_wild := true
@export var draw_two_on_wildcard_finish := true
@export var allow_two_in_sequences := false
@export var draw_count_uses_dice := false

@export_category("Sequence")
@export var steps: Array[TutorialStep] = []
@export var entry_step_id: StringName


func build_rules() -> GameRules:
	var rules := GameRules.new()
	rules.include_jokers = include_jokers
	rules.jokers_are_wild = include_jokers and jokers_are_wild
	rules.draw_two_on_wildcard_finish = (
		rules.jokers_are_wild and draw_two_on_wildcard_finish
	)
	rules.allow_two_in_sequences = allow_two_in_sequences
	rules.draw_count_uses_dice = draw_count_uses_dice
	return rules


func uses_graph() -> bool:
	return not entry_step_id.is_empty()


func get_step(step_id: StringName) -> TutorialStep:
	for step in steps:
		if step != null and step.step_id == step_id:
			return step
	return null


func get_initial_hands_debug() -> Array[Dictionary]:
	var session := GameSession.new()
	var names: Array[String] = []
	for index in range(player_count):
		names.append("Player %d" % (index + 1))
	if not session.start_game(names, SeedCodec.to_int(seed_text), build_rules(), seed_text):
		return []
	var result: Array[Dictionary] = []
	for player in session.players:
		var cards: Array[Dictionary] = []
		for card in player.hand:
			cards.append({
				"card_id": card.card_id,
				"rank": card.get_sort_value(),
				"label": card.get_rank_label(),
				"suit": card.suit,
				"joker_kind": card.joker_kind,
			})
		result.append({"player_index": player.player_id, "cards": cards})
	return result


func validate_graph() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for step in steps:
		if step == null:
			errors.append("Scenario contains an empty step.")
			continue
		if step.step_id.is_empty():
			errors.append("A step has no step_id.")
		elif ids.has(step.step_id):
			errors.append("Duplicate step_id: %s" % step.step_id)
		else:
			ids[step.step_id] = true
	if uses_graph() and not ids.has(entry_step_id):
		errors.append("Entry step does not exist: %s" % entry_step_id)
	for step in steps:
		if step == null:
			continue
		for transition in step.transitions:
			if transition != null and not transition.target_step_id.is_empty() and not ids.has(transition.target_step_id):
				errors.append("%s points to missing step %s" % [step.step_id, transition.target_step_id])
	return errors
