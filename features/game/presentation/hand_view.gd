class_name HandView
extends Control

signal card_toggled(card_id: int, selected: bool)

const CARD_SIZE := Vector2(96.0, 134.0)
const MAX_SPACING := 72.0
const MIN_SPACING := 22.0
const DEFAULT_Y := 18.0
const SELECTED_Y := 0.0

var _card_views: Array[CardView] = []
var _selected_ids: Array[int] = []
var _interaction_enabled := false


func _ready() -> void:
	resized.connect(_layout_cards)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_hand(cards: Array[CardData], selected_ids: Array[int], enabled: bool) -> void:
	_clear_cards()
	_selected_ids.assign(selected_ids)
	_interaction_enabled = enabled

	for card in cards:
		var card_view := CardView.new()
		add_child(card_view)
		card_view.configure(card, enabled)
		card_view.set_selected(_selected_ids.has(card.card_id))
		card_view.selection_changed.connect(_on_card_selection_changed)
		_card_views.append(card_view)

	_layout_cards.call_deferred()


func set_selection(selected_ids: Array[int]) -> void:
	_selected_ids.assign(selected_ids)
	for card_view in _card_views:
		card_view.set_selected(_selected_ids.has(card_view.card_id))
	_layout_cards()


func set_interaction_enabled(value: bool) -> void:
	_interaction_enabled = value
	for card_view in _card_views:
		card_view.set_interaction_enabled(value)


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
		card_view.position = Vector2(
			start_x + spacing * index,
			SELECTED_Y if _selected_ids.has(card_view.card_id) else DEFAULT_Y,
		)
		card_view.z_index = 100 + index if _selected_ids.has(card_view.card_id) else index


func _clear_cards() -> void:
	for card_view in _card_views:
		card_view.queue_free()
	_card_views.clear()


func _on_card_selection_changed(card_id: int, selected: bool) -> void:
	if selected and not _selected_ids.has(card_id):
		_selected_ids.append(card_id)
	elif not selected:
		_selected_ids.erase(card_id)
	_layout_cards()
	card_toggled.emit(card_id, selected)
