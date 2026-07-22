class_name HandView
extends Control

signal selection_changed(selected_ids: Array[int])

const CARD_SIZE := Vector2(96.0, 134.0)
const MAX_SPACING := 72.0
const MIN_SPACING := 22.0
const DEFAULT_Y := 22.0

var _card_views: Array[CardView] = []
var _selected_ids: Array[int] = []
var _interaction_enabled := false
var _drag_active := false
var _drag_visited := {}


func _ready() -> void:
	resized.connect(_layout_cards)
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process_input(true)


func set_hand(cards: Array[CardData], selected_ids: Array[int], enabled: bool) -> void:
	_clear_cards()
	_selected_ids.assign(selected_ids)
	_interaction_enabled = enabled
	_drag_active = false
	_drag_visited.clear()

	for card in cards:
		var card_view := CardView.new()
		add_child(card_view)
		card_view.configure(card, enabled)
		card_view.set_selected(_selected_ids.has(card.card_id), true)
		card_view.left_pressed.connect(_on_card_left_pressed)
		card_view.pointer_entered.connect(_on_card_pointer_entered)
		_card_views.append(card_view)

	_layout_cards.call_deferred()


func set_selection(selected_ids: Array[int]) -> void:
	_selected_ids.assign(selected_ids)
	for card_view in _card_views:
		card_view.set_selected(_selected_ids.has(card_view.card_id))


func clear_selection() -> void:
	if _selected_ids.is_empty():
		return
	_selected_ids.clear()
	for card_view in _card_views:
		card_view.set_selected(false)
	_emit_selection()


func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	if not value:
		_drag_active = false
	for card_view in _card_views:
		card_view.set_interaction_enabled(value)


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drag_active = false
		_drag_visited.clear()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _interaction_enabled:
		clear_selection()


func _layout_cards() -> void:
	if _card_views.is_empty() or size.x <= 0.0:
		return

	var spacing := MAX_SPACING
	if _card_views.size() > 1:
		spacing = minf(MAX_SPACING, (size.x - CARD_SIZE.x) / (_card_views.size() - 1))
		spacing = maxf(MIN_SPACING, spacing)
	var total_width := CARD_SIZE.x + spacing * (_card_views.size() - 1)
	var start_x := maxf(0.0, (size.x - total_width) * 0.5)

	for index in range(_card_views.size()):
		var card_view := _card_views[index]
		card_view.size = CARD_SIZE
		card_view.z_index = index
		card_view.set_base_position(Vector2(start_x + spacing * index, DEFAULT_Y), true)


func _clear_cards() -> void:
	for card_view in _card_views:
		card_view.queue_free()
	_card_views.clear()


func _on_card_left_pressed(card_id: int) -> void:
	if not _interaction_enabled:
		return
	_drag_active = true
	_drag_visited.clear()
	_toggle_card_once(card_id)


func _on_card_pointer_entered(card_id: int) -> void:
	if (
		_drag_active
		and _interaction_enabled
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		_toggle_card_once(card_id)


func _toggle_card_once(card_id: int) -> void:
	if _drag_visited.has(card_id):
		return
	_drag_visited[card_id] = true
	if _selected_ids.has(card_id):
		_selected_ids.erase(card_id)
	else:
		_selected_ids.append(card_id)
	for card_view in _card_views:
		if card_view.card_id == card_id:
			card_view.set_selected(_selected_ids.has(card_id))
			break
	_emit_selection()


func _emit_selection() -> void:
	var snapshot: Array[int] = []
	snapshot.assign(_selected_ids)
	selection_changed.emit(snapshot)
