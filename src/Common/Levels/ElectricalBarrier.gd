extends Node2D

var energy_count=0
const MAX_ENERGY=7

onready var _animatedSprite :=get_node("AnimatedSprite")
onready var _animatedSpriteProgress :=get_node("AnimatedSprite2")

func _ready() -> void:
	_animatedSprite.play()
	
func increment():
	energy_count+=1
	if energy_count > MAX_ENERGY:
		energy_count=0
		
	_animatedSpriteProgress.frame=energy_count+1
