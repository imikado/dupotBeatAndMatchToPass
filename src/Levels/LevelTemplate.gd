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

onready var _electricalBarrier01 := get_node("ElectricalBarriers/01/ElectricalBarrier")

var score:=0

func _ready() -> void:
	player.set_camera_limit_rect(cameraLimitRect)

	Events.connect("player_health_changed",self,"_on_player_healt_changed")
	Events.connect("actor_health_changed",self,"_on_actor_healt_changed")
	
	Events.connect("actor_took_damage",self,"_on_actor_took_damage")
	
	
	
func _on_player_healt_changed(newLife:float):
	hud.update_player_life(newLife)

func _on_actor_healt_changed(actor:KinematicBody2D,previous_value:float,new_value:float):
	actor.update_enemy_life (previous_value,new_value)
	
	
	if new_value <= 0.0:
		score+=10
		hud.update_score( score )
		
		var new_energy = Energie.instance()
		new_energy.global_position=actor.global_position 
		add_child(new_energy)
		new_energy.set_target( _electricalBarrier01)

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
	

	pass

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
	
