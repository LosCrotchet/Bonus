extends Control

class_name Card

@export var suit:int					# 花色 (0=黑桃,1=红心,2=方块,3=梅花)；对于Joker，0=小王，1=大王
@export var rank:int					# 点数 (1=3,2=4,11=K,12=A,13=2, 0=JOKER)
@export var enable: bool = true
@export var is_folded:bool = false
@export var is_selected:bool = false
@export var is_drag_select:bool = false

@onready var card_1 = preload("res://assets/sound/card1.ogg")
@onready var card_fan_2 = preload("res://assets/sound/cardFan2.ogg")
@onready var card_3 = preload("res://assets/sound/card3.ogg")
@onready var card_slide_1 = preload("res://assets/sound/cardSlide1.ogg")
@onready var card_slide_2 = preload("res://assets/sound/cardSlide2.ogg")


const width = 500
const height = 700

var tween : Tween

const DEFAULT_Y : float = 0
const HOVER_Y : float = -15
const ACTIVE_Y : float = -30

func _process(delta):
	$FrontFace.visible = not is_folded
	var x = 3 - suit
	var y = 0
	if rank == 0:
		x = 2
		y = 13
	elif rank >= 1 and rank <= 8:
		y = rank 
	elif rank == 12:
		y = 9
	elif rank == 9:
		y = 10
	elif rank == 10:
		y = 12
	elif rank == 11:
		y = 11
	elif rank == 13:
		y = 0
	
	$FrontFace.region_rect = Rect2(width*x, height*y, width, height)
	
	if is_folded:
		$BackFace.region_rect = Rect2(0, height*13, width, height)
	else:
		$BackFace.region_rect = Rect2(width, height*13, width, height)

# 核心动画函数
func animate_to(target_y: float, t: float = 0.1):
	if tween and tween.is_valid():
		tween.kill() # 终止正在进行的动画，防止状态冲突
		
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", target_y, t)

func set_enable(flag: bool):
	enable = flag
	if not enable:
		force_cancel()

func _on_mouse_entered():
	if not enable:
		return
	# 如果鼠标移入时按钮不是按下的状态，才触发 Hover 动画
	if is_drag_select:
		_on_button_down()
	else:
		if not is_selected:
			animate_to(HOVER_Y)

func _on_mouse_exited():
	if not enable:
		return
	# 鼠标移出时恢复默认
	if not is_drag_select:
		if not is_selected:
			animate_to(DEFAULT_Y)


func force_select():
	if not is_selected:
		animate_to(ACTIVE_Y, 0.05)
	is_selected = true

func force_cancel():
	if is_selected:
		animate_to(DEFAULT_Y)
	is_selected = false


func _on_button_down() -> void:
	if not enable:
		return
	if is_selected:
		animate_to(DEFAULT_Y)
	else:
		animate_to(ACTIVE_Y, 0.05)
	play_sound()
	is_selected = not is_selected

func play_sound():
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	audio_player.stream = [card_slide_1, card_slide_2][randi_range(0, 1)]
	audio_player.play()
	await audio_player.finished
	remove_child(audio_player)
