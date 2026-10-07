extends Control

@onready var _score:=get_node("score")

@onready var _menuButton:=get_node("Control/menuButton")
@onready var _scoreButton:=get_node("Control/hightScoresButton")

@onready var _buttonList=[
	_menuButton,
	_scoreButton
]

var _selected=1

func _ready() -> void:
	Sound.stop_music()
	Sound.play("gameover", 0.0)

	var reveal = ScoreReveal.count_up(self, _score, GlobalPlayer.get_score())
	if Game.last_score_is_record and GlobalPlayer.get_score() > 0:
		reveal.tween_callback(ScoreReveal.show_record.bind(self, _score))

	_menuButton.connect("released", Callable(self, "goto_menu"))
	_scoreButton.connect("released", Callable(self, "goto_scores"))
	
	$playerGameOver.play("default")
	
	refresh_buttons()

func goto_menu():
	if Transition.is_busy():
		return
	Sound.play("menu_select", 0.0)
	GlobalPlayer.reset_game()
	Transition.goto("res://src/UI/menu.tscn")
	
func goto_scores():
	if Transition.is_busy():
		return
	Sound.play("menu_select", 0.0)
	Transition.goto("res://src/UI/scores.tscn")

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
		_buttonList[i].deselect()
			
	get_selected_buton().select()
	
func next_button():
	_selected+=1
	if(_selected>=_buttonList.size()):
		_selected=0
	Sound.play("menu_move", 0.0)
	refresh_buttons()
