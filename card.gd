extends Node2D

class_name Card

@export var suit:int					# 花色 (0=黑桃,1=红心,2=方块,3=梅花)；对于Joker，0=小王，1=大王
@export var rank:int					# 点数 (1=3,2=4,11=K,12=A,13=2, 0=JOKER)
@export var is_folded:bool = false
@export var is_selected:bool = false

const width = 500
const height = 700


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
