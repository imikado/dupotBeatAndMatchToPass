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

@onready var _menuButton:=get_node("menuButton")

@onready var _line:=get_node("line")
@onready var _table:=get_node("scroll/table")

class scoreSorter:
	static func sort_descending(a, b):
		if a['score'] > b['score']:
			return true
		return false

func _ready() -> void:
	
	var scoreList=Game.getHighScoreList()
	
	scoreList.sort_custom(Callable(scoreSorter, "sort_descending"))

	
	build(scoreList)
	
	_menuButton.connect("released", Callable(self, "goto_menu"))
	_menuButton.select()

const RANK_COLORS = [Color("ffd34d"), Color("dfe6e9"), Color("e17055")]

func build(scoreList):
	if scoreList.is_empty():
		build_empty_message()
		return

	var rank = 0
	for scoreLoop in scoreList:
		
		var newLine=_line.duplicate()
		newLine.get_child(0).text="#" + str(rank + 1) + "  " + scoreLoop.date;
		newLine.get_child(1).text=str(int(scoreLoop.score));
		newLine.visible=true

		if rank < RANK_COLORS.size():
			newLine.get_child(1).add_theme_color_override("font_color", RANK_COLORS[rank])
		
		_table.add_child(newLine)

		newLine.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.05 * rank)
		tween.tween_property(newLine, "modulate:a", 1.0, 0.2)

		rank += 1


func build_empty_message() -> void:
	var label := Label.new()
	label.text = "NO SCORE YET... GO PLAY!"
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 100)
	label.size = Vector2(320, 12)
	add_child(label)

	var blink := create_tween().set_loops()
	blink.tween_property(label, "modulate:a", 0.4, 0.7)
	blink.tween_property(label, "modulate:a", 1.0, 0.7)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_menuButton.emit_signal("released")


func goto_menu():
	if Transition.is_busy():
		return
	Sound.play("menu_select", 0.0)
	GlobalPlayer.reset_game()
	Transition.goto("res://src/UI/menu.tscn")
