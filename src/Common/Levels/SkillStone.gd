class_name SkillStone
extends StaticBody2D

# Pierre de lumière du niveau boutique : chaque coup du joueur verse des gems dans la
# compétence gravée dessus. Dessous, une jauge pixel art par joueur montre la
# progression vers le niveau suivant, le niveau atteint et le bonus.

signal invested(player, result)

const SKILL_TITLES := {
	GlobalPlayer.SKILL_SPEED: "SPEED",
	GlobalPlayer.SKILL_ATTACK: "ATTACK",
	GlobalPlayer.SKILL_RESISTANCE: "RESIST",
}
const SKILL_COLORS := {
	GlobalPlayer.SKILL_SPEED: Color("7fdbff"),
	GlobalPlayer.SKILL_ATTACK: Color("ff6b5a"),
	GlobalPlayer.SKILL_RESISTANCE: Color("c39bff"),
}
# Runes 7x7 gravées sur la face de la pierre
const RUNES := {
	GlobalPlayer.SKILL_SPEED: [
		"..X..X.",
		"...X..X",
		"....X.X",
		"...X..X",
		"..X..X.",
		".......",
		"XXXXXXX",
	],
	GlobalPlayer.SKILL_ATTACK: [
		"......X",
		".....X.",
		"....X..",
		"X..X...",
		".XX....",
		".XX....",
		"X..X...",
	],
	GlobalPlayer.SKILL_RESISTANCE: [
		"XXXXXXX",
		"X..X..X",
		"X..X..X",
		"XXXXXXX",
		".X.X.X.",
		"..XXX..",
		"...X...",
	],
}

const OUTLINE_COLOR := Color("140c1c")
const STONE_COLOR := Color("4a4e69")
const STONE_LIGHT := Color("6b7094")
const STONE_DARK := Color("2b2d42")
const COLOR_MAXED := Color("7bed9f")
const COLOR_MUTED := Color(1, 1, 1, 0.55)
const COLOR_ERROR := Color("ff6b5a")

const GAUGE_WIDTH := 40.0
const GAUGE_HEIGHT := 5.0
const GAUGE_Y := 6.0
const GAUGE_SPACING := 16.0

var skill := GlobalPlayer.SKILL_SPEED
var _color: Color
var _glow := 0.0
var _hit := 0.0
var _crystal: Node2D
var _halo: Sprite2D
var _light: PointLight2D
var _title: Label
var _gauges := []


func setup(skill_: String) -> SkillStone:
	skill = skill_
	return self


func _ready() -> void:
	_color = SKILL_COLORS[skill]
	collision_layer = 2
	collision_mask = 0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 10)
	shape.shape = rect
	shape.position = Vector2(0, -5)
	add_child(shape)

	Fx.shadow(self, 26)

	_light = Fx.light(self, _color, 0.8)
	_light.position = Vector2(0, -20)
	_light.enabled = true
	_light.energy = 0.7

	_halo = Sprite2D.new()
	_halo.texture = Fx.radial_texture()
	_halo.material = Fx.additive_material()
	_halo.modulate = Color(_color, 0.35)
	_halo.scale = Vector2(0.55, 0.55)
	_halo.position = Vector2(0, -22)
	add_child(_halo)

	_crystal = Node2D.new()
	_crystal.draw.connect(_draw_crystal)
	add_child(_crystal)

	_title = build_label(self, SKILL_TITLES[skill], Vector2(-30, -54), Vector2(60, 14))
	_title.add_theme_color_override("font_color", _color.lerp(Color.WHITE, 0.35))

	var count := 2 if GlobalPlayer.two_players else 1
	for i in range(count):
		_gauges.append(build_gauge(i, Vector2(0, GAUGE_Y + GAUGE_SPACING * i)))
	refresh(false)

	var tween := create_tween().set_loops()
	tween.tween_method(_set_glow, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_method(_set_glow, 1.0, 0.0, 1.2).set_trans(Tween.TRANS_SINE)


func build_gauge(index: int, origin: Vector2) -> Dictionary:
	var panel := Control.new()
	panel.position = origin + Vector2(-GAUGE_WIDTH / 2, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var gauge := PixelBar.new()
	gauge.size = Vector2(GAUGE_WIDTH, GAUGE_HEIGHT)
	gauge.segment = GlobalPlayer.GEMS_PER_INVEST
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(gauge)
	gauge.set_fill_color(_color)

	if GlobalPlayer.two_players:
		var tag := ColorRect.new()
		tag.color = Player.COOP_COLORS[index]
		tag.size = Vector2(2, GAUGE_HEIGHT)
		tag.position = Vector2(-4, 0)
		panel.add_child(tag)

	var info := build_label(panel, "", Vector2(-10, 3), Vector2(GAUGE_WIDTH + 20, 12))
	return {"index": index, "gauge": gauge, "info": info}


func build_label(parent: Node, text_: String, position_: Vector2, size_: Vector2) -> Label:
	var label := Label.new()
	label.text = text_
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# add_child avant la taille : hors de l'arbre le Label garde la taille de la police par défaut
	parent.add_child(label)
	label.position = position_
	label.size = size_
	return label


func refresh(animate := true) -> void:
	for row in _gauges:
		var index: int = row.index
		var gauge: PixelBar = row.gauge
		var level := GlobalPlayer.skill_level(skill, index)
		var bonus := roundi(level * GlobalPlayer.SKILL_BONUS_PER_LEVEL * 100)
		if GlobalPlayer.is_skill_maxed(skill, index):
			gauge.max_value = 1.0
			gauge.set_value(1.0, animate)
			row.info.text = "MAX +%d%%" % bonus
			row.info.add_theme_color_override("font_color", COLOR_MAXED)
		else:
			var cost := GlobalPlayer.skill_cost(skill, index)
			var progress := GlobalPlayer.skill_progress(skill, index)
			gauge.max_value = cost
			gauge.set_value(progress, animate)
			row.info.text = "LV%d %d/%d" % [level, progress, cost]
			row.info.add_theme_color_override("font_color", Color.WHITE if level > 0 or progress > 0 else COLOR_MUTED)


func gauge_tip(index: int) -> Vector2:
	for row in _gauges:
		if row.index == index:
			var gauge: PixelBar = row.gauge
			var ratio := clampf(gauge.value / maxf(gauge.max_value, 1.0), 0.0, 1.0)
			return gauge.global_position + Vector2(GAUGE_WIDTH * ratio, GAUGE_HEIGHT / 2)
	return global_position


# Appelé par la HitBox du joueur
func on_player_hit(player: Player) -> void:
	var index := player.player_index
	var target := gauge_tip(index)
	var result := GlobalPlayer.invest_skill(skill, index)
	_hit = 1.0
	create_tween().tween_property(self, "_hit", 0.0, 0.25)
	Fx.squash(_crystal, Vector2(1.15, 0.9))

	if result == 0:
		Sound.play("menu_move", 0.0, -4.0, 0.6)
		var text := "MAX LEVEL" if GlobalPlayer.is_skill_maxed(skill, index) else "NO GEMS"
		Fx.floating_text(get_parent(), text, global_position + Vector2(0, -40), COLOR_ERROR)
		shake()
		invested.emit(player, result)
		return

	Fx.hit_spark(get_parent(), global_position + Vector2(signf(player.global_position.x - global_position.x) * 8, -16))
	fly_gem(player.global_position + Vector2(0, -20), target)
	if result == 2:
		refresh(false)
		for row in _gauges:
			if row.index == index:
				row.gauge.flash()
		Sound.play("mana_ready", 0.0)
		Fx.burst(get_parent(), global_position + Vector2(0, -20), _color, 18)
		Fx.ring(get_parent(), global_position, _color, 28.0, 0.4)
		Fx.floating_text(get_parent(), "%s LV %d!" % [SKILL_TITLES[skill], GlobalPlayer.skill_level(skill, index)], global_position + Vector2(0, -44), _color.lerp(Color.WHITE, 0.4))
		player.shake_camera(2.0, 0.12)
	else:
		refresh()
		Sound.play("energy", 0.0, 0.0, 0.9 + 0.3 * float(GlobalPlayer.skill_progress(skill, index)) / GlobalPlayer.skill_cost(skill, index))
	invested.emit(player, result)


func fly_gem(from: Vector2, to: Vector2) -> void:
	var gem := Fx.gem_icon(get_parent(), from, 2.5)
	gem.z_index = 100
	var tween := gem.create_tween()
	tween.tween_property(gem, "global_position", to, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(gem.queue_free)


func shake() -> void:
	var tween := create_tween()
	for offset in [-2, 2, -1, 1, 0]:
		tween.tween_property(_crystal, "position:x", offset, 0.03)


func _set_glow(value: float) -> void:
	_glow = value
	_light.energy = 0.8 + 0.5 * value + _hit
	_halo.modulate.a = 0.25 + 0.2 * value + 0.4 * _hit
	_crystal.queue_redraw()


func _draw_crystal() -> void:
	var dark := _color.darkened(0.55)
	var mid := _color.darkened(0.2)
	var light := _color.lightened(0.45)

	# socle de pierre
	_crystal.draw_rect(Rect2(-12, -6, 24, 6), OUTLINE_COLOR)
	_crystal.draw_rect(Rect2(-11, -5, 22, 4), STONE_DARK)
	_crystal.draw_rect(Rect2(-11, -5, 22, 1), STONE_COLOR)
	_crystal.draw_rect(Rect2(-9, -8, 18, 3), OUTLINE_COLOR)
	_crystal.draw_rect(Rect2(-8, -7, 16, 1), STONE_LIGHT)

	# cristal : contour, face sombre à droite, face claire à gauche, arête centrale
	var top := -38.0 - 2.0 * _glow
	_crystal.draw_colored_polygon(PackedVector2Array([Vector2(-10, -7), Vector2(-10, -26), Vector2(0, top - 1), Vector2(10, -26), Vector2(10, -7)]), OUTLINE_COLOR)
	_crystal.draw_colored_polygon(PackedVector2Array([Vector2(-9, -7), Vector2(-9, -26), Vector2(0, top), Vector2(0, -7)]), mid)
	_crystal.draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(0, top), Vector2(9, -26), Vector2(9, -7)]), dark)
	_crystal.draw_colored_polygon(PackedVector2Array([Vector2(-9, -26), Vector2(0, top), Vector2(-5, -27)]), light)
	_crystal.draw_rect(Rect2(-8, -25, 1, 16), Color(light, 0.8))

	# reflet qui pulse (HDR > 1 pour le glow de l'environnement)
	var intensity := 1.0 + 0.8 * _glow + 1.5 * _hit
	var bright := Color(light.r * intensity, light.g * intensity, light.b * intensity)
	_crystal.draw_rect(Rect2(-6, -30, 1, 2), bright)
	_crystal.draw_rect(Rect2(6, -12, 1, 2), Color(bright, 0.6))

	# rune gravée au centre
	_crystal.draw_rect(Rect2(-5, -24, 11, 11), Color(OUTLINE_COLOR, 0.55))
	var rune_color := Color(intensity, intensity, intensity)
	var rune: Array = RUNES[skill]
	for y in range(rune.size()):
		var line: String = rune[y]
		for x in range(line.length()):
			if line[x] == "X":
				_crystal.draw_rect(Rect2(-3 + x, -22 + y, 1, 1), rune_color)
