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

	show_gems()

	_menuButton.connect("released", Callable(self, "goto_nextLevel"))
	_menuButton.select()

# Sous le panneau : gems de chaque joueur et bonus de vie restante
func show_gems() -> void:
	var indices := [0, 1] if GlobalPlayer.two_players else [0]
	var width := 150.0
	var start_x := 160.0 - width * indices.size() / 2.0
	for i in range(indices.size()):
		var index: int = indices[i]
		var text := ("P%d " % (index + 1)) if GlobalPlayer.two_players else ""
		text += "%d  (+%d LIFE BONUS)" % [GlobalPlayer.get_gems(index), GlobalPlayer.last_life_bonus[index]]
		var label := Label.new()
		label.text = text
		label.add_theme_font_override("font", Fx.FONT)
		label.add_theme_font_size_override("font_size", 5)
		label.add_theme_color_override("font_color", Player.COOP_COLORS[index] if GlobalPlayer.two_players else Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.position = Vector2(start_x + width * i + 12, 155)
		label.size = Vector2(width - 12, 12)
		add_child(label)
		Fx.gem_icon(self, Vector2(start_x + width * i + 6, 161), 3.0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_menuButton.emit_signal("released")


func goto_nextLevel():
	if Transition.is_busy():
		return
	Sound.play("menu_select", 0.0)
	GlobalPlayer.set_level(GlobalPlayer.get_level()+1)
	Transition.goto("res://src/Levels/LevelBonus.tscn")
	
