class_name CardView
extends TextureButton

signal selection_changed(card_id: int, selected: bool)

var card_id := -1
var selected := false
var interaction_enabled := true


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func configure(card: CardData, enabled: bool) -> void:
	card_id = card.card_id
	texture_normal = CardTextureCatalog.get_texture(card)
	tooltip_text = card.get_display_name()
	set_interaction_enabled(enabled)


func set_selected(value: bool) -> void:
	selected = value
	self_modulate = Color(1.0, 0.93, 0.72) if selected else Color.WHITE


func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
	disabled = not value
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	)
	if not value:
		self_modulate = Color(0.86, 0.86, 0.86)
	else:
		set_selected(selected)


func _on_pressed() -> void:
	if not interaction_enabled:
		return
	set_selected(not selected)
	selection_changed.emit(card_id, selected)


func _on_mouse_entered() -> void:
	if interaction_enabled and not selected:
		self_modulate = Color(1.0, 1.0, 0.9)


func _on_mouse_exited() -> void:
	if interaction_enabled:
		set_selected(selected)
