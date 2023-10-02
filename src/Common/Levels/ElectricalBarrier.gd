extends Node2D

signal is_visible

var energy_count=0
var max_energy=6

export(Game.ENEMY_TYPE_LIST) var type :=   Game.ENEMY_TYPE_LIST.ANT

onready var _animatedSprite :=get_node("AnimatedSprite")
onready var _animatedSpriteProgress :=get_node("AnimatedSprite2")

onready var _barrier := get_node("barrier")
onready var _collisision := get_node("StaticBody2D/CollisionShape2D")

onready var _icons := get_node("icons")


var _type_icon_list :={}

func _ready() -> void:
	if Game.DEBUG_ENABLED:
		max_energy=1
	
	_animatedSprite.play()
	
	_type_icon_list ={
		Game.ENEMY_TYPE_LIST.ANT : get_node("icons/ant"),
		Game.ENEMY_TYPE_LIST.SPIDER : get_node("icons/spider"),
		Game.ENEMY_TYPE_LIST.BEETLE : get_node("icons/beetle")
	}
	
	for icon_loop in _icons.get_children():
		icon_loop.visible=false
		
	_type_icon_list[type].visible=true
	
func build():
	return
	
	_type_icon_list ={
		Game.ENEMY_TYPE_LIST.ANT : get_node("icons/ant"),
		Game.ENEMY_TYPE_LIST.SPIDER : get_node("icons/spider"),
		Game.ENEMY_TYPE_LIST.BEETLE : get_node("icons/beetle")
	}
	
	for icon_loop in _icons.get_children():
		icon_loop.visible=false
		
	_type_icon_list[type].visible=true

func set_type(type_):
	type=type_
	
	build()


func get_type():
	return type


func enable_barrier():
	_barrier.visible=true
	_collisision.disabled=false
	
func disable_barrier():
	_barrier.visible=false
	_collisision.disabled=true
	
func increment():
	energy_count+=1
	if energy_count > max_energy:
		return
		energy_count=0
		enable_barrier()
		
	_animatedSpriteProgress.frame=energy_count
	
	if energy_count==max_energy:
		disable_barrier()


func _on_VisibilityNotifier2D_screen_entered() -> void:
	emit_signal("is_visible")
	pass # Replace with function body.
