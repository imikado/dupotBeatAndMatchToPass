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
const BANNER_Y=46

const MID_LIFE_THRESHOLD=50.0
const LOW_LIFE_THRESHOLD=25.0

# Secousse au pixel près (décalages entiers dans la vue 320x180)
const SHAKE_OFFSETS=[Vector2(-2, 0), Vector2(2, 1), Vector2(-1, -1), Vector2(1, 0), Vector2.ZERO]
const SHAKE_STEP=0.04

var _life_target:=0.0

# Les deux blocs joueurs encadrent le score commun.
const P2_BAR_POSITION=Vector2(193, 3)
const P2_MANA_OFFSET=Vector2(0, 10)
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

const GEM_ROW_Y=21
const GEM_ICON_HALF=3.0
const GEM_ORIGINS=[25.0, 193.0]
var _gem_icons:=[null, null]
var _gem_labels:=[null, null]
var _gem_tweens:=[null, null]
var _gem_colors:=[Color.WHITE, Color.WHITE]

# Ligne de progression sous le bloc joueur : niveau d'attaque et de mana, et un cran
# par power-up ramassé (GlobalPlayer.POWER_UPS_PER_LEVEL crans pour le niveau suivant)
const PROGRESS_ROW_Y=38
const PROGRESS_BAR_WIDTH=36
const PROGRESS_PIP_GAP=2
const PROGRESS_PIP_HEIGHT=4
const PROGRESS_LABEL_OFFSET_Y=-4
const PROGRESS_ROW_HEIGHT=10
static var _progress_icons:={}
const PROGRESS_BG=Color("30253a")
# [{"attack": {"label", "pips", "level", "count"}, "mana": {...}}, ...] par joueur
var _progress_rows:=[null, null]

# Sélecteur d'arme sous la ligne de progression : visible dès qu'une 2e arme est achetée,
# clic / toucher sur une icône pour la choisir (ou l'action « weapon »)
const WEAPON_ROW_Y=48
const WEAPON_SLOT=15
const WEAPON_SELECTED=Color("ffd34d")
var _weapon_rows:=[null, null]


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

	build_player_panel(0)
	build_gem_counter(0)
	build_progress_row(0)
	build_weapon_row(0)
	Events.player_weapon_changed.connect(refresh_weapons)
	_score.position=Vector2(129, 1)
	_score.size=Vector2(62, 14)
	_score.pivot_offset=Vector2(31, 7)
	_score.add_theme_font_size_override("font_size", 7)

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
	_banner_sub.position = Vector2(0, BANNER_Y + 19)
	_banner_sub.size = Vector2(320, 12)
	_banner_sub.visible = false


func build_panel(rect:Rect2, color:Color, accent:Color) -> Panel:
	var panel:=Panel.new()
	panel.position=rect.position
	panel.size=rect.size
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.z_index=-1
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=accent
	style.border_width_bottom=1
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	move_child(panel, 0)
	return panel


func build_player_panel(index:int) -> void:
	var color:Color=Player.COOP_COLORS[index]
	var left:=1.0 if index == 0 else 191.0
	build_panel(Rect2(left, 1, 128, 36), Color("140f20d9"), color.darkened(0.45)).z_index=-2
	var tag:=build_label(5, HORIZONTAL_ALIGNMENT_CENTER)
	tag.name="PlayerTag%d" % index
	tag.text="P%d" % (index + 1)
	tag.add_theme_color_override("font_color", color)
	tag.position=Vector2(3 if index == 0 else 299, GEM_ROW_Y)
	tag.size=Vector2(18, 12)


func build_gem_counter(index:int) -> void:
	if _gem_labels[index] != null:
		return
	var left:float=GEM_ORIGINS[index]
	build_panel(Rect2(left, 22, 102, 13), Color("30253ae6"), Fx.GEM_COLOR.darkened(0.65))
	_gem_icons[index]=Fx.gem_icon(self, Vector2(left + 6, 29), GEM_ICON_HALF)
	var caption:=build_label(5, HORIZONTAL_ALIGNMENT_LEFT)
	caption.text="GEMS"
	caption.position=Vector2(left + 14, GEM_ROW_Y)
	caption.size=Vector2(26, 12)
	caption.add_theme_color_override("font_color", Fx.GEM_COLOR.lightened(0.25))
	var label:=build_label(5, HORIZONTAL_ALIGNMENT_RIGHT)
	label.name="Gems%d" % index
	label.position=Vector2(left + 40, GEM_ROW_Y)
	label.size=Vector2(58, 12)
	label.text=str(GlobalPlayer.get_gems(index))
	_gem_labels[index]=label


func build_progress_row(index:int) -> void:
	if _progress_rows[index] != null:
		return
	var left:=1.0 if index == 0 else 191.0
	build_panel(Rect2(left, PROGRESS_ROW_Y, 128, PROGRESS_ROW_HEIGHT), Color("140f20d9"), Player.COOP_COLORS[index].darkened(0.45)).z_index=-2
	var row:={}
	var x:=left + 3
	for kind in [GlobalPlayer.PROGRESS_ATTACK, GlobalPlayer.PROGRESS_MANA]:
		var color:Color=PowerUp.COLORS[kind]
		var icon:=TextureRect.new()
		icon.texture=progress_icon(kind)
		icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position=Vector2(x, PROGRESS_ROW_Y)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		var label:=build_label(5, HORIZONTAL_ALIGNMENT_LEFT)
		# Les chiffres Pixeled sont dessinés ~6 px sous le haut du Label : sans ce décalage,
		# ils débordent sur le liseré bas du panneau (y = PROGRESS_ROW_Y + PROGRESS_ROW_HEIGHT - 1)
		label.position=Vector2(x + 10, PROGRESS_ROW_Y + PROGRESS_LABEL_OFFSET_Y)
		label.size=Vector2(10, 12)
		label.add_theme_color_override("font_color", color)
		x+=21
		var pips:=[]
		var count:=GlobalPlayer.POWER_UPS_PER_LEVEL
		var pip_width:=floorf((PROGRESS_BAR_WIDTH - PROGRESS_PIP_GAP * (count - 1)) / float(count))
		for i in range(count):
			var pip:=ColorRect.new()
			pip.color=PROGRESS_BG
			pip.position=Vector2(x + (pip_width + PROGRESS_PIP_GAP) * i, PROGRESS_ROW_Y + 3)
			pip.size=Vector2(pip_width, PROGRESS_PIP_HEIGHT)
			pip.pivot_offset=pip.size / 2
			pip.mouse_filter=Control.MOUSE_FILTER_IGNORE
			add_child(pip)
			pips.append(pip)
		x+=PROGRESS_BAR_WIDTH + 4
		row[kind]={"label": label, "pips": pips, "level": GlobalPlayer.progress_level(kind, index), "count": filled_pips(kind, index)}
	_progress_rows[index]=row
	update_progress(index, false)


# Icône 9x9 détourée de noir : épée (attaque) ou éclair (mana)
static func progress_icon(kind:String) -> ImageTexture:
	if _progress_icons.has(kind):
		return _progress_icons[kind]
	var glyph:Array
	# lame claire, garde et poignée de la couleur du niveau
	var blade:Array=[]
	if kind == GlobalPlayer.PROGRESS_MANA:
		glyph=[Vector2i(4, 0), Vector2i(3, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
			Vector2i(4, 4), Vector2i(3, 5), Vector2i(2, 6)]
	else:
		blade=[Vector2i(6, 0), Vector2i(5, 1), Vector2i(4, 2), Vector2i(3, 3)]
		glyph=blade + [Vector2i(1, 3), Vector2i(2, 4), Vector2i(3, 5), Vector2i(1, 5), Vector2i(0, 6)]
	var image:=Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for point in glyph:
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			image.set_pixelv(point + Vector2i.ONE + offset, Color.BLACK)
	var color:Color=PowerUp.COLORS[kind]
	for point in glyph:
		image.set_pixelv(point + Vector2i.ONE, Color("e8eef5") if blade.has(point) else color.lightened(0.2))
	_progress_icons[kind]=ImageTexture.create_from_image(image)
	return _progress_icons[kind]


func build_weapon_row(index:int) -> void:
	if _weapon_rows[index] != null:
		return
	var row:=Control.new()
	row.name="Weapons%d" % index
	row.position=Vector2(1.0 if index == 0 else 191.0, WEAPON_ROW_Y)
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_weapon_rows[index]=row
	refresh_weapons(index)


func refresh_weapons(index:=0) -> void:
	var row:Control=_weapon_rows[index]
	if row == null:
		return
	for child in row.get_children():
		child.queue_free()
	var owned:Array=GlobalPlayer.WEAPONS.filter(func(weapon): return GlobalPlayer.has_weapon(weapon, index))
	row.visible=owned.size() > 1
	if not row.visible:
		return
	var width:=WEAPON_SLOT * owned.size() + 2
	var background:=Panel.new()
	background.size=Vector2(width, WEAPON_SLOT + 2)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("140f20d9")
	style.border_color=Player.COOP_COLORS[index].darkened(0.45)
	style.border_width_bottom=1
	background.add_theme_stylebox_override("panel", style)
	row.add_child(background)
	for i in range(owned.size()):
		var weapon:String=owned[i]
		var selected:=GlobalPlayer.get_weapon(index) == weapon
		var slot:=ColorRect.new()
		slot.position=Vector2(1 + WEAPON_SLOT * i, 1)
		slot.size=Vector2(WEAPON_SLOT, WEAPON_SLOT)
		slot.color=WEAPON_SELECTED if selected else Color(0, 0, 0, 0)
		slot.mouse_filter=Control.MOUSE_FILTER_STOP
		slot.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		slot.gui_input.connect(_on_weapon_slot_input.bind(index, weapon))
		row.add_child(slot)
		var inner:=ColorRect.new()
		inner.position=Vector2(1, 1)
		inner.size=Vector2(WEAPON_SLOT - 2, WEAPON_SLOT - 2)
		inner.color=Color("30253a") if selected else Color(0, 0, 0, 0)
		inner.mouse_filter=Control.MOUSE_FILTER_IGNORE
		slot.add_child(inner)
		var icon:=TextureRect.new()
		icon.texture=WeaponIcons.texture(weapon)
		icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position=Vector2(1, 1)
		icon.modulate=Color.WHITE if selected else Color(1, 1, 1, 0.45)
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
	var hint:=Label.new()
	hint.text=PlayerInput.action_label(index if GlobalPlayer.two_players else PlayerInput.SOLO, "weapon")
	hint.add_theme_font_override("font", Fx.FONT)
	hint.add_theme_font_size_override("font_size", 5)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 3)
	hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_child(hint)
	hint.position=Vector2(width + 3, 1)
	hint.size=Vector2(40, WEAPON_SLOT)


func _on_weapon_slot_input(event:InputEvent, index:int, weapon:String) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		Events.weapon_select_requested.emit(index, weapon)
		get_viewport().set_input_as_handled()


func progress_text(_kind:String, level:int) -> String:
	return str(level)


# crans allumés : power-ups ramassés vers le niveau suivant (tous au niveau max)
func filled_pips(kind:String, index:=0) -> int:
	if GlobalPlayer.is_progress_maxed(kind, index):
		return GlobalPlayer.POWER_UPS_PER_LEVEL
	return GlobalPlayer.progress_xp(kind, index)


func paint_pips(pips:Array, count:int, color:Color) -> void:
	for i in range(pips.size()):
		pips[i].color=color if i < count else PROGRESS_BG


# Niveaux et crans ; un cran gagné s'allume en blanc, un niveau gagné allume tous les crans
# puis les vide et fait clignoter l'étiquette
func update_progress(index:=0, animate:=true) -> void:
	var row=_progress_rows[index]
	if row == null:
		return
	for kind in row:
		var entry:Dictionary=row[kind]
		var level:=GlobalPlayer.progress_level(kind, index)
		var count:=filled_pips(kind, index)
		var color:Color=PowerUp.COLORS[kind]
		var label:Label=entry["label"]
		var pips:Array=entry["pips"]
		label.text=progress_text(kind, level)
		if not animate:
			paint_pips(pips, count, color)
		elif level > entry["level"]:
			paint_pips(pips, pips.size(), Color.WHITE)
			var flash:=create_tween()
			flash.tween_interval(0.25)
			flash.tween_callback(paint_pips.bind(pips, count, color))
			label.pivot_offset=Vector2(0, label.size.y / 2)
			label.scale=Vector2(1.3, 1.3)
			label.add_theme_color_override("font_color", Color.WHITE)
			var pop:=create_tween()
			pop.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			pop.tween_interval(0.2)
			pop.tween_callback(func(): label.add_theme_color_override("font_color", PowerUp.COLORS[kind]))
		else:
			paint_pips(pips, count, color)
			for i in range(entry["count"], count):
				var pip:ColorRect=pips[i]
				pip.color=Color.WHITE
				pip.scale=Vector2(1.4, 1.6)
				var tween:=create_tween()
				tween.tween_property(pip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(pip, "color", color, 0.25)
		entry["level"]=level
		entry["count"]=count


func update_gems(value:int, index:=0) -> void:
	var label:Label=_gem_labels[index]
	if label == null or label.text == str(value):
		return
	var is_gain:=value > int(label.text)
	label.text=str(value)
	if not is_gain:
		return
	if _gem_tweens[index]:
		_gem_tweens[index].kill()
	label.pivot_offset=Vector2(label.size.x, label.size.y / 2)
	label.scale=Vector2(1.12, 1.12)
	label.add_theme_color_override("font_color", Fx.GEM_COLOR)
	var tween:=create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.15)
	tween.tween_callback(func(): label.add_theme_color_override("font_color", _gem_colors[index]))
	_gem_tweens[index]=tween


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
	_score.scale=Vector2(1.12, 1.12)
	_score.add_theme_color_override("font_color", SCORE_COLOR_GAIN)
	_score_pop_tween = create_tween()
	_score_pop_tween.tween_interval(0.06)
	_score_pop_tween.tween_property(_score, "scale", Vector2(1.06, 1.06), 0.0)
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

	var portrait:Control=_portrait.duplicate()
	portrait.name="PortraitP2"
	add_child(portrait)
	portrait.position=Vector2(298, 2)
	portrait.get_node("Background").color=Player.COOP_COLORS[1].darkened(0.75)
	portrait.get_node("Highlight").color=Player.COOP_COLORS[1]
	portrait.get_node("Icon").modulate=Player.COOP_COLORS[1]
	_portrait.get_node("Highlight").color=Player.COOP_COLORS[0]

	build_player_panel(1)
	build_gem_counter(1)
	build_progress_row(1)
	build_weapon_row(1)
	for index in [0, 1]:
		_gem_colors[index]=Player.COOP_COLORS[index]
		_gem_labels[index].add_theme_color_override("font_color", _gem_colors[index])

	_level.position=Vector2(130, 18)
	_level.size=Vector2(60, 12)
	_level.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_level.add_theme_font_size_override("font_size", 5)
	_streak_label.position=Vector2(110, 35)
	_streak_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER


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
