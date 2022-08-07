extends Enemy

onready var Bullet = preload("res://src/Actors/SimpleEnemies/Spider/Bullet.tscn")
onready var BulletSpawnPosition= get_node("BodyPivot/BulletSpawnPosition")

func _init() -> void:
	_near_distance=300
	_damage=20

	_type= Game.ENEMY_TYPE_LIST.SPIDER


func attack():
	
	spawn_bullet()
	
func spawn_bullet():
	var side
	var new_bullet= Bullet.instance()
		
	if _player.global_position.x < global_position.x:
		side=new_bullet.LEFT
	else:
		side=new_bullet.RIGHT
	

	
	get_parent().add_child(new_bullet)
	
	new_bullet.set_global_position(BulletSpawnPosition.global_position)
	new_bullet.set_direction(side)
	
