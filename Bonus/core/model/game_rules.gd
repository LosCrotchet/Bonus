class_name GameRules
extends RefCounted

var include_jokers := true
var jokers_are_wild := true
var allow_two_in_sequences := false
var draw_count_uses_dice := false


func clone() -> GameRules:
	var copy := GameRules.new()
	copy.include_jokers = include_jokers
	copy.jokers_are_wild = jokers_are_wild
	copy.allow_two_in_sequences = allow_two_in_sequences
	copy.draw_count_uses_dice = draw_count_uses_dice
	return copy
