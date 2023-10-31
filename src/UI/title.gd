extends Node2D

func _ready():
	
	var keyboardOsList=["HTML5","Web","X11","Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD","Windows"]

	var osName= OS.get_name()
	#print(osName)
	if(keyboardOsList.find(osName)!=-1):
		Game.setControlsEnabled(false)
		pass
		
	yield(get_tree().create_timer(2.0), "timeout")
	_on_Timer_timeout()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass


func _on_Timer_timeout():
	get_tree().change_scene("res://src/UI/menu.tscn")
	pass # Replace with function body.
