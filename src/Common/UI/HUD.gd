extends CanvasLayer

onready var _player_life_progress_bar=get_node("Container/Player/VBoxContainer/LifeProgressBar" )
onready var _player_tween=get_node("Tween")

onready var _player_mana_progress_bar=get_node("Container/Player/VBoxContainer/ManaProgressBar")

onready var _score=get_node("Container/Score/Label")



func _ready() -> void:
	pass
	

func update_score(value:int):
	_score.text=str(value)
	

func update_player_mana(value:float)->void:
	var clamped_value = int(clamp(value, _player_mana_progress_bar.min_value, _player_mana_progress_bar.max_value))

	_player_tween.interpolate_method(self, "_update_player_mana_bar", _player_mana_progress_bar.value, clamped_value, 0.33)
	_player_tween.start()
	
	
func _update_player_mana_bar(value:float)->void:
	_player_mana_progress_bar.value=value
	

func update_player_life(value:float)->void:

	var health = int(clamp(value, _player_life_progress_bar.min_value, _player_life_progress_bar.max_value))

	_player_tween.interpolate_method(self, "_update_player_health_bar", _player_life_progress_bar.value, health, 0.33)
	_player_tween.start()
	
	
func _update_player_health_bar(health_target: float) -> void:
	_player_life_progress_bar.value = health_target



