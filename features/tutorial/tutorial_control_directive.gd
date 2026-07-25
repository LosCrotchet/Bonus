@tool
class_name TutorialControlDirective
extends Resource

enum Mode {
	DISABLE,
	HIDE,
	ENABLE,
	SHOW,
}

@export var target_path: NodePath
@export var mode := Mode.DISABLE


func get_summary() -> String:
	var names := ["Disable", "Hide", "Enable", "Show"]
	return "%s: %s" % [names[mode], target_path]
