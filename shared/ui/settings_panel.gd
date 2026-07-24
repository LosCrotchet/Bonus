class_name AppSettingsPanel
extends PanelContainer

signal applied
signal canceled
signal return_to_menu_requested

@export var show_navigation_actions := true
@export var title_key: StringName = &"UI_GAME_SETTINGS"

@onready var title_label: Label = %Title
@onready var game_speed_buttons: Array[Button] = [
	%SpeedSlowButton,
	%SpeedMediumButton,
	%SpeedFastButton,
]
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var window_mode_buttons: Array[Button] = [
	%WindowedButton,
	%FullscreenButton,
]
@onready var language_option: OptionButton = %LanguageOption
@onready var status_text_toggle: CheckBox = %StatusTextToggle
@onready var double_click_toggle: CheckBox = %DoubleClickToggle
@onready var simplified_cards_toggle: CheckBox = %SimplifiedCardsToggle
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var master_volume_value: Label = %MasterVolumeValue
@onready var sfx_volume_value: Label = %SfxVolumeValue
@onready var music_volume_value: Label = %MusicVolumeValue
@onready var apply_button: Button = %ApplyButton
@onready var apply_status: Label = %ApplyStatus
@onready var navigation_actions: VBoxContainer = %NavigationActions
@onready var exit_menu_button: Button = %ExitMenuButton
@onready var exit_menu_confirmation: HBoxContainer = %ExitMenuConfirmation

var _apply_feedback_tween: Tween
var _apply_status_rest_position := Vector2.ZERO


func _ready() -> void:
	theme = preload("res://assets/themes/cartoon_ui/controls.tres")
	title_label.text = tr(title_key)
	apply_button.pressed.connect(_on_apply_pressed)
	%CancelButton.pressed.connect(cancel_edit)
	exit_menu_button.pressed.connect(_show_exit_menu_confirmation)
	%ExitMenuYes.pressed.connect(_confirm_return_to_menu)
	%ExitMenuNo.pressed.connect(_cancel_return_to_menu)
	master_volume_slider.value_changed.connect(SettingsService.set_master_volume)
	sfx_volume_slider.value_changed.connect(SettingsService.set_sfx_volume)
	music_volume_slider.value_changed.connect(SettingsService.set_music_volume)
	SettingsService.audio_changed.connect(_on_audio_changed)
	SettingsService.language_changed.connect(_on_language_changed)
	navigation_actions.visible = show_navigation_actions
	$Layout.move_child(navigation_actions, $Layout.get_child_count() - 1)
	_populate_options()
	begin_edit()
	ControlMotion.bind_buttons(self)


func begin_edit() -> void:
	_sync_from_snapshot(SettingsService.get_snapshot())
	_hide_confirmations()
	_hide_apply_status()


func cancel_edit() -> void:
	begin_edit()
	canceled.emit()


func _on_apply_pressed() -> void:
	var snapshot := {
		"game_speed": _selected_button_index(game_speed_buttons),
		"resolution": resolution_option.get_item_metadata(resolution_option.selected),
		"window_mode": _selected_button_index(window_mode_buttons),
		"locale": language_option.get_item_metadata(language_option.selected),
		"show_status_text": status_text_toggle.button_pressed,
		"double_click_actions": double_click_toggle.button_pressed,
		"use_simplified_cards": simplified_cards_toggle.button_pressed,
	}
	if SettingsService.apply_settings(snapshot):
		AudioService.play(&"settings_applied")
		_show_apply_success()
		applied.emit()


func _populate_options() -> void:
	resolution_option.clear()
	for index in range(SettingsService.RESOLUTIONS.size()):
		var value: Vector2i = SettingsService.RESOLUTIONS[index]
		resolution_option.add_item(_resolution_label(value), index)
		resolution_option.set_item_metadata(index, value)

	language_option.clear()
	language_option.add_item(tr(&"UI_LANGUAGE_ZH_CN"), 0)
	language_option.set_item_metadata(0, "zh_CN")
	language_option.add_item(tr(&"UI_LANGUAGE_EN"), 1)
	language_option.set_item_metadata(1, "en")


func _sync_from_snapshot(snapshot: Dictionary) -> void:
	_select_button_by_index(game_speed_buttons, int(snapshot["game_speed"]))
	_select_button_by_index(window_mode_buttons, int(snapshot["window_mode"]))
	for index in range(resolution_option.item_count):
		if resolution_option.get_item_metadata(index) == snapshot["resolution"]:
			resolution_option.select(index)
			break
	for index in range(language_option.item_count):
		if language_option.get_item_metadata(index) == snapshot["locale"]:
			language_option.select(index)
			break
	status_text_toggle.button_pressed = bool(snapshot["show_status_text"])
	double_click_toggle.button_pressed = bool(snapshot["double_click_actions"])
	simplified_cards_toggle.button_pressed = bool(snapshot["use_simplified_cards"])
	master_volume_slider.set_value_no_signal(float(snapshot["master_volume"]))
	sfx_volume_slider.set_value_no_signal(float(snapshot["sfx_volume"]))
	music_volume_slider.set_value_no_signal(float(snapshot["music_volume"]))
	_update_volume_labels()


func _select_option_by_id(option: OptionButton, item_id: int) -> void:
	for index in range(option.item_count):
		if option.get_item_id(index) == item_id:
			option.select(index)
			return


func _select_button_by_index(buttons: Array[Button], selected_index: int) -> void:
	if selected_index >= 0 and selected_index < buttons.size():
		buttons[selected_index].button_pressed = true


func _selected_button_index(buttons: Array[Button]) -> int:
	for index in range(buttons.size()):
		if buttons[index].button_pressed:
			return index
	return 0


func _resolution_label(value: Vector2i) -> String:
	var suffixes := {
		Vector2i(1280, 720): "720p",
		Vector2i(1920, 1080): "1080p",
		Vector2i(2560, 1440): "2K",
		Vector2i(3840, 2160): "4K",
	}
	var suffix := suffixes.get(value, "") as String
	return "%d x %d%s" % [
		value.x,
		value.y,
		" (%s)" % suffix if not suffix.is_empty() else "",
	]


func _show_exit_menu_confirmation() -> void:
	AudioService.play(&"ui_confirm")
	_hide_confirmations()
	exit_menu_button.visible = false
	exit_menu_confirmation.visible = true


func _confirm_return_to_menu() -> void:
	AudioService.play(&"ui_confirm")
	return_to_menu_requested.emit()


func _cancel_return_to_menu() -> void:
	AudioService.play(&"ui_cancel")
	_hide_confirmations()


func _hide_confirmations() -> void:
	exit_menu_button.visible = true
	exit_menu_confirmation.visible = false


func _on_audio_changed(master: float, sfx: float, music: float) -> void:
	master_volume_slider.set_value_no_signal(master)
	sfx_volume_slider.set_value_no_signal(sfx)
	music_volume_slider.set_value_no_signal(music)
	_update_volume_labels()


func _update_volume_labels() -> void:
	master_volume_value.text = "%d%%" % roundi(master_volume_slider.value * 100.0)
	sfx_volume_value.text = "%d%%" % roundi(sfx_volume_slider.value * 100.0)
	music_volume_value.text = "%d%%" % roundi(music_volume_slider.value * 100.0)


func _show_apply_success() -> void:
	if _apply_feedback_tween != null:
		_apply_feedback_tween.kill()
	apply_status.text = tr(&"UI_APPLY_SUCCESS")
	_position_apply_status()
	apply_status.visible = true
	apply_status.modulate.a = 0.0
	apply_status.position = _apply_status_rest_position
	_apply_feedback_tween = create_tween().set_parallel(true)
	_apply_feedback_tween.tween_property(apply_status, "modulate:a", 1.0, 0.14)
	_apply_feedback_tween.tween_property(
		apply_status,
		"position:y",
		_apply_status_rest_position.y - 10.0,
		0.28,
	).set_delay(0.85)
	_apply_feedback_tween.tween_property(apply_status, "modulate:a", 0.0, 0.28).set_delay(0.85)
	_apply_feedback_tween.chain().tween_callback(_finish_apply_status)


func _hide_apply_status() -> void:
	if _apply_feedback_tween != null:
		_apply_feedback_tween.kill()
		_apply_feedback_tween = null
	_finish_apply_status()


func _finish_apply_status() -> void:
	apply_status.visible = false
	apply_status.modulate.a = 1.0
	apply_status.position = _apply_status_rest_position
	_apply_feedback_tween = null


func _position_apply_status() -> void:
	var button_rect := apply_button.get_global_rect()
	var panel_rect := get_global_rect()
	apply_status.global_position = Vector2(
		panel_rect.end.x + 12.0,
		button_rect.get_center().y - apply_status.size.y * 0.5,
	)
	_apply_status_rest_position = apply_status.position


func _on_language_changed(_locale: String) -> void:
	title_label.text = tr(title_key)
	var snapshot := SettingsService.get_snapshot()
	_populate_options()
	_sync_from_snapshot(snapshot)
