extends AnimatedSprite

func _ready() -> void:
	play()
	


func _on_ComboPlusOne_animation_finished() -> void:
	queue_free()
	pass # Replace with function body.
