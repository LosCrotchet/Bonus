extends Node2D

@export var number:int = 1
@export var wait_time:float = 2
@export var enable:bool = true

@onready var Outlook = $outlook
@onready var Animation_timer = $Timer

signal DiceTimeout(result:int)

func _ready() -> void:
	DeckManager.dice_roll.connect(Callable(self, "_on_player_manager_player_dice_roll"))
	DeckManager.dice_result.connect(Callable(self, "_on_receive_dice_result"))

func start_animation():
	if enable:
		Outlook.play("roll")
		if DeckManager.GameMode != 2:
			wait_time = randf_range(1, 2.5)
			Animation_timer.start(wait_time)

func _on_timer_timeout():
	Outlook.stop()
	Outlook.play("still")
	Outlook.stop()
	number = randi_range(1, 6)
	Outlook.set_frame_and_progress(number-1, 0)
	DiceTimeout.emit(number)
	if DeckManager.GameMode == 1:
		WebController.send_dice_result(number)

func _on_receive_dice_result(result):
	Outlook.stop()
	Outlook.play("still")
	Outlook.stop()
	number = result
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
