extends Node2D


func _ready() -> void:
	$AnimatedSprite.play()

func _on_Area2D_body_entered(body: Node) -> void:
	if body is Player:
		Events.emit_signal("player_took_lifebottle",self)
		
	pass # Replace with function body.
