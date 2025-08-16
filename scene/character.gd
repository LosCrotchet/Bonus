extends Node2D

@onready var LeftEye = $Head/LeftEye
@onready var RightEye = $Head/RightEye
@onready var Mouse = $Head/Mouse
@onready var Head = $Head
@onready var AssetEyeDefault = preload("res://assets/eye_default.png")
@onready var AssetEyeClose = preload("res://assets/eye_close.png")
@onready var AssetMouseOpen = preload("res://assets/mouse_open.png")
@onready var AssetMouseDefault = preload("res://assets/mouse_default.png")
@onready var AssetMouseHappy = preload("res://assets/mouse_happy.png")

@export var EyeFollowEnable:bool = true
@export var EyeFocusPosition:Vector2 = Vector2(0, 0)

var left_eye_tween
var right_eye_tween
var mouse_tween
var mouse_statue = -1

func  _ready():
	$Twinkle.wait_time = randi_range(3, 6)
	$Twinkle_tmp.wait_time = randf_range(0.1, 0.3)
	$Twinkle.start()
	
	EyeFocusPosition = Vector2(740, 400)

func update_Head():
	# Update Head coordinate, including eyes and mouse
	#var mouse_coordinate = get_viewport().get_mouse_position()
	var mouse_coordinate = EyeFocusPosition
	if EyeFollowEnable:
		mouse_coordinate = get_global_mouse_position()
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Restriction in the screen, useless if global position
	'''if mouse_coordinate.x < 0:
		mouse_coordinate.x = 0
	if mouse_coordinate.x > viewport_size.x:
		mouse_coordinate.x = viewport_size.x
	if mouse_coordinate.y < 0:
		mouse_coordinate.y = 0
	if mouse_coordinate.y > viewport_size.y:
		mouse_coordinate.y = viewport_size.y'''
	
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
	$Twinkle_tmp.start()
# Timer for eye closing
func _on_twinkle_tmp_timeout():
	LeftEye.texture = AssetEyeDefault
	RightEye.texture = AssetEyeDefault
	$Twinkle.wait_time = randi_range(3, 6)
	$Twinkle_tmp.wait_time = randf_range(0.1, 0.3)
	$Twinkle.start()

func _on_mouse_timeout():
	if mouse_statue == -1:
		Mouse.texture = [AssetMouseDefault, AssetMouseHappy, AssetMouseOpen][randi_range(0, 2)]
		$Mouse.wait_time = randi_range(3, 10)

func set_mouse(statue:int):
	mouse_statue = statue
	if statue != -1:
		Mouse.texture = [AssetMouseDefault, AssetMouseHappy, AssetMouseOpen][mouse_statue]
