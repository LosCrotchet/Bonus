extends Node2D

@export var number:int
@export var wait_time:float = 2
@export var enable:bool = true

@onready var Outlook = $outlook
@onready var Animation_timer = $Timer

signal DiceTimeout(result:int)

func start_animation():
	if enable:
		Outlook.play("roll")
		Animation_timer.start(wait_time)

func _on_timer_timeout():
	Outlook.stop()
	Outlook.play("still")
	Outlook.stop()
	number = randi_range(1, 6)
	Outlook.set_frame_and_progress(number-1, 0)
	DiceTimeout.emit(number)

func change_statue(statue:int = 0):
	if statue == 0:
		enable = true
		Outlook.stop()
		Outlook.play("still")
		Outlook.stop()
		if number != 0:
			Outlook.set_frame_and_progress(number-1, 0)
		else:
			Outlook.set_frame_and_progress(0, 0)
	if statue == 1:
		enable = false
		Outlook.stop()
		Outlook.play("bonus")
		Outlook.stop()
		Outlook.set_frame_and_progress(0, 0)

func _on_player_manager_player_dice_roll():
	start_animation()

func _on_outlook_animation_finished():
	if Outlook.animation == "bonus":
		if Outlook.frame == 5:
			Outlook.play_backwards("bonus")
		if Outlook.frame == 0:
			Outlook.play("bonus")
