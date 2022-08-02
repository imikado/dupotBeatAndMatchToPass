extends Node2D



onready var player=get_node("Player")
onready var cameraLimitRect=get_node("CameraLimitRect")


onready var hud=get_node("HUD")

onready var Ant:=preload("res://src/Actors/SimpleEnemies/Ant.tscn")

onready var Energie:=preload("res://src/Common/Levels/Energy.tscn")

onready var _spawnPositionLeft:=get_node("Player/SpawnPosition2DLeft")
onready var _spawnPositionLeft2:=get_node("Player/SpawnPosition2DLeft2")
onready var _spawnPositionRight:=get_node("Player/SpawnPosition2DRight")
onready var _spawnPositionRight2:=get_node("Player/SpawnPosition2DRight2")


onready var _electricalBarriers := get_node("ElectricalBarriers")

var _score:=0

var _active_barrier_list:=[]

func _ready() -> void:
	player.set_camera_limit_rect(cameraLimitRect)

	Events.connect("player_health_changed",self,"_on_player_healt_changed")
	Events.connect("actor_health_changed",self,"_on_actor_healt_changed")
	
	Events.connect("actor_took_damage",self,"_on_actor_took_damage")
	
	for GroupLoop in _electricalBarriers.get_children():
		for BarrierLoop in GroupLoop.get_children():
			BarrierLoop.connect("is_visible",self,"_on_barrier_is_visible",[BarrierLoop])
	
	
func _on_barrier_is_visible(barrier):
	if false==_active_barrier_list.has(barrier):
		_active_barrier_list.append(barrier)
	
	
func _on_player_healt_changed(newLife:float):
	hud.update_player_life(newLife)


func _on_actor_healt_changed(actor:KinematicBody2D,previous_value:float,new_value:float):
	actor.update_enemy_life (previous_value,new_value)
	
	
	if new_value <= 0.0:
		_score+=10
		hud.update_score( _score )
		
		var new_energy = Energie.instance()
		new_energy.global_position=actor.global_position 
		add_child(new_energy)
		var barrier_target = find_barrier_for_actor(actor)
		if barrier_target:
			new_energy.set_target( barrier_target)
		else:
			print_debug("Error to find active barrier")


func find_barrier_for_actor(actor:KinematicBody2D):
	
	var near_distance=100
	var nearer_barrier=null
	
	for barrier_loop in _active_barrier_list:
		if actor.get_type() == barrier_loop.get_type():
			var distance_to_barrier=actor.global_position.distance_to(barrier_loop.global_position)
							
			if nearer_barrier==null:
				nearer_barrier=barrier_loop
				near_distance=distance_to_barrier
			else:

				if distance_to_barrier < near_distance :
					nearer_barrier=barrier_loop
					near_distance=distance_to_barrier

	return nearer_barrier

func _on_actor_took_damage(actor,damage):
	#if actor.has_method("get_life"):
	#	actor.update_enemy_life (actor.get_life(),actor.get_life())
	actor.took_damage(damage)


func spawn_enemy_on_position(enemy_to_spawn,spawn_position,offset=Vector2.ZERO):
	var enemy_spawn = enemy_to_spawn.instance()
	enemy_spawn.add_to_group(Game.GROUP_ENEMY)
	enemy_spawn.setPlayer(player)
	add_child(enemy_spawn)
	
	enemy_spawn.set_global_position(spawn_position.global_position+offset)
	

func _on_spawn01_screen_entered() -> void:
	spawn_enemy_on_position(Ant,_spawnPositionLeft)
	spawn_enemy_on_position(Ant,_spawnPositionRight2)
	

func _on_spawn02_screen_entered() -> void:
	spawn_enemy_on_position(Ant,_spawnPositionLeft)
	spawn_enemy_on_position(Ant,_spawnPositionLeft2,Vector2(-25,0))
	spawn_enemy_on_position(Ant,_spawnPositionRight)
	


func _on_spawn03_screen_entered() -> void:
	spawn_enemy_on_position(Ant,_spawnPositionLeft)
	spawn_enemy_on_position(Ant,_spawnPositionLeft2,Vector2(-25,0))
	spawn_enemy_on_position(Ant,_spawnPositionRight)
	spawn_enemy_on_position(Ant,_spawnPositionRight2,Vector2(25,0))
	
