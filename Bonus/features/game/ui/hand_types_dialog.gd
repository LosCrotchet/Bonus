class_name HandTypesDialog
extends PanelContainer

signal close_requested

const CARD_SIZE := Vector2(48.0, 65.0)
const SUITS := [
	CardData.Suit.CLUBS,
	CardData.Suit.DIAMONDS,
	CardData.Suit.HEARTS,
	CardData.Suit.SPADES,
]

@onready var rows: VBoxContainer = %Rows

var _hover_tweens: Dictionary = {}


func _ready() -> void:
	%CloseButton.pressed.connect(func() -> void: close_requested.emit())
	SettingsService.language_changed.connect(_on_language_changed)
	_build_rows()


func _build_rows() -> void:
	_clear_rows()
	for group_data in _get_groups():
		rows.add_child(_create_point_group(group_data))


func refresh_card_style() -> void:
	_build_rows()


func _create_point_group(group_data: Dictionary) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 0)

	var point_panel := PanelContainer.new()
	point_panel.custom_minimum_size = Vector2(72.0, 0.0)
	point_panel.add_theme_stylebox_override("panel", _point_style())
	var point_label := Label.new()
	point_label.text = str(group_data["point"])
	point_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	point_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	point_label.add_theme_font_size_override("font_size", 25)
	point_label.add_theme_color_override("font_color", Color(0.98, 0.77, 0.28))
	point_panel.add_child(point_label)
	group.add_child(point_panel)

	var group_rows := VBoxContainer.new()
	group_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_rows.add_theme_constant_override("separation", 2)
	var entries := group_data["entries"] as Array
	for index in range(entries.size()):
		group_rows.add_child(_create_pattern_row(entries[index] as Dictionary, index % 2 == 1))
	group.add_child(group_rows)
	return group


func _create_pattern_row(entry: Dictionary, alternate: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 80.0)
	panel.add_theme_stylebox_override("panel", _row_style(alternate))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(160.0, 0.0)
	name_label.text = tr(entry["name"] as StringName)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.95))
	row.add_child(name_label)

	var description := Label.new()
	description.custom_minimum_size = Vector2(360.0, 0.0)
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.text = tr(entry["description"] as StringName)
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 14)
	description.add_theme_color_override("font_color", Color(0.72, 0.8, 0.78))
	row.add_child(description)

	var example_center := CenterContainer.new()
	example_center.custom_minimum_size = Vector2(285.0, 0.0)
	row.add_child(example_center)
	var example_cards := HBoxContainer.new()
	example_cards.add_theme_constant_override("separation", -16)
	example_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	example_center.add_child(example_cards)
	for card in _cards_for(entry["ranks"] as Array):
		example_cards.add_child(_create_preview_card(card))
	return panel


func _create_preview_card(card: CardData) -> TextureRect:
	var preview := TextureRect.new()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	preview.custom_minimum_size = CARD_SIZE
	preview.texture = CardTextureCatalog.get_texture(card)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_STOP
	preview.pivot_offset = CARD_SIZE * 0.5
	preview.mouse_entered.connect(_on_preview_entered.bind(preview))
	preview.mouse_exited.connect(_on_preview_exited.bind(preview))
	return preview


func _on_preview_entered(preview: TextureRect) -> void:
	AudioService.play(&"card_hover")
	_tween_preview(preview, Vector2(1.08, 1.08), -5.0, Color(1.0, 1.0, 0.92))
	preview.z_index = 3


func _on_preview_exited(preview: TextureRect) -> void:
	_tween_preview(preview, Vector2.ONE, 0.0, Color.WHITE)
	preview.z_index = 0


func _tween_preview(
	preview: TextureRect,
	target_scale: Vector2,
	target_y: float,
	target_color: Color,
) -> void:
	if _hover_tweens.has(preview):
		(_hover_tweens[preview] as Tween).kill()
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(preview, "scale", target_scale, 0.15)
	tween.tween_property(preview, "position:y", target_y, 0.15)
	tween.tween_property(preview, "self_modulate", target_color, 0.15)
	_hover_tweens[preview] = tween


func _cards_for(ranks: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	var counts := {}
	for rank_value in ranks:
		var rank := int(rank_value)
		var repeat_index := int(counts.get(rank, 0))
		counts[rank] = repeat_index + 1
		cards.append(
			CardData.new(
				10000 + cards.size(),
				rank,
				SUITS[repeat_index % SUITS.size()],
				CardData.JokerKind.NONE,
				floori(float(repeat_index) / float(SUITS.size())),
			)
		)
	return cards


func _get_groups() -> Array[Dictionary]:
	return [
		{"point": 1, "entries": [
			_entry(&"HAND_SINGLE", &"HAND_DESC_SINGLE", [7]),
		]},
		{"point": 2, "entries": [
			_entry(&"HAND_PAIR", &"HAND_DESC_PAIR", [7, 7]),
		]},
		{"point": 3, "entries": [
			_entry(&"HAND_TRIPLE", &"HAND_DESC_TRIPLE", [7, 7, 7]),
			_entry(&"HAND_STRAIGHT_3", &"HAND_DESC_STRAIGHT", [5, 6, 7]),
		]},
		{"point": 4, "entries": [
			_entry(&"HAND_FOUR_KIND", &"HAND_DESC_FOUR_KIND", [7, 7, 7, 7]),
			_entry(&"HAND_STRAIGHT_4", &"HAND_DESC_STRAIGHT", [5, 6, 7, 8]),
			_entry(&"HAND_TRIPLE_WITH_ONE", &"HAND_DESC_TRIPLE_WITH_ONE", [7, 7, 7, 9]),
			_entry(&"HAND_PAIR_STRAIGHT_2", &"HAND_DESC_PAIR_STRAIGHT", [6, 6, 7, 7]),
		]},
		{"point": 5, "entries": [
			_entry(&"HAND_FIVE_KIND", &"HAND_DESC_FIVE_KIND", [7, 7, 7, 7, 7]),
			_entry(&"HAND_STRAIGHT_5", &"HAND_DESC_STRAIGHT", [4, 5, 6, 7, 8]),
			_entry(&"HAND_TRIPLE_WITH_PAIR", &"HAND_DESC_TRIPLE_WITH_PAIR", [7, 7, 7, 9, 9]),
			_entry(&"HAND_FOUR_WITH_ONE", &"HAND_DESC_FOUR_WITH_ONE", [7, 7, 7, 7, 9]),
		]},
		{"point": 6, "entries": [
			_entry(&"HAND_SIX_KIND", &"HAND_DESC_SIX_KIND", [7, 7, 7, 7, 7, 7]),
			_entry(&"HAND_STRAIGHT_6", &"HAND_DESC_STRAIGHT", [3, 4, 5, 6, 7, 8]),
			_entry(&"HAND_FIVE_WITH_ONE", &"HAND_DESC_FIVE_WITH_ONE", [7, 7, 7, 7, 7, 9]),
			_entry(&"HAND_FOUR_WITH_TWO", &"HAND_DESC_FOUR_WITH_TWO", [7, 7, 7, 7, 9, 10]),
			_entry(&"HAND_TRIPLE_WITH_TRIPLE", &"HAND_DESC_TRIPLE_WITH_TRIPLE", [7, 7, 7, 9, 9, 9]),
			_entry(&"HAND_PAIR_STRAIGHT_3", &"HAND_DESC_PAIR_STRAIGHT", [6, 6, 7, 7, 8, 8]),
		]},
	]


func _entry(name_key: StringName, description_key: StringName, ranks: Array) -> Dictionary:
	return {"name": name_key, "description": description_key, "ranks": ranks}


func _point_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.1, 0.1, 0.98)
	style.border_width_right = 1
	style.border_color = Color(0.28, 0.4, 0.37, 0.8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	return style


func _row_style(alternate: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.115, 0.145, 0.14, 0.96)
		if alternate
		else Color(0.095, 0.12, 0.118, 0.96)
	)
	style.content_margin_left = 16.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	return style


func _clear_rows() -> void:
	for child in rows.get_children():
		child.queue_free()


func _on_language_changed(_locale: String) -> void:
	_build_rows()
