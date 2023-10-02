extends Node2D

signal fall_ended


onready var _sprite:=get_node("Sprite")
onready var _hitBox:=get_node("HitBox/CollisionShape2D")


var _damage:=20

func _ready() -> void:
	hide_impact()
	
	
func start_fall():
	
	hide_impact()
	
	$AnimationPlayer.stop(true)
	$AnimationPlayer.play("storm")
	
	#var tween:=create_tween()
	
	#var end_position=position
	#position=Vector2(position.x,-310)
	
	#tween.tween_property(self,"position",end_position,0.2)
	
	#yield(tween,"finished")
	
	
	
	#emit_signal("fall_ended")
	
	#_sprite.visible=false
	#_hitBox.disabled=true


func end_fall():
	emit_signal("fall_ended")
	

func display_impact():
	_hitBox.disabled=false
	_sprite.visible=true
	
func hide_impact():
	_sprite.visible=false
	_hitBox.disabled=true
	
	#emit_signal("fall_ended")


func _on_HitBox_body_entered(body: Node) -> void:
	if body.is_in_group(Game.GROUP_ENEMY):
		Events.emit_signal("actor_took_damage",body,_damage)
	pass # Replace with function body.
