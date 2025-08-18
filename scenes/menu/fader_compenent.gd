extends Node

func fade(target:CanvasItem, t:float = 0.5):
	var fade_tween = get_tree().create_tween().set_parallel(true)
	fade_tween.tween_property(target, "modulate", Color(1, 1, 1, 0.8), t)
	#fade_tween.tween_property(target, "modulate", Color(1, 1, 1, 0.3), t)

func defade(target:CanvasItem, t:float = 0.5):
	var fade_tween = get_tree().create_tween().set_parallel(true)
	fade_tween.tween_property(target, "modulate", Color(1, 1, 1, 1), t)
