extends Control


var scoreLista=[
	{
		"date": "2023-03-24 08:00:00",
		"score":120
	},
	{
		"date": "2023-03-25 09:25:00",
		"score":35
	},
	{
		"date": "2023-03-24 08:00:00",
		"score":20
	},
	{
		"date": "2023-03-25 09:25:00",
		"score":35
	},
	{
		"date": "2023-03-24 08:00:00",
		"score":20
	},
	{
		"date": "2023-03-25 09:25:00",
		"score":35
	},
	{
		"date": "2023-03-24 08:00:00",
		"score":20
	},
	{
		"date": "2023-03-25 09:25:00",
		"score":35
	}
]

onready var _menuButton:=get_node("menuButton")

onready var _line:=get_node("line")
onready var _table:=get_node("scroll/table")

class scoreSorter:
	static func sort_descending(a, b):
		if a['score'] > b['score']:
			return true
		return false

func _ready() -> void:
	
	var scoreList=Game.getHighScoreList()
	
	scoreList.sort_custom(scoreSorter, "sort_descending")

	
	build(scoreList)
	
	_menuButton.connect("released",self,"goto_menu")
	_menuButton.select()

func build(scoreList):
	
	for scoreLoop in scoreList:
		
		var newLine=_line.duplicate()
		newLine.get_child(0).text=scoreLoop.date;
		newLine.get_child(1).text=str(scoreLoop.score);
		newLine.visible=true
		
		_table.add_child(newLine)
		
		print(scoreLoop)
	
	pass
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_menuButton.emit_signal("released")


func goto_menu():
	GlobalPlayer.reset_game()
	get_tree().change_scene("res://src/UI/menu.tscn")
