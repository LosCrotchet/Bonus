class_name LanProtocol
extends RefCounted

const DEFAULT_PORT := 9077
const MIN_PORT := 1024
const MAX_PORT := 65535
const MAX_PLAYER_ID_LENGTH := 24
const PROTOCOL_VERSION := 1

enum ActionType {
	ROLL,
	PLAY,
	PASS,
}


static func sanitize_player_id(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.length() > MAX_PLAYER_ID_LENGTH:
		cleaned = cleaned.left(MAX_PLAYER_ID_LENGTH)
	return cleaned


static func is_valid_player_id(value: String) -> bool:
	return not sanitize_player_id(value).is_empty()


static func is_valid_port(value: int) -> bool:
	return value >= MIN_PORT and value <= MAX_PORT


static func rules_to_dictionary(rules: GameRules) -> Dictionary:
	return {
		"include_jokers": rules.include_jokers,
		"jokers_are_wild": rules.jokers_are_wild,
		"draw_two_on_wildcard_finish": rules.draw_two_on_wildcard_finish,
		"allow_two_in_sequences": rules.allow_two_in_sequences,
		"draw_count_uses_dice": rules.draw_count_uses_dice,
	}


static func rules_from_dictionary(value: Dictionary) -> GameRules:
	var rules := GameRules.new()
	rules.include_jokers = bool(value.get("include_jokers", true))
	rules.jokers_are_wild = (
		rules.include_jokers and bool(value.get("jokers_are_wild", true))
	)
	rules.draw_two_on_wildcard_finish = (
		rules.jokers_are_wild
		and bool(value.get("draw_two_on_wildcard_finish", true))
	)
	rules.allow_two_in_sequences = bool(value.get("allow_two_in_sequences", false))
	rules.draw_count_uses_dice = bool(value.get("draw_count_uses_dice", false))
	return rules


static func normalize_room_config(value: Dictionary) -> Dictionary:
	var player_count := clampi(int(value.get("player_count", 3)), 2, 4)
	var timeout_seconds := int(value.get("turn_timeout", 30))
	if timeout_seconds not in [15, 30, 60]:
		timeout_seconds = 30
	var seed_text := SeedCodec.sanitize(str(value.get("seed_text", "")))
	if not SeedCodec.is_valid(seed_text):
		seed_text = SeedCodec.generate_random_text()
	var rules_value: Variant = value.get("rules", {})
	var rules: GameRules = (
		rules_value as GameRules
		if rules_value is GameRules
		else rules_from_dictionary(rules_value as Dictionary)
	)
	return {
		"player_count": player_count,
		"turn_timeout": timeout_seconds,
		"seed_text": seed_text,
		"seed_value": SeedCodec.to_int(seed_text),
		"use_custom_seed": bool(value.get("use_custom_seed", false)),
		"rules": rules_to_dictionary(rules),
	}
