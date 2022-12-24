extends Node2D

signal player_entered_gate


func _on_Area2D_body_entered(body: Node) -> void:
	if body is Player:
		emit_signal("player_entered_gate")
		
	pass # Replace with function body.
