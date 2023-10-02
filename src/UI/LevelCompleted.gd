extends Control

onready var _score:=get_node("score")
onready var _menuButton:=get_node("Control/menuButton")

onready var _title:=get_node("title")

var levelCompleted=0

func _ready() -> void:
	_score.text=str(GlobalPlayer.get_score())

	levelCompleted=GlobalPlayer.get_level()
	
	_title.text="LEVEL "+("%02d" % levelCompleted)+": COMPLETED"

	_menuButton.connect("released",self,"goto_nextLevel")



func goto_nextLevel():
	GlobalPlayer.set_level(GlobalPlayer.get_level()+1)
	get_tree().change_scene("res://src/Levels/LevelBonus.tscn")
	
