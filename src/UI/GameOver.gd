extends Control

onready var _score:=get_node("score")

onready var _menuButton:=get_node("Control/menu")

func _ready() -> void:
	_score.text=str(GlobalPlayer.get_score())

	_menuButton.connect("pressed",self,"goto_menu")
	

func goto_menu():
	GlobalPlayer.reset_game()
	get_tree().change_scene("res://src/UI/menu.tscn")
	
