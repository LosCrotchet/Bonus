class_name TutorialDirector
extends Control

@onready var blocker: ColorRect = %Blocker
@onready var highlight: Panel = %Highlight
@onready var dialog: PanelContainer = %Dialog
@onready var emoji_view: TextureRect = %Emoji
@onready var pointer_emoji_view: TextureRect = %PointerEmoji
@onready var message_label: Label = %Message
@onready var continue_indicator: TextureRect = %ContinueIndicator

var _game: Control
var _scenario: TutorialScenario
var _step_index := 0
var _current_step: TutorialStep
var _dialog_tween: Tween
var _pointer_tween: Tween
var _continue_indicator_tween: Tween
var _continue_float_tween: Tween
var _continue_ready := false
var _started := false


func _ready() -> void:
	blocker.visible = false
	highlight.visible = false
	dialog.visible = false
	pointer_emoji_view.visible = false
	continue_indicator.visible = false
	resized.connect(_on_resized)
	set_process_input(true)
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


func _input(event: InputEvent) -> void:
	if (
		_current_step == null
		or _current_step.continue_mode != TutorialStep.ContinueMode.BUTTON
		or not _continue_ready
		or event is not InputEventMouseButton
	):
		return
	var mouse_event := event as InputEventMouseButton
	if (
		not mouse_event.pressed
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
		or mouse_event.double_click
		or _game.call("is_tutorial_input_passthrough_point", mouse_event.position)
	):
		return
	_advance_button_step()
	get_viewport().set_input_as_handled()


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
	blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_continue_ready = false
	continue_indicator.visible = false
	continue_indicator.modulate.a = 0.0
	_position_dialog(step)
	dialog.visible = not message.is_empty() or emoji_view.visible
	_update_highlight(step.highlight_path)
	_update_pointer()
	if dialog.visible:
		_play_dialog_enter()
	if pointer_emoji_view.visible:
		_play_pointer_enter()
	if (
		step.continue_mode == TutorialStep.ContinueMode.BUTTON
		and step.minimum_display_time > 0.0
	):
		_enable_continue_after_delay(step.minimum_display_time, step)
	elif step.continue_mode == TutorialStep.ContinueMode.BUTTON:
		_show_continue_indicator()


func _enable_continue_after_delay(duration: float, expected_step: TutorialStep) -> void:
	await get_tree().create_timer(duration).timeout
	if _current_step == expected_step:
		_show_continue_indicator()


func _show_continue_indicator() -> void:
	_continue_ready = true
	continue_indicator.visible = true
	continue_indicator.modulate.a = 0.0
	continue_indicator.scale = Vector2(0.82, 0.82)
	continue_indicator.position = Vector2.ZERO
	continue_indicator.pivot_offset = continue_indicator.size * 0.5
	if _continue_indicator_tween != null:
		_continue_indicator_tween.kill()
	if _continue_float_tween != null:
		_continue_float_tween.kill()
		_continue_float_tween = null
	_continue_indicator_tween = create_tween().set_parallel(true)
	_continue_indicator_tween.tween_property(
		continue_indicator,
		"modulate:a",
		1.0,
		0.18,
	)
	_continue_indicator_tween.tween_property(
		continue_indicator,
		"scale",
		Vector2.ONE,
		0.24,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_continue_indicator_tween.chain().tween_callback(
		_start_continue_indicator_float,
	)


func _start_continue_indicator_float() -> void:
	if not _continue_ready or not continue_indicator.visible:
		return
	continue_indicator.position = Vector2.ZERO
	_continue_float_tween = create_tween().set_loops()
	_continue_float_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_continue_float_tween.tween_property(
		continue_indicator,
		"position:y",
		-3.0,
		0.55,
	)
	_continue_float_tween.tween_property(
		continue_indicator,
		"position:y",
		2.0,
		0.55,
	)


func _advance_button_step() -> void:
	if _current_step == null or not _continue_ready:
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
	_continue_ready = false
	_current_step = null
	blocker.visible = false
	highlight.visible = false
	dialog.visible = false
	pointer_emoji_view.visible = false
	continue_indicator.visible = false
	if _continue_indicator_tween != null:
		_continue_indicator_tween.kill()
		_continue_indicator_tween = null
	if _continue_float_tween != null:
		_continue_float_tween.kill()
		_continue_float_tween = null
	continue_indicator.position = Vector2.ZERO
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


func _position_dialog(step: TutorialStep) -> void:
	var viewport_size := size
	var dialog_width := minf(step.dialog_width, viewport_size.x - 68.0)
	var message_width := dialog_width - 36.0
	if emoji_view.visible:
		message_width -= 120.0
	var font := message_label.get_theme_font(&"font")
	var font_size := message_label.get_theme_font_size(&"font_size")
	var text_height := font.get_multiline_string_size(
		message_label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(120.0, message_width),
		font_size,
	).y
	var required_height := maxf(
		104.0,
		text_height + 42.0,
	) + 28.0
	var dialog_size := Vector2(
		dialog_width,
		minf(maxf(step.dialog_height, required_height), viewport_size.y - 68.0),
	)
	var dialog_position: Vector2
	match step.placement:
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
	_position_dialog(_current_step)
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
