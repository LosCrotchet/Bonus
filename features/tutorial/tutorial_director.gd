class_name TutorialDirector
extends Control

@onready var blocker: ColorRect = %Blocker
@onready var highlight: Panel = %Highlight
@onready var dialog: PanelContainer = %Dialog
@onready var emoji_view: TextureRect = %Emoji
@onready var pointer_emoji_view: TextureRect = %PointerEmoji
@onready var message_label: Label = %Message
@onready var continue_button: Button = %ContinueButton

var _game: Control
var _scenario: TutorialScenario
var _step_index := 0
var _current_step: TutorialStep
var _dialog_tween: Tween
var _pointer_tween: Tween
var _started := false


func _ready() -> void:
	blocker.visible = false
	highlight.visible = false
	dialog.visible = false
	pointer_emoji_view.visible = false
	continue_button.pressed.connect(_on_continue_pressed)
	resized.connect(_on_resized)
	set_process(false)


func setup(game: Control, scenario: TutorialScenario) -> void:
	_game = game
	_scenario = scenario


func start() -> void:
	_started = true
	notify_event(&"tutorial_started")


func restart() -> void:
	if _current_step != null:
		_finish_current_step()
	_step_index = 0
	_started = true
	notify_event(&"tutorial_started")


func notify_event(event_key: StringName, payload: Dictionary = {}) -> void:
	if not _started:
		return
	if _current_step != null:
		if (
			_current_step.continue_mode == TutorialStep.ContinueMode.EVENT
			and _current_step.continue_event == event_key
		):
			_finish_current_step()
		else:
			return
	_show_next_matching_step(event_key, payload)


func _show_next_matching_step(event_key: StringName, _payload: Dictionary) -> void:
	if _scenario == null or _step_index >= _scenario.steps.size():
		return
	var step := _scenario.steps[_step_index]
	if step == null or step.trigger != event_key:
		return
	_step_index += 1
	_current_step = step
	_apply_ai_commands(step.ai_commands)
	_game.call("set_tutorial_gameplay_locked", step.blocks_gameplay)
	_show_step(step)


func _show_step(step: TutorialStep) -> void:
	var message := step.get_message(self)
	blocker.visible = step.dim_background
	blocker.mouse_filter = (
		Control.MOUSE_FILTER_STOP if step.blocks_gameplay else Control.MOUSE_FILTER_IGNORE
	)
	message_label.text = message
	emoji_view.texture = step.emoji
	emoji_view.visible = step.emoji != null
	pointer_emoji_view.texture = step.pointer_emoji
	pointer_emoji_view.visible = (
		step.pointer_emoji != null
		and not step.pointer_target_path.is_empty()
		and _game.has_node(step.pointer_target_path)
	)
	pointer_emoji_view.custom_minimum_size = Vector2.ONE * step.pointer_size
	pointer_emoji_view.size = Vector2.ONE * step.pointer_size
	continue_button.visible = step.continue_mode == TutorialStep.ContinueMode.BUTTON
	continue_button.disabled = step.minimum_display_time > 0.0
	_position_dialog(step.placement)
	dialog.visible = not message.is_empty() or emoji_view.visible
	_update_highlight(step.highlight_path)
	_update_pointer()
	if dialog.visible:
		_play_dialog_enter()
	if pointer_emoji_view.visible:
		_play_pointer_enter()
	if continue_button.disabled:
		_enable_continue_after_delay(step.minimum_display_time, step)


func _enable_continue_after_delay(duration: float, expected_step: TutorialStep) -> void:
	await get_tree().create_timer(duration).timeout
	if _current_step == expected_step:
		continue_button.disabled = false


func _on_continue_pressed() -> void:
	if _current_step == null or continue_button.disabled:
		return
	AudioService.play(&"ui_confirm")
	var trigger := _current_step.trigger
	var has_chained_step := (
		_scenario != null
		and _step_index < _scenario.steps.size()
		and _scenario.steps[_step_index] != null
		and _scenario.steps[_step_index].trigger == trigger
	)
	_finish_current_step(not has_chained_step)
	_show_next_matching_step(trigger, {})


func _finish_current_step(unlock_gameplay := true) -> void:
	_current_step = null
	blocker.visible = false
	highlight.visible = false
	dialog.visible = false
	pointer_emoji_view.visible = false
	if _pointer_tween != null:
		_pointer_tween.kill()
		_pointer_tween = null
	set_process(false)
	if _game != null and unlock_gameplay:
		_game.call("set_tutorial_gameplay_locked", false)


func _apply_ai_commands(commands: Array[Dictionary]) -> void:
	for command in commands:
		_game.call(
			"queue_tutorial_ai_command",
			int(command.get("player_index", 1)),
			command,
		)


func _position_dialog(placement: int) -> void:
	var viewport_size := size
	var dialog_size := Vector2(
		minf(560.0, viewport_size.x - 68.0),
		150.0,
	)
	var dialog_position: Vector2
	match placement:
		TutorialStep.Placement.TOP:
			dialog_position = Vector2(
				(viewport_size.x - dialog_size.x) * 0.5,
				34.0,
			)
		TutorialStep.Placement.LEFT:
			dialog_position = Vector2(
				34.0,
				(viewport_size.y - dialog_size.y) * 0.5,
			)
		TutorialStep.Placement.RIGHT:
			dialog_position = Vector2(
				viewport_size.x - dialog_size.x - 34.0,
				(viewport_size.y - dialog_size.y) * 0.5,
			)
		_:
			dialog_position = Vector2(
				(viewport_size.x - dialog_size.x) * 0.5,
				viewport_size.y - dialog_size.y - 34.0,
			)
	dialog.anchor_left = 0.0
	dialog.anchor_top = 0.0
	dialog.anchor_right = 0.0
	dialog.anchor_bottom = 0.0
	dialog.offset_left = dialog_position.x
	dialog.offset_top = dialog_position.y
	dialog.offset_right = dialog_position.x + dialog_size.x
	dialog.offset_bottom = dialog_position.y + dialog_size.y


func _on_resized() -> void:
	if _current_step == null:
		return
	_position_dialog(_current_step.placement)
	_reposition_highlight()
	_reposition_pointer()


func _update_highlight(path: NodePath) -> void:
	highlight.visible = not path.is_empty() and _game.has_node(path)
	set_process(highlight.visible)
	if highlight.visible:
		_reposition_highlight()


func _process(_delta: float) -> void:
	_reposition_highlight()
	_reposition_pointer()


func _reposition_highlight() -> void:
	if _current_step == null or _current_step.highlight_path.is_empty():
		return
	var target := _game.get_node_or_null(_current_step.highlight_path) as Control
	if target == null:
		highlight.visible = false
		return
	var rect := target.get_global_rect().grow(6.0)
	highlight.global_position = rect.position
	highlight.size = rect.size


func _update_pointer() -> void:
	if not pointer_emoji_view.visible:
		return
	set_process(true)
	_reposition_pointer()


func _reposition_pointer() -> void:
	if (
		_current_step == null
		or _current_step.pointer_target_path.is_empty()
		or not pointer_emoji_view.visible
	):
		return
	var target := _game.get_node_or_null(
		_current_step.pointer_target_path,
	) as Control
	if target == null:
		pointer_emoji_view.visible = false
		return
	var target_rect := target.get_global_rect()
	var pointer_size := pointer_emoji_view.size
	var desired_position := Vector2(
		target_rect.end.x - pointer_size.x - 42.0,
		target_rect.position.y + 24.0,
	)
	var viewport_rect := get_viewport_rect().grow(-12.0)
	pointer_emoji_view.global_position = Vector2(
		clampf(
			desired_position.x,
			viewport_rect.position.x,
			viewport_rect.end.x - pointer_size.x,
		),
		clampf(
			desired_position.y,
			viewport_rect.position.y,
			viewport_rect.end.y - pointer_size.y,
		),
	)


func _play_pointer_enter() -> void:
	if _pointer_tween != null:
		_pointer_tween.kill()
	pointer_emoji_view.modulate.a = 0.0
	pointer_emoji_view.scale = Vector2(0.82, 0.82)
	pointer_emoji_view.pivot_offset = pointer_emoji_view.size * 0.5
	_pointer_tween = create_tween().set_loops()
	_pointer_tween.tween_property(
		pointer_emoji_view,
		"modulate:a",
		1.0,
		0.16,
	)
	_pointer_tween.parallel().tween_property(
		pointer_emoji_view,
		"scale",
		Vector2.ONE,
		0.22,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pointer_tween.tween_property(
		pointer_emoji_view,
		"rotation",
		-0.08,
		0.42,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pointer_tween.tween_property(
		pointer_emoji_view,
		"rotation",
		0.08,
		0.42,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_dialog_enter() -> void:
	if _dialog_tween != null:
		_dialog_tween.kill()
	dialog.pivot_offset = dialog.size * 0.5
	dialog.scale = Vector2(0.92, 0.92)
	dialog.modulate.a = 0.0
	_dialog_tween = create_tween().set_parallel(true)
	_dialog_tween.tween_property(dialog, "scale", Vector2.ONE, 0.22).set_trans(
		Tween.TRANS_BACK,
	).set_ease(Tween.EASE_OUT)
	_dialog_tween.tween_property(dialog, "modulate:a", 1.0, 0.14)
