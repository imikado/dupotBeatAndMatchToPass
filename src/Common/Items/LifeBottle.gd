extends Node2D

const POP_HEIGHT := 18.0


func _ready() -> void:
	$AnimatedSprite2D.play()

func _on_Area2D_body_entered(body: Node) -> void:
	if body is Player:
		Events.emit_signal("player_took_lifebottle",self)
		
	pass # Replace with function body.


# Jaillit du sac en arc, rebondit, et ne se ramasse qu'une fois au sol
func pop_to(target: Vector2) -> void:
	var area := $Area2D
	var sprite := $AnimatedSprite2D
	area.set_deferred("monitoring", false)
	Fx.shadow(self, 8).position = Vector2(0, 7)

	create_tween().tween_property(self, "global_position", target, 0.45).set_ease(Tween.EASE_OUT)

	var hop := create_tween()
	hop.tween_property(sprite, "position:y", -POP_HEIGHT, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	hop.tween_property(sprite, "position:y", 0.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	hop.tween_property(sprite, "position:y", -4.0, 0.08).set_ease(Tween.EASE_OUT)
	hop.tween_property(sprite, "position:y", 0.0, 0.08).set_ease(Tween.EASE_IN)
	hop.tween_callback(area.set_deferred.bind("monitoring", true))
