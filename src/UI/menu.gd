extends Node2D

onready var _PlayButton:=get_node("Control/PlayButton")
onready var _ScoreButton:=get_node("Control/hightScoresButton")
onready var _settingsButton:=get_node("Control/settingsButton")

func _ready() -> void:
	_PlayButton.connect("released",self,"goto_game")
	
	_ScoreButton.connect("released",self,"goto_scores")
	_settingsButton.connect("released",self,"goto_settings")
	
func goto_game():
	get_tree().change_scene("res://src/Levels/LevelTemplate.tscn")
	
func goto_scores():
	get_tree().change_scene("res://src/UI/scores.tscn")

func goto_settings():
	get_tree().change_scene("res://src/UI/settings.tscn")
