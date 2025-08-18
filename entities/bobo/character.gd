extends Node2D

@onready var LeftEye = $Head/LeftEye
@onready var RightEye = $Head/RightEye
@onready var Mouse = $Head/Mouse
@onready var Head = $Head
@onready var Body = $Body
@onready var LeftHand = $LeftHand
@onready var RightHand = $RightHand
@onready var AssetEyeDefault = preload("res://entities/bobo/textures/eye_default.png")
@onready var AssetEyeClose = preload("res://entities/bobo/textures/eye_close.png")
@onready var AssetEyeWinkRight = preload("res://entities/bobo/textures/eye_wink_right.png")
@onready var AssetEyeWinkLeft = preload("res://entities/bobo/textures/eye_wink_left.png")
@onready var AssetMouseOpen = preload("res://entities/bobo/textures/mouse_open.png")
@onready var AssetMouseDefault = preload("res://entities/bobo/textures/mouse_default.png")
@onready var AssetMouseHappy = preload("res://entities/bobo/textures/mouse_happy.png")
@onready var AssetMouseSmile = preload("res://entities/bobo/textures/mouse_smile.png")
@onready var AssetMouseLaugh = preload("res://entities/bobo/textures/mouse_laugh.png")

@export var SwayEnable:bool = true
@export var EyeFollowEnable:bool = true
@export var EyeFocusPosition:Vector2 = Vector2(0, 0)

var left_eye_tween
var right_eye_tween
var mouse_tween
var mouse_statue = -1
var talk_enable:bool = false
var talk_statue:int = 0
var sway_direction:int = 0

var tmp_tweens = {}

func  _ready():
	$TwinkleOpen.wait_time = randi_range(3, 6)
	$TwinkleClose.wait_time = randf_range(0.1, 0.3)
	$TwinkleOpen.start()
	
	EyeFocusPosition = Vector2(740, 400)
	mouse_statue = 2
	
	Head.position = Vector2(0, 0)
	Body.position = Vector2(0, 280)
	LeftHand.position = Vector2(140, 270)
	RightHand.position = Vector2(-140, 270)

func update_Head():
	if SwayEnable:
		var ratio = $HeadSway.time_left / $HeadSway.wait_time
		if sway_direction == 0:
			Head.position.y = -ratio * 8 + 8
			Body.position.y = -ratio * 4 + 284
			#LeftHand.position.y = -ratio * 4 + 274
			#RightHand.position.y = -ratio * 6 + 276
		else:
			Head.position.y = -(1-ratio) * 8 + 8
			Body.position.y = -(1-ratio) * 4 + 284
			#LeftHand.position.y = -(1-ratio) * 4 + 274
			#RightHand.position.y = -(1-ratio) * 6 + 276
	
	# Update Head coordinate, including eyes and mouse
	var mouse_coordinate = EyeFocusPosition
	if EyeFollowEnable:
		mouse_coordinate = get_global_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	
	# First calculate the eye position, then use eye_gap to get exact eye position.
	# The same with mouse position.
	var delta_coordinate = mouse_coordinate - Head.position - position
	var distance = sqrt(delta_coordinate.x**2 + delta_coordinate.y**2)
	var ks = 0.7 * sqrt(viewport_size.x**2 + viewport_size.y**2)
	var eye_gap = 70*ks / (distance+ks)
	var mouse_gap = 70*ks / (abs(delta_coordinate.y)+ks)

	var radius = 90 - 90*ks/3/(distance+ks/3)
	var calx = radius*delta_coordinate.x/distance
	var caly = radius*delta_coordinate.y/distance
	
	if is_nan(calx):
		calx = 0
	if is_nan(caly):
		caly = 0
	
	if left_eye_tween:
		left_eye_tween.kill()
	left_eye_tween = get_tree().create_tween()
	left_eye_tween.tween_property(LeftEye, "position", Vector2(calx+eye_gap/2, caly), 0.1)
	
	if right_eye_tween:
		right_eye_tween.kill()
	right_eye_tween = get_tree().create_tween()
	right_eye_tween.tween_property(RightEye, "position", Vector2(calx-eye_gap/2, caly), 0.1)
	
	if mouse_tween:
		mouse_tween.kill()
	mouse_tween = get_tree().create_tween()
	mouse_tween.tween_property(Mouse, "position", Vector2(calx, caly+mouse_gap), 0.1)

func _process(delta):
	update_Head()

# Twinkle twinkle little star
func _on_twinkle_timeout():
	LeftEye.texture = AssetEyeClose
	RightEye.texture = AssetEyeClose
	$TwinkleClose.start()
# Timer for eye closing
func _on_twinkle_tmp_timeout():
	LeftEye.texture = AssetEyeDefault
	RightEye.texture = AssetEyeDefault
	$TwinkleOpen.wait_time = randi_range(3, 6)
	$TwinkleClose.wait_time = randf_range(0.1, 0.3)
	$TwinkleOpen.start()

func _on_mouse_timeout():
	if mouse_statue == -1:
		Mouse.texture = [AssetMouseDefault, AssetMouseHappy, AssetMouseOpen, AssetMouseLaugh, AssetMouseSmile][randi_range(0, 4)]
		$Mouse.wait_time = randi_range(3, 10)

func set_mouse(statue:int):
	mouse_statue = statue
	if statue != -1:
		Mouse.texture = [AssetMouseDefault, AssetMouseHappy, AssetMouseOpen, AssetMouseLaugh, AssetMouseSmile][mouse_statue]

func wink(which_eye:int = 0, wait_time:float = 1.0):
	match which_eye:
		0:
			LeftEye.texture = AssetEyeWinkLeft
			RightEye.texture = AssetEyeWinkRight
		1:
			LeftEye.texture = AssetEyeWinkLeft
		2:
			RightEye.texture = AssetEyeWinkRight
	await get_tree().create_timer(wait_time).timeout
	LeftEye.texture = AssetEyeDefault
	RightEye.texture = AssetEyeDefault

func talk():
	if talk_enable:
		$TalkMouse.start(randf_range(0.1, 0.3))
		talk_statue = 0
	else:
		$TalkMouse.stop()
		mouse_statue = 2
	talk_enable = not talk_enable

func _on_talk_mouse_timeout() -> void:
	if mouse_statue != -1:
		match talk_statue:
			0:
				Mouse.texture = AssetMouseSmile
			1:
				Mouse.texture = AssetMouseOpen
		talk_statue = (talk_statue + 1) % 2
	
	$TalkMouse.start(randf_range(0.1, 0.3))

func _on_head_sway_timeout() -> void:
	sway_direction = (sway_direction + 1) % 2

func _on_change_mouse_pressed() -> void:
	set_mouse((mouse_statue + 1) % 5)

func hold():
	EyeFollowEnable = false
	EyeFocusPosition = Vector2(0, 220) + position
	move(LeftHand, "position", Vector2(60, 200), 0.6)
	move(RightHand, "position", Vector2(-60, 200), 0.6)
	await get_tree().create_timer(1).timeout
	
	EyeFocusPosition = Vector2(-90, 180) + position
	move(LeftHand, "position", Vector2(-40, 190), 0.6)
	move(RightHand, "position", Vector2(-125, 170), 0.6)
	await get_tree().create_timer(1.5).timeout
	
	EyeFocusPosition = Vector2(90, 180) + position
	move(LeftHand, "position", Vector2(125, 170), 0.6)
	move(RightHand, "position", Vector2(40, 190), 0.6)
	await get_tree().create_timer(1.5).timeout
	
	EyeFocusPosition = Vector2(0, 220) + position
	move(LeftHand, "position", Vector2(60, 200), 0.6)
	move(RightHand, "position", Vector2(-60, 200), 0.6)
	await get_tree().create_timer(1).timeout
	
	EyeFollowEnable = true
	#EyeFocusPosition = Vector2(0, 220) + position
	move(LeftHand, "position", Vector2(140, 270), 0.6)
	move(RightHand, "position", Vector2(-140, 270), 0.6)

func greeting():
	EyeFollowEnable = false
	EyeFocusPosition = Vector2(0, 0) + position
	move(LeftHand, "position", Vector2(140, 270), 0.4)
	move(RightHand, "position", Vector2(-150, 50), 0.4)
	await get_tree().create_timer(0.4).timeout
	
	move(RightHand, "position", Vector2(-220, 70), 0.3)
	await get_tree().create_timer(0.3).timeout
	move(RightHand, "position", Vector2(-150, 50), 0.3)
	await get_tree().create_timer(0.3).timeout
	move(RightHand, "position", Vector2(-220, 70), 0.3)
	await get_tree().create_timer(0.3).timeout
	move(RightHand, "position", Vector2(-150, 50), 0.3)
	await get_tree().create_timer(0.3).timeout
	
	EyeFollowEnable = true
	#EyeFocusPosition = Vector2(0, 220) + position
	move(LeftHand, "position", Vector2(140, 270), 0.6)
	move(RightHand, "position", Vector2(-140, 270), 0.6)
	
	move(RightHand, "position", Vector2(-140, 270), 0.6)

func move(object, prop, to_val, wait_time, trans:Tween.TransitionType = Tween.TRANS_CUBIC, parallel:bool = true):
	if tmp_tweens.get(object):
		tmp_tweens[object].kill()
	tmp_tweens[object] = get_tree().create_tween().set_parallel(parallel)
	tmp_tweens[object].set_trans(trans)
	tmp_tweens[object].tween_property(object, prop, to_val, wait_time)
