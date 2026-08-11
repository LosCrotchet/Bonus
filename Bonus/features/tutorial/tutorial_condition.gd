@tool
class_name TutorialCondition
extends Resource

enum Source {
	EVENT_PAYLOAD,
	GAME_PROPERTY,
}

enum Operator {
	EQUALS,
	NOT_EQUALS,
	GREATER,
	GREATER_OR_EQUAL,
	LESS,
	LESS_OR_EQUAL,
	IS_TRUE,
	IS_FALSE,
}

@export var source := Source.EVENT_PAYLOAD
@export var property_path := ""
@export var operator := Operator.EQUALS
@export var compare_value := ""


func matches(game: Node, payload: Dictionary) -> bool:
	var actual: Variant = _read_payload(payload) if source == Source.EVENT_PAYLOAD else _read_game(game)
	match operator:
		Operator.IS_TRUE:
			return bool(actual)
		Operator.IS_FALSE:
			return not bool(actual)
		Operator.NOT_EQUALS:
			return not _values_equal(actual, compare_value)
		Operator.GREATER:
			return _as_number(actual) > _as_number(compare_value)
		Operator.GREATER_OR_EQUAL:
			return _as_number(actual) >= _as_number(compare_value)
		Operator.LESS:
			return _as_number(actual) < _as_number(compare_value)
		Operator.LESS_OR_EQUAL:
			return _as_number(actual) <= _as_number(compare_value)
		_:
			return _values_equal(actual, compare_value)


func get_summary() -> String:
	var operators := ["=", "!=", ">", ">=", "<", "<=", "true", "false"]
	var prefix := "payload" if source == Source.EVENT_PAYLOAD else "game"
	if operator in [Operator.IS_TRUE, Operator.IS_FALSE]:
		return "%s.%s is %s" % [prefix, property_path, operators[operator]]
	return "%s.%s %s %s" % [prefix, property_path, operators[operator], compare_value]


func _read_payload(payload: Dictionary) -> Variant:
	var value: Variant = payload
	for part in property_path.split(".", false):
		if value is Dictionary and (value as Dictionary).has(part):
			value = (value as Dictionary)[part]
		else:
			return null
	return value


func _read_game(game: Node) -> Variant:
	if game == null:
		return null
	var value: Variant = game
	for part in property_path.split(".", false):
		if value is Object:
			value = (value as Object).get(part)
		elif value is Dictionary and (value as Dictionary).has(part):
			value = (value as Dictionary)[part]
		else:
			return null
	return value


func _values_equal(actual: Variant, expected: String) -> bool:
	if actual is bool:
		return bool(actual) == (expected.to_lower() in ["true", "1", "yes"])
	if actual is int or actual is float:
		return is_equal_approx(_as_number(actual), _as_number(expected))
	return str(actual) == expected


func _as_number(value: Variant) -> float:
	return float(str(value))
