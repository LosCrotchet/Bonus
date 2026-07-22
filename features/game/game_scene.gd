extends Control

const HUMAN_PLAYER_INDEX := 0
const AI_PLAYER_INDEX := 1
const DICE_ROOT := "res://assets/art/dice/"

@onready var turn_label: Label = %TurnLabel
@onready var deck_count_label: Label = %DeckCount
@onready var opponent_name_label: Label = %OpponentName
@onready var opponent_count_label: Label = %OpponentCount
@onready var opponent_card_row: HBoxContainer = %OpponentCardRow
@onready var dice_texture: TextureRect = %DiceTexture
@onready var dice_value_label: Label = %DiceValue
@onready var played_cards: HBoxContainer = %PlayedCards
@onready var played_caption: Label = %PlayedCaption
@onready var status_label: Label = %StatusLabel
@onready var hand_view: HandView = %HandView
@onready var selected_label: Label = %SelectedLabel
@onready var roll_button: Button = %RollButton
@onready var hint_button: Button = %HintButton
@onready var pass_button: Button = %PassButton
@onready var play_button: Button = %PlayButton
@onready var result_overlay: Control = %ResultOverlay
@onready var winner_label: Label = %WinnerLabel
@onready var restart_button: Button = %RestartButton
@onready var new_game_button: Button = %NewGameButton

var _session: GameSession
var _selected_card_ids: Array[int] = []
var _transient_message := ""
var _ai_task_running := false
var _game_serial := 0


func _ready() -> void:
	roll_button.pressed.connect(_on_roll_pressed)
	hint_button.pressed.connect(_on_hint_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	play_button.pressed.connect(_on_play_pressed)
	restart_button.pressed.connect(_start_new_game)
	new_game_button.pressed.connect(_start_new_game)
	hand_view.card_toggled.connect(_on_card_toggled)
	_start_new_game()


func _start_new_game() -> void:
	_game_serial += 1
	_ai_task_running = false
	_selected_card_ids.clear()
	_transient_message = ""
	_session = GameSession.new()
	_session.state_changed.connect(_refresh)
	_session.game_finished.connect(_on_game_finished)
	var player_names: Array[String] = ["你", "北家"]
	_session.start_game(player_names)
	result_overlay.visible = false
	_refresh()


func _refresh() -> void:
	if _session == null or _session.players.is_empty():
		return
	_prune_selection()
	_refresh_header()
	_refresh_opponent()
	_refresh_center_table()
	_refresh_hand()
	_refresh_actions()
	_refresh_status()
	_schedule_ai_if_needed()


func _refresh_header() -> void:
	turn_label.text = (
		"你的回合" if _session.current_player_index == HUMAN_PLAYER_INDEX else "北家回合"
	)
	deck_count_label.text = "%d 张" % _session.draw_pile.size()


func _refresh_opponent() -> void:
	var opponent := _session.players[AI_PLAYER_INDEX]
	opponent_name_label.text = opponent.display_name
	opponent_count_label.text = "%d 张" % opponent.hand.size()
	_clear_container(opponent_card_row)
	for _index in range(mini(opponent.hand.size(), 7)):
		var card_back := TextureRect.new()
		card_back.texture = CardTextureCatalog.get_card_back()
		card_back.custom_minimum_size = Vector2(44.0, 62.0)
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		opponent_card_row.add_child(card_back)


func _refresh_center_table() -> void:
	if _session.dice_value == 0:
		dice_texture.texture = load(DICE_ROOT + "die_white_1.png") as Texture2D
		dice_texture.modulate = Color(1.0, 1.0, 1.0, 0.28)
		dice_value_label.text = "等待掷骰"
	else:
		dice_texture.texture = load(
			DICE_ROOT + "die_white_%d.png" % _session.dice_value
		) as Texture2D
		dice_texture.modulate = Color.WHITE
		dice_value_label.text = "%d 点" % _session.dice_value

	_clear_container(played_cards)
	if _session.last_played_cards.is_empty():
		played_caption.text = "等待出牌"
	else:
		played_caption.text = "桌面牌 · %d 张" % _session.last_played_cards.size()
		for card in _session.last_played_cards:
			var card_texture := TextureRect.new()
			card_texture.texture = CardTextureCatalog.get_texture(card)
			card_texture.custom_minimum_size = Vector2(48.0, 68.0)
			card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			played_cards.add_child(card_texture)


func _refresh_hand() -> void:
	var can_select := (
		_session.current_player_index == HUMAN_PLAYER_INDEX
		and _session.phase == GameSession.Phase.AWAITING_ACTION
	)
	hand_view.set_hand(
		_session.players[HUMAN_PLAYER_INDEX].hand,
		_selected_card_ids,
		can_select,
	)
	var target_count := _session.dice_value if can_select else 0
	selected_label.text = "已选 %d / %d" % [_selected_card_ids.size(), target_count]


func _refresh_actions() -> void:
	var is_human_turn := _session.current_player_index == HUMAN_PLAYER_INDEX
	var awaiting_roll := is_human_turn and _session.phase == GameSession.Phase.AWAITING_ROLL
	var awaiting_action := is_human_turn and _session.phase == GameSession.Phase.AWAITING_ACTION
	roll_button.disabled = not awaiting_roll
	hint_button.disabled = not awaiting_action
	pass_button.disabled = not awaiting_action
	play_button.disabled = not awaiting_action


func _refresh_status() -> void:
	if not _transient_message.is_empty():
		status_label.text = _transient_message
		return
	if _session.phase == GameSession.Phase.FINISHED:
		status_label.text = "本局已经结束"
	elif _session.current_player_index == AI_PLAYER_INDEX:
		status_label.text = "北家正在行动…"
	elif _session.phase == GameSession.Phase.AWAITING_ROLL:
		status_label.text = "轮到你了，先掷骰子"
	elif _session.players[HUMAN_PLAYER_INDEX].hand.size() < _session.dice_value:
		status_label.text = "手牌不足 %d 张，本回合请选择不出" % _session.dice_value
	else:
		status_label.text = "选择 %d 张牌，然后出牌" % _session.dice_value


func _on_roll_pressed() -> void:
	_transient_message = ""
	_selected_card_ids.clear()
	if not _session.roll_dice(HUMAN_PLAYER_INDEX):
		_transient_message = _session.last_error
	_refresh()


func _on_hint_pressed() -> void:
	_selected_card_ids.clear()
	var hand := _session.players[HUMAN_PLAYER_INDEX].hand
	if hand.size() < _session.dice_value:
		_transient_message = "没有足够的手牌可供选择"
	else:
		for index in range(_session.dice_value):
			_selected_card_ids.append(hand[index].card_id)
		_transient_message = ""
	hand_view.set_selection(_selected_card_ids)
	selected_label.text = "已选 %d / %d" % [_selected_card_ids.size(), _session.dice_value]
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


func _on_card_toggled(card_id: int, selected: bool) -> void:
	_transient_message = ""
	if selected and not _selected_card_ids.has(card_id):
		_selected_card_ids.append(card_id)
	elif not selected:
		_selected_card_ids.erase(card_id)
	selected_label.text = "已选 %d / %d" % [_selected_card_ids.size(), _session.dice_value]
	_refresh_status()


func _schedule_ai_if_needed() -> void:
	if _ai_task_running or _session.phase == GameSession.Phase.FINISHED:
		return
	if _session.current_player_index != AI_PLAYER_INDEX:
		return
	_ai_task_running = true
	_run_ai_turn.call_deferred(_game_serial)


func _run_ai_turn(serial: int) -> void:
	await get_tree().create_timer(0.55).timeout
	if serial != _game_serial or _session.current_player_index != AI_PLAYER_INDEX:
		return
	_session.roll_dice(AI_PLAYER_INDEX)

	await get_tree().create_timer(0.55).timeout
	if serial != _game_serial or _session.current_player_index != AI_PLAYER_INDEX:
		return
	var hand := _session.players[AI_PLAYER_INDEX].hand
	if hand.size() >= _session.dice_value:
		var card_ids: Array[int] = []
		for index in range(_session.dice_value):
			card_ids.append(hand[index].card_id)
		_session.play_cards(AI_PLAYER_INDEX, card_ids)
	else:
		_session.pass_turn(AI_PLAYER_INDEX)
	_ai_task_running = false


func _on_game_finished(p_winner_index: int) -> void:
	winner_label.text = "%s 获胜" % _session.players[p_winner_index].display_name
	result_overlay.visible = true


func _prune_selection() -> void:
	for index in range(_selected_card_ids.size() - 1, -1, -1):
		if _session.players[HUMAN_PLAYER_INDEX].find_card_index(_selected_card_ids[index]) == -1:
			_selected_card_ids.remove_at(index)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
