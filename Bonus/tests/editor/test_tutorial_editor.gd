@tool
extends SceneTree

const EDITOR_SCENE := preload("res://addons/tutorial_editor/tutorial_editor.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	TutorialEditorPreview.use_test_scene = true
	var editor := EDITOR_SCENE.instantiate() as Control
	root.add_child(editor)
	await process_frame
	await process_frame

	var scenario := editor.get("_scenario") as TutorialScenario
	var step := editor.get("_step") as TutorialStep
	var preview := editor.get("_preview") as TutorialEditorPreview
	assert(scenario != null)
	assert(step != null)
	assert(preview != null)
	_test_graph_connection(editor, scenario)
	preview.size = Vector2(960.0, 540.0)
	preview.set_step(step)
	await process_frame

	var original := step.normalized_dialog_rect
	var center := preview.call("_dialog_screen_rect").get_center() as Vector2
	preview.call("_begin_dialog_drag", center)
	preview.call("_update_dialog_drag", center + Vector2(36.0, -18.0))
	preview.call("_gui_input", _left_release(center + Vector2(36.0, -18.0)))
	assert(step.use_custom_dialog_rect)
	assert(step.normalized_dialog_rect != original)
	assert(step.normalized_dialog_rect.position.x >= 0.0)
	assert(step.normalized_dialog_rect.end.x <= 1.0)
	assert(step.normalized_dialog_rect.position.y >= 0.0)
	assert(step.normalized_dialog_rect.end.y <= 1.0)
	_test_resize(preview, step, Vector2(1.0, 0.5), Vector2(42.0, 0.0))
	_test_resize(preview, step, Vector2(0.5, 1.0), Vector2(0.0, 30.0))
	_test_resize(preview, step, Vector2.ONE, Vector2(24.0, 18.0))

	preview.begin_sample(&"highlight")
	preview.call("_sample_at", preview.call("_base_to_screen", Vector2(640.0, 360.0)))
	assert(preview.sample_kind.is_empty())

	print("BONUS_TEST_TUTORIAL_EDITOR_OK")
	editor.queue_free()
	await process_frame
	quit()


func _test_graph_connection(editor: Control, scenario: TutorialScenario) -> void:
	assert(scenario.steps.size() >= 2)
	var source := scenario.steps[0]
	var target := scenario.steps[1]
	var original_transitions := source.transitions.duplicate()
	editor.call(
		"_on_graph_connection_requested",
		source.step_id,
		0,
		target.step_id,
		0,
	)
	var graph := editor.get("_graph") as GraphEdit
	assert(graph.has_node(NodePath(str(source.step_id))))
	assert(graph.has_node(NodePath(str(target.step_id))))
	assert(graph.is_node_connected(source.step_id, 0, target.step_id, 0))
	editor.call(
		"_on_graph_disconnection_requested",
		source.step_id,
		0,
		target.step_id,
		0,
	)
	assert(not graph.is_node_connected(source.step_id, 0, target.step_id, 0))
	source.transitions.assign(original_transitions)
	editor.call("_rebuild_graph")


func _test_resize(
	preview: TutorialEditorPreview,
	step: TutorialStep,
	normalized_handle: Vector2,
	delta: Vector2,
) -> void:
	var before := step.normalized_dialog_rect
	var rect := preview.call("_dialog_screen_rect") as Rect2
	var handle := rect.position + rect.size * normalized_handle
	preview.call("_begin_dialog_drag", handle)
	preview.call("_update_dialog_drag", handle + delta)
	preview.call("_gui_input", _left_release(handle + delta))
	assert(step.normalized_dialog_rect != before)
	assert(step.normalized_dialog_rect.end.x <= 1.0)
	assert(step.normalized_dialog_rect.end.y <= 1.0)


func _left_release(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	return event
