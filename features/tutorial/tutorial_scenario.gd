class_name TutorialScenario
extends Resource

@export_category("Match")
@export_range(2, 4, 1) var player_count := 3
@export var seed_text := "teach001"

@export_category("Rules")
@export var include_jokers := true
@export var jokers_are_wild := true
@export var draw_two_on_wildcard_finish := true
@export var allow_two_in_sequences := false
@export var draw_count_uses_dice := false

@export_category("Sequence")
@export var steps: Array[TutorialStep] = []


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
