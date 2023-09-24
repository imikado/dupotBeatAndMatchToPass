extends Node2D

onready var _PlayButton:=get_node("Control/PlayButton")
onready var _ScoreButton:=get_node("Control/hightScoresButton")

func _ready() -> void:
	_PlayButton.connect("released",self,"goto_game")
	
	_ScoreButton.connect("released",self,"goto_scores")
	
	
func goto_game():
	get_tree().change_scene("res://src/Levels/Level01.tscn")
	
func goto_scores():
	get_tree().change_scene("res://src/UI/scores.tscn")
