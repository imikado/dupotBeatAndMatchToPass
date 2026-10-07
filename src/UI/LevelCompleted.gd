extends Control

@onready var _score:=get_node("score")
@onready var _menuButton:=get_node("Control/menuButton")

@onready var _title:=get_node("title")

var levelCompleted=0

func _ready() -> void:
	Sound.stop_music()
	Sound.play("level_complete", 0.0)

	ScoreReveal.count_up(self, _score, GlobalPlayer.get_score())

	levelCompleted=GlobalPlayer.get_level()
	
	_title.text="LEVEL "+("%02d" % levelCompleted)+": COMPLETED"

	_menuButton.connect("released", Callable(self, "goto_nextLevel"))
	_menuButton.select()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_menuButton.emit_signal("released")


func goto_nextLevel():
	if Transition.is_busy():
		return
	Sound.play("menu_select", 0.0)
	GlobalPlayer.set_level(GlobalPlayer.get_level()+1)
	Transition.goto("res://src/Levels/LevelBonus.tscn")
	
