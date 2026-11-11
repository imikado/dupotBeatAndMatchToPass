extends CanvasLayer

@onready var _player_life_progress_bar:PixelBar=get_node("Control/LifeProgressBar")
@onready var _player_mana_progress_bar:PixelBar=get_node("Control/ManaProgressBar")

@onready var _portrait:=get_node("Portrait")
@onready var _portrait_icon:=get_node("Portrait/Icon")
@onready var _bars:=get_node("Control")

@onready var _score=get_node("score")
@onready var _level=get_node("level")

@onready var _score_value:=0

const LIFE_COLOR_HIGH=Color("44a840")
const LIFE_COLOR_MID=Color("e0b43a")
const LIFE_COLOR_LOW=Color("d8432e")
const LIFE_COLOR_BLINK=Color("ffb0a0")

const MANA_COLOR_ENOUGH=Color("3b6dd9")
const MANA_COLOR_NOTENOUGH=Color("8a2f4a")
const MANA_SHIMMER_PERIOD=2.0
const MANA_SHIMMER_PERIOD_FULL=0.9

const SCORE_COLOR=Color.WHITE
const SCORE_COLOR_GAIN=Color("ffd34d")

const STREAK_Y=18
const BANNER_Y=24

const MID_LIFE_THRESHOLD=50.0
const LOW_LIFE_THRESHOLD=25.0

# Secousse au pixel près (décalages entiers dans la vue 320x180)
const SHAKE_OFFSETS=[Vector2(-2, 0), Vector2(2, 1), Vector2(-1, -1), Vector2(1, 0), Vector2.ZERO]
const SHAKE_STEP=0.04

var _life_target:=0.0

# Mode 2 joueurs : jauges de vie et de mana du joueur 2 en haut à droite (LEVEL xx passe dessous)
const P2_BAR_POSITION=Vector2(215, 3)
const P2_MANA_OFFSET=Vector2(0, 10)
const P2_HUD_SHIFT_Y=16
var _p2_life_bar:PixelBar
var _p2_mana_bar:PixelBar
var _p2_life_target:=0.0
var _mana_cells:=0
var _p2_mana_cells:=0

var _shake_tween:Tween
var _portrait_tween:Tween
var _score_tween:Tween
var _score_pop_tween:Tween
var _portrait_position:Vector2
var _bars_position:Vector2

var _streak_label:Label
var _banner:Label
var _banner_sub:Label
var _banner_tween:Tween

func _ready() -> void:
	add_to_group("hud")
	set_title("LEVEL "+("%02d" % GlobalPlayer.get_level()))

	_portrait_position=_portrait.position
	_bars_position=_bars.position

	# État de départ sans animation : le niveau appelle ensuite update_* avec les mêmes valeurs
	_life_target=GlobalPlayer.life
	_player_life_progress_bar.set_value(_life_target, false)
	refresh_life_color(_life_target)

	_mana_cells=mana_cells(GlobalPlayer.mana)
	_player_mana_progress_bar.max_value=GlobalPlayer.MAX_MANA
	_player_mana_progress_bar.segment=GlobalPlayer.attack_amount_mana
	_player_mana_progress_bar.set_value(GlobalPlayer.mana, false)
	refresh_mana_color(GlobalPlayer.mana)

	update_score_value(GlobalPlayer.get_score())

	_streak_label = build_label(5, HORIZONTAL_ALIGNMENT_RIGHT)
	# Sous « LEVEL xx » (glyphes de la police Pixeled jusqu'à y = 20 environ)
	_streak_label.position = Vector2(217, STREAK_Y)
	_streak_label.size = Vector2(100, 10)
	_streak_label.visible = false

	_banner = build_label(10, HORIZONTAL_ALIGNMENT_CENTER)
	# Bandeau dans le ciel, au-dessus des personnages et de leurs textes flottants
	_banner.position = Vector2(0, BANNER_Y)
	_banner.size = Vector2(320, 24)
	_banner.pivot_offset = _banner.size / 2
	_banner.visible = false

	_banner_sub = build_label(5, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_sub.position = Vector2(0, BANNER_Y + 22)
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
	if value == _score_value:
		return

	var is_gain:=value > _score_value

	if _score_tween:
		_score_tween.kill()
	_score_tween = create_tween()
	_score_tween.tween_method(Callable(self, "update_score_value"), _score_value, value, 0.5)

	if is_gain:
		pop_score()


func update_score_value(value:int):
	_score.text="%06d" % value
	_score_value=value


# Le score grossit d'un coup en jaune puis revient par paliers
func pop_score() -> void:
	if _score_pop_tween:
		_score_pop_tween.kill()
	_score.scale=Vector2(1.5, 1.5)
	_score.add_theme_color_override("font_color", SCORE_COLOR_GAIN)
	_score_pop_tween = create_tween()
	_score_pop_tween.tween_interval(0.06)
	_score_pop_tween.tween_property(_score, "scale", Vector2(1.25, 1.25), 0.0)
	_score_pop_tween.tween_interval(0.06)
	_score_pop_tween.tween_property(_score, "scale", Vector2.ONE, 0.0)
	_score_pop_tween.tween_interval(0.2)
	_score_pop_tween.tween_callback(func(): _score.add_theme_color_override("font_color", SCORE_COLOR))



func mana_cells(value:float) -> int:
	return int(floor(value / GlobalPlayer.attack_amount_mana))


# index : 0 joueur 1 (et solo), 1 joueur 2
func update_player_mana(value:float, index:=0)->void:
	var bar:=mana_bar(index)
	if bar == null:
		return
	bar.set_value(value)
	refresh_mana_color(value, bar)

	# Une case de plus = une attaque de foudre de plus disponible
	var cells:=mana_cells(value)
	var previous_cells:=_p2_mana_cells if index == 1 else _mana_cells
	if cells > previous_cells:
		bar.flash()
	if index == 1:
		_p2_mana_cells=cells
	else:
		_mana_cells=cells


func mana_bar(index:int) -> PixelBar:
	return _p2_mana_bar if index == 1 else _player_mana_progress_bar


func refresh_mana_color(value:float, bar:PixelBar = null) -> void:
	if bar == null:
		bar=_player_mana_progress_bar
	if value >= GlobalPlayer.attack_amount_mana:
		bar.set_fill_color(MANA_COLOR_ENOUGH)
		# Orage disponible : un reflet parcourt la jauge, plus souvent quand elle est pleine
		var period:=MANA_SHIMMER_PERIOD_FULL if value >= GlobalPlayer.MAX_MANA else MANA_SHIMMER_PERIOD
		bar.start_shimmer(period)
	else:
		bar.set_fill_color(MANA_COLOR_NOTENOUGH)
		bar.stop_shimmer()


func enable_second_player() -> void:
	if _p2_life_bar:
		return
	_p2_life_bar=_player_life_progress_bar.duplicate()
	add_child(_p2_life_bar)
	_p2_life_bar.position=P2_BAR_POSITION
	_p2_life_bar.size=_player_life_progress_bar.size
	_p2_life_target=GlobalPlayer.life2
	_p2_life_bar.set_value(_p2_life_target, false)
	refresh_life_color(_p2_life_target, _p2_life_bar)

	_p2_mana_bar=_player_mana_progress_bar.duplicate()
	add_child(_p2_mana_bar)
	_p2_mana_bar.position=P2_BAR_POSITION + P2_MANA_OFFSET
	_p2_mana_bar.size=_player_mana_progress_bar.size
	_p2_mana_bar.max_value=GlobalPlayer.MAX_MANA
	_p2_mana_bar.segment=GlobalPlayer.attack_amount_mana
	_p2_mana_cells=mana_cells(GlobalPlayer.mana2)
	_p2_mana_bar.set_value(GlobalPlayer.mana2, false)
	refresh_mana_color(GlobalPlayer.mana2, _p2_mana_bar)

	var tag:=build_label(5, HORIZONTAL_ALIGNMENT_RIGHT)
	tag.text="P2"
	tag.add_theme_color_override("font_color", Player.COOP_COLORS[1])
	tag.position=P2_BAR_POSITION + Vector2(-16, -2)
	tag.size=Vector2(14, 10)

	var p1_tag:=build_label(5, HORIZONTAL_ALIGNMENT_LEFT)
	p1_tag.text="P1"
	p1_tag.add_theme_color_override("font_color", Player.COOP_COLORS[0])
	p1_tag.position=Vector2(3, 22)
	p1_tag.size=Vector2(14, 10)

	_level.position.y+=P2_HUD_SHIFT_Y
	_streak_label.position.y+=P2_HUD_SHIFT_Y


func update_player_life(value:float, index:=0)->void:
	if index == 1:
		update_second_player_life(value)
		return
	var previous:=_life_target
	_life_target=clamp(value, 0.0, _player_life_progress_bar.max_value)
	if is_equal_approx(previous, _life_target):
		return

	_player_life_progress_bar.set_value(_life_target)
	refresh_life_color(_life_target)

	if _life_target < previous:
		_player_life_progress_bar.flash()
		shake_hud()
		flash_portrait(Color(1.0, 0.3, 0.3))
	else:
		flash_portrait(Color(0.5, 1.0, 0.5))


func update_second_player_life(value:float)->void:
	if _p2_life_bar == null:
		return
	var previous:=_p2_life_target
	_p2_life_target=clamp(value, 0.0, _p2_life_bar.max_value)
	if is_equal_approx(previous, _p2_life_target):
		return
	_p2_life_bar.set_value(_p2_life_target)
	refresh_life_color(_p2_life_target, _p2_life_bar)
	if _p2_life_target < previous:
		_p2_life_bar.flash()
		shake_hud()


func refresh_life_color(value:float, bar:PixelBar = null) -> void:
	if bar == null:
		bar=_player_life_progress_bar
	if value > MID_LIFE_THRESHOLD:
		bar.set_fill_color(LIFE_COLOR_HIGH)
	elif value > LOW_LIFE_THRESHOLD:
		bar.set_fill_color(LIFE_COLOR_MID)
	else:
		bar.set_fill_color(LIFE_COLOR_LOW)

	if value <= LOW_LIFE_THRESHOLD and value > 0:
		bar.start_blink(LIFE_COLOR_BLINK)
	else:
		bar.stop_blink()


func shake_hud() -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	for offset in SHAKE_OFFSETS:
		_shake_tween.tween_callback(func():
			_portrait.position = _portrait_position + offset
			_bars.position = _bars_position + offset
		)
		_shake_tween.tween_interval(SHAKE_STEP)


func flash_portrait(color:Color) -> void:
	if _portrait_tween:
		_portrait_tween.kill()
	_portrait_icon.modulate = color
	_portrait_tween = create_tween()
	_portrait_tween.tween_interval(0.1)
	_portrait_tween.tween_callback(func(): _portrait_icon.modulate = Color.WHITE)
	_portrait_tween.tween_interval(0.06)
	_portrait_tween.tween_callback(func(): _portrait_icon.modulate = color)
	_portrait_tween.tween_interval(0.1)
	_portrait_tween.tween_callback(func(): _portrait_icon.modulate = Color.WHITE)
