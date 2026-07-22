class_name CardView
extends TextureButton

signal left_pressed(card_id: int)
signal pointer_entered(card_id: int)

const HOVER_OFFSET_Y := -8.0
const SELECTED_OFFSET_Y := -20.0
const MOVE_DURATION := 0.12

var card_id := -1
var selected := false
var interaction_enabled := true

var _hovered := false
var _base_position := Vector2.ZERO
var _move_tween: Tween


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(card: CardData, enabled: bool) -> void:
	card_id = card.card_id
	texture_normal = CardTextureCatalog.get_texture(card)
	tooltip_text = (
		tr(card.get_name_translation_key())
		if card.is_joker()
		else "%s %s" % [tr(card.get_suit_translation_key()), card.get_rank_label()]
	)
	set_interaction_enabled(enabled)


func set_base_position(value: Vector2, instant: bool = false) -> void:
	_base_position = value
	_animate_position(instant)


func set_selected(value: bool, instant: bool = false) -> void:
	selected = value
	_update_tint()
	_animate_position(instant)


func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
	disabled = not value
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	if not value:
		_hovered = false
	_update_tint()


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		left_pressed.emit(card_id)
		accept_event()


func _on_mouse_entered() -> void:
	if not interaction_enabled:
		return
	_hovered = true
	_update_tint()
	_animate_position()
	pointer_entered.emit(card_id)


func _on_mouse_exited() -> void:
	if not interaction_enabled:
		return
	_hovered = false
	_update_tint()
	_animate_position()


func _animate_position(instant: bool = false) -> void:
	var offset_y := 0.0
	if selected:
		offset_y = SELECTED_OFFSET_Y
	elif _hovered:
		offset_y = HOVER_OFFSET_Y
	var target := _base_position + Vector2(0.0, offset_y)

	if _move_tween != null:
		_move_tween.kill()
	if instant or not is_inside_tree():
		position = target
		return
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", target, MOVE_DURATION)


func _update_tint() -> void:
	if not interaction_enabled:
		self_modulate = Color(0.84, 0.84, 0.84)
	elif selected:
		self_modulate = Color(1.0, 0.91, 0.65)
	elif _hovered:
		self_modulate = Color(1.0, 1.0, 0.9)
	else:
		self_modulate = Color.WHITE
