extends Line2D

signal fall_ended


onready var _sprite:=get_node("Sprite")
onready var _hitBox:=get_node("HitBox/CollisionShape2D")


var _damage:=20

func _ready() -> void:
	_sprite.visible=false
	_hitBox.disabled=true
	
	
func start_fall():
	
	var tween:=create_tween()
	
	var end_position=position
	position=Vector2(position.x,-310)
	
	tween.tween_property(self,"position",end_position,0.2)
	
	yield(tween,"finished")
	
	_sprite.visible=true
	_hitBox.disabled=false
	
	emit_signal("fall_ended")


func end_fall():
	_hitBox.disabled=true
	



func _on_HitBox_body_entered(body: Node) -> void:
	if body.is_in_group(Game.GROUP_ENEMY):
		Events.emit_signal("actor_took_damage",body,_damage)
	pass # Replace with function body.
