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
@export_range(420.0, 900.0, 10.0) var dialog_width := 760.0
@export_range(160.0, 400.0, 10.0) var dialog_height := 210.0
@export_category("Pointer")
@export var pointer_emoji: Texture2D
@export var pointer_target_path: NodePath
@export_range(24.0, 160.0, 1.0) var pointer_size := 72.0
@export_category("Flow")
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
