@tool
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

enum InputLock {
	DEAL_SKIP = 1,
	DOUBLE_CLICK = 2,
	ROLL = 4,
	HAND = 8,
	PLAY = 16,
	PASS = 32,
	HINT = 64,
	AUTOMATION = 128,
	AI = 256,
}

@export var step_id: StringName
@export var trigger: StringName = &"tutorial_started"
@export var message_key: StringName
@export_multiline var fallback_message := ""
@export var emoji: Texture2D
@export var placement := Placement.BOTTOM
@export_range(420.0, 900.0, 10.0) var dialog_width := 760.0
@export_range(160.0, 400.0, 10.0) var dialog_height := 210.0
@export_category("WYSIWYG Layout")
@export var use_custom_dialog_rect := false
@export var normalized_dialog_rect := Rect2(0.2, 0.66, 0.6, 0.28)
@export_category("Pointer")
@export var pointer_emoji: Texture2D
@export var pointer_target_path: NodePath
@export_range(24.0, 160.0, 1.0) var pointer_size := 72.0
@export var pointer_offset := Vector2.ZERO
@export_category("Flow")
@export var continue_mode := ContinueMode.BUTTON
@export var continue_event: StringName
@export var blocks_gameplay := true
@export var dim_background := true
@export var highlight_path: NodePath
@export_range(0.0, 5.0, 0.05) var minimum_display_time := 0.0
@export_range(1, 16, 1) var type_sound_every_characters := 2
@export var ai_commands: Array[Dictionary] = []
@export_flags(
	"Disable deal skip",
	"Disable double click",
	"Disable roll",
	"Disable hand",
	"Disable play",
	"Disable pass",
	"Disable hint",
	"Disable automation",
	"Pause AI",
) var input_locks := 0
@export var control_directives: Array[TutorialControlDirective] = []
@export var scripted_ai_actions: Array[TutorialAICommand] = []
@export_category("Graph")
@export var transitions: Array[TutorialTransition] = []
@export var editor_graph_position := Vector2.ZERO


func get_message(host: Node) -> String:
	if not message_key.is_empty():
		return host.tr(message_key)
	return fallback_message


func get_ai_commands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for command in ai_commands:
		result.append(command.duplicate(true))
	for action in scripted_ai_actions:
		if action != null:
			result.append(action.to_command())
	return result
