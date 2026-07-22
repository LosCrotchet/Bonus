class_name HandView
extends Control

signal selection_changed(selected_ids: Array[int])
signal order_changed(ordered_ids: Array[int])
signal play_requested

const CARD_SIZE := Vector2(96.0, 134.0)
const MAX_SPACING := 72.0
const MIN_SPACING := 18.0
const LONG_PRESS_SECONDS := 0.22
const SWIPE_THRESHOLD := 10.0
const FAN_DEPTH := 13.0
const MAX_FAN_ANGLE := 0.105
const RIGHT_SAFE_AREA := 100.0

var _card_views: Array[CardView] = []
var _selected_ids: Array[int] = []
var _interaction_enabled := false
var _auto_sort_enabled := true
var _selection_drag_active := false
var _drag_visited := {}
var _pressed_card_id := -1
var _pressed_was_selected := false
var _press_elapsed := 0.0
var _press_origin := Vector2.ZERO
var _reorder_active := false
var _dragged_card: CardView
var _drag_grab_offset := Vector2.ZERO
var _hovered_card_id := -1


func _ready() -> void:
	resized.connect(_layout_cards)
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_background_gui_input)
	set_process(true)
	set_process_input(true)


func set_hand(
	cards: Array[CardData],
	selected_ids: Array[int],
	enabled: bool,
	auto_sort_enabled: bool = true,
) -> void:
	_selected_ids.assign(selected_ids)
	_interaction_enabled = enabled
	_auto_sort_enabled = auto_sort_enabled
	var existing := {}
	for card_view in _card_views:
		existing[card_view.card_id] = card_view

	var next_views: Array[CardView] = []
	var added_views: Array[CardView] = []
	for card in cards:
		var card_view: CardView
		if existing.has(card.card_id):
			card_view = existing[card.card_id] as CardView
			existing.erase(card.card_id)
		else:
			card_view = _create_card_view(card)
			added_views.append(card_view)
		card_view.configure(card, enabled)
		card_view.set_selected(_selected_ids.has(card.card_id), true)
		next_views.append(card_view)

	for removed in existing.values():
		(removed as CardView).queue_free()
	_card_views.assign(next_views)
	_layout_cards(true)
	for index in range(added_views.size()):
		added_views[index].play_entry_animation(minf(index, 8) * 0.035)


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
		_reset_pointer_state()
	for card_view in _card_views:
		card_view.set_interaction_enabled(value)


func set_auto_sort_enabled(value: bool) -> void:
	_auto_sort_enabled = value
	if value and _reorder_active:
		_finish_reorder()


func get_ordered_ids() -> Array[int]:
	var ordered_ids: Array[int] = []
	for card_view in _card_views:
		ordered_ids.append(card_view.card_id)
	return ordered_ids


func _process(delta: float) -> void:
	if (
		_pressed_card_id == -1
		or _reorder_active
		or _auto_sort_enabled
		or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		return
	_press_elapsed += delta
	if (
		_press_elapsed >= LONG_PRESS_SECONDS
		and get_global_mouse_position().distance_to(_press_origin) <= SWIPE_THRESHOLD
	):
		_begin_reorder()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _reorder_active:
		_update_reorder(event.position)
		return
	if event is not InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _reorder_active:
			_finish_reorder()
		else:
			_reset_pointer_state()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _interaction_enabled:
		clear_selection()


func _layout_cards(instant: bool = false, skip_dragged: bool = false) -> void:
	if _card_views.is_empty() or size.x <= 0.0:
		return
	var available_width := maxf(CARD_SIZE.x, size.x - RIGHT_SAFE_AREA)
	var spacing := MAX_SPACING
	if _card_views.size() > 1:
		spacing = clampf(
			(available_width - CARD_SIZE.x) / (_card_views.size() - 1),
			MIN_SPACING,
			MAX_SPACING,
		)
	var total_width := CARD_SIZE.x + spacing * (_card_views.size() - 1)
	var start_x := maxf(0.0, (available_width - total_width) * 0.5)
	var angle_span := minf(MAX_FAN_ANGLE, maxf(0.025, _card_views.size() * 0.0045))

	for index in range(_card_views.size()):
		var card_view := _card_views[index]
		card_view.size = CARD_SIZE
		card_view.pivot_offset = CARD_SIZE * 0.5
		if not (skip_dragged and card_view == _dragged_card):
			card_view.z_index = index
		var normalized := (
			0.0
			if _card_views.size() == 1
			else float(index) / float(_card_views.size() - 1) * 2.0 - 1.0
		)
		var y := 5.0 + absf(normalized) * absf(normalized) * FAN_DEPTH
		var angle := normalized * angle_span
		card_view.set_base_transform(
			Vector2(start_x + spacing * index, y),
			angle,
			instant,
		)


func _create_card_view(card: CardData) -> CardView:
	var card_view := CardView.new()
	add_child(card_view)
	card_view.size = CARD_SIZE
	card_view.configure(card, _interaction_enabled)
	card_view.left_pressed.connect(_on_card_left_pressed)
	card_view.pointer_entered.connect(_on_card_pointer_entered)
	card_view.pointer_exited.connect(_on_card_pointer_exited)
	return card_view


func _on_card_left_pressed(card_id: int) -> void:
	if not _interaction_enabled:
		return
	_pressed_card_id = card_id
	_pressed_was_selected = _selected_ids.has(card_id)
	_press_elapsed = 0.0
	_press_origin = get_global_mouse_position()
	_selection_drag_active = true
	_drag_visited.clear()
	_toggle_card_once(card_id)


func _on_card_pointer_entered(card_id: int) -> void:
	_hovered_card_id = card_id
	_update_neighbor_avoidance()
	if (
		_selection_drag_active
		and not _reorder_active
		and _interaction_enabled
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		if get_global_mouse_position().distance_to(_press_origin) > SWIPE_THRESHOLD:
			_pressed_card_id = -1
		_toggle_card_once(card_id)


func _on_card_pointer_exited(card_id: int) -> void:
	if _hovered_card_id == card_id:
		_hovered_card_id = -1
		_update_neighbor_avoidance()


func _toggle_card_once(card_id: int) -> void:
	if _drag_visited.has(card_id):
		return
	_drag_visited[card_id] = true
	_set_card_selected(card_id, not _selected_ids.has(card_id))
	_emit_selection()


func _set_card_selected(card_id: int, value: bool) -> void:
	if value:
		if not _selected_ids.has(card_id):
			_selected_ids.append(card_id)
	else:
		_selected_ids.erase(card_id)
	var card_view := _find_card_view(card_id)
	if card_view != null:
		card_view.set_selected(value)


func _begin_reorder() -> void:
	_dragged_card = _find_card_view(_pressed_card_id)
	if _dragged_card == null:
		_reset_pointer_state()
		return
	# The press was provisionally treated as a click. Restore it before dragging.
	_set_card_selected(_pressed_card_id, _pressed_was_selected)
	_emit_selection()
	_reorder_active = true
	_selection_drag_active = false
	_drag_grab_offset = get_global_mouse_position() - _dragged_card.global_position
	_dragged_card.set_dragging(true)


func _update_reorder(global_mouse_position: Vector2) -> void:
	if _dragged_card == null:
		return
	var local_target := global_mouse_position - global_position - _drag_grab_offset
	local_target.x = clampf(local_target.x, 0.0, maxf(0.0, size.x - CARD_SIZE.x))
	local_target.y = clampf(local_target.y, -28.0, maxf(0.0, size.y - CARD_SIZE.y))
	_dragged_card.set_drag_position(local_target)

	var old_index := _card_views.find(_dragged_card)
	var target_center_x := local_target.x + CARD_SIZE.x * 0.5
	var new_index := old_index
	for index in range(_card_views.size()):
		if _card_views[index] == _dragged_card:
			continue
		var other_center := _card_views[index].position.x + CARD_SIZE.x * 0.5
		if target_center_x > other_center:
			new_index = index
		elif index < old_index:
			new_index = index
			break
	if new_index != old_index:
		_card_views.remove_at(old_index)
		_card_views.insert(clampi(new_index, 0, _card_views.size()), _dragged_card)
		_layout_cards(false, true)


func _finish_reorder() -> void:
	if not _reorder_active:
		_reset_pointer_state()
		return
	_reorder_active = false
	if _dragged_card != null:
		_dragged_card.set_dragging(false)
	_layout_cards()
	order_changed.emit(get_ordered_ids())
	_reset_pointer_state()


func _reset_pointer_state() -> void:
	_pressed_card_id = -1
	_press_elapsed = 0.0
	_selection_drag_active = false
	_reorder_active = false
	_dragged_card = null
	_drag_visited.clear()


func _update_neighbor_avoidance() -> void:
	var hovered_index := -1
	for index in range(_card_views.size()):
		if _card_views[index].card_id == _hovered_card_id:
			hovered_index = index
			break
	for index in range(_card_views.size()):
		var offset := Vector2.ZERO
		if hovered_index != -1 and index == hovered_index - 1:
			offset = Vector2(-5.0, 1.5)
		elif hovered_index != -1 and index == hovered_index + 1:
			offset = Vector2(5.0, 1.5)
		_card_views[index].set_neighbor_offset(offset)


func _find_card_view(card_id: int) -> CardView:
	for card_view in _card_views:
		if card_view.card_id == card_id:
			return card_view
	return null


func _on_background_gui_input(event: InputEvent) -> void:
	if (
		_interaction_enabled
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.double_click
	):
		play_requested.emit()
		accept_event()


func _emit_selection() -> void:
	var snapshot: Array[int] = []
	snapshot.assign(_selected_ids)
	selection_changed.emit(snapshot)
