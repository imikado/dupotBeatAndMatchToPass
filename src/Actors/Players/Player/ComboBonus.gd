extends AnimatedSprite

signal combo_arrived

var _target:Node

func _ready() -> void:
	play()
	

func set_target(target:Node):
	_target=target
	play()
	

func _on_ComboBonus_animation_finished() -> void:

	var tween = create_tween()
	tween.tween_property(self,"global_position",_target.global_position,1)
	
	tween.connect("finished",self,"_on_combo_finished")

func _on_combo_finished()->void:
	queue_free()
	
	emit_signal("combo_arrived")
	
