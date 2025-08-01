extends Node

@export var enable:bool = true
@export var target:CanvasGroup
@export var offset:Vector2
@export var dice:Node
@export var dice_offset:Vector2
@export var GameController:Node

var is_selecting = false
var last_select = -1
var targets

signal DicePlayTimeout

func _ready():
	pass

func dice_play():
	var pos = dice.get_global_mouse_position()
	print(dice_offset, " ", pos)
	if pos.x <= dice_offset.x+50 and pos.x >= dice_offset.x-50 and\
	   pos.y <= dice_offset.y+50 and pos.y >= dice_offset.y-50 and\
	   pos.x+pos.y-dice_offset.x-dice_offset.y <= 55 and pos.x+pos.y-dice_offset.x-dice_offset.y >= -55 and\
	   -pos.x+pos.y+dice_offset.x-dice_offset.y <= 55 and -pos.x+pos.y+dice_offset.x-dice_offset.y >= -55:
		var result = GameController.able_to_dice()
		if result:
			print(result)
			dice.Number = result
			dice.start_animation()
			print("dice play")
			
			await dice.DiceTimeout
			DicePlayTimeout.emit()

func position_update():
	var pos = target.get_global_mouse_position()
	targets = target.get_children()
	for i in range(len(targets)):
		var item = targets[i]
		var center = item.position + offset
		if last_select == i:
			continue
		if i == len(targets)-1:
			if pos.x >= center.x-71 and pos.x <= center.x+71 and pos.y >= center.y-95 and pos.y <= center.y+95:
				if item.is_selected:
					item.position.y += 30
				else:
					item.position.y -= 30
				item.is_selected = not item.is_selected
				last_select = i
		else:
			var next_center = targets[i+1].position + offset
			if pos.x >= center.x-71 and pos.x <= next_center.x-71 and pos.y >= center.y-95 and pos.y <= center.y+95:
				if item.is_selected:
					item.position.y += 30
				else:
					item.position.y -= 30
				item.is_selected = not item.is_selected
				last_select = i

func cancel_select():
	var targets = target.get_children()
	for i in range(len(targets)):
		var item = targets[i]
		if item.is_selected:
			item.position.y += 30
			item.is_selected = false
		

func _process(delta):
	if is_selecting and GameController.get_game_statue()[3] == 1 and GameController.get_game_statue()[0] == 0:
		position_update()

func _input(event):
	if event.is_action_released("select"):
		is_selecting = false
		last_select = -1
		dice_play()
	if event.is_action_pressed("select"):
		is_selecting = true
		last_select = -1
	if event.is_action_released("cancel_select"):
		cancel_select()
