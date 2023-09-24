extends Control

onready var _score:=get_node("score")

onready var _menuButton:=get_node("Control/menuButton")
onready var _ScoreButton:=get_node("Control/hightScoresButton")

func _ready() -> void:
	_score.text=str(GlobalPlayer.get_score())

	_menuButton.connect("released",self,"goto_menu")
	_ScoreButton.connect("released",self,"goto_scores")

func goto_menu():
	GlobalPlayer.reset_game()
	get_tree().change_scene("res://src/UI/menu.tscn")
	
func goto_scores():
	get_tree().change_scene("res://src/UI/scores.tscn")
