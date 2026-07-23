class_name ControlMotion
extends RefCounted

const HOVER_SCALE := Vector2(1.025, 1.025)
const PRESSED_SCALE := Vector2(0.98, 0.98)
const MOTION_DURATION := 0.09


static func bind_buttons(root: Node) -> void:
	for child in root.find_children("*", "BaseButton", true, false):
		var button := child as BaseButton
		if button == null or button.get_meta(&"motion_bound", false):
			continue
		button.set_meta(&"motion_bound", true)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		button.resized.connect(_refresh_pivot.bind(button))
		button.mouse_entered.connect(_animate.bind(button, HOVER_SCALE))
		button.mouse_exited.connect(_animate.bind(button, Vector2.ONE))
		button.button_down.connect(_animate.bind(button, PRESSED_SCALE))
		button.button_up.connect(_on_button_up.bind(button))
		_refresh_pivot(button)


static func _refresh_pivot(button: BaseButton) -> void:
	# Keeping the bottom edge fixed makes the scale read as a small upward lift.
	button.pivot_offset = Vector2(button.size.x * 0.5, button.size.y)


static func _animate(button: BaseButton, target: Vector2) -> void:
	var previous: Tween
	if button.has_meta(&"motion_tween"):
		previous = button.get_meta(&"motion_tween") as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	_refresh_pivot(button)
	var tween := button.create_tween()
	tween.tween_property(button, "scale", target, MOTION_DURATION).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	button.set_meta(&"motion_tween", tween)


static func _on_button_up(button: BaseButton) -> void:
	var hovered := Rect2(Vector2.ZERO, button.size).has_point(
		button.get_local_mouse_position(),
	)
	_animate(button, HOVER_SCALE if hovered else Vector2.ONE)
