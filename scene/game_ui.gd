extends CanvasGroup

class_name GameUI

var hand_count = 0
var deck_count

func _on_game_manager_game_signal(now_whos_turn, now_whos_dice, dice_result, played_cards, last_player, is_bonus):
	await get_tree().create_timer(0.2).timeout
	if now_whos_turn == 0 and (dice_result != -1 or is_bonus):
		visible = true
		$PlayButton.disabled = false
		$HintButton.disabled = false
		$PassButton.disabled = false
		if is_bonus and now_whos_turn == now_whos_dice and len(played_cards) == 0:
			$PassButton.visible = false
		else:
			$PassButton.visible = true
	else:
		visible = false

func _on_player_manager_player_select_update(type):
	$SelectTypeLabel.text = type

func _on_player_manager_player_hand_count_update(count):
	hand_count = count

func _on_player_manager_game_end(player_name):
	visible = false

func _on_player_manager_player_finish(action):
	$PassButton.disabled = true
	$HintButton.disabled = true
	$PlayButton.disabled = true

func _on_pass_button_pressed():
	$PassButton.disabled = true
