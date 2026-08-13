class_name TutorialDirector
extends Control

signal event_source_released

const TYPEWRITER_CHARACTERS_PER_SECOND := 32.0
const TYPEWRITER_SOUND_PITCH_SCALE := 2.0
const NO_HIGHLIGHT_CUTOUT := Vector4(-1.0, -1.0, -1.0, -1.0)

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
var _continue_event_received := true
var _text_reveal_complete := true
var _minimum_display_complete := true
var _presentation_generation := 0
var _started := false
var _control_restore_state: Dictionary = {}
var _event_source_blocked := false


func _ready() -> void:
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2.ZERO
	emoji_view.custom_minimum_size = Vector2(104.0, 0.0)
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
	if _scenario != null and _scenario.uses_graph():
		_show_graph_step(_scenario.entry_step_id, {})
	else:
		notify_event(&"tutorial_started")


func restart() -> void:
	if _event_source_blocked:
		_event_source_blocked = false
		call_deferred("_emit_event_source_released")
	if _current_step != null:
		_finish_current_step()
	_step_index = 0
	_started = true
	if _scenario != null and _scenario.uses_graph():
		_show_graph_step(_scenario.entry_step_id, {})
	else:
		notify_event(&"tutorial_started")


func notify_event(event_key: StringName, payload: Dictionary = {}) -> void:
	if not _started:
		return
	if (
		_current_step != null
		and _current_step.continue_mode == TutorialStep.ContinueMode.BUTTON
		and not _current_step.continue_event.is_empty()
		and _current_step.continue_event == event_key
	):
		_continue_event_received = true
		_try_enable_continue()
		return
	if _scenario != null and _scenario.uses_graph():
		if _current_step == null:
			return
		var transition := _find_graph_transition(
			TutorialTransition.TriggerMode.EVENT,
			event_key,
			payload,
		)
		if transition != null:
			_follow_graph_transition(transition, payload)
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


func notify_checkpoint(event_key: StringName, payload: Dictionary = {}) -> bool:
	notify_event(event_key, payload)
	if not _event_source_blocked or _current_step == null:
		_event_source_blocked = false
		return false
	return true


func _input(event: InputEvent) -> void:
	if (
		_current_step == null
		or _current_step.continue_mode != TutorialStep.ContinueMode.BUTTON
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
	if not _text_reveal_complete:
		_complete_text_reveal(_current_step, _presentation_generation)
		get_viewport().set_input_as_handled()
		return
	if not _continue_ready:
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
	_apply_ai_commands(step.get_ai_commands())
	_game.call("set_tutorial_gameplay_locked", step.blocks_gameplay)
	_game.call("set_tutorial_input_locks", step.input_locks)
	_game.call(
		"set_tutorial_action_bar_override",
		step.show_action_bar_while_locked,
	)
	_apply_control_directives(step.control_directives)
	_show_step(step)


func _show_graph_step(step_id: StringName, _payload: Dictionary) -> void:
	if _scenario == null or step_id.is_empty():
		_finish_current_step()
		return
	var step := _scenario.get_step(step_id)
	if step == null:
		push_error("Tutorial transition points to missing step: %s" % step_id)
		_finish_current_step()
		return
	_current_step = step
	if step.blocks_event_source:
		_event_source_blocked = true
	_game.call("mark_tutorial_step_shown", step.step_id)
	_apply_ai_commands(step.get_ai_commands())
	_game.call("set_tutorial_gameplay_locked", step.blocks_gameplay)
	_game.call("set_tutorial_input_locks", step.input_locks)
	_game.call(
		"set_tutorial_action_bar_override",
		step.show_action_bar_while_locked,
	)
	_apply_control_directives(step.control_directives)
	_show_step(step)


func _show_step(step: TutorialStep) -> void:
	var message := step.get_message(self)
	var minimum_display_time := step.minimum_display_time
	if minimum_display_time <= 0.0 and not message.is_empty():
		# With no authored delay, derive a readable floor from both copy length
		# and the typewriter duration. Ten characters map to roughly one second.
		minimum_display_time = maxf(
			message.length() / 10.0,
			message.length() / (TYPEWRITER_CHARACTERS_PER_SECOND * 1.5),
		)
	_presentation_generation += 1
	var generation := _presentation_generation
	blocker.visible = step.dim_background
	blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.text = message
	message_label.visible_characters = 0 if not message.is_empty() else -1
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
	_continue_event_received = step.continue_event.is_empty()
	_text_reveal_complete = message.is_empty()
	_minimum_display_complete = minimum_display_time <= 0.0
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
	if not message.is_empty():
		_run_typewriter(message.length(), step, generation)
	if minimum_display_time > 0.0:
		_complete_minimum_display_after_delay(
			minimum_display_time,
			step,
			generation,
		)
	_try_enable_continue()


func _run_typewriter(
	total_characters: int,
	expected_step: TutorialStep,
	generation: int,
) -> void:
	var revealed := 0
	var character_interval := 1.0 / TYPEWRITER_CHARACTERS_PER_SECOND
	var sound_interval := maxi(1, expected_step.type_sound_every_characters)
	while revealed < total_characters:
		await get_tree().create_timer(character_interval, false).timeout
		if (
			_current_step != expected_step
			or generation != _presentation_generation
			or _text_reveal_complete
		):
			return
		revealed += 1
		message_label.visible_characters = revealed
		if (revealed - 1) % sound_interval == 0:
			AudioService.play(&"tutorial_type", 0.0, TYPEWRITER_SOUND_PITCH_SCALE)
	_complete_text_reveal(expected_step, generation)


func _complete_text_reveal(
	expected_step: TutorialStep,
	generation: int,
) -> void:
	if (
		_current_step != expected_step
		or generation != _presentation_generation
		or _text_reveal_complete
	):
		return
	message_label.visible_characters = -1
	_text_reveal_complete = true
	_try_enable_continue()


func _complete_minimum_display_after_delay(
	duration: float,
	expected_step: TutorialStep,
	generation: int,
) -> void:
	await get_tree().create_timer(duration, false).timeout
	if _current_step != expected_step or generation != _presentation_generation:
		return
	_minimum_display_complete = true
	_try_enable_continue()


func _try_enable_continue() -> void:
	if (
		_current_step == null
		or _current_step.continue_mode != TutorialStep.ContinueMode.BUTTON
		or not _text_reveal_complete
		or not _minimum_display_complete
		or not _continue_event_received
		or _continue_ready
	):
		return
	_show_continue_indicator()


func _show_continue_indicator() -> void:
	if _continue_ready:
		return
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
	AudioService.play(&"tutorial_confirm")
	if _scenario != null and _scenario.uses_graph():
		var transition := _find_graph_transition(
			TutorialTransition.TriggerMode.CLICK,
			&"",
			{},
		)
		if transition == null:
			_finish_current_step()
		else:
			_follow_graph_transition(transition, {})
		return
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
	var finished_step_id := (
		_current_step.step_id if _current_step != null else StringName()
	)
	var releases_source := (
		_current_step != null
		and _current_step.releases_event_source
		and _event_source_blocked
	)
	_presentation_generation += 1
	_continue_ready = false
	_continue_event_received = true
	_text_reveal_complete = true
	_minimum_display_complete = true
	_current_step = null
	blocker.visible = false
	_set_blocker_cutout(NO_HIGHLIGHT_CUTOUT)
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
	message_label.visible_characters = -1
	if _pointer_tween != null:
		_pointer_tween.kill()
		_pointer_tween = null
	set_process(false)
	_restore_control_directives()
	if _game != null:
		_game.call("mark_tutorial_step_finished", finished_step_id)
		_game.call("set_tutorial_action_bar_override", false)
	if _game != null and unlock_gameplay:
		_game.call("set_tutorial_gameplay_locked", false)
		_game.call("set_tutorial_input_locks", 0)
	if releases_source:
		_event_source_blocked = false
		call_deferred("_emit_event_source_released")


func _emit_event_source_released() -> void:
	event_source_released.emit()


func _find_graph_transition(
	mode: TutorialTransition.TriggerMode,
	event_key: StringName,
	payload: Dictionary,
) -> TutorialTransition:
	if _current_step == null:
		return null
	for transition in _current_step.transitions:
		if (
			transition != null
			and transition.trigger_mode == mode
			and transition.matches(_game, event_key, payload)
		):
			return transition
	return null


func _follow_graph_transition(
	transition: TutorialTransition,
	payload: Dictionary,
) -> void:
	_finish_current_step(false)
	_show_graph_step(transition.target_step_id, payload)


func _apply_ai_commands(commands: Array[Dictionary]) -> void:
	for command in commands:
		_game.call(
			"queue_tutorial_ai_command",
			int(command.get("player_index", 1)),
			command,
		)


func _position_dialog(step: TutorialStep) -> void:
	var viewport_size := size
	if step.use_custom_dialog_rect:
		var normalized := step.normalized_dialog_rect
		var custom_position := Vector2(
			clampf(normalized.position.x, 0.0, 0.96) * viewport_size.x,
			clampf(normalized.position.y, 0.0, 0.94) * viewport_size.y,
		)
		var custom_size := Vector2(
			clampf(normalized.size.x, 0.08, 1.0) * viewport_size.x,
			clampf(normalized.size.y, 0.08, 1.0) * viewport_size.y,
		)
		custom_size.x = minf(custom_size.x, viewport_size.x - custom_position.x - 12.0)
		custom_size.y = minf(custom_size.y, viewport_size.y - custom_position.y - 12.0)
		_set_dialog_rect(Rect2(custom_position, custom_size))
		return
	var dialog_width := minf(step.dialog_width, viewport_size.x - 68.0)
	var dialog_size := Vector2(
		dialog_width,
		minf(step.dialog_height, viewport_size.y - 68.0),
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
	_set_dialog_rect(Rect2(dialog_position, dialog_size))


func _set_dialog_rect(rect: Rect2) -> void:
	# PanelContainer normally grows to fit its children. Matching hard minimum and
	# maximum sizes makes the authored rectangle authoritative while Label wraps.
	dialog.custom_maximum_size = rect.size
	dialog.custom_minimum_size = rect.size
	dialog.anchor_left = 0.0
	dialog.anchor_top = 0.0
	dialog.anchor_right = 0.0
	dialog.anchor_bottom = 0.0
	dialog.offset_left = rect.position.x
	dialog.offset_top = rect.position.y
	dialog.offset_right = rect.end.x
	dialog.offset_bottom = rect.end.y


func _apply_control_directives(
	directives: Array[TutorialControlDirective],
) -> void:
	_restore_control_directives()
	for directive in directives:
		if directive == null or directive.target_path.is_empty():
			continue
		var target := _game.get_node_or_null(directive.target_path) as Control
		if target == null:
			push_warning("Tutorial control target not found: %s" % directive.target_path)
			continue
		_control_restore_state[target] = {
			"visible": target.visible,
			"mouse_filter": target.mouse_filter,
			"disabled": target.disabled if target is BaseButton else false,
		}
		_apply_control_directive(target, directive.mode)
	if not _control_restore_state.is_empty():
		set_process(true)


func _apply_control_directive(target: Control, mode: int) -> void:
	match mode:
		TutorialControlDirective.Mode.HIDE:
			target.visible = false
		TutorialControlDirective.Mode.SHOW:
			target.visible = true
		TutorialControlDirective.Mode.DISABLE:
			if target is BaseButton:
				(target as BaseButton).disabled = true
			else:
				target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		TutorialControlDirective.Mode.ENABLE:
			if target is BaseButton:
				(target as BaseButton).disabled = false
			else:
				target.mouse_filter = Control.MOUSE_FILTER_STOP


func _restore_control_directives() -> void:
	for target_value in _control_restore_state:
		var target := target_value as Control
		if not is_instance_valid(target):
			continue
		var state := _control_restore_state[target] as Dictionary
		target.visible = bool(state["visible"])
		target.mouse_filter = int(state["mouse_filter"]) as Control.MouseFilter
		if target is BaseButton:
			(target as BaseButton).disabled = bool(state["disabled"])
	_control_restore_state.clear()


func _on_resized() -> void:
	if _current_step == null:
		return
	_position_dialog(_current_step)
	_reposition_highlight()
	_reposition_pointer()


func _update_highlight(path: NodePath) -> void:
	highlight.visible = not path.is_empty() and _game.has_node(path)
	if not highlight.visible:
		_set_blocker_cutout(NO_HIGHLIGHT_CUTOUT)
	set_process(highlight.visible)
	if highlight.visible:
		_reposition_highlight()


func _process(_delta: float) -> void:
	_reposition_highlight()
	_reposition_pointer()
	for target_value in _control_restore_state:
		var target := target_value as Control
		if not is_instance_valid(target):
			continue
		for directive in _current_step.control_directives if _current_step != null else []:
			if directive != null and _game.get_node_or_null(directive.target_path) == target:
				_apply_control_directive(target, directive.mode)


func _reposition_highlight() -> void:
	if _current_step == null or _current_step.highlight_path.is_empty():
		return
	var target := _game.get_node_or_null(_current_step.highlight_path) as Control
	if target == null:
		highlight.visible = false
		_set_blocker_cutout(NO_HIGHLIGHT_CUTOUT)
		return
	var rect := target.get_global_rect().grow(6.0)
	highlight.global_position = rect.position
	highlight.size = rect.size
	if blocker.visible and blocker.size.x > 0.0 and blocker.size.y > 0.0:
		var blocker_rect := blocker.get_global_rect()
		var local_position := rect.position - blocker_rect.position
		var local_end := rect.end - blocker_rect.position
		_set_blocker_cutout(Vector4(
			clampf(local_position.x / blocker_rect.size.x, 0.0, 1.0),
			clampf(local_position.y / blocker_rect.size.y, 0.0, 1.0),
			clampf(local_end.x / blocker_rect.size.x, 0.0, 1.0),
			clampf(local_end.y / blocker_rect.size.y, 0.0, 1.0),
		))


func _set_blocker_cutout(value: Vector4) -> void:
	var blocker_material := blocker.material as ShaderMaterial
	if blocker_material != null:
		blocker_material.set_shader_parameter(&"cutout_rect", value)


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
	) + _current_step.pointer_offset
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
