extends Node2D

# Boutique d'armes, après le niveau bonus : un bouton d'achat par arme (et par joueur en coop),
# actif seulement si le joueur a assez de gems. CONTINUE mène au niveau suivant.

const ButtonStyle = preload("res://src/Common/UI/MenuButtonStyle.gd")

const NEXT_LEVEL := "res://src/Levels/LevelTemplate.tscn"
const SHOP_WEAPONS := [GlobalPlayer.WEAPON_AXE, GlobalPlayer.WEAPON_BOMB]
const SCREEN := Vector2(320, 180)
const CARD_WIDTH := 110.0
const BUY_Y := 58.0
const BUY_STEP := 20.0
const CARD_Y := 40.0
const CARD_GAP := 20.0
const BUY_WIDTH := 90.0
const CONTINUE_WIDTH := 128.0
const CONTINUE_Y := 152.0
const PANEL := Color("241a2c")
const PANEL_BORDER := Color("4a4e69")
const COLOR_OWNED := Color("7bed9f")
const COLOR_MUTED := Color(1, 1, 1, 0.55)

var _root: Control
var _pause_menu: PauseMenu
var _gems_label: Label
# {"button", "weapon", "index"} ; weapon vide = CONTINUE
var _entries := []
var _price_labels := {}
var _selected := 0
var _leaving := false


func _ready() -> void:
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_root = Control.new()
	_root.size = SCREEN
	layer.add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.05, 0.55)
	dim.size = SCREEN
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var title := build_label(_root, "WEAPON SHOP", Vector2(0, 4), Vector2(SCREEN.x, 14), 10)
	title.add_theme_color_override("font_color", ButtonStyle.GOLD)
	_gems_label = build_label(_root, "", Vector2(0, 20), Vector2(SCREEN.x, 10), 6)
	_gems_label.add_theme_color_override("font_color", Fx.GEM_COLOR)

	var total := CARD_WIDTH * SHOP_WEAPONS.size() + CARD_GAP * (SHOP_WEAPONS.size() - 1)
	var x := (SCREEN.x - total) / 2.0
	for weapon in SHOP_WEAPONS:
		build_card(weapon, Vector2(x, CARD_Y))
		x += CARD_WIDTH + CARD_GAP

	var next := add_button(_root, Vector2((SCREEN.x - CONTINUE_WIDTH) / 2.0, CONTINUE_Y), CONTINUE_WIDTH, "", -1)
	next.pressed.connect(_leave)

	_selected = first_enabled()
	refresh()
	Sound.play_music()


func build_card(weapon: String, origin: Vector2) -> void:
	var color: Color = WeaponIcons.COLORS[weapon]
	var card := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PANEL, 0.92)
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	card.position = origin
	var players := 2 if GlobalPlayer.two_players else 1
	card.size = Vector2(CARD_WIDTH, BUY_Y + BUY_STEP * players + 2)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(card)

	var icon := TextureRect.new()
	icon.texture = WeaponIcons.texture(weapon)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(22, 22)
	icon.position = Vector2((CARD_WIDTH - 22) / 2.0, 4)
	card.add_child(icon)

	var name_label := build_label(card, GlobalPlayer.WEAPON_TITLES[weapon], Vector2(0, 28), Vector2(CARD_WIDTH, 10), 6)
	name_label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.3))
	_price_labels[weapon] = build_label(card, "%d GEMS" % GlobalPlayer.WEAPON_PRICES[weapon], Vector2(0, 40), Vector2(CARD_WIDTH, 10), 6)

	for index in range(players):
		var button := add_button(card, Vector2((CARD_WIDTH - BUY_WIDTH) / 2.0, BUY_Y + BUY_STEP * index), BUY_WIDTH, weapon, index)
		button.pressed.connect(_buy.bind(weapon, index))


func add_button(parent: Control, position_: Vector2, width: float, weapon: String, index: int) -> Button:
	var button := Button.new()
	button.position = position_
	button.size = Vector2(width, ButtonStyle.HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	var entry := _entries.size()
	button.mouse_entered.connect(func():
		if not button.disabled:
			_selected = entry
			refresh())
	_entries.append({"button": button, "weapon": weapon, "index": index})
	return button


func build_label(parent: Control, text_: String, position_: Vector2, size_: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.position = position_
	label.size = size_
	return label


func can_buy(weapon: String, index: int) -> bool:
	return not GlobalPlayer.has_weapon(weapon, index) and GlobalPlayer.get_gems(index) >= GlobalPlayer.WEAPON_PRICES[weapon]


func refresh() -> void:
	if GlobalPlayer.two_players:
		_gems_label.text = "P1 %d GEMS   P2 %d GEMS" % [GlobalPlayer.get_gems(0), GlobalPlayer.get_gems(1)]
	else:
		_gems_label.text = "%d GEMS" % GlobalPlayer.get_gems(0)

	for weapon in _price_labels:
		var affordable := false
		for index in range(2 if GlobalPlayer.two_players else 1):
			affordable = affordable or can_buy(weapon, index)
		_price_labels[weapon].add_theme_color_override("font_color", Fx.GEM_COLOR if affordable else COLOR_MUTED)

	for i in range(_entries.size()):
		var entry: Dictionary = _entries[i]
		var button: Button = entry.button
		var caption := "CONTINUE"
		if entry.weapon != "":
			var prefix := "P%d " % (entry.index + 1) if GlobalPlayer.two_players else ""
			var owned := GlobalPlayer.has_weapon(entry.weapon, entry.index)
			button.disabled = not can_buy(entry.weapon, entry.index)
			caption = prefix + ("OWNED" if owned else "BUY")
		ButtonStyle.apply(button, caption, i == _selected and not button.disabled)
		if entry.weapon != "" and GlobalPlayer.has_weapon(entry.weapon, entry.index):
			button.get_node("Label").add_theme_color_override("font_color", COLOR_OWNED)


func first_enabled() -> int:
	for i in range(_entries.size()):
		if not _entries[i].button.disabled:
			return i
	return _entries.size() - 1


func move_selection(step: int) -> void:
	var count := _entries.size()
	for _i in range(count):
		_selected = (_selected + step + count) % count
		if not _entries[_selected].button.disabled:
			break
	Sound.play("menu_move", 0.0)
	refresh()


func _buy(weapon: String, index: int) -> void:
	if not GlobalPlayer.buy_weapon(weapon, index):
		Sound.play("menu_move", 0.0, -4.0, 0.6)
		return
	Sound.play("mana_ready", 0.0)
	refresh()
	if _entries[_selected].button.disabled:
		_selected = first_enabled()
		refresh()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Sound.play("menu_select", 0.0)
	Transition.goto(NEXT_LEVEL)


func _input(event: InputEvent) -> void:
	if _leaving or _pause_menu.is_open():
		return
	if Game.isInputPauseButton(event):
		_pause_menu.open()
	elif event.is_action_pressed(PlayerAbstractState.INPUT_UP) or event.is_action_pressed(PlayerAbstractState.INPUT_LEFT):
		move_selection(-1)
	elif event.is_action_pressed(PlayerAbstractState.INPUT_DOWN) or event.is_action_pressed(PlayerAbstractState.INPUT_RIGHT):
		move_selection(1)
	elif Game.isInputValidateButton(event):
		var button: Button = _entries[_selected].button
		if not button.disabled:
			button.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and _pause_menu:
		_pause_menu.open()
