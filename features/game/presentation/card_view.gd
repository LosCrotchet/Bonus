class_name CardView
extends TextureButton

signal left_pressed(card_id: int)
signal pointer_entered(card_id: int)
signal pointer_exited(card_id: int)

const HOVER_OFFSET_Y := -9.0
const SELECTED_OFFSET_Y := -22.0
const INTERACTION_DURATION := 0.14
var card_id := -1
var selected := false
var interaction_enabled := true

var _hovered := false
var _base_position := Vector2.ZERO
var _base_rotation := 0.0
var _neighbor_offset := Vector2.ZERO
var _move_tween: Tween
var _shadow_near: TextureRect
var _shadow_far: TextureRect


func _ready() -> void:
	set_meta(&"control_motion_disabled", true)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size * 0.5
	_create_shadows()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(card: CardData, enabled: bool) -> void:
	card_id = card.card_id
	texture_normal = CardTextureCatalog.get_texture(card)
	tooltip_text = ""
	_update_shadow_textures()
	set_interaction_enabled(enabled)


func set_base_transform(value: Vector2, angle: float, instant: bool = false) -> void:
	if _base_position.is_equal_approx(value) and is_equal_approx(_base_rotation, angle):
		return
	_base_position = value
	_base_rotation = angle
	_animate_transform(instant)


func set_selected(value: bool, instant: bool = false) -> void:
	if selected == value:
		return
	selected = value
	if not instant:
		AudioService.play(&"card_select" if value else &"card_deselect")
	_update_tint()
	_animate_transform(instant)


func set_neighbor_offset(value: Vector2) -> void:
	if _neighbor_offset == value:
		return
	_neighbor_offset = value
	_animate_transform()


func set_interaction_enabled(value: bool) -> void:
	var was_hovered := _hovered
	interaction_enabled = value
	disabled = not value
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	if not value:
		_hovered = false
	_update_tint()
	if was_hovered and not value:
		_animate_transform()


func play_entry_animation(delay: float = 0.0) -> void:
	if not is_inside_tree():
		return
	if _move_tween != null:
		_move_tween.kill()
	position = _target_position() + Vector2(0.0, -92.0)
	rotation = _base_rotation - 0.08
	scale = Vector2(0.78, 0.78)
	modulate.a = 0.0
	_move_tween = create_tween().set_parallel(true)
	var duration := SettingsService.get_gameplay_duration(
		SettingsService.GameplayTiming.CARD_ENTRY,
	)
	_move_tween.tween_property(self, "position", _target_position(), duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "rotation", _base_rotation, duration * 0.84).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.9).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "modulate:a", 1.0, duration * 0.5).set_delay(delay)


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		left_pressed.emit(card_id)
		accept_event()


func _on_mouse_entered() -> void:
	if not interaction_enabled:
		return
	AudioService.play(&"card_hover")
	_hovered = true
	_update_tint()
	_animate_transform()
	pointer_entered.emit(card_id)


func _on_mouse_exited() -> void:
	if not interaction_enabled:
		return
	_hovered = false
	_update_tint()
	_animate_transform()
	pointer_exited.emit(card_id)


func _animate_transform(instant: bool = false) -> void:
	var target := _target_position()
	if _move_tween != null:
		_move_tween.kill()
	# A container resize can interrupt the initial deal before its fade finishes.
	# Restore a visible baseline; later draw animations run after layout is stable.
	if modulate.a < 0.99:
		modulate.a = 1.0
		scale = Vector2.ONE
	if instant or not is_inside_tree():
		position = target
		rotation = _base_rotation
		return
	_move_tween = create_tween().set_parallel(true)
	_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", target, INTERACTION_DURATION)
	_move_tween.tween_property(self, "rotation", _base_rotation, INTERACTION_DURATION)


func _target_position() -> Vector2:
	var vertical_offset := 0.0
	if selected:
		vertical_offset = SELECTED_OFFSET_Y
	elif _hovered:
		vertical_offset = HOVER_OFFSET_Y
	return _base_position + _neighbor_offset + Vector2(0.0, vertical_offset)


func _update_tint() -> void:
	if not interaction_enabled:
		self_modulate = Color(0.84, 0.84, 0.84)
	elif selected:
		self_modulate = Color(1.0, 0.93, 0.72)
	elif _hovered:
		self_modulate = Color(1.0, 1.0, 0.93)
	else:
		self_modulate = Color.WHITE


func _create_shadows() -> void:
	_shadow_far = _new_shadow(Color(0.0, 0.0, 0.0, 0.12))
	_shadow_near = _new_shadow(Color(0.0, 0.0, 0.0, 0.25))
	_update_shadow_textures()
	_update_shadow_offsets()


func _new_shadow(tint: Color) -> TextureRect:
	var shadow := TextureRect.new()
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	shadow.show_behind_parent = true
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.modulate = tint
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shadow)
	move_child(shadow, 0)
	return shadow


func _update_shadow_textures() -> void:
	if _shadow_near == null:
		return
	_shadow_near.texture = texture_normal
	_shadow_far.texture = texture_normal


func _update_shadow_offsets() -> void:
	if _shadow_near == null:
		return
	_shadow_near.position = Vector2(3.0, 5.0)
	_shadow_far.position = Vector2(6.0, 9.0)
