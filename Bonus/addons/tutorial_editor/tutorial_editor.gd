@tool
extends Control

const DEFAULT_SCENARIO := "res://features/tutorial/content/default_tutorial.tres"
const STEP_DIRECTORY := "res://features/tutorial/content/steps"
const PreviewClass := preload("res://addons/tutorial_editor/tutorial_preview.gd")

var _editor_interface: EditorInterface
var _scenario: TutorialScenario
var _step: TutorialStep
var _transition: TutorialTransition
var _updating := false

var _path_edit: LineEdit
var _status: Label
var _step_list: ItemList
var _preview: TutorialEditorPreview
var _graph: GraphEdit
var _hands_tree: Tree
var _transition_list: ItemList
var _directive_list: ItemList
var _ai_list: ItemList

var _id_edit: LineEdit
var _trigger_edit: LineEdit
var _message_key_edit: LineEdit
var _message_edit: TextEdit
var _placement_option: OptionButton
var _custom_rect_check: CheckBox
var _rect_label: Label
var _emoji_edit: LineEdit
var _pointer_edit: LineEdit
var _pointer_size: SpinBox
var _highlight_edit: LineEdit
var _blocks_check: CheckBox
var _dim_check: CheckBox
var _continue_option: OptionButton
var _continue_event_edit: LineEdit
var _minimum_time: SpinBox
var _lock_checks: Array[CheckBox] = []

var _directive_mode: OptionButton
var _ai_player: SpinBox
var _ai_phase: OptionButton
var _ai_action: OptionButton
var _ai_dice: SpinBox
var _ai_ids: LineEdit
var _ai_ranks: LineEdit
var _ai_interpretation: LineEdit
var _transition_mode: OptionButton
var _transition_event: LineEdit
var _transition_target: LineEdit

var _scenario_dialog: FileDialog
var _texture_dialog: FileDialog
var _texture_target := ""


func set_editor_interface(value: EditorInterface) -> void:
	_editor_interface = value


func _ready() -> void:
	_build_ui()
	_load_scenario(DEFAULT_SCENARIO)


func save_all() -> void:
	_commit_step_fields()
	_commit_transition_fields()
	if _scenario == null:
		return
	for step in _scenario.steps:
		if step == null:
			continue
		var path := step.resource_path
		if path.is_empty():
			path = "%s/%s.tres" % [STEP_DIRECTORY, _safe_file_name(str(step.step_id))]
		var result := ResourceSaver.save(step, path)
		if result != OK:
			_set_status("Could not save %s (error %d)" % [path, result], true)
			return
	var scenario_path := _scenario.resource_path
	if scenario_path.is_empty():
		scenario_path = DEFAULT_SCENARIO
	var result := ResourceSaver.save(_scenario, scenario_path)
	if result == OK:
		_path_edit.text = scenario_path
		_set_status("Saved %s" % scenario_path)
	else:
		_set_status("Could not save scenario (error %d)" % result, true)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"separation", 6)
	add_child(root)
	root.add_child(_build_toolbar())

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 270
	root.add_child(split)
	split.add_child(_build_left_panel())

	var center_split := HSplitContainer.new()
	center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_split.split_offset = -380
	split.add_child(center_split)
	center_split.add_child(_build_center_panel())
	center_split.add_child(_build_inspector())

	_scenario_dialog = FileDialog.new()
	_scenario_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_scenario_dialog.access = FileDialog.ACCESS_RESOURCES
	_scenario_dialog.filters = PackedStringArray(["*.tres ; Tutorial resources"])
	_scenario_dialog.file_selected.connect(_load_scenario)
	add_child(_scenario_dialog)

	_texture_dialog = FileDialog.new()
	_texture_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_texture_dialog.access = FileDialog.ACCESS_RESOURCES
	_texture_dialog.filters = PackedStringArray(["*.png,*.webp,*.svg ; Images"])
	_texture_dialog.file_selected.connect(_on_texture_selected)
	add_child(_texture_dialog)


func _build_toolbar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 38.0
	bar.add_child(_make_label("Scenario", 74.0))
	_path_edit = LineEdit.new()
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.placeholder_text = DEFAULT_SCENARIO
	bar.add_child(_path_edit)
	bar.add_child(_make_button("Open", func() -> void: _scenario_dialog.popup_centered_ratio(0.72)))
	bar.add_child(_make_button("Reload", func() -> void: _load_scenario(_path_edit.text)))
	bar.add_child(_make_button("Save All", save_all))
	bar.add_child(_make_button("Validate", _validate_scenario))
	bar.add_child(_make_button("Run Tutorial", _run_tutorial))
	_status = Label.new()
	_status.custom_minimum_size.x = 220.0
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_status)
	return bar


func _build_left_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 260.0
	panel.add_child(_section_title("SCENARIO"))
	var match_grid := GridContainer.new()
	match_grid.columns = 2
	match_grid.add_child(_make_label("Players"))
	var players := SpinBox.new()
	players.min_value = 2
	players.max_value = 4
	players.value_changed.connect(func(value: float) -> void:
		if _scenario != null and not _updating:
			_scenario.player_count = int(value)
			_refresh_hands()
	)
	players.set_meta(&"field", &"players")
	match_grid.add_child(players)
	match_grid.add_child(_make_label("Seed"))
	var seed := LineEdit.new()
	seed.text_changed.connect(func(value: String) -> void:
		if _scenario != null and not _updating:
			_scenario.seed_text = value
			_refresh_hands()
	)
	seed.set_meta(&"field", &"seed")
	match_grid.add_child(seed)
	panel.add_child(match_grid)
	var scenario_actions := HBoxContainer.new()
	scenario_actions.add_child(_make_button("Selected = Start", _set_selected_as_start))
	scenario_actions.add_child(_make_button("Legacy order", _clear_graph_entry))
	panel.add_child(scenario_actions)
	panel.add_child(_make_button("Edit scenario rules in Inspector", _inspect_scenario))
	panel.add_child(HSeparator.new())
	panel.add_child(_section_title("STEPS"))
	_step_list = ItemList.new()
	_step_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_step_list.allow_reselect = true
	_step_list.item_selected.connect(_select_step)
	panel.add_child(_step_list)
	var actions := HBoxContainer.new()
	actions.add_child(_make_button("+", _add_step, 38.0))
	actions.add_child(_make_button("Up", func() -> void: _move_step(-1)))
	actions.add_child(_make_button("Down", func() -> void: _move_step(1)))
	actions.add_child(_make_button("Duplicate", _duplicate_step))
	actions.add_child(_make_button("Delete", _delete_step))
	panel.add_child(actions)
	panel.add_child(HSeparator.new())
	panel.add_child(_section_title("DETERMINISTIC HANDS"))
	_hands_tree = Tree.new()
	_hands_tree.custom_minimum_size.y = 170.0
	_hands_tree.columns = 1
	_hands_tree.hide_root = true
	panel.add_child(_hands_tree)
	return panel


func _build_center_panel() -> Control:
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var preview_margin := MarginContainer.new()
	preview_margin.name = "WYSIWYG Preview"
	preview_margin.add_theme_constant_override(&"margin_left", 8)
	preview_margin.add_theme_constant_override(&"margin_top", 8)
	preview_margin.add_theme_constant_override(&"margin_right", 8)
	preview_margin.add_theme_constant_override(&"margin_bottom", 8)
	_preview = PreviewClass.new() as TutorialEditorPreview
	_preview.dialog_rect_changed.connect(_on_preview_dialog_rect_changed)
	_preview.target_sampled.connect(_on_target_sampled)
	preview_margin.add_child(_preview)
	tabs.add_child(preview_margin)

	_graph = GraphEdit.new()
	_graph.name = "Flow Graph"
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.show_arrange_button = true
	_graph.right_disconnects = true
	_graph.add_valid_right_disconnect_type(0)
	_graph.add_theme_constant_override(&"port_hotzone_inner_extent", 34)
	_graph.add_theme_constant_override(&"port_hotzone_outer_extent", 34)
	_graph.connection_request.connect(_on_graph_connection_requested)
	_graph.disconnection_request.connect(_on_graph_disconnection_requested)
	_graph.delete_nodes_request.connect(_on_graph_delete_requested)
	var graph_hint := Label.new()
	graph_hint.text = "Drag yellow output -> blue input"
	graph_hint.add_theme_color_override(&"font_color", Color(0.75, 0.8, 0.8))
	_graph.get_menu_hbox().add_child(graph_hint)
	tabs.add_child(_graph)
	return tabs


func _build_inspector() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 370.0
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override(&"separation", 7)
	scroll.add_child(form)
	form.add_child(_section_title("STEP CONTENT"))
	_id_edit = _line_field(form, "Step ID", _on_step_text_changed)
	_trigger_edit = _line_field(form, "Legacy trigger", _on_step_text_changed)
	_message_key_edit = _line_field(form, "Translation key", _on_step_text_changed)
	form.add_child(_make_label("Dialogue / fallback text"))
	_message_edit = TextEdit.new()
	_message_edit.custom_minimum_size.y = 100.0
	_message_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_message_edit.text_changed.connect(_on_step_text_changed)
	form.add_child(_message_edit)

	var emoji_row := HBoxContainer.new()
	emoji_row.add_child(_make_label("Emoji", 105.0))
	_emoji_edit = LineEdit.new()
	_emoji_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_emoji_edit.text_changed.connect(_on_step_text_changed)
	emoji_row.add_child(_emoji_edit)
	emoji_row.add_child(_make_button("...", _pick_emoji, 34.0))
	form.add_child(emoji_row)

	var placement_row := HBoxContainer.new()
	placement_row.add_child(_make_label("Preset", 105.0))
	_placement_option = OptionButton.new()
	for label in ["Bottom", "Top", "Left", "Right"]:
		_placement_option.add_item(label)
	_placement_option.item_selected.connect(_on_step_value_changed)
	placement_row.add_child(_placement_option)
	_custom_rect_check = CheckBox.new()
	_custom_rect_check.text = "Custom rect"
	_custom_rect_check.toggled.connect(_on_step_value_changed)
	placement_row.add_child(_custom_rect_check)
	form.add_child(placement_row)
	_rect_label = Label.new()
	_rect_label.add_theme_color_override(&"font_color", Color(0.65, 0.72, 0.72))
	form.add_child(_rect_label)

	form.add_child(HSeparator.new())
	form.add_child(_section_title("POINTER & HIGHLIGHT"))
	_pointer_edit = _sample_path_field(form, "Pointer target", &"pointer")
	var pointer_row := HBoxContainer.new()
	pointer_row.add_child(_make_label("Pointer emoji", 105.0))
	var pointer_texture := LineEdit.new()
	pointer_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pointer_texture.text_changed.connect(func(value: String) -> void:
		if _step != null and not _updating:
			_step.pointer_emoji = load(value) as Texture2D if ResourceLoader.exists(value) else null
			_preview.queue_redraw()
	)
	pointer_texture.set_meta(&"field", &"pointer_texture")
	pointer_row.add_child(pointer_texture)
	pointer_row.add_child(_make_button("...", func() -> void: _pick_texture("pointer"), 34.0))
	form.add_child(pointer_row)
	_pointer_size = SpinBox.new()
	_pointer_size.min_value = 24
	_pointer_size.max_value = 160
	_pointer_size.value_changed.connect(_on_step_value_changed)
	_add_labeled_control(form, "Pointer size", _pointer_size)
	_highlight_edit = _sample_path_field(form, "Highlight", &"highlight")

	form.add_child(HSeparator.new())
	form.add_child(_section_title("TIMING & FLOW"))
	_blocks_check = _check_field(form, "Block all gameplay", _on_step_value_changed)
	_dim_check = _check_field(form, "Dim background", _on_step_value_changed)
	_continue_option = OptionButton.new()
	_continue_option.add_item("Click anywhere")
	_continue_option.add_item("Wait for event")
	_continue_option.item_selected.connect(_on_step_value_changed)
	_add_labeled_control(form, "Continue", _continue_option)
	_continue_event_edit = _line_field(form, "Continue event", _on_step_text_changed)
	_minimum_time = SpinBox.new()
	_minimum_time.min_value = 0.0
	_minimum_time.max_value = 5.0
	_minimum_time.step = 0.05
	_minimum_time.value_changed.connect(_on_step_value_changed)
	_add_labeled_control(form, "Minimum time", _minimum_time)

	form.add_child(_section_title("INPUT LOCKS"))
	var lock_grid := GridContainer.new()
	lock_grid.columns = 2
	for lock_name in ["Deal skip", "Double click", "Roll", "Hand", "Play", "Pass", "Hint", "Automation", "AI"]:
		var check := CheckBox.new()
		check.text = lock_name
		check.toggled.connect(_on_input_locks_changed)
		_lock_checks.append(check)
		lock_grid.add_child(check)
	form.add_child(lock_grid)

	form.add_child(HSeparator.new())
	form.add_child(_section_title("CONTROL DIRECTIVES"))
	_directive_list = ItemList.new()
	_directive_list.custom_minimum_size.y = 86.0
	form.add_child(_directive_list)
	var directive_row := HBoxContainer.new()
	_directive_mode = OptionButton.new()
	for mode_name in ["Disable", "Hide", "Enable", "Show"]:
		_directive_mode.add_item(mode_name)
	directive_row.add_child(_directive_mode)
	directive_row.add_child(_make_button("Sample & add", func() -> void: _preview.begin_sample(&"control")))
	directive_row.add_child(_make_button("Remove", _remove_directive))
	form.add_child(directive_row)

	form.add_child(HSeparator.new())
	form.add_child(_section_title("SCRIPTED AI"))
	_ai_list = ItemList.new()
	_ai_list.custom_minimum_size.y = 90.0
	form.add_child(_ai_list)
	var ai_grid := GridContainer.new()
	ai_grid.columns = 2
	_ai_player = SpinBox.new()
	_ai_player.min_value = 1
	_ai_player.max_value = 3
	_add_grid_field(ai_grid, "Player index", _ai_player)
	_ai_phase = OptionButton.new()
	for value in ["Any", "Awaiting roll", "Awaiting action"]:
		_ai_phase.add_item(value)
	_add_grid_field(ai_grid, "Phase", _ai_phase)
	_ai_action = OptionButton.new()
	for value in ["Roll", "Play", "Pass"]:
		_ai_action.add_item(value)
	_add_grid_field(ai_grid, "Action", _ai_action)
	_ai_dice = SpinBox.new()
	_ai_dice.min_value = 0
	_ai_dice.max_value = 6
	_ai_dice.tooltip_text = "0 uses the seeded RNG; 1-6 forces the result."
	_add_grid_field(ai_grid, "Forced dice", _ai_dice)
	_ai_ids = LineEdit.new()
	_ai_ids.placeholder_text = "e.g. 14, 27"
	_add_grid_field(ai_grid, "Card IDs", _ai_ids)
	_ai_ranks = LineEdit.new()
	_ai_ranks.placeholder_text = "e.g. 3, 3, 4"
	_add_grid_field(ai_grid, "Ranks", _ai_ranks)
	_ai_interpretation = LineEdit.new()
	_add_grid_field(ai_grid, "Interpretation", _ai_interpretation)
	form.add_child(ai_grid)
	var ai_actions := HBoxContainer.new()
	ai_actions.add_child(_make_button("Add command", _add_ai_command))
	ai_actions.add_child(_make_button("Remove", _remove_ai_command))
	form.add_child(ai_actions)

	form.add_child(HSeparator.new())
	form.add_child(_section_title("OUTGOING TRANSITIONS"))
	_transition_list = ItemList.new()
	_transition_list.custom_minimum_size.y = 92.0
	_transition_list.item_selected.connect(_select_transition)
	form.add_child(_transition_list)
	_transition_mode = OptionButton.new()
	_transition_mode.add_item("Click")
	_transition_mode.add_item("Event")
	_transition_mode.item_selected.connect(_on_transition_changed)
	_add_labeled_control(form, "Trigger", _transition_mode)
	_transition_event = _line_field(form, "Event", _on_transition_changed)
	_transition_target = _line_field(form, "Target step", _on_transition_changed)
	var transition_actions := HBoxContainer.new()
	transition_actions.add_child(_make_button("Remove", _remove_transition))
	transition_actions.add_child(_make_button("Edit conditions", _inspect_transition))
	form.add_child(transition_actions)
	form.add_child(_make_button("Edit every step parameter in Inspector", _inspect_step))
	return scroll


func _load_scenario(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		_set_status("Scenario not found: %s" % path, true)
		return
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if loaded is not TutorialScenario:
		_set_status("Resource is not a TutorialScenario", true)
		return
	_scenario = loaded as TutorialScenario
	_path_edit.text = path
	_refresh_scenario_fields()
	_rebuild_step_list()
	_rebuild_graph()
	_refresh_hands()
	if not _scenario.steps.is_empty():
		_step_list.select(0)
		_select_step(0)
	else:
		_set_step(null)
	_set_status("Loaded %s" % path)


func _refresh_scenario_fields() -> void:
	_updating = true
	for node in _find_nodes_with_meta(self, &"field"):
		match node.get_meta(&"field"):
			&"players":
				(node as SpinBox).value = _scenario.player_count
			&"seed":
				(node as LineEdit).text = _scenario.seed_text
	_updating = false


func _rebuild_step_list() -> void:
	_step_list.clear()
	if _scenario == null:
		return
	for index in range(_scenario.steps.size()):
		var step := _scenario.steps[index]
		_step_list.add_item("%02d  %s" % [index + 1, step.step_id if step != null else "<empty>"])


func _select_step(index: int) -> void:
	if _scenario == null or index < 0 or index >= _scenario.steps.size():
		return
	_commit_step_fields()
	_set_step(_scenario.steps[index])


func _set_step(value: TutorialStep) -> void:
	_step = value
	_transition = null
	_preview.set_step(value)
	_refresh_step_fields()
	_refresh_directives()
	_refresh_ai_commands()
	_refresh_transitions()


func _refresh_step_fields() -> void:
	_updating = true
	var enabled := _step != null
	var controls := [
		_id_edit, _trigger_edit, _message_key_edit, _message_edit,
		_placement_option, _custom_rect_check, _emoji_edit, _pointer_edit,
		_pointer_size, _highlight_edit, _blocks_check, _dim_check,
		_continue_option, _continue_event_edit, _minimum_time,
	]
	for control in controls:
		if control is LineEdit or control is TextEdit or control is SpinBox:
			control.editable = enabled
		elif control is BaseButton:
			control.disabled = not enabled
	if _step != null:
		_id_edit.text = str(_step.step_id)
		_trigger_edit.text = str(_step.trigger)
		_message_key_edit.text = str(_step.message_key)
		_message_edit.text = _step.fallback_message
		_placement_option.select(_step.placement)
		_custom_rect_check.button_pressed = _step.use_custom_dialog_rect
		_emoji_edit.text = _step.emoji.resource_path if _step.emoji != null else ""
		_pointer_edit.text = str(_step.pointer_target_path)
		_pointer_size.value = _step.pointer_size
		_highlight_edit.text = str(_step.highlight_path)
		_blocks_check.button_pressed = _step.blocks_gameplay
		_dim_check.button_pressed = _step.dim_background
		_continue_option.select(_step.continue_mode)
		_continue_event_edit.text = str(_step.continue_event)
		_minimum_time.value = _step.minimum_display_time
		for index in range(_lock_checks.size()):
			_lock_checks[index].button_pressed = (_step.input_locks & (1 << index)) != 0
		_update_rect_label()
	else:
		_id_edit.text = ""
		_trigger_edit.text = ""
		_message_key_edit.text = ""
		_message_edit.text = ""
		_rect_label.text = ""
	_updating = false


func _commit_step_fields() -> void:
	if _step == null or _updating:
		return
	var old_id := _step.step_id
	_step.step_id = StringName(_id_edit.text.strip_edges())
	_step.trigger = StringName(_trigger_edit.text.strip_edges())
	_step.message_key = StringName(_message_key_edit.text.strip_edges())
	_step.fallback_message = _message_edit.text
	_step.placement = _placement_option.selected
	_step.use_custom_dialog_rect = _custom_rect_check.button_pressed
	_step.emoji = load(_emoji_edit.text) as Texture2D if ResourceLoader.exists(_emoji_edit.text) else null
	_step.pointer_target_path = NodePath(_pointer_edit.text)
	_step.pointer_size = _pointer_size.value
	_step.highlight_path = NodePath(_highlight_edit.text)
	_step.blocks_gameplay = _blocks_check.button_pressed
	_step.dim_background = _dim_check.button_pressed
	_step.continue_mode = _continue_option.selected
	_step.continue_event = StringName(_continue_event_edit.text.strip_edges())
	_step.minimum_display_time = _minimum_time.value
	if old_id != _step.step_id:
		_update_transition_targets(old_id, _step.step_id)
		_rebuild_step_list()
		_rebuild_graph()
	_preview.queue_redraw()


func _on_step_text_changed(_value: Variant = null) -> void:
	if not _updating:
		_commit_step_fields()


func _on_step_value_changed(_value: Variant = null) -> void:
	if not _updating:
		_commit_step_fields()
		_update_rect_label()


func _on_input_locks_changed(_enabled: bool) -> void:
	if _step == null or _updating:
		return
	var mask := 0
	for index in range(_lock_checks.size()):
		if _lock_checks[index].button_pressed:
			mask |= 1 << index
	_step.input_locks = mask


func _on_preview_dialog_rect_changed(_rect: Rect2) -> void:
	_custom_rect_check.set_pressed_no_signal(true)
	_update_rect_label()


func _update_rect_label() -> void:
	if _step == null:
		_rect_label.text = ""
		return
	var rect := _step.normalized_dialog_rect
	_rect_label.text = (
		"Normalized rect  x %.3f  y %.3f  w %.3f  h %.3f"
		% [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	)


func _on_target_sampled(kind: StringName, path: NodePath) -> void:
	if _step == null:
		return
	match kind:
		&"pointer":
			_pointer_edit.text = str(path)
			_step.pointer_target_path = path
		&"highlight":
			_highlight_edit.text = str(path)
			_step.highlight_path = path
		&"control":
			var directive := TutorialControlDirective.new()
			directive.target_path = path
			directive.mode = _directive_mode.selected
			_step.control_directives.append(directive)
			_refresh_directives()
	_preview.queue_redraw()
	_set_status("Sampled %s: %s" % [kind, path])


func _add_step() -> void:
	if _scenario == null:
		return
	var new_step := TutorialStep.new()
	new_step.step_id = _unique_step_id("step_%02d" % (_scenario.steps.size() + 1))
	new_step.editor_graph_position = Vector2(80.0 + _scenario.steps.size() * 240.0, 120.0)
	_scenario.steps.append(new_step)
	if _scenario.entry_step_id.is_empty():
		_scenario.entry_step_id = new_step.step_id
	_rebuild_step_list()
	_rebuild_graph()
	var index := _scenario.steps.size() - 1
	_step_list.select(index)
	_select_step(index)


func _duplicate_step() -> void:
	if _scenario == null or _step == null:
		return
	var copy := _step.duplicate(true) as TutorialStep
	copy.step_id = _unique_step_id("%s_copy" % _step.step_id)
	copy.editor_graph_position += Vector2(40.0, 70.0)
	copy.transitions.clear()
	_scenario.steps.append(copy)
	_rebuild_step_list()
	_rebuild_graph()
	var index := _scenario.steps.size() - 1
	_step_list.select(index)
	_select_step(index)


func _delete_step() -> void:
	if _scenario == null or _step == null:
		return
	var removed_id := _step.step_id
	var index := _scenario.steps.find(_step)
	_scenario.steps.erase(_step)
	for step in _scenario.steps:
		for transition in step.transitions.duplicate():
			if transition.target_step_id == removed_id:
				step.transitions.erase(transition)
	if _scenario.entry_step_id == removed_id:
		_scenario.entry_step_id = _scenario.steps[0].step_id if not _scenario.steps.is_empty() else &""
	_rebuild_step_list()
	_rebuild_graph()
	if _scenario.steps.is_empty():
		_set_step(null)
	else:
		index = clampi(index, 0, _scenario.steps.size() - 1)
		_step_list.select(index)
		_select_step(index)


func _move_step(direction: int) -> void:
	if _scenario == null or _step == null:
		return
	var old_index := _scenario.steps.find(_step)
	var new_index := clampi(old_index + direction, 0, _scenario.steps.size() - 1)
	if old_index == new_index:
		return
	var moved := _scenario.steps[old_index]
	_scenario.steps.remove_at(old_index)
	_scenario.steps.insert(new_index, moved)
	_rebuild_step_list()
	_step_list.select(new_index)
	_rebuild_graph()


func _set_selected_as_start() -> void:
	if _scenario == null or _step == null:
		return
	_scenario.entry_step_id = _step.step_id
	_rebuild_graph()
	_set_status("Graph entry: %s" % _step.step_id)


func _clear_graph_entry() -> void:
	if _scenario == null:
		return
	_scenario.entry_step_id = &""
	_rebuild_graph()
	_set_status("Legacy ordered mode enabled")


func _rebuild_graph() -> void:
	if _graph == null:
		return
	_graph.clear_connections()
	for child in _graph.get_children():
		if child is GraphNode:
			_graph.remove_child(child)
			child.queue_free()
	if _scenario == null:
		return
	for index in range(_scenario.steps.size()):
		var step := _scenario.steps[index]
		if step == null or step.step_id.is_empty():
			continue
		var node := GraphNode.new()
		node.name = str(step.step_id)
		node.title = "%s%s" % ["START  " if step.step_id == _scenario.entry_step_id else "", step.step_id]
		node.position_offset = (
			step.editor_graph_position
			if step.editor_graph_position != Vector2.ZERO
			else Vector2(80 + index * 230, 100)
		)
		var summary := Label.new()
		summary.custom_minimum_size = Vector2(170, 54)
		summary.text = _step_summary(step)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.add_child(summary)
		node.set_slot(0, true, 0, Color(0.4, 0.8, 1.0), true, 0, Color(1.0, 0.72, 0.3))
		node.node_selected.connect(_select_graph_node.bind(step))
		node.position_offset_changed.connect(func() -> void: step.editor_graph_position = node.position_offset)
		_graph.add_child(node)
	for step in _scenario.steps:
		if step == null:
			continue
		for transition in step.transitions:
			if transition != null and _graph.has_node(NodePath(str(transition.target_step_id))):
				if not _graph.is_node_connected(step.step_id, 0, transition.target_step_id, 0):
					var error := _graph.connect_node(
						step.step_id,
						0,
						transition.target_step_id,
						0,
					)
					if error != OK:
						push_error(
							"Could not draw tutorial transition %s -> %s (error %d)"
							% [step.step_id, transition.target_step_id, error],
						)


func _on_graph_connection_requested(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	var source := _scenario.get_step(from)
	if source == null or _has_transition_to(source, to):
		return
	var transition := TutorialTransition.new()
	transition.target_step_id = to
	source.transitions.append(transition)
	var error := _graph.connect_node(from, 0, to, 0)
	if error != OK:
		source.transitions.erase(transition)
		_set_status("Could not create graph connection (error %d)" % error, true)
		return
	_set_step(source)
	_select_transition(source.transitions.size() - 1)
	_set_status("Connected %s -> %s" % [from, to])


func _has_transition_to(source: TutorialStep, target_id: StringName) -> bool:
	for transition in source.transitions:
		if transition != null and transition.target_step_id == target_id:
			return true
	return false


func _on_graph_disconnection_requested(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	var source := _scenario.get_step(from)
	if source == null:
		return
	for transition in source.transitions.duplicate():
		if transition != null and transition.target_step_id == to:
			source.transitions.erase(transition)
	if _graph.is_node_connected(from, 0, to, 0):
		_graph.disconnect_node(from, 0, to, 0)
	_refresh_transitions()
	_set_status("Disconnected %s -> %s" % [from, to])


func _on_graph_delete_requested(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var target := _scenario.get_step(node_name)
		if target != null:
			_step = target
			_delete_step()


func _select_graph_node(step: TutorialStep) -> void:
	var index := _scenario.steps.find(step)
	if index >= 0:
		_step_list.select(index)
		_select_step(index)


func _refresh_transitions() -> void:
	_transition_list.clear()
	_transition = null
	if _step == null:
		return
	for transition in _step.transitions:
		_transition_list.add_item("%s  ->  %s" % [transition.get_label(), transition.target_step_id])
	_refresh_transition_fields()


func _select_transition(index: int) -> void:
	_commit_transition_fields()
	_transition = _step.transitions[index] if _step != null and index < _step.transitions.size() else null
	_refresh_transition_fields()


func _refresh_transition_fields() -> void:
	_updating = true
	if _transition == null:
		_transition_mode.select(0)
		_transition_event.text = ""
		_transition_target.text = ""
	else:
		_transition_mode.select(_transition.trigger_mode)
		_transition_event.text = str(_transition.event_key)
		_transition_target.text = str(_transition.target_step_id)
	_updating = false


func _commit_transition_fields() -> void:
	if _transition == null or _updating:
		return
	_transition.trigger_mode = _transition_mode.selected
	_transition.event_key = StringName(_transition_event.text.strip_edges())
	_transition.target_step_id = StringName(_transition_target.text.strip_edges())


func _on_transition_changed(_value: Variant = null) -> void:
	if _updating:
		return
	_commit_transition_fields()
	if _transition != null:
		var index := _step.transitions.find(_transition)
		if index >= 0 and index < _transition_list.item_count:
			_transition_list.set_item_text(index, "%s  ->  %s" % [_transition.get_label(), _transition.target_step_id])
	_rebuild_graph()


func _remove_transition() -> void:
	if _step == null or _transition == null:
		return
	_step.transitions.erase(_transition)
	_transition = null
	_refresh_transitions()
	_rebuild_graph()


func _refresh_directives() -> void:
	_directive_list.clear()
	if _step == null:
		return
	for directive in _step.control_directives:
		_directive_list.add_item(directive.get_summary())


func _remove_directive() -> void:
	if _step == null or _directive_list.get_selected_items().is_empty():
		return
	_step.control_directives.remove_at(_directive_list.get_selected_items()[0])
	_refresh_directives()


func _refresh_ai_commands() -> void:
	_ai_list.clear()
	if _step == null:
		return
	for command in _step.scripted_ai_actions:
		_ai_list.add_item(command.get_summary())


func _add_ai_command() -> void:
	if _step == null:
		return
	var command := TutorialAICommand.new()
	command.player_index = int(_ai_player.value)
	command.phase = _ai_phase.selected
	command.action = _ai_action.selected
	command.forced_dice_value = int(_ai_dice.value)
	command.card_ids = _parse_int_list(_ai_ids.text)
	command.ranks = _parse_int_list(_ai_ranks.text)
	command.interpretation_key = _ai_interpretation.text.strip_edges()
	_step.scripted_ai_actions.append(command)
	_refresh_ai_commands()


func _remove_ai_command() -> void:
	if _step == null or _ai_list.get_selected_items().is_empty():
		return
	_step.scripted_ai_actions.remove_at(_ai_list.get_selected_items()[0])
	_refresh_ai_commands()


func _refresh_hands() -> void:
	_hands_tree.clear()
	var root := _hands_tree.create_item()
	if _scenario == null:
		return
	for hand in _scenario.get_initial_hands_debug():
		var item := _hands_tree.create_item(root)
		var card_labels := PackedStringArray()
		for card in hand["cards"] as Array:
			card_labels.append("%s#%d" % [card["label"], card["card_id"]])
		item.set_text(0, "P%d  %s" % [int(hand["player_index"]), "  ".join(card_labels)])
		item.set_tooltip_text(0, "Use #numbers as exact card_ids in scripted AI commands.")


func _validate_scenario() -> void:
	_commit_step_fields()
	if _scenario == null:
		return
	var errors := _scenario.validate_graph()
	if errors.is_empty():
		_set_status("Validation passed: %d steps" % _scenario.steps.size())
	else:
		_set_status(" | ".join(errors), true)


func _run_tutorial() -> void:
	save_all()
	if _editor_interface != null:
		_editor_interface.play_main_scene()
	_set_status("Project started. Choose Tutorial on the main menu.")


func _inspect_step() -> void:
	if _editor_interface != null and _step != null:
		_editor_interface.edit_resource(_step)


func _inspect_scenario() -> void:
	if _editor_interface != null and _scenario != null:
		_editor_interface.edit_resource(_scenario)


func _inspect_transition() -> void:
	if _editor_interface != null and _transition != null:
		_editor_interface.edit_resource(_transition)


func _pick_emoji() -> void:
	_pick_texture("emoji")


func _pick_texture(target: String) -> void:
	_texture_target = target
	_texture_dialog.popup_centered_ratio(0.72)


func _on_texture_selected(path: String) -> void:
	if _step == null:
		return
	if _texture_target == "emoji":
		_emoji_edit.text = path
		_step.emoji = load(path) as Texture2D
	else:
		for node in _find_nodes_with_meta(self, &"field"):
			if node.get_meta(&"field") == &"pointer_texture":
				(node as LineEdit).text = path
		_step.pointer_emoji = load(path) as Texture2D
	_preview.queue_redraw()


func _update_transition_targets(old_id: StringName, new_id: StringName) -> void:
	if _scenario.entry_step_id == old_id:
		_scenario.entry_step_id = new_id
	for step in _scenario.steps:
		for transition in step.transitions:
			if transition != null and transition.target_step_id == old_id:
				transition.target_step_id = new_id


func _unique_step_id(base: String) -> StringName:
	var candidate := base
	var suffix := 2
	while _scenario.get_step(StringName(candidate)) != null:
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return StringName(candidate)


func _parse_int_list(text: String) -> Array[int]:
	var result: Array[int] = []
	for value in text.replace("，", ",").split(",", false):
		if value.strip_edges().is_valid_int():
			result.append(value.strip_edges().to_int())
	return result


func _safe_file_name(value: String) -> String:
	var result := value.to_lower()
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(character, "_")
	return result if not result.is_empty() else "tutorial_step"


func _step_summary(step: TutorialStep) -> String:
	var message := step.fallback_message.replace("\n", " ")
	if message.is_empty():
		message = "[%s]" % step.message_key
	return message.left(55) + ("..." if message.length() > 55 else "")


func _set_status(text: String, error := false) -> void:
	_status.text = text
	_status.add_theme_color_override(&"font_color", Color(1.0, 0.42, 0.38) if error else Color(0.48, 0.9, 0.62))


func _make_label(text: String, width := 0.0) -> Label:
	var label := Label.new()
	label.text = text
	if width > 0.0:
		label.custom_minimum_size.x = width
	return label


func _section_title(text: String) -> Label:
	var label := _make_label(text)
	label.add_theme_font_size_override(&"font_size", 13)
	label.add_theme_color_override(&"font_color", Color(1.0, 0.77, 0.3))
	return label


func _make_button(text: String, callback: Callable, width := 0.0) -> Button:
	var button := Button.new()
	button.text = text
	if width > 0.0:
		button.custom_minimum_size.x = width
	button.pressed.connect(callback)
	return button


func _line_field(parent: Control, label: String, callback: Callable) -> LineEdit:
	var edit := LineEdit.new()
	edit.text_changed.connect(callback)
	_add_labeled_control(parent, label, edit)
	return edit


func _check_field(parent: Control, label: String, callback: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = label
	check.toggled.connect(callback)
	parent.add_child(check)
	return check


func _sample_path_field(parent: Control, label: String, kind: StringName) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_child(_make_label(label, 105.0))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_step_text_changed)
	row.add_child(edit)
	row.add_child(_make_button("Sample", func() -> void: _preview.begin_sample(kind)))
	parent.add_child(row)
	return edit


func _add_labeled_control(parent: Control, label: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_child(_make_label(label, 105.0))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)


func _add_grid_field(grid: GridContainer, label: String, control: Control) -> void:
	grid.add_child(_make_label(label))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _find_nodes_with_meta(node: Node, key: StringName) -> Array[Node]:
	var result: Array[Node] = []
	if node.has_meta(key):
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_nodes_with_meta(child, key))
	return result
