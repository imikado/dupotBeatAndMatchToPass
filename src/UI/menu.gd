extends Node2D

const SELECTED_OFFSET_X = -6.0

@onready var _playButton:=get_node("Control/playButton")
@onready var _highScoresButton:=get_node("Control/hightScoresButton")
@onready var _settingsButton:=get_node("Control/settingsButton")

@onready var _title:=get_node("Title")
@onready var _version:=get_node("version")

var _selected=0
var _buttons_x := 0.0
var _is_leaving := false

var _music_label: Label

@onready var _buttonList=[
	_playButton,
	_highScoresButton,
	_settingsButton
]

func _ready() -> void:
	_playButton.connect("released", Callable(self, "goto_game"))

	_highScoresButton.connect("released", Callable(self, "goto_scores"))
	_settingsButton.connect("released", Callable(self, "goto_settings"))

	_buttons_x = _playButton.position.x

	refresh_buttons(false)

	Sound.play_music()

	_version.text="VERSION "+str(GlobalVersion.version)

	Fx.fireflies(self)
	build_best_score_label()
	build_music_label()
	animate_intro()


func build_label(text_: String, position_: Vector2, width: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text_
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = position_
	label.size = Vector2(width, 10)
	add_child(label)
	return label


func build_best_score_label() -> void:
	var best = Game.getHighestScore(Game.getHighScoreList())
	if best <= 0:
		return
	build_label("BEST  " + str(int(best)), Vector2(200, 136), 110, Color("ffd34d"))


func build_music_label() -> void:
	if Game.isControlsEnabled():
		return
	_music_label = build_label("", Vector2(236, 168), 84, Color(1, 1, 1, 0.6))
	_music_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	refresh_music_label()


func refresh_music_label() -> void:
	if _music_label:
		_music_label.text = "M: MUSIC " + ("ON" if Sound.is_music_enabled() else "OFF")


func animate_intro() -> void:
	var title_y: float = _title.position.y
	_title.modulate.a = 0.0
	_title.position.y = title_y - 10

	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(_title, "position:y", title_y, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(start_title_bob.bind(title_y))

	for i in range(_buttonList.size()):
		var button = _buttonList[i]
		var target_x = _buttons_x + (SELECTED_OFFSET_X if i == _selected else 0.0)
		button.position.x = 340
		var slide := create_tween()
		slide.tween_interval(0.1 + i * 0.08)
		slide.tween_property(button, "position:x", target_x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func start_title_bob(title_y: float) -> void:
	var bob := create_tween().set_loops()
	bob.tween_property(_title, "position:y", title_y - 2, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_title, "position:y", title_y, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func leave(path: String) -> void:
	if _is_leaving:
		return
	_is_leaving = true
	Sound.play("menu_select", 0.0)
	Transition.goto(path)


func goto_game():
	leave("res://src/Levels/LevelTemplate.tscn")

func goto_scores():
	leave("res://src/UI/scores.tscn")

func goto_settings():
	leave("res://src/UI/settings.tscn")

#control buttons
func _input(event: InputEvent) -> void:
	if _is_leaving:
		return
	if event is InputEventKey and event.keycode == KEY_M:
		refresh_music_label.call_deferred()
		return
	if event.is_action_pressed(PlayerAbstractState.INPUT_UP):
		previous_button()
	elif Game.isInputNextButton(event):
		next_button()
	elif Game.isInputValidateButton(event):
		Game.setControlsEnabled(false)
		get_selected_buton().emit_signal("released")

func get_selected_buton():
	return _buttonList[_selected]

func refresh_buttons(animate := true):
	for i in range(_buttonList.size()):
		_buttonList[i].deselect()
		if animate:
			var target_x = _buttons_x + (SELECTED_OFFSET_X if i == _selected else 0.0)
			create_tween().tween_property(_buttonList[i], "position:x", target_x, 0.1)

	get_selected_buton().select()

func next_button():
	_selected+=1
	if(_selected>=_buttonList.size()):
		_selected=0
	Sound.play("menu_move", 0.0)
	refresh_buttons()

func previous_button():
	_selected-=1
	if(_selected<0):
		_selected=_buttonList.size()-1
	Sound.play("menu_move", 0.0)
	refresh_buttons()
