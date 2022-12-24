extends Node2D

func _ready():
	yield(get_tree().create_timer(2.0), "timeout")
	_on_Timer_timeout()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Timer_timeout():
	get_tree().change_scene("res://src/UI/menu.tscn")
	pass # Replace with function body.
