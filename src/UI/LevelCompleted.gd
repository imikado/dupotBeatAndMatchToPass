extends Control

onready var _score:=get_node("score")
onready var _menuButton:=get_node("Control/menuButton")

var levelCompleted=0

func _ready() -> void:
	_score.text=str(GlobalPlayer.get_score())

	levelCompleted=GlobalPlayer.get_level()

	_menuButton.connect("released",self,"goto_nextLevel")



func goto_nextLevel():
	GlobalPlayer.reset_game()
	
	get_tree().change_scene("res://src/Levels/LevelBonus.tscn")
	
