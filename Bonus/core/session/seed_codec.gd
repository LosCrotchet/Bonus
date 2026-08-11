@tool
class_name SeedCodec
extends RefCounted

const LENGTH := 8
const ALPHABET := "0123456789abcdefghijklmnopqrstuvwxyz"


static func generate_random_text() -> String:
	var random_source := RandomNumberGenerator.new()
	random_source.randomize()
	var result := ""
	for _index in range(LENGTH):
		result += ALPHABET[random_source.randi_range(0, ALPHABET.length() - 1)]
	return result


static func sanitize(value: String) -> String:
	var result := ""
	for character in value.strip_edges().to_lower():
		if ALPHABET.contains(character):
			result += character
		if result.length() >= LENGTH:
			break
	return result


static func is_valid(value: String) -> bool:
	var normalized := sanitize(value)
	return value.strip_edges().length() == LENGTH and normalized == value.strip_edges().to_lower()


static func to_int(value: String) -> int:
	var normalized := sanitize(value)
	var seed_value := int(normalized.hash()) + 1
	return seed_value if seed_value != 0 else 1


static func from_int(value: int) -> String:
	var remaining := absi(value)
	var result := ""
	for _index in range(LENGTH):
		result = ALPHABET[remaining % ALPHABET.length()] + result
		remaining = floori(float(remaining) / float(ALPHABET.length()))
	return result
