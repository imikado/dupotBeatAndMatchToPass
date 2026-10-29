extends Node

# Visite automatique pour update_screenshots.sh (« -- --screenshots=<dossier> --tour ») :
# enchaîne les scènes, joue à la place du joueur et enregistre Screenshot_NN.png,
# puis quitte le jeu

const TITLE_SCENE := "res://src/UI/title.tscn"
const LEVEL_SCENE := "res://src/Levels/LevelTemplate.tscn"
const BONUS_SCENE := "res://src/Levels/LevelBonus.tscn"

# Délai max d'attente d'une situation avant de capturer quand même
const STEP_TIMEOUT := 60.0

# Portée de l'épée (HitBox du joueur) et zone où l'on compte les ennemis « dans la mêlée »
const ATTACK_OFFSET_X := 16.0
const ATTACK_TOLERANCE := Vector2(4, 3)
const ATTACK_INTERVAL := 0.12
const CROWD_DISTANCE := 90.0
# L'attaque mana couvre tout l'écran ; capture quand les éclairs touchent le sol
const STORM_DISTANCE := 150.0
const STORM_IMPACT_DELAY := 0.8

const MIN_LIFE := 40.0

var _bot_group := ""
var _attack_cooldown := 0.0
var _pressed := {}

var _crowd_kill := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	Events.actor_health_changed.connect(_on_actor_health_changed)
	run()


func run() -> void:
	# Le boot mène tout seul à l'écran titre
	await wait_scene(TITLE_SCENE)
	await wait_until(func(): return get_tree().current_scene.get("_can_continue") == true)
	await wait_until(func(): return get_tree().current_scene._press_label.modulate.a > 0.95)
	shoot(6)

	await start_level(1)
	await wait_crowd_kill(2)
	await wait(0.3)
	shoot(3)

	await wait_until(func(): return get_banner_text() == "WAY CLEAR!")
	await wait(0.4)
	shoot(4)

	await start_bonus()
	await wait(5.0)
	await wait_until(func(): return get_player().get_state().begins_with("Attack"))
	await wait(0.1)
	shoot(5)

	await start_level(2)
	await wait_crowd_kill(2)
	await wait(0.3)
	shoot(2)

	await start_level(3)
	await wait_until(func(): return count_enemies_near(STORM_DISTANCE) >= 3)
	release_all()
	_bot_group = ""
	press_action(PlayerStateMachine.INPUT_ATTACK_MANA)
	await wait(STORM_IMPACT_DELAY)
	shoot(1)

	get_tree().quit()


func start_level(level: int) -> void:
	_bot_group = ""
	release_all()
	GlobalPlayer.reset_game()
	GlobalPlayer.set_level(level)
	GlobalPlayer.mana = GlobalPlayer.MAX_MANA
	Transition.goto(LEVEL_SCENE)
	await wait_scene(LEVEL_SCENE)
	_bot_group = Game.GROUP_ENEMY


func start_bonus() -> void:
	_bot_group = ""
	release_all()
	Transition.goto(BONUS_SCENE)
	await wait_scene(BONUS_SCENE)
	_bot_group = Game.GROUP_BONUSACTOR


func shoot(number: int) -> void:
	Game.takeScreenshot("Screenshot_%02d.png" % number)


func wait(duration: float) -> void:
	await get_tree().create_timer(duration, true, false, true).timeout


func wait_until(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + STEP_TIMEOUT * 1000
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			push_warning("Capture : situation attendue non atteinte, capture quand même")
			return
		await get_tree().process_frame


func wait_scene(path: String) -> void:
	await wait_until(func(): return get_tree().current_scene and get_tree().current_scene.scene_file_path == path and not Transition.is_busy())
	await wait(0.5)


# Attend qu'un ennemi meure avec d'autres ennemis autour du joueur
func wait_crowd_kill(min_enemies: int) -> void:
	await wait_until(func(): return count_enemies_near(CROWD_DISTANCE) >= min_enemies + 1)
	_crowd_kill = false
	await wait_until(func(): return _crowd_kill and count_enemies_near(CROWD_DISTANCE) >= min_enemies)


func _on_actor_health_changed(_actor, _previous_value: float, new_value: float) -> void:
	if new_value <= 0.0:
		_crowd_kill = true


func get_player() -> Player:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Node2D/Player") as Player


func get_banner_text() -> String:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null or not hud._banner.visible:
		return ""
	return hud._banner.text


func count_enemies_near(distance: float) -> int:
	var player := get_player()
	if player == null:
		return 0
	var count := 0
	for enemy in get_tree().get_nodes_in_group(Game.GROUP_ENEMY):
		if not enemy._is_dying and enemy.global_position.distance_to(player.global_position) < distance:
			count += 1
	return count


func find_target(player: Player) -> Node2D:
	var nearest: Node2D = null
	for actor in get_tree().get_nodes_in_group(_bot_group):
		if actor.get("_is_dying") == true:
			continue
		if nearest == null or actor.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position):
			nearest = actor
	return nearest


# Bot : va se placer à côté de la cible la plus proche et enchaîne les coups d'épée,
# avance vers la droite quand il n'y a personne
func _physics_process(delta: float) -> void:
	var player := get_player()
	if _bot_group == "" or player == null or Transition.is_busy():
		return

	# Fenêtre qui perd le focus : le niveau se met en pause, on reprend
	var pause_menu = get_tree().current_scene.get("_pause_menu")
	if pause_menu and pause_menu.is_open():
		pause_menu.close()

	if player._life < MIN_LIFE:
		player.heal(Player.MAX_LIFE)

	_attack_cooldown -= delta

	var direction := Vector2.ZERO
	var target := find_target(player)
	if target == null:
		if _bot_group == Game.GROUP_ENEMY:
			direction.x = 1
	else:
		var side := -1.0 if target.global_position.x < player.global_position.x else 1.0
		var gap: Vector2 = target.global_position - Vector2(side * ATTACK_OFFSET_X, 0) - player.global_position
		var facing: float = player.get_node("BodyPivot").scale.x
		if abs(gap.x) > ATTACK_TOLERANCE.x:
			direction.x = sign(gap.x)
		if abs(gap.y) > ATTACK_TOLERANCE.y:
			direction.y = sign(gap.y)
		if direction == Vector2.ZERO and sign(facing) != side:
			direction.x = side
		elif direction == Vector2.ZERO and _attack_cooldown <= 0.0:
			_attack_cooldown = ATTACK_INTERVAL
			press_action(PlayerStateMachine.INPUT_ATTACK)

	set_action(PlayerAbstractState.INPUT_RIGHT, direction.x > 0)
	set_action(PlayerAbstractState.INPUT_LEFT, direction.x < 0)
	set_action(PlayerAbstractState.INPUT_DOWN, direction.y > 0)
	set_action(PlayerAbstractState.INPUT_UP, direction.y < 0)


func set_action(action: String, pressed: bool) -> void:
	if _pressed.get(action, false) == pressed:
		return
	_pressed[action] = pressed
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func press_action(action: String) -> void:
	set_action(action, true)
	set_action(action, false)


func release_all() -> void:
	for action in _pressed.keys():
		set_action(action, false)
