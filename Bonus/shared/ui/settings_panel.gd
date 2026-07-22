class_name AppSettingsPanel
extends PanelContainer

signal applied
signal canceled
signal return_to_menu_requested
signal quit_requested

@export var show_navigation_actions := true
@export var title_key: StringName = &"UI_GAME_SETTINGS"

@onready var title_label: Label = %Title
@onready var game_speed_option: OptionButton = %GameSpeedOption
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var language_option: OptionButton = %LanguageOption
@onready var status_text_toggle: CheckButton = %StatusTextToggle
@onready var auto_pass_toggle: CheckButton = %AutoPassToggle
@onready var double_click_toggle: CheckButton = %DoubleClickToggle
@onready var navigation_actions: VBoxContainer = %NavigationActions
@onready var exit_menu_button: Button = %ExitMenuButton
@onready var exit_menu_confirmation: HBoxContainer = %ExitMenuConfirmation
@onready var exit_game_button: Button = %ExitGameButton
@onready var exit_game_confirmation: HBoxContainer = %ExitGameConfirmation


func _ready() -> void:
	title_label.text = tr(title_key)
	%ApplyButton.pressed.connect(_on_apply_pressed)
	%CancelButton.pressed.connect(cancel_edit)
	exit_menu_button.pressed.connect(_show_exit_menu_confirmation)
	%ExitMenuYes.pressed.connect(func() -> void: return_to_menu_requested.emit())
	%ExitMenuNo.pressed.connect(_hide_confirmations)
	exit_game_button.pressed.connect(_show_exit_game_confirmation)
	%ExitGameYes.pressed.connect(func() -> void: quit_requested.emit())
	%ExitGameNo.pressed.connect(_hide_confirmations)
	SettingsService.language_changed.connect(_on_language_changed)
	navigation_actions.visible = show_navigation_actions
	_populate_options()
	begin_edit()


func begin_edit() -> void:
	_sync_from_snapshot(SettingsService.get_snapshot())
	_hide_confirmations()


func cancel_edit() -> void:
	begin_edit()
	canceled.emit()


func _on_apply_pressed() -> void:
	var snapshot := {
		"game_speed": game_speed_option.get_selected_id(),
		"resolution": resolution_option.get_item_metadata(resolution_option.selected),
		"window_mode": window_mode_option.get_selected_id(),
		"locale": language_option.get_item_metadata(language_option.selected),
		"show_status_text": status_text_toggle.button_pressed,
		"auto_pass": auto_pass_toggle.button_pressed,
		"double_click_actions": double_click_toggle.button_pressed,
	}
	if SettingsService.apply_settings(snapshot):
		applied.emit()


func _populate_options() -> void:
	game_speed_option.clear()
	game_speed_option.add_item(tr(&"UI_SPEED_SLOW"), SettingsService.GameSpeed.SLOW)
	game_speed_option.add_item(tr(&"UI_SPEED_MEDIUM"), SettingsService.GameSpeed.MEDIUM)
	game_speed_option.add_item(tr(&"UI_SPEED_FAST"), SettingsService.GameSpeed.FAST)

	resolution_option.clear()
	for index in range(SettingsService.RESOLUTIONS.size()):
		var value: Vector2i = SettingsService.RESOLUTIONS[index]
		resolution_option.add_item(_resolution_label(value), index)
		resolution_option.set_item_metadata(index, value)

	window_mode_option.clear()
	window_mode_option.add_item(tr(&"UI_WINDOWED"), SettingsService.WindowMode.WINDOWED)
	window_mode_option.add_item(tr(&"UI_FULLSCREEN"), SettingsService.WindowMode.FULLSCREEN)

	language_option.clear()
	language_option.add_item(tr(&"UI_LANGUAGE_ZH_CN"), 0)
	language_option.set_item_metadata(0, "zh_CN")
	language_option.add_item(tr(&"UI_LANGUAGE_EN"), 1)
	language_option.set_item_metadata(1, "en")


func _sync_from_snapshot(snapshot: Dictionary) -> void:
	_select_option_by_id(game_speed_option, int(snapshot["game_speed"]))
	_select_option_by_id(window_mode_option, int(snapshot["window_mode"]))
	for index in range(resolution_option.item_count):
		if resolution_option.get_item_metadata(index) == snapshot["resolution"]:
			resolution_option.select(index)
			break
	for index in range(language_option.item_count):
		if language_option.get_item_metadata(index) == snapshot["locale"]:
			language_option.select(index)
			break
	status_text_toggle.button_pressed = bool(snapshot["show_status_text"])
	auto_pass_toggle.button_pressed = bool(snapshot["auto_pass"])
	double_click_toggle.button_pressed = bool(snapshot["double_click_actions"])


func _select_option_by_id(option: OptionButton, item_id: int) -> void:
	for index in range(option.item_count):
		if option.get_item_id(index) == item_id:
			option.select(index)
			return


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
	_hide_confirmations()
	exit_menu_button.visible = false
	exit_menu_confirmation.visible = true


func _show_exit_game_confirmation() -> void:
	_hide_confirmations()
	exit_game_button.visible = false
	exit_game_confirmation.visible = true


func _hide_confirmations() -> void:
	exit_menu_button.visible = true
	exit_menu_confirmation.visible = false
	exit_game_button.visible = true
	exit_game_confirmation.visible = false


func _on_language_changed(_locale: String) -> void:
	title_label.text = tr(title_key)
	var snapshot := SettingsService.get_snapshot()
	_populate_options()
	_sync_from_snapshot(snapshot)
