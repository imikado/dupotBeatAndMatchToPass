extends CanvasLayer

onready var _player_progress_bar=get_node("Container/Player/ProgressBar")
onready var _player_tween=get_node("Tween")


onready var _score=get_node("Container/Score/Label")



func _ready() -> void:
	pass
	

func update_score(value:int):
	_score.text=str(value)
	

func update_player_life(value:float)->void:

	var health = int(clamp(value, _player_progress_bar.min_value, _player_progress_bar.max_value))
	# Here, notice we call `interpolate_method()`. We have the `Tween` node
	# repeatedly call the `_update_health_bar()` method on this node.
	_player_tween.interpolate_method(self, "_update_player_health_bar", _player_progress_bar.value, health, 0.33)
	_player_tween.start()
	
	
func _update_player_health_bar(health_target: float) -> void:
	_player_progress_bar.value = health_target
	# We couldn't directly tween the color with `Tween.interpolate_property()`,
	# this is a case where we need to use `interpolate_method()` instead.
	
	#_progress_bar.tint_progress = Color("EB564B").linear_interpolate(
	#	Color("4DA6FF"), health_target / _progress_bar.max_value
	#)
