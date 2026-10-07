extends CanvasLayer

@onready var _player_life_progress_bar=get_node("Control/LifeProgressBar" )

@onready var _player_mana_progress_bar=get_node("Control/ManaProgressBar")
@onready var _player_mana_progress_bar_color=get_node("Control/ManaProgressBar").get_theme_stylebox("fill")


@onready var _score=get_node("score")
@onready var _level=get_node("level")

@onready var _score_value:=0

const MANA_COLOR_ENOUGH=Color("0516a0")
const MANA_COLOR_NOTENOUGH=Color("900000")

const LOW_LIFE_THRESHOLD=25.0

var _low_life_tween:Tween

var _streak_label:Label
var _banner:Label
var _banner_sub:Label
var _banner_tween:Tween

func _ready() -> void:
	add_to_group("hud")
	set_title("LEVEL "+("%02d" % GlobalPlayer.get_level()))

	_streak_label = build_label(5, HORIZONTAL_ALIGNMENT_RIGHT)
	_streak_label.position = Vector2(217, 13)
	_streak_label.size = Vector2(100, 10)
	_streak_label.visible = false

	_banner = build_label(10, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.position = Vector2(0, 60)
	_banner.size = Vector2(320, 24)
	_banner.pivot_offset = _banner.size / 2
	_banner.visible = false

	_banner_sub = build_label(5, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_sub.position = Vector2(0, 86)
	_banner_sub.size = Vector2(320, 12)
	_banner_sub.visible = false


func build_label(font_size:int, alignment) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func show_banner(text:String, sub_text:String = "", color:Color = Color.WHITE, duration:float = 1.4) -> void:
	if _banner_tween:
		_banner_tween.kill()

	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = sub_text
	_banner.visible = true
	_banner_sub.visible = sub_text != ""
	_banner.modulate.a = 1.0
	_banner_sub.modulate.a = 1.0
	_banner.scale = Vector2(2.0, 2.0)

	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)
	_banner_tween.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.3)
	_banner_tween.tween_callback(func():
		_banner.visible = false
		_banner_sub.visible = false
	)


func hide_banner() -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner.visible = false
	_banner_sub.visible = false


func update_streak(streak:int, multiplier:int) -> void:
	if streak < 2:
		_streak_label.visible = false
		return

	var previous_text := _streak_label.text
	_streak_label.visible = true
	if multiplier > 1:
		_streak_label.text = str(streak) + " KILLS  x" + str(multiplier)
	else:
		_streak_label.text = str(streak) + " KILLS"

	var colors := [Color.WHITE, Color("ffd34d"), Color("ff9f43"), Color("ff4d4d")]
	_streak_label.add_theme_color_override("font_color", colors[clamp(multiplier - 1, 0, colors.size() - 1)])

	if previous_text.ends_with("x" + str(multiplier)) == false and multiplier > 1:
		_streak_label.pivot_offset = Vector2(_streak_label.size.x, _streak_label.size.y / 2)
		_streak_label.scale = Vector2(1.6, 1.6)
		create_tween().tween_property(_streak_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_bonus_level():
	set_title("BONUS LEVEL")
	
func set_title(text_):
	var debug:=""
	if Game.DEBUG_ENABLED:
		debug=" (debug)"
	_level.text=text_+debug

func update_score(value:int):
	
	var start_score=_score_value
	var end_score:=value
	
	var tween := create_tween()
	tween.tween_method(Callable(self, "update_score_value"), start_score, end_score, 1)
	

func update_score_value(value:int):
	_score.text=str(value)
	_score_value=value
	
	

func update_player_mana(value:float)->void:
	var end_clamped_value = float(clamp(value, _player_mana_progress_bar.min_value, _player_mana_progress_bar.max_value))

	var start_value=_player_mana_progress_bar.value

	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.tween_method(Callable(self, "_update_player_mana_bar"), start_value, end_clamped_value, 0.5)
	
	
func _update_player_mana_bar(value:float)->void:
	_player_mana_progress_bar.value=value
	
	if value >= GlobalPlayer.attack_amount_mana:
		set_mana_progress_bar_enough()
	else:
		set_mana_progress_bar_notenough()


func set_mana_progress_bar_enough():
	_player_mana_progress_bar_color.set_bg_color(MANA_COLOR_ENOUGH)


func set_mana_progress_bar_notenough():
	_player_mana_progress_bar_color.set_bg_color(MANA_COLOR_NOTENOUGH)


func update_player_life(value:float)->void:

	var end_clamped_value = float(clamp(value, _player_life_progress_bar.min_value, _player_life_progress_bar.max_value))

	var start_value=_player_life_progress_bar.value

	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_method(Callable(self, "_update_player_health_bar"), start_value, end_clamped_value, 0.3)
	
	
	
func _update_player_health_bar(health_target: float) -> void:
	_player_life_progress_bar.value = health_target

	if health_target <= LOW_LIFE_THRESHOLD and health_target > 0:
		start_low_life_warning()
	else:
		stop_low_life_warning()


func start_low_life_warning() -> void:
	if _low_life_tween and _low_life_tween.is_valid():
		return
	_low_life_tween = create_tween().set_loops()
	_low_life_tween.tween_property(_player_life_progress_bar, "modulate", Color(1.6, 0.6, 0.6), 0.3)
	_low_life_tween.tween_property(_player_life_progress_bar, "modulate", Color.WHITE, 0.3)


func stop_low_life_warning() -> void:
	if _low_life_tween:
		_low_life_tween.kill()
		_low_life_tween = null
	_player_life_progress_bar.modulate = Color.WHITE



