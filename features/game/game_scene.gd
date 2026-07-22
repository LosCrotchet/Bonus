extends Control

const HUMAN_PLAYER_INDEX := 0
const DEFAULT_PLAYER_COUNT := 3
const DICE_ROOT := "res://assets/art/dice/"
const ACTIVE_BORDER_COLOR := Color(1.0, 0.78, 0.26, 1.0)
const INACTIVE_BORDER_COLOR := Color(0.25, 0.4, 0.36, 0.75)

@onready var settings_button: Button = %SettingsButton
@onready var settings_popup: PopupPanel = %SettingsPopup
@onready var player_count_option: OptionButton = %PlayerCountOption
@onready var settings_new_game_button: Button = %SettingsNewGameButton
@onready var exit_button: Button = %ExitButton
@onready var status_label: Label = %StatusLabel
@onready var deck_count_label: Label = %DeckCountLabel
@onready var dice_button: TextureButton = %DiceButton
@onready var dice_value_label: Label = %DiceValue
@onready var played_cards: HBoxContainer = %PlayedCards
@onready var played_caption: Label = %PlayedCaption
@onready var action_bar: HBoxContainer = %ActionBar
@onready var hint_button: Button = %HintButton
@onready var pass_button: Button = %PassButton
@onready var play_button: Button = %PlayButton
@onready var hand_panel: PanelContainer = %HandPanel
@onready var hand_title: Label = %HandTitle
@onready var hand_view: HandView = %HandView
@onready var selected_label: Label = %SelectedLabel
@onready var result_overlay: Control = %ResultOverlay
@onready var winner_label: Label = %WinnerLabel
@onready var restart_button: Button = %RestartButton

var _session: GameSession
var _selected_card_ids: Array[int] = []
var _player_count := DEFAULT_PLAYER_COUNT
var _transient_message := ""
var _ai_task_running := false
var _rolling := false
var _game_serial := 0
var _dice_prompt_tween: Tween
var _dice_rest_position := Vector2.ZERO
var _seat_views := {}


func _ready() -> void:
	settings_button.pressed.connect(_on_settings_pressed)
	settings_new_game_button.pressed.connect(_on_settings_new_game_pressed)
	exit_button.pressed.connect(get_tree().quit)
	dice_button.pressed.connect(_on_dice_pressed)
	hint_button.pressed.connect(_on_hint_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	play_button.pressed.connect(_on_play_pressed)
	restart_button.pressed.connect(_start_new_game)
	hand_view.selection_changed.connect(_on_hand_selection_changed)

	_seat_views = {
		"北家": {
			"panel": %NorthSeat,
			"name": %NorthName,
			"count": %NorthCount,
			"cards": %NorthCards,
		},
		"西家": {
			"panel": %WestSeat,
			"name": %WestName,
			"count": %WestCount,
			"cards": %WestCards,
		},
		"东家": {
			"panel": %EastSeat,
			"name": %EastName,
			"count": %EastCount,
			"cards": %EastCards,
		},
	}

	_start_new_game()
	await get_tree().process_frame
	_dice_rest_position = dice_button.position
	dice_button.pivot_offset = dice_button.size * 0.5
	_refresh_dice_prompt()


func _start_new_game() -> void:
	_game_serial += 1
	_ai_task_running = false
	_rolling = false
	_selected_card_ids.clear()
	_transient_message = ""
	_stop_dice_prompt()

	_session = GameSession.new()
	_session.state_changed.connect(_refresh)
	_session.game_finished.connect(_on_game_finished)
	_session.start_game(_player_names_for_count(_player_count))
	result_overlay.visible = false
	_refresh()


func _player_names_for_count(count: int) -> Array[String]:
	# The array is turn order. Empty compass seats are skipped.
	match count:
		2:
			return ["南家", "北家"]
		3:
			return ["南家", "北家", "西家"]
		4:
			return ["南家", "东家", "北家", "西家"]
	return ["南家", "北家", "西家"]


func _refresh() -> void:
	if _session == null or _session.players.is_empty():
		return
	_prune_selection()
	_refresh_seats()
	_refresh_center_table()
	_refresh_hand()
	_refresh_actions()
	_refresh_status()
	_refresh_dice_prompt()
	_schedule_ai_if_needed()


func _refresh_seats() -> void:
	for seat_name in _seat_views:
		var view: Dictionary = _seat_views[seat_name]
		var player_index := _find_player_index(seat_name)
		var panel := view["panel"] as PanelContainer
		panel.visible = player_index != -1
		if player_index == -1:
			continue

		var player := _session.players[player_index]
		(view["name"] as Label).text = player.display_name
		(view["count"] as Label).text = "%d 张" % player.hand.size()
		_set_panel_highlight(panel, player_index == _session.current_player_index)
		_fill_card_backs(view["cards"] as HBoxContainer, player.hand.size())

	hand_title.text = "南家（你） · %d 张" % _session.players[HUMAN_PLAYER_INDEX].hand.size()
	_set_panel_highlight(hand_panel, _session.current_player_index == HUMAN_PLAYER_INDEX)


func _refresh_center_table() -> void:
	deck_count_label.text = "剩余 %d 张" % _session.draw_pile.size()
	if not _rolling:
		if _session.dice_value == 0:
			dice_button.texture_normal = _dice_texture(1)
			dice_button.modulate = Color(1.0, 1.0, 1.0, 0.5)
			dice_value_label.text = (
				"点击掷骰" if _can_human_roll() else "等待掷骰"
			)
		else:
			dice_button.texture_normal = _dice_texture(_session.dice_value)
			dice_button.modulate = Color.WHITE
			dice_value_label.text = "%d 点" % _session.dice_value

	_clear_container(played_cards)
	if _session.last_played_cards.is_empty():
		played_caption.text = "出牌区 · 暂无出牌"
		return

	var player_name := _session.players[_session.played_by_index].display_name
	var pattern_name := (
		_session.last_play_pattern.get_display_name()
		if _session.last_play_pattern != null
		else "%d 张" % _session.last_played_cards.size()
	)
	played_caption.text = "出牌区 · %s打出%s" % [player_name, pattern_name]
	for card in _session.last_played_cards:
		var card_texture := TextureRect.new()
		card_texture.texture = CardTextureCatalog.get_texture(card)
		card_texture.custom_minimum_size = Vector2(54.0, 76.0)
		card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		played_cards.add_child(card_texture)


func _refresh_hand() -> void:
	var can_select := _can_human_act()
	hand_view.set_hand(
		_session.players[HUMAN_PLAYER_INDEX].hand,
		_selected_card_ids,
		can_select,
	)
	_refresh_selection_label()


func _refresh_actions() -> void:
	var awaiting_action := _can_human_act() and not _rolling
	action_bar.visible = awaiting_action
	hint_button.disabled = not awaiting_action
	pass_button.disabled = not awaiting_action
	play_button.disabled = not awaiting_action
	dice_button.disabled = not _can_human_roll() or _rolling
	dice_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not dice_button.disabled else Control.CURSOR_ARROW
	)


func _refresh_status() -> void:
	if not _transient_message.is_empty():
		status_label.text = _transient_message
		return
	if _rolling:
		status_label.text = "%s正在掷骰…" % _session.players[_session.current_player_index].display_name
		return
	if _session.phase == GameSession.Phase.FINISHED:
		status_label.text = "%s获胜" % _session.players[_session.winner_index].display_name
		return

	var current_name := _session.players[_session.current_player_index].display_name
	if _session.phase == GameSession.Phase.AWAITING_ROLL:
		status_label.text = (
			"轮到南家，点击骰子开始回合"
			if _session.current_player_index == HUMAN_PLAYER_INDEX
			else "%s准备掷骰" % current_name
		)
	elif _session.is_bonus and _session.last_play_pattern == null:
		status_label.text = "%s获得 BONUS，可打出任意合法牌型" % current_name
	elif _session.last_play_pattern != null:
		status_label.text = "%s需要盖过%s，或选择不出" % [
			current_name,
			_session.last_play_pattern.get_display_name(),
		]
	else:
		status_label.text = "%s需要打出 %d 张合法牌，或选择不出" % [
			current_name,
			_session.dice_value,
		]


func _refresh_selection_label() -> void:
	if not _can_human_act():
		selected_label.text = "已选 0 张"
	elif _session.is_bonus and _session.last_play_pattern == null:
		selected_label.text = "已选 %d 张 · BONUS" % _selected_card_ids.size()
	elif _session.last_play_pattern != null:
		selected_label.text = "已选 %d / %d" % [
			_selected_card_ids.size(),
			_session.last_play_pattern.card_count,
		]
	else:
		selected_label.text = "已选 %d / %d" % [
			_selected_card_ids.size(),
			_session.dice_value,
		]


func _on_dice_pressed() -> void:
	if not _can_human_roll() or _rolling:
		return
	_animate_roll_and_commit(HUMAN_PLAYER_INDEX, _game_serial)


func _animate_roll_and_commit(player_index: int, serial: int) -> void:
	_rolling = true
	_transient_message = ""
	_selected_card_ids.clear()
	_stop_dice_prompt()
	_refresh_actions()
	_refresh_status()

	for step in range(8):
		if serial != _game_serial:
			return
		dice_button.texture_normal = _dice_texture((step * 5 + 2) % 6 + 1)
		dice_button.modulate = Color.WHITE
		dice_button.rotation = -0.09 if step % 2 == 0 else 0.09
		await get_tree().create_timer(0.055).timeout

	if serial != _game_serial:
		return
	_session.roll_dice(player_index)
	_rolling = false
	dice_button.rotation = 0.0
	_refresh()


func _on_hint_pressed() -> void:
	_transient_message = ""
	var recommendation := _session.get_recommended_play(HUMAN_PLAYER_INDEX)
	if recommendation.is_empty():
		_transient_message = "当前没有可出的合法牌，请选择不出"
	else:
		_selected_card_ids.assign(recommendation)
		hand_view.set_selection(_selected_card_ids)
	_refresh_selection_label()
	_refresh_status()


func _on_pass_pressed() -> void:
	_transient_message = ""
	_selected_card_ids.clear()
	if not _session.pass_turn(HUMAN_PLAYER_INDEX):
		_transient_message = _session.last_error
	_refresh()


func _on_play_pressed() -> void:
	_transient_message = ""
	if not _session.play_cards(HUMAN_PLAYER_INDEX, _selected_card_ids):
		_transient_message = _session.last_error
	else:
		_selected_card_ids.clear()
	_refresh()


func _on_hand_selection_changed(selected_ids: Array[int]) -> void:
	_transient_message = ""
	_selected_card_ids.assign(selected_ids)
	_refresh_selection_label()
	_refresh_status()


func _schedule_ai_if_needed() -> void:
	if _ai_task_running or _session.phase == GameSession.Phase.FINISHED:
		return
	if _session.current_player_index == HUMAN_PLAYER_INDEX:
		return
	_ai_task_running = true
	_run_ai_until_human.call_deferred(_game_serial)


func _run_ai_until_human(serial: int) -> void:
	while (
		serial == _game_serial
		and _session.phase != GameSession.Phase.FINISHED
		and _session.current_player_index != HUMAN_PLAYER_INDEX
	):
		var player_index := _session.current_player_index
		if _session.phase == GameSession.Phase.AWAITING_ROLL:
			await get_tree().create_timer(0.42).timeout
			if serial != _game_serial:
				return
			await _animate_roll_and_commit(player_index, serial)
		else:
			await get_tree().create_timer(0.58).timeout
			if serial != _game_serial or player_index != _session.current_player_index:
				return
			var card_ids := _session.get_recommended_play(player_index)
			if card_ids.is_empty():
				_session.pass_turn(player_index)
			else:
				_session.play_cards(player_index, card_ids)
	_ai_task_running = false


func _on_settings_pressed() -> void:
	for item_index in range(player_count_option.item_count):
		if player_count_option.get_item_id(item_index) == _player_count:
			player_count_option.select(item_index)
			break
	settings_popup.popup_centered(Vector2i(310, 286))


func _on_settings_new_game_pressed() -> void:
	_player_count = player_count_option.get_selected_id()
	settings_popup.hide()
	_start_new_game()


func _on_game_finished(player_index: int) -> void:
	winner_label.text = "%s获胜" % _session.players[player_index].display_name
	result_overlay.visible = true


func _refresh_dice_prompt() -> void:
	if not is_node_ready():
		return
	if _can_human_roll() and not _rolling:
		if _dice_prompt_tween == null or not _dice_prompt_tween.is_running():
			_start_dice_prompt()
	else:
		_stop_dice_prompt()


func _start_dice_prompt() -> void:
	if _dice_rest_position == Vector2.ZERO:
		_dice_rest_position = dice_button.position
	_stop_dice_prompt()
	_dice_prompt_tween = create_tween().set_loops()
	_dice_prompt_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dice_prompt_tween.tween_property(
		dice_button,
		"position",
		_dice_rest_position + Vector2(0.0, -5.0),
		0.5,
	)
	_dice_prompt_tween.parallel().tween_property(dice_button, "scale", Vector2(1.06, 1.06), 0.5)
	_dice_prompt_tween.tween_property(dice_button, "position", _dice_rest_position, 0.5)
	_dice_prompt_tween.parallel().tween_property(dice_button, "scale", Vector2.ONE, 0.5)


func _stop_dice_prompt() -> void:
	if _dice_prompt_tween != null:
		_dice_prompt_tween.kill()
		_dice_prompt_tween = null
	if is_instance_valid(dice_button):
		dice_button.position = _dice_rest_position if _dice_rest_position != Vector2.ZERO else dice_button.position
		dice_button.scale = Vector2.ONE


func _fill_card_backs(container: HBoxContainer, card_count: int) -> void:
	_clear_container(container)
	for _index in range(mini(card_count, 7)):
		var card_back := TextureRect.new()
		card_back.texture = CardTextureCatalog.get_card_back()
		card_back.custom_minimum_size = Vector2(38.0, 52.0)
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(card_back)


func _set_panel_highlight(panel: PanelContainer, active: bool) -> void:
	var source := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if source == null:
		return
	var style := source.duplicate() as StyleBoxFlat
	style.border_color = ACTIVE_BORDER_COLOR if active else INACTIVE_BORDER_COLOR
	var width := 3 if active else 2
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	panel.add_theme_stylebox_override("panel", style)


func _find_player_index(display_name: String) -> int:
	for index in range(_session.players.size()):
		if _session.players[index].display_name == display_name:
			return index
	return -1


func _can_human_roll() -> bool:
	return (
		_session != null
		and _session.current_player_index == HUMAN_PLAYER_INDEX
		and _session.phase == GameSession.Phase.AWAITING_ROLL
	)


func _can_human_act() -> bool:
	return (
		_session != null
		and _session.current_player_index == HUMAN_PLAYER_INDEX
		and _session.phase == GameSession.Phase.AWAITING_ACTION
		and not _rolling
	)


func _dice_texture(value: int) -> Texture2D:
	return load(DICE_ROOT + "die_white_%d.png" % value) as Texture2D


func _prune_selection() -> void:
	for index in range(_selected_card_ids.size() - 1, -1, -1):
		if _session.players[HUMAN_PLAYER_INDEX].find_card_index(_selected_card_ids[index]) == -1:
			_selected_card_ids.remove_at(index)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
