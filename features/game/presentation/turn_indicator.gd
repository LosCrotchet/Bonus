class_name TurnIndicator
extends Control

const INDICATOR_SIZE := Vector2(48.0, 48.0)

@export var accent_color := Color(1.0, 0.76, 0.22)

var _phase := 0.0
var _move_tween: Tween


func _ready() -> void:
	custom_minimum_size = INDICATOR_SIZE
	size = INDICATOR_SIZE
	pivot_offset = INDICATOR_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 2.8, TAU)
	queue_redraw()


func move_to(target_center: Vector2, facing_rotation: float, instant: bool = false) -> void:
	var target_position := target_center - size * 0.5
	var target_rotation := rotation + wrapf(facing_rotation - rotation, -PI, PI)
	if _move_tween != null:
		_move_tween.kill()
	if instant or not is_inside_tree():
		position = target_position
		rotation = target_rotation
		return
	_move_tween = create_tween().set_parallel(true)
	_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, "position", target_position, 0.28)
	_move_tween.tween_property(self, "rotation", target_rotation, 0.24)


func _draw() -> void:
	var bob := sin(_phase * 1.35) * 1.5
	var tip := Vector2(24.0, 4.0 + bob)
	var base_center := Vector2(24.0, 32.0 + bob)
	var vertices := PackedVector2Array()
	for index in range(3):
		var angle := _phase + TAU * float(index) / 3.0
		vertices.append(
			base_center + Vector2(cos(angle) * 13.0, sin(angle) * 5.5)
		)

	for index in range(3):
		var next_index := (index + 1) % 3
		var light := 0.58 + 0.28 * sin(_phase + float(index) * TAU / 3.0)
		var face_color := accent_color.darkened(1.0 - light)
		face_color.a = 0.96
		draw_colored_polygon(
			PackedVector2Array([tip, vertices[index], vertices[next_index]]),
			face_color,
		)

	var base_color := accent_color.darkened(0.42)
	base_color.a = 0.92
	draw_colored_polygon(vertices, base_color)
	draw_polyline(
		PackedVector2Array([vertices[0], vertices[1], vertices[2], vertices[0]]),
		accent_color.lightened(0.2),
		1.25,
		true,
	)
	draw_line(tip, vertices[0], accent_color.lightened(0.38), 1.2, true)
	draw_circle(tip, 1.7, Color(1.0, 0.96, 0.72, 0.95))
