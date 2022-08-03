extends Enemy

func _init() -> void:
	_near_distance=20
	_damage=10
	
	_type= Game.ENEMY_TYPE_LIST.BEETLE
