extends CanvasLayer

onready var _player_life_progress_bar=get_node("Control/LifeProgressBar" )

onready var _player_mana_progress_bar=get_node("Control/ManaProgressBar")
onready var _player_mana_progress_bar_color=get_node("Control/ManaProgressBar").get("custom_styles/fg")


onready var _score=get_node("score")

onready var _score_value:=0

const MANA_COLOR_ENOUGH=Color("0516a0")
const MANA_COLOR_NOTENOUGH=Color("900000")

func _ready() -> void:
	pass
	

func update_score(value:int):
	
	var start_score=_score_value
	var end_score:=value
	
	var tween := create_tween()
	tween.tween_method(self,"update_score_value",start_score,end_score,1)
	

func update_score_value(value:int):
	_score.text=str(value)
	_score_value=value
	
	

func update_player_mana(value:float)->void:
	var end_clamped_value = float(clamp(value, _player_mana_progress_bar.min_value, _player_mana_progress_bar.max_value))

	var start_value=_player_mana_progress_bar.value

	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.tween_method(self,"_update_player_mana_bar", start_value, end_clamped_value, 0.5)
	
	
func _update_player_mana_bar(value:float)->void:
	_player_mana_progress_bar.value=value
	
	if value >= GlobalPlayer.attack_amount_mana:
		set_mana_progress_bar_enough()
	else:
		set_mana_progress_bar_notenough()


func set_mana_progress_bar_enough():
	_player_mana_progress_bar_color.set_bg_color(MANA_COLOR_ENOUGH)


func set_mana_progress_bar_notenough():
	_player_mana_progress_bar_color.set_bg_color(MANA_COLOR_NOTENOUGH)


func update_player_life(value:float)->void:

	var end_clamped_value = float(clamp(value, _player_life_progress_bar.min_value, _player_life_progress_bar.max_value))

	var start_value=_player_life_progress_bar.value

	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_method(self,"_update_player_health_bar",start_value, end_clamped_value, 0.3)
	
	
	
func _update_player_health_bar(health_target: float) -> void:
	_player_life_progress_bar.value = health_target



