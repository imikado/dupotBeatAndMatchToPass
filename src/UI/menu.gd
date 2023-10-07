extends Node2D

onready var _playButton:=get_node("Control/playButton")
onready var _highScoresButton:=get_node("Control/hightScoresButton")
onready var _settingsButton:=get_node("Control/settingsButton")

var _selected=0

onready var _buttonList=[
	_playButton,
	_highScoresButton,
	_settingsButton
]

func _ready() -> void:
	_playButton.connect("released",self,"goto_game")
	
	_highScoresButton.connect("released",self,"goto_scores")
	_settingsButton.connect("released",self,"goto_settings")
	
	refresh_buttons()

	

	
func goto_game():
	get_tree().change_scene("res://src/Levels/LevelTemplate.tscn")
	
func goto_scores():
	get_tree().change_scene("res://src/UI/scores.tscn")

func goto_settings():
	get_tree().change_scene("res://src/UI/settings.tscn")
	
#control buttons
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_mana"):
		next_button()
	if event.is_action_pressed("attack"):
		get_selected_buton().emit_signal("released")
		
func get_selected_buton():
	return _buttonList[_selected]
	
func refresh_buttons():
	for i in range(_buttonList.size()):
		_buttonList[i].unselect()
			
	get_selected_buton().select()
	
func next_button():
	_selected+=1
	if(_selected>=_buttonList.size()):
		_selected=0
	refresh_buttons()
