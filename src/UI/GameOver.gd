extends Control

onready var _score:=get_node("score")

onready var _menuButton:=get_node("Control/menuButton")
onready var _scoreButton:=get_node("Control/hightScoresButton")

onready var _buttonList=[
	_menuButton,
	_scoreButton
]

var _selected=1

func _ready() -> void:
	_score.text=str(GlobalPlayer.get_score())

	_menuButton.connect("released",self,"goto_menu")
	_scoreButton.connect("released",self,"goto_scores")
	
	$playerGameOver.play("default")
	
	refresh_buttons()

func goto_menu():
	GlobalPlayer.reset_game()
	get_tree().change_scene("res://src/UI/menu.tscn")
	
func goto_scores():
	get_tree().change_scene("res://src/UI/scores.tscn")

#control buttons
func _input(event: InputEvent) -> void:
	if Game.isInputNextButton(event):
		next_button()
	elif Game.isInputValidateButton(event):
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
