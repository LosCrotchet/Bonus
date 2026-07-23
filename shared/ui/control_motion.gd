class_name ControlMotion
extends RefCounted

const HOVER_SCALE := Vector2(1.015, 1.015)
const PRESSED_SCALE := Vector2(0.98, 0.98)
const HOVER_LIFT := Vector2(0.0, -4.0)
const PRESSED_LIFT := Vector2(0.0, -1.0)
const MOTION_DURATION := 0.11


static func bind_buttons(root: Node) -> void:
	for child in root.find_children("*", "BaseButton", true, false):
		var button := child as BaseButton
		if button == null or button.get_meta(&"motion_bound", false):
			continue
		button.set_meta(&"motion_bound", true)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		button.resized.connect(_refresh_pivot.bind(button))
		button.mouse_entered.connect(_on_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_mouse_exited.bind(button))
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))
		button.set_meta(&"motion_rest_position", button.position)
		_refresh_pivot(button)


static func _refresh_pivot(button: BaseButton) -> void:
	# Keeping the bottom edge fixed makes the scale read as a small upward lift.
	button.pivot_offset = Vector2(button.size.x * 0.5, button.size.y)


static func _on_mouse_entered(button: BaseButton) -> void:
	if button.disabled:
		return
	var previous := _get_tween(button)
	if previous == null or not previous.is_running():
		button.set_meta(&"motion_rest_position", button.position)
	_animate(button, HOVER_SCALE, HOVER_LIFT)


static func _on_mouse_exited(button: BaseButton) -> void:
	_animate(button, Vector2.ONE, Vector2.ZERO)


static func _on_button_down(button: BaseButton) -> void:
	if button.disabled:
		return
	_animate(button, PRESSED_SCALE, PRESSED_LIFT)


static func _get_tween(button: BaseButton) -> Tween:
	var previous: Tween
	if button.has_meta(&"motion_tween"):
		previous = button.get_meta(&"motion_tween") as Tween
	return previous


static func _animate(
	button: BaseButton,
	target_scale: Vector2,
	lift: Vector2,
) -> void:
	var previous := _get_tween(button)
	if previous != null and previous.is_valid():
		previous.kill()
	_refresh_pivot(button)
	var rest_position := button.get_meta(
		&"motion_rest_position",
		button.position,
	) as Vector2
	var tween := button.create_tween().set_parallel(true)
	tween.tween_property(button, "scale", target_scale, MOTION_DURATION).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		button,
		"position",
		rest_position + lift,
		MOTION_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	button.set_meta(&"motion_tween", tween)


static func _on_button_up(button: BaseButton) -> void:
	var hovered := Rect2(Vector2.ZERO, button.size).has_point(
		button.get_local_mouse_position(),
	)
	_animate(
		button,
		HOVER_SCALE if hovered else Vector2.ONE,
		HOVER_LIFT if hovered else Vector2.ZERO,
	)
