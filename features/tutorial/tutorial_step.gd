class_name TutorialStep
extends Resource

enum Placement {
	BOTTOM,
	TOP,
	LEFT,
	RIGHT,
}

enum ContinueMode {
	BUTTON,
	EVENT,
}

@export var step_id: StringName
@export var trigger: StringName = &"tutorial_started"
@export var message_key: StringName
@export_multiline var fallback_message := ""
@export var emoji: Texture2D
@export var placement := Placement.BOTTOM
@export var continue_mode := ContinueMode.BUTTON
@export var continue_event: StringName
@export var blocks_gameplay := true
@export var dim_background := true
@export var highlight_path: NodePath
@export_range(0.0, 5.0, 0.05) var minimum_display_time := 0.0
@export var ai_commands: Array[Dictionary] = []


func get_message(host: Node) -> String:
	if not message_key.is_empty():
		return host.tr(message_key)
	return fallback_message
