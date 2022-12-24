extends Node2D

const MIN_SPAWN_Y=127

onready var _ysort=get_node("YSort")
onready var _player=get_node("YSort/Player")
onready var _cameraLimitRect=get_node("CameraLimitRect")
onready var _hud=get_node("HUD")
onready var _controls=get_node("Controls")

onready var _hudScore:=get_node("HUD/Container/Score/Position2D")

onready var Ant:=preload("res://src/Actors/SimpleEnemies/Ant.tscn")
onready var Beetle:=preload("res://src/Actors/SimpleEnemies/Beetle.tscn")
onready var Spider:=preload("res://src/Actors/SimpleEnemies/Spider.tscn")

onready var Squirrel:=preload("res://src/Actors/BonusActors/Squirrel.tscn")

onready var Energie:=preload("res://src/Common/Levels/Energy.tscn")

onready var LifeBottle:=preload("res://src/Common/Items/LifeBottle.tscn")

onready var ComboPlusOne:=preload("res://src/Actors/Players/ComboPlusOne.tscn")
onready var ComboBonus:=preload("res://src/Actors/Players/Player/ComboBonus.tscn")

onready var _spawnPositionLeft:=get_node("YSort/Player/SpawnPosition2DLeft")
onready var _spawnPositionLeft2:=get_node("YSort/Player/SpawnPosition2DLeft2")
onready var _spawnPositionRight:=get_node("YSort/Player/SpawnPosition2DRight")
onready var _spawnPositionRight2:=get_node("YSort/Player/SpawnPosition2DRight2")

onready var _positionRightTop:=get_node("Bonus/rightTop")
onready var _positionRightBottom:=get_node("Bonus/rightBottom");
onready var _positionLeftTop:=get_node("Bonus/leftTop");
onready var _positionLeftBottom:=get_node("Bonus/leftBottom");

onready var _spawnTimer:=get_node("Timers/SpawnTimer")
onready var _manaTimer:=get_node("Timers/ManaTimer")

onready var _electricalBarriers := get_node("ElectricalBarriers")

onready var _specialEffects := get_node("SpecialEffects")

onready var _bonus:=get_node("Bonus")
onready var _timeLeftLabel:=get_node("HUD/timeLeft")

var _active_barrier_list:=[]

var _wave_number=2
var _total_wave_number=0
var _random_combo_count=0

var _timeLeft:=10



onready var _wave_array:=[
	 
]


func debug():
	_player.global_position.x +=1500
	_wave_number=2


func _ready() -> void:
	if Game.DEBUG_ENABLED:
		debug()
	else:
		_player.global_position.x +=300
	
	_hud.update_player_life(GlobalPlayer.life)
	_hud.update_score(GlobalPlayer.get_score())
	_hud.update_player_mana(GlobalPlayer.mana)
	
	update_mana_button()
		
	_player.set_camera_limit_rect(_cameraLimitRect)

	Events.connect("player_health_changed",self,"_on_player_healt_changed")
	Events.connect("actor_health_changed",self,"_on_actor_healt_changed")
	
	Events.connect("actor_took_damage",self,"_on_actor_took_damage")
	Events.connect("actor_took_damage_by_bullet",self,"_on_actor_took_damage_by_bullet")
	
	Events.connect("player_launch_mana_attack",self,"_on_player_launch_mana_attack")
	
	Events.connect("actor_let_item",self,"_on_actor_let_item")
	Events.connect("player_took_lifebottle",self,"_on_player_took_lifebottle")
	
	var startEndMoveList:=[
		{
			"start":_positionLeftTop,
			"end":_positionRightBottom
		},
		{
			"start":_positionRightTop,
			"end":_positionLeftBottom
		}

	]

	for startEndMoveLoop in startEndMoveList:
		var newSquirrel=Squirrel.instance()
		newSquirrel.add_to_group(Game.GROUP_BONUSACTOR)
		_ysort.add_child(newSquirrel)
		print(startEndMoveLoop)
		newSquirrel.set_global_position(startEndMoveLoop["start"].global_position)
		newSquirrel.setTarget(startEndMoveLoop["end"])




func _on_barrier_is_visible(barrier):
	var is_first_barrier=false
	if _active_barrier_list.size()==0:
		is_first_barrier=true
		
	if false==_active_barrier_list.has(barrier):
		_active_barrier_list.append(barrier)
	
	if is_first_barrier:
		process_spawn()
		_spawnTimer.start()
	
func _on_player_healt_changed(newLife:float):
	GlobalPlayer.update_life(newLife)
	_hud.update_player_life(GlobalPlayer.life)
	
	if newLife <=0:
		get_tree().change_scene("res://src/UI/GameOver.tscn")


func manage_combo_for_actor(actor):
	var new_combo_plus_one = ComboPlusOne.instance()
	new_combo_plus_one.global_position = actor.global_position + Vector2(0,-20)
	
	var combo_count=actor.get_combo_count()
		
	var delta_position=Vector2.ZERO
	if combo_count==0:
		delta_position.x=-5
		delta_position.y=5
	elif combo_count==1:
		new_combo_plus_one.scale=Vector2(1.2,1.2)
		#delta_position.x=5
		delta_position.y=-5
	
	elif combo_count==2:
		new_combo_plus_one.scale=Vector2(2.6,2.6)
		#delta_position.x=25
		delta_position.y=-25
		
		var new_combo_bonus = ComboBonus.instance()
		new_combo_bonus.global_position = actor.global_position + Vector2(0,-50)
		new_combo_bonus.connect("combo_arrived",self,"_on_combo_bonus_finished")
		new_combo_bonus.set_target(_hudScore)
		new_combo_bonus.set_as_toplevel(true)
		
		_specialEffects.add_child(new_combo_bonus)
		
	new_combo_plus_one.global_position+=delta_position
	
	new_combo_plus_one.set_as_toplevel(true)
	_specialEffects.add_child(new_combo_plus_one)
	
	actor.increment_combo_count()


func _on_actor_healt_changed(actor:KinematicBody2D,previous_value:float,new_value:float):
	
	actor.update_enemy_life (previous_value,new_value)

	
	if _player.is_combo():
	
		manage_combo_for_actor(actor)
	
	else:
		actor.reset_combo_count()
	
	
	if new_value <= 0.0:
		increment_score(10)
		
		var new_energy = Energie.instance()
		new_energy.global_position=actor.global_position 
		add_child(new_energy)
		var barrier_target = find_barrier_for_actor(actor)
		if barrier_target:
			new_energy.set_target( barrier_target)
		else:
			print_debug("Error to find active barrier")


func increment_score(points:int):
	var new_score:int 
	new_score=GlobalPlayer.get_score() + points
	GlobalPlayer.save_score(new_score)
	_hud.update_score( new_score )


func _on_combo_bonus_finished():
	increment_score(10)


func find_barrier_for_actor(actor:KinematicBody2D):
	
	var near_x=0
	var nearer_barrier=null
	
	for barrier_loop in _active_barrier_list:
		if actor.get_type() == barrier_loop.get_type():
			var barrier_x=barrier_loop.global_position.x
							
			if nearer_barrier==null:
				nearer_barrier=barrier_loop
				near_x=barrier_x
			else:

				if near_x < barrier_x :
					nearer_barrier=barrier_loop
					near_x=barrier_x

	return nearer_barrier

func _on_actor_took_damage(actor,damage):
	#if actor.has_method("get_life"):
	#	actor.update_enemy_life (actor.get_life(),actor.get_life())
	actor.took_damage(damage)

func _on_actor_let_item(actor):
	var newLifeBottle=LifeBottle.instance()
	_bonus.add_child(newLifeBottle)
	
	newLifeBottle.set_global_position( actor.global_position)
	

func _on_actor_took_damage_by_bullet(actor,damage,bullet):
	#if actor.has_method("get_life"):
	#	actor.update_enemy_life (actor.get_life(),actor.get_life())
	_on_actor_took_damage(actor,damage)
	
	bullet.explode()
	

func spawn_enemy_on_position(enemy_to_spawn,spawn_position,offset=Vector2.ZERO):
	var enemy_spawn = enemy_to_spawn.instance()
	
	var active_barrier=find_barrier_for_actor(enemy_spawn)
	if active_barrier==null:
		enemy_spawn.queue_free()
		return
	
	enemy_spawn.add_to_group(Game.GROUP_ENEMY)
	enemy_spawn.setPlayer(_player)

	
	if spawn_position.global_position.y < MIN_SPAWN_Y:
		spawn_position.global_position.y=MIN_SPAWN_Y
	
	enemy_spawn.set_global_position(spawn_position.global_position+offset)
	
	_ysort.add_child(enemy_spawn)

func process_spawn():
	if _wave_number >= _wave_array.size():
		return
	
	for wave_loop in _wave_array[_wave_number]:
		var offset=Vector2.ZERO
		if wave_loop.has("offset"):
			offset=wave_loop["offset"]
		spawn_enemy_on_position( wave_loop["enemy"],wave_loop["position"],offset)
	
	_wave_number+=1
	_total_wave_number+=1
	if _wave_number >= _wave_array.size():
		_wave_number=0



func _on_SpawnTimer_timeout() -> void:
	process_spawn()
	
	if _total_wave_number > 8:
		_spawnTimer.wait_time=5
	elif _total_wave_number > 4:
		_spawnTimer.wait_time=10
	
	
	_spawnTimer.start()


func _on_ManaTimer_timeout() -> void:
	GlobalPlayer.increment_mana(1)
	_hud.update_player_mana(GlobalPlayer.mana)
	
	update_mana_button()


func _on_player_launch_mana_attack()->void:
	GlobalPlayer.use_amount_mana(GlobalPlayer.attack_amount_mana)
	_hud.update_player_mana(GlobalPlayer.mana)
	
	update_mana_button()
	

func update_mana_button():
	if GlobalPlayer.can_use_amount_mana(GlobalPlayer.attack_amount_mana):
		_controls.enable_mana_button()
	else:
		_controls.disable_mana_button()



func _on_Gate_player_entered_gate() -> void:
	print('next level')
	get_tree().change_scene("res://src/Levels/Level02.tscn")
	pass # Replace with function body.

func _on_player_took_lifebottle(bottle)->void:
	#print("_on_player_took_lifebottle")
	bottle.queue_free()
	
	GlobalPlayer.update_life(GlobalPlayer.life+10)
	_hud.update_player_life(GlobalPlayer.life)
	


func _on_timeLeft_timeout() -> void:
	_timeLeft-=1
	if(_timeLeft<0):
		get_tree().change_scene("res://src/Levels/Level03.tscn")

	_timeLeftLabel.text=str(_timeLeft)

	pass # Replace with function body.
