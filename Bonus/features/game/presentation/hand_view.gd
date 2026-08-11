class_name HandView
extends Control

signal selection_changed(selected_ids: Array[int])
signal blank_double_clicked

const CARD_SIZE := Vector2(96.0, 134.0)
const MAX_SPACING := 72.0
const MIN_SPACING := 18.0
const SWIPE_THRESHOLD := 10.0
const FAN_DEPTH := 10.0
const MAX_FAN_ANGLE := 0.078

var _card_views: Array[CardView] = []
var _selected_ids: Array[int] = []
var _interaction_enabled := false
var _selection_drag_active := false
var _drag_visited := {}
var _pressed_card_id := -1
var _press_origin := Vector2.ZERO
var _hovered_card_id := -1


func _ready() -> void:
	resized.connect(_layout_cards)
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_background_gui_input)
	set_process_input(true)


func set_hand(
	cards: Array[CardData],
	selected_ids: Array[int],
	enabled: bool,
) -> void:
	_selected_ids.assign(selected_ids)
	_interaction_enabled = enabled
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
		added_views[index].play_entry_animation(
			minf(index, 8) * SettingsService.get_gameplay_duration(
				SettingsService.GameplayTiming.CARD_ENTRY,
			) * 0.09,
		)


func set_selection(selected_ids: Array[int]) -> void:
	_selected_ids.assign(selected_ids)
	for card_view in _card_views:
		card_view.set_selected(_selected_ids.has(card_view.card_id))


func refresh_card_textures() -> void:
	for card_view in _card_views:
		card_view.refresh_texture()


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
		_hovered_card_id = -1
		_update_neighbor_avoidance()
	for card_view in _card_views:
		card_view.set_interaction_enabled(value)


func get_animation_snapshots(card_ids: Array[int]) -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for card_id in card_ids:
		var card_view := _find_card_view(card_id)
		if card_view == null:
			continue
		snapshots.append({
			"card_id": card_id,
			"texture": card_view.texture_normal,
			"global_position": card_view.global_position,
			"global_rotation": card_view.get_global_transform().get_rotation(),
			"size": card_view.size,
		})
	return snapshots


func set_cards_animation_hidden(card_ids: Array[int], should_hide: bool) -> void:
	for card_id in card_ids:
		var card_view := _find_card_view(card_id)
		if card_view != null:
			card_view.visible = not should_hide


func _input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _interaction_enabled:
			_selection_drag_active = true
			_drag_visited.clear()
			_pressed_card_id = -1
			_press_origin = event.position
		else:
			_reset_pointer_state()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _interaction_enabled:
		clear_selection()


func _layout_cards(instant: bool = false) -> void:
	if _card_views.is_empty() or size.x <= 0.0:
		return
	var available_width := maxf(CARD_SIZE.x, size.x)
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
	_press_origin = get_global_mouse_position()
	_selection_drag_active = true
	_drag_visited.clear()
	_toggle_card_once(card_id)


func _on_card_pointer_entered(card_id: int) -> void:
	_hovered_card_id = card_id
	_update_neighbor_avoidance()
	if (
		_selection_drag_active
		and _interaction_enabled
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		if (
			_pressed_card_id == -1
			or get_global_mouse_position().distance_to(_press_origin) > SWIPE_THRESHOLD
		):
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


func _reset_pointer_state() -> void:
	_pressed_card_id = -1
	_selection_drag_active = false
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
		blank_double_clicked.emit()
		accept_event()


func _emit_selection() -> void:
	var snapshot: Array[int] = []
	snapshot.assign(_selected_ids)
	selection_changed.emit(snapshot)
