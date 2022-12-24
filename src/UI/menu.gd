extends Node2D

onready var _PlayButton:=get_node("Control/PlayButton")

func _ready() -> void:
	_PlayButton.connect("pressed",self,"goto_game")
	
	
func goto_game():
	get_tree().change_scene("res://src/Levels/Level01.tscn")
