@tool
class_name TutorialEditorPreview
extends Control

signal dialog_rect_changed(normalized_rect: Rect2)
signal target_sampled(kind: StringName, path: NodePath)

const BASE_SIZE := Vector2(1280.0, 720.0)
const GAME_SCENE_PATH := "res://features/game/game_scene.tscn"

static var use_test_scene := false

var step: TutorialStep
var sample_kind: StringName
var _viewport: SubViewport
var _game_root: Control
var _canvas_rect := Rect2()
var _drag_mode := 0
var _drag_start := Vector2.ZERO
var _drag_rect := Rect2()


func _ready() -> void:
	custom_minimum_size = Vector2(640.0, 360.0)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	clip_contents = true
	_build_game_preview()
	resized.connect(queue_redraw)


func set_step(value: TutorialStep) -> void:
	step = value
	queue_redraw()


func begin_sample(kind: StringName) -> void:
	sample_kind = kind
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	queue_redraw()


func cancel_sample() -> void:
	sample_kind = &""
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _build_game_preview() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "GamePreviewViewport"
	_viewport.size = Vector2i(BASE_SIZE)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	if use_test_scene:
		_game_root = _build_test_game_scene()
	else:
		var packed := load(GAME_SCENE_PATH) as PackedScene
		if packed == null:
			push_error("Tutorial preview could not load %s" % GAME_SCENE_PATH)
			return
		_game_root = packed.instantiate() as Control
	_viewport.add_child(_game_root)


func _build_test_game_scene() -> Control:
	var game := Control.new()
	game.name = "GameScene"
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var target := Panel.new()
	target.name = "SampleTarget"
	target.position = Vector2(500.0, 280.0)
	target.size = Vector2(280.0, 160.0)
	game.add_child(target)
	return game


func _draw() -> void:
	_canvas_rect = _get_canvas_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.03, 0.03), true)
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), _canvas_rect, false)
	if step == null:
		_draw_center_text("Open a TutorialScenario and select a step")
		return
	if step.dim_background:
		draw_rect(_canvas_rect, Color(0.0, 0.0, 0.0, 0.5), true)
	_draw_sampled_target(step.highlight_path, Color(1.0, 0.76, 0.2, 0.95), 4.0)
	_draw_dialog()
	_draw_pointer()
	if not sample_kind.is_empty():
		draw_rect(_canvas_rect, Color(0.25, 0.8, 1.0, 0.09), true)
		_draw_center_text("Click a game control to sample: %s" % sample_kind)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			if not sample_kind.is_empty():
				_sample_at(button.position)
				accept_event()
				return
			_begin_dialog_drag(button.position)
		else:
			_drag_mode = 0
		accept_event()
	elif event is InputEventMouseMotion and _drag_mode != 0:
		_update_dialog_drag((event as InputEventMouseMotion).position)
		accept_event()


func _begin_dialog_drag(mouse_position: Vector2) -> void:
	if step == null:
		return
	var rect := _dialog_screen_rect()
	if not rect.grow(8.0).has_point(mouse_position):
		return
	_drag_start = _screen_to_base(mouse_position)
	_drag_rect = _normalized_to_base(
		step.normalized_dialog_rect if step.use_custom_dialog_rect else _preset_dialog_rect(step),
	)
	var local := _screen_to_base(mouse_position) - _drag_rect.position
	var edge := 14.0
	var right := local.x >= _drag_rect.size.x - edge
	var bottom := local.y >= _drag_rect.size.y - edge
	_drag_mode = 4 if right and bottom else 2 if right else 3 if bottom else 1


func _update_dialog_drag(mouse_position: Vector2) -> void:
	if step == null:
		return
	var delta := _screen_to_base(mouse_position) - _drag_start
	var rect := _drag_rect
	match _drag_mode:
		1:
			rect.position += delta
		2:
			rect.size.x += delta.x
		3:
			rect.size.y += delta.y
		4:
			rect.size += delta
	rect.size.x = clampf(rect.size.x, 180.0, BASE_SIZE.x)
	rect.size.y = clampf(rect.size.y, 100.0, BASE_SIZE.y)
	rect.position.x = clampf(rect.position.x, 0.0, BASE_SIZE.x - rect.size.x)
	rect.position.y = clampf(rect.position.y, 0.0, BASE_SIZE.y - rect.size.y)
	step.use_custom_dialog_rect = true
	step.normalized_dialog_rect = Rect2(rect.position / BASE_SIZE, rect.size / BASE_SIZE)
	dialog_rect_changed.emit(step.normalized_dialog_rect)
	queue_redraw()


func _sample_at(screen_position: Vector2) -> void:
	var base_position := _screen_to_base(screen_position)
	var target := _find_deepest_control(_game_root, base_position)
	if target == null or target == _game_root:
		return
	var path := _game_root.get_path_to(target)
	target_sampled.emit(sample_kind, path)
	cancel_sample()


func _find_deepest_control(node: Node, point: Vector2) -> Control:
	var result: Control
	for child in node.get_children():
		var candidate := _find_deepest_control(child, point)
		if candidate != null:
			result = candidate
	if result != null:
		return result
	if node is Control:
		var control := node as Control
		if control.visible and control.get_global_rect().has_point(point):
			return control
	return null


func _draw_dialog() -> void:
	var rect := _dialog_screen_rect()
	draw_style_box(_dialog_style(), rect)
	var padding := 14.0 * _canvas_scale()
	var emoji_size := minf(rect.size.y - padding * 2.0, 104.0 * _canvas_scale())
	var text_left := rect.position.x + padding
	if step.emoji != null and emoji_size > 12.0:
		var emoji_rect := Rect2(
			Vector2(text_left, rect.position.y + (rect.size.y - emoji_size) * 0.5),
			Vector2.ONE * emoji_size,
		)
		draw_texture_rect(step.emoji, emoji_rect, false)
		text_left = emoji_rect.end.x + padding
	var font := get_theme_default_font()
	var font_size := maxi(11, int(18.0 * _canvas_scale()))
	var message := step.fallback_message
	if message.is_empty() and not step.message_key.is_empty():
		message = "[%s]" % step.message_key
	draw_multiline_string(
		font,
		Vector2(text_left, rect.position.y + padding + font_size),
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.end.x - text_left - padding,
		font_size,
		-1,
		Color.WHITE,
		TextServer.BREAK_MANDATORY
		| TextServer.BREAK_WORD_BOUND
		| TextServer.BREAK_ADAPTIVE,
	)
	var handle := 9.0
	draw_rect(Rect2(rect.end - Vector2.ONE * handle, Vector2.ONE * handle), Color(1.0, 0.76, 0.2), true)


func _draw_pointer() -> void:
	if step.pointer_emoji == null or step.pointer_target_path.is_empty():
		return
	var target_rect := _target_screen_rect(step.pointer_target_path)
	if target_rect.size == Vector2.ZERO:
		return
	var pointer_size := step.pointer_size * _canvas_scale()
	var rect := Rect2(
		target_rect.end - Vector2(pointer_size + 10.0, target_rect.size.y * 0.5),
		Vector2.ONE * pointer_size,
	)
	draw_texture_rect(step.pointer_emoji, rect, false)


func _draw_sampled_target(path: NodePath, color: Color, width: float) -> void:
	var rect := _target_screen_rect(path)
	if rect.size != Vector2.ZERO:
		draw_rect(rect.grow(4.0), color, false, width)


func _target_screen_rect(path: NodePath) -> Rect2:
	if path.is_empty() or _game_root == null:
		return Rect2()
	var target := _game_root.get_node_or_null(path) as Control
	if target == null:
		return Rect2()
	var rect := target.get_global_rect()
	return Rect2(_base_to_screen(rect.position), rect.size * _canvas_scale())


func _dialog_screen_rect() -> Rect2:
	if step == null:
		return Rect2()
	var normalized := step.normalized_dialog_rect
	if not step.use_custom_dialog_rect:
		normalized = _preset_dialog_rect(step)
	var base_rect := _normalized_to_base(normalized)
	return Rect2(_base_to_screen(base_rect.position), base_rect.size * _canvas_scale())


func _preset_dialog_rect(value: TutorialStep) -> Rect2:
	var normalized_size := Vector2(value.dialog_width, value.dialog_height) / BASE_SIZE
	match value.placement:
		TutorialStep.Placement.TOP:
			return Rect2(Vector2((1.0 - normalized_size.x) * 0.5, 0.047), normalized_size)
		TutorialStep.Placement.LEFT:
			return Rect2(Vector2(0.027, (1.0 - normalized_size.y) * 0.5), normalized_size)
		TutorialStep.Placement.RIGHT:
			return Rect2(Vector2(0.973 - normalized_size.x, (1.0 - normalized_size.y) * 0.5), normalized_size)
		_:
			return Rect2(Vector2((1.0 - normalized_size.x) * 0.5, 0.953 - normalized_size.y), normalized_size)


func _dialog_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.075, 0.98)
	style.border_color = Color(0.96, 0.76, 0.28, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style


func _get_canvas_rect() -> Rect2:
	var scale_value := minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	var fitted := BASE_SIZE * scale_value
	return Rect2((size - fitted) * 0.5, fitted)


func _canvas_scale() -> float:
	return _canvas_rect.size.x / BASE_SIZE.x if _canvas_rect.size.x > 0.0 else 1.0


func _base_to_screen(point: Vector2) -> Vector2:
	return _canvas_rect.position + point * _canvas_scale()


func _screen_to_base(point: Vector2) -> Vector2:
	return (point - _canvas_rect.position) / maxf(_canvas_scale(), 0.001)


func _normalized_to_base(rect: Rect2) -> Rect2:
	return Rect2(rect.position * BASE_SIZE, rect.size * BASE_SIZE)


func _draw_center_text(text: String) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	draw_string(font, (size - text_size) * 0.5, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.9, 0.9))
