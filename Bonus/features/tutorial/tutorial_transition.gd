@tool
class_name TutorialTransition
extends Resource

enum TriggerMode {
	CLICK,
	EVENT,
}

@export var target_step_id: StringName
@export var trigger_mode := TriggerMode.CLICK
@export var event_key: StringName
@export var label := ""
@export var conditions: Array[TutorialCondition] = []


func matches(game: Node, event: StringName, payload: Dictionary) -> bool:
	if trigger_mode == TriggerMode.EVENT and event_key != event:
		return false
	for condition in conditions:
		if condition != null and not condition.matches(game, payload):
			return false
	return true


func get_label() -> String:
	if not label.is_empty():
		return label
	if trigger_mode == TriggerMode.CLICK:
		return "Click"
	return str(event_key)
