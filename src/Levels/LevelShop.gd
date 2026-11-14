extends Node2D

# Niveau boutique, après le niveau bonus : trois pierres de lumière, une par compétence.
# Chaque coup sur une pierre verse des gems dans sa jauge (jauge pleine = niveau +5 %).
# La porte de sortie mène au niveau suivant.

const NEXT_LEVEL := "res://src/Levels/LevelTemplate.tscn"
const STONE_Y := 140.0
const STONE_XS := [64.0, 140.0, 216.0]
const EXIT_DOOR_POSITION := Vector2(292, 116)
const EXIT_LABEL_COLOR := Color("ffd34d")

@onready var _ysort = get_node("Node2D")
@onready var _player: Player = get_node("Node2D/Player")
@onready var _cameraLimitRect = get_node("CameraLimitRect")
@onready var _hud = get_node("HUD")
@onready var _controls = get_node("Controls")
@onready var _specialEffects := get_node("SpecialEffects")

@onready var _spawnPositionLeft := get_node("Node2D/Player/SpawnPosition2DLeft")
@onready var _spawnPositionLeft2 := get_node("Node2D/Player/SpawnPosition2DLeft2")
@onready var _spawnPositionRight := get_node("Node2D/Player/SpawnPosition2DRight")
@onready var _spawnPositionRight2 := get_node("Node2D/Player/SpawnPosition2DRight2")

var _pause_menu: PauseMenu
var _players: Array = []
var _leaving := false


func _ready() -> void:
	_player.set_life(GlobalPlayer.life)
	_hud.update_player_life(GlobalPlayer.life)
	_hud.update_score(GlobalPlayer.get_score())
	_hud.update_player_mana(GlobalPlayer.mana)
	_hud.update_gems(GlobalPlayer.get_gems(0), 0)
	_hud.set_title("SKILL SHRINE")
	_hud.update_streak(GlobalPlayer.kill_streak, GlobalPlayer.get_multiplier())

	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)

	_player.set_camera_limit_rect(_cameraLimitRect)

	_players = [_player]
	if GlobalPlayer.two_players:
		var result := Coop.setup_level(self, _player, _ysort, _cameraLimitRect,
			[_spawnPositionLeft, _spawnPositionLeft2, _spawnPositionRight, _spawnPositionRight2])
		_players.append(result[0])
		_hud.enable_second_player()
		_hud.update_player_life(GlobalPlayer.life2, 1)
		_hud.update_player_mana(GlobalPlayer.mana2, 1)
		_hud.update_gems(GlobalPlayer.get_gems(1), 1)
		_controls.visible = false

	for i in range(GlobalPlayer.SKILLS.size()):
		var stone := SkillStone.new().setup(GlobalPlayer.SKILLS[i])
		_ysort.add_child(stone)
		stone.global_position = Vector2(STONE_XS[i], STONE_Y)
		stone.invested.connect(_on_stone_invested)

	var door := BonusDoor.new()
	_ysort.add_child(door)
	door.global_position = EXIT_DOOR_POSITION
	door._label.text = "EXIT"
	door._label.add_theme_color_override("font_color", EXIT_LABEL_COLOR)
	door.player_entered.connect(_on_exit_entered)

	Events.player_launch_mana_attack.connect(_on_player_launch_mana_attack)
	update_mana_button()

	Sound.play_music()
	_hud.show_banner("SKILL SHRINE", "HIT A STONE TO SPEND YOUR GEMS", Color("7bed9f"), 2.2)


func _input(event: InputEvent) -> void:
	if Game.isInputPauseButton(event) and not _pause_menu.is_open():
		_pause_menu.open()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and _pause_menu:
		_pause_menu.open()


func _on_stone_invested(player: Player, result: int) -> void:
	if result != 0:
		_hud.update_gems(GlobalPlayer.get_gems(player.player_index), player.player_index)


func _on_exit_entered(_player_: Player) -> void:
	if _leaving:
		return
	_leaving = true
	Sound.play("menu_select", 0.0)
	Transition.goto(NEXT_LEVEL)


func _on_player_launch_mana_attack(player: Player = null) -> void:
	var index := player.player_index if player else 0
	GlobalPlayer.use_amount_mana(GlobalPlayer.attack_amount_mana, index)
	_hud.update_player_mana(GlobalPlayer.get_mana(index), index)
	update_mana_button()


func update_mana_button() -> void:
	if GlobalPlayer.can_use_amount_mana(GlobalPlayer.attack_amount_mana):
		_controls.enable_mana_button()
	else:
		_controls.disable_mana_button()
