extends Node

@export var enable:bool = true
@export var target:Node2D
@export var time:float

var tweens = {}

func update_flip():
	var count = len(target.get_children())
	var gap = 1750 / (count + 25)
	
	for i in range(count):
		var new_position = Vector2((-0.5*(count-1)+i)*gap, 0)
		var total
		total = tweens[i].get_total_elapsed_time()
		if total < 2*time:
			tweens[i].stop()
			do_tween(total, i)
			tweens[i].play()

func do_tween(t, id):
	print("DO:", t, " ", id)
	var count = len(target.get_children())
	var gap = 1750 / (count + 25)
	var target_position = Vector2((-0.5*(count-1)+id)*gap, 0)
	
	if t <= time:
		tweens[id].tween_property(target.get_child(id), "position", target_position, 2*time-t)
		tweens[id].tween_property(target.get_child(id), "scale:x", 0.1, time).set_delay(time-t)
		tweens[id].tween_property(target.get_child(id), "rotation", 0, 2*time)
		tweens[id].tween_property(target.get_child(id), "face_enable", true, 0.001).set_delay(time-t)
		tweens[id].tween_property(target.get_child(id), "background_position", Vector2i(1, 0), 0.001).set_delay(time-t)
		tweens[id].tween_property(target.get_child(id), "scale:x", 1, 2*time).set_delay(time-t)
	elif t > time:
		tweens[id].tween_property(target.get_child(id), "position", target_position, 2*time-t)
		tweens[id].tween_property(target.get_child(id), "rotation", 0, 2*time-t)
		tweens[id].tween_property(target.get_child(id), "scale:x", 1, 2*time-t)

func start_flip(id):
	var gap = 1750 / (id + 25)
	var target_position = Vector2(0.5*(id-1)*gap, 0)
	id -= 1
	tweens[id] = get_tree().create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	#do_tween(0, id)
	update_flip()
