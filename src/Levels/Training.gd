extends Node2D

const ButtonStyle = preload("res://src/Common/UI/MenuButtonStyle.gd")

const WALK_RECT := Rect2(12, 82, 296, 88)
const DUMMY_POSITION := Vector2(210, 124)
const GROUND_Y := 70
# ForestBackground est calé sur le sol des niveaux (bord à y = 107) : on le remonte à GROUND_Y
const FOREST_SHIFT_Y := GROUND_Y - 107
# lune déplacée sous le bouton MENU, hors du titre
const MOON_POSITION := Vector2(284, 40)

# Palette commune au menu, au menu pause et au HUD
const COLOR_GOLD := Color("ffd34d")
const COLOR_TEXT := Color("fff0bf")
const COLOR_MUTED := Color("c9ccff")
const COLOR_OUTLINE := Color("140c1c")
const COLOR_BORDER := Color("5c61d5")
const COLOR_PANEL := Color(0.04, 0.06, 0.13, 0.85)
const COLOR_TARGET := Color("ffbd69")
const COLOR_DOWN := Color("ff4d4d")
const COLOR_QUICK := Color("7fdbff")
const COLOR_HEAVY := Color("ff9f43")

const BUTTON_HEIGHT := ButtonStyle.HEIGHT
const TOP_BUTTON_WIDTH := 64
const TARGET_ROW_Y := 30
const TARGET_BAR_X := 114
const TARGET_BAR_WIDTH := 80
const COMBOS_WIDTH := 190
const COMBOS_ROW_Y := 28
const COMBOS_ROW_STEP := 9

var players: Array[Player] = []
var dummy: TrainingDummy
var combos_panel: Control
var _life_label: Label
var _life_bar: PixelBar
var _ko_label: Label
var _leaving := false
var _feedback_labels: Array[Label] = []


func _ready() -> void:
	PlayerInput.apply()
	build_arena()
	var camera := Camera2D.new()
	camera.position = Vector2(160, 90)
	add_child(camera)
	var actors := Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	for i in range(2 if GlobalPlayer.two_players else 1):
		var player: Player = load("res://src/Actors/Players/Player%s.tscn" % ("2" if i == 1 else "")).instantiate()
		player.get_node("Camera2D").enabled = false
		player.position = Vector2(245, 140) if i == 1 else Vector2(160, 124)
		actors.add_child(player)
		if GlobalPlayer.two_players:
			player.setup_coop(i, camera)
		if i == 1:
			player.get_node("BodyPivot").scale.x = -1
		players.append(player)
	camera.make_current()
	dummy = load("res://src/Actors/TrainingDummy.tscn").instantiate()
	dummy.position = DUMMY_POSITION
	actors.add_child(dummy)
	build_interface()
	dummy.training_life_changed.connect(update_target_life)
	dummy.respawned.connect(update_ko_count)
	update_target_life(dummy.get_life())
	Events.actor_took_damage.connect(_on_actor_took_damage)
	Events.actor_took_damage_by_bullet.connect(_on_actor_took_damage_by_bullet)
	if not GlobalPlayer.two_players:
		add_child(load("res://src/Common/UI/Controls.tscn").instantiate())


func build_arena() -> void:
	var ground := TextureRect.new()
	ground.texture = load("res://src/Levels/LevelTemplate/ground.png")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.position = Vector2(0, GROUND_Y)
	ground.size = Vector2(320, 180 - GROUND_Y)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	# Même décor que les niveaux (ciel, lune, arbres, ombre du sol), remonté au bord du sol
	var forest: Node2D = load("res://src/Levels/ForestBackground.tscn").instantiate()
	forest.position.y = FOREST_SHIFT_Y
	add_child(forest)
	forest.get_node("ParallaxBackground").offset.y = FOREST_SHIFT_Y
	forest.get_node("ParallaxBackground/Moon/moon").position = MOON_POSITION - Vector2(0, FOREST_SHIFT_Y)
	# buissons de premier plan : ils masqueraient le bas de l'arène et le HUD
	forest.get_node("ParallaxBackground2").visible = false
	for rect in [Rect2(-8, 62, 20, 128), Rect2(308, 62, 20, 128), Rect2(0, 62, 320, 20), Rect2(0, 170, 320, 20)]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.get_center()
		wall.add_child(shape)
		add_child(wall)


# `at.y` = haut des majuscules : la police Pixeled a un grand interligne (ascent 11 pour
# des capitales de 5 px en taille 5), on remonte le Label d'autant pour placer le texte au pixel
func label(text_: String, at: Vector2, width: float, parent: Node, color: Color = COLOR_TEXT, font_size: int = 5, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var value := Label.new()
	value.text = text_
	value.position = Vector2(at.x, at.y - cap_offset(font_size))
	value.size = Vector2(width, Fx.FONT.get_height(font_size))
	value.horizontal_alignment = alignment
	value.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	value.add_theme_font_override("font", Fx.FONT)
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", color)
	value.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	value.add_theme_constant_override("outline_size", 3 if font_size > 5 else 2)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# un Label plus étroit que son texte s'élargit vers la droite : on garde l'ancrage voulu
	var overflow: float = value.get_minimum_size().x - width
	if overflow > 0:
		value.size.x = width + overflow
		if alignment == HORIZONTAL_ALIGNMENT_CENTER:
			value.position.x -= floorf(overflow / 2.0)
		elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			value.position.x -= overflow
	parent.add_child(value)
	return value


func cap_offset(font_size: int) -> float:
	return Fx.FONT.get_ascent(font_size) - font_size


func button(text_: String, at: Vector2, width: float, parent: Node, callback: Callable) -> Button:
	var value := Button.new()
	value.position = at
	value.size = Vector2(width, BUTTON_HEIGHT)
	value.focus_mode = Control.FOCUS_NONE
	value.pressed.connect(callback)
	parent.add_child(value)
	ButtonStyle.bind_interaction(value, text_)
	return value


func box_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(1)
	style.anti_aliasing = false
	return style


func build_interface() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 20
	add_child(hud)
	button("COMBOS", Vector2(4, 4), TOP_BUTTON_WIDTH, hud, toggle_combos)
	button("MENU", Vector2(316 - TOP_BUTTON_WIDTH, 4), TOP_BUTTON_WIDTH, hud, leave_training)
	if not Game.is_mobile():
		label("C / LB", Vector2(4, 23), TOP_BUTTON_WIDTH, hud, COLOR_MUTED, 5, HORIZONTAL_ALIGNMENT_CENTER)
		label("ESC", Vector2(316 - TOP_BUTTON_WIDTH, 23), TOP_BUTTON_WIDTH, hud, COLOR_MUTED, 5, HORIZONTAL_ALIGNMENT_CENTER)
	# Titre centré comme « LEVEL xx » du HUD des niveaux, mode de jeu en or dessous
	label("TRAINING", Vector2(80, 5), 160, hud, Color.WHITE, 10, HORIZONTAL_ALIGNMENT_CENTER)
	label("2 PLAYERS" if GlobalPlayer.two_players else "1 PLAYER", Vector2(80, 19), 160, hud, COLOR_GOLD, 5, HORIZONTAL_ALIGNMENT_CENTER)
	# Vie de la cible : libellé, jauge pixel (même rendu que les jauges du HUD), valeur
	label("TARGET", Vector2(TARGET_BAR_X - 44, TARGET_ROW_Y), 40, hud, COLOR_TEXT, 5, HORIZONTAL_ALIGNMENT_RIGHT)
	_life_bar = PixelBar.new()
	_life_bar.max_value = TrainingDummy.MAX_TRAINING_LIFE
	_life_bar.segment = 10.0
	_life_bar.fill_color = COLOR_TARGET
	_life_bar.position = Vector2(TARGET_BAR_X, TARGET_ROW_Y)
	_life_bar.size = Vector2(TARGET_BAR_WIDTH, 6)
	_life_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_life_bar)
	_life_bar.set_value(TrainingDummy.MAX_TRAINING_LIFE, false)
	_life_label = label("", Vector2(TARGET_BAR_X + TARGET_BAR_WIDTH + 4, TARGET_ROW_Y), 60, hud)
	_ko_label = label("", Vector2(80, TARGET_ROW_Y + 11), 160, hud, COLOR_MUTED, 5, HORIZONTAL_ALIGNMENT_CENTER)
	update_ko_count()
	for i in range(players.size()):
		var feedback := label("P%d: QUICK / HEAVY TO PRACTISE" % (i + 1), Vector2(4, 53 + i * 9), 312, hud, Player.COOP_COLORS[i], 5, HORIZONTAL_ALIGNMENT_CENTER)
		_feedback_labels.append(feedback)
		players[i].combo_feedback.connect(func(message: String):
			feedback.text = "P%d: %s" % [i + 1, message])
	build_combos_panel(hud)


func build_combos_panel(hud: CanvasLayer) -> void:
	combos_panel = Control.new()
	combos_panel.size = Vector2(320, 180)
	hud.add_child(combos_panel)
	# voile sur l'arène : la liste reste lisible, un clic à côté la ferme
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.05, 0.45)
	dim.size = combos_panel.size
	dim.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
			toggle_combos())
	combos_panel.add_child(dim)
	var panel := Panel.new()
	var panel_size := Vector2(COMBOS_WIDTH, COMBOS_ROW_Y + CombatChain.RECIPES.size() * COMBOS_ROW_STEP + 44)
	panel.size = panel_size
	panel.position = ((Vector2(320, 180) - panel_size) / 2.0).floor()
	# opaque : en rendu HDR 2D, même 4 % de transparence laisse deviner le HUD derrière
	panel.add_theme_stylebox_override("panel", box_style(Color(0.04, 0.06, 0.13), COLOR_GOLD))
	combos_panel.add_child(panel)
	label("COMBOS", Vector2(0, 5), COMBOS_WIDTH, panel, COLOR_GOLD, 5, HORIZONTAL_ALIGNMENT_CENTER)
	label("R", Vector2(40, 15), 8, panel, COLOR_QUICK)
	label("QUICK", Vector2(47, 15), 30, panel, COLOR_MUTED)
	label("L", Vector2(88, 15), 8, panel, COLOR_HEAVY)
	label("HEAVY", Vector2(95, 15), 30, panel, COLOR_MUTED)
	separator(panel, COMBOS_ROW_Y - 4)
	var row := 0
	for recipe in CombatChain.RECIPES:
		var y := COMBOS_ROW_Y + row * COMBOS_ROW_STEP
		# une lettre par colonne fixe : les séquences restent alignées malgré la police proportionnelle
		var sequence := str(recipe)
		for i in sequence.length():
			var heavy := sequence[i] == CombatChain.HEAVY
			label("L" if heavy else "R", Vector2(8 + i * 6, y), 6, panel, COLOR_HEAVY if heavy else COLOR_QUICK, 5, HORIZONTAL_ALIGNMENT_CENTER)
		label(str(CombatChain.RECIPES[recipe]), Vector2(40, y), 80, panel, COLOR_TEXT)
		var strike := CombatChain.strike(recipe)
		var effect := "SLAM" if strike.slam else "x%d HITS" % strike.hits.size()
		label(effect, Vector2(COMBOS_WIDTH - 56, y), 48, panel, COLOR_GOLD if strike.slam else COLOR_MUTED, 5, HORIZONTAL_ALIGNMENT_RIGHT)
		row += 1
	var footer_y := COMBOS_ROW_Y + row * COMBOS_ROW_STEP
	separator(panel, footer_y)
	label("BUFFER %.2fS - TIMING VARIES" % CombatChain.BUFFER_SECONDS, Vector2(0, footer_y + 4), COMBOS_WIDTH, panel, COLOR_MUTED, 5, HORIZONTAL_ALIGNMENT_CENTER)
	label("MULTI-HIT: TAP EVERY <%.2fS" % CombatChain.MASH_WINDOW, Vector2(0, footer_y + 13), COMBOS_WIDTH, panel, COLOR_MUTED, 5, HORIZONTAL_ALIGNMENT_CENTER)
	button("CLOSE", Vector2((COMBOS_WIDTH - TOP_BUTTON_WIDTH) / 2.0, footer_y + 25), TOP_BUTTON_WIDTH, panel, toggle_combos)
	combos_panel.hide()


func separator(parent: Control, y: float) -> void:
	var line := ColorRect.new()
	line.color = Color(COLOR_GOLD, 0.35)
	line.position = Vector2(6, y)
	line.size = Vector2(COMBOS_WIDTH - 12, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func update_target_life(value: float) -> void:
	_life_bar.set_value(value)
	if value <= 0:
		_life_label.text = "DOWN"
		_life_label.add_theme_color_override("font_color", COLOR_DOWN)
	else:
		_life_label.text = "%d / %d" % [int(value), int(TrainingDummy.MAX_TRAINING_LIFE)]
		_life_label.add_theme_color_override("font_color", COLOR_TEXT)


func update_ko_count() -> void:
	_ko_label.text = "KO %d  -  TARGET RESPAWNS AT THE SAME SPOT" % dummy.respawn_count


func toggle_combos() -> void:
	combos_panel.visible = not combos_panel.visible


func leave_training() -> void:
	if _leaving:
		return
	_leaving = true
	Transition.goto("res://src/UI/menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if (event is InputEventKey and event.pressed and event.keycode == KEY_C) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER):
		toggle_combos()
		get_viewport().set_input_as_handled()
	elif Game.isInputPauseButton(event):
		leave_training()
		get_viewport().set_input_as_handled()


func _on_actor_took_damage(actor: Node, damage: int) -> void:
	if actor == dummy:
		dummy.took_damage(damage)


func _on_actor_took_damage_by_bullet(actor: Node, damage: int, bullet: Node) -> void:
	_on_actor_took_damage(actor, damage)
	bullet.explode()
