@tool
extends EditorPlugin

const EDITOR_SCENE := preload("res://addons/tutorial_editor/tutorial_editor.tscn")

var _editor: Control


func _enter_tree() -> void:
	_editor = EDITOR_SCENE.instantiate() as Control
	_editor.set_editor_interface(get_editor_interface())
	EditorInterface.get_editor_main_screen().add_child(_editor)
	_make_visible(false)


func _exit_tree() -> void:
	if is_instance_valid(_editor):
		_editor.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_editor):
		_editor.visible = visible


func _get_plugin_name() -> String:
	return "Tutorial"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(&"AnimationTrackGroup", &"EditorIcons")


func _save_external_data() -> void:
	if is_instance_valid(_editor):
		_editor.save_all()
