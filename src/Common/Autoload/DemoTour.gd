extends "res://src/Common/Autoload/ScreenshotTour.gd"

# Démo du README pour update_demo.sh (« -- --screenshots=<dossier> --demo=<clip> »,
# lancé avec --write-movie) : joue la séquence du clip et affiche « Demo clip : <début> <fin> »,
# les numéros des images enregistrées à garder dans le gif, puis quitte le jeu
#   launch   : logo de boot, écran titre puis menu       -> docs/media/launch.gif
#   gameplay : combo, kills et orage d'éclairs (niveau 1) -> docs/media/gameplay.gif
#              + capture de l'orage                       -> docs/media/lightning.png
#   video    : lancement, niveau 1 + orage, bonus, niveau 3 + orage, avec le son
#              (export_video.sh)                          -> export/demo.mp4

const MENU_SCENE := "res://src/UI/menu.tscn"

const MENU_DURATION := 2.5
const FIGHT_DURATION := 3.0
# L'orage part quand des ennemis sont autour mais aucun au contact de Gordon
# (attente max en temps de jeu, puis l'orage part quand même)
const STORM_MIN_ENEMIES := 1
const STORM_TRIGGER_DISTANCE := 90.0
const STORM_CLEAR_DISTANCE := 50.0
const STORM_WAIT_MAX := 3.0
# Le clip de gameplay commence quand un ennemi atteignable est à cette distance
const TARGET_CLOSE_DISTANCE := 40.0
const AFTER_STORM_DURATION := 2.0
# Vidéo YouTube : durées des séquences (temps de jeu)
const VIDEO_TITLE_DURATION := 2.0
const VIDEO_FIGHT_DURATION := 8.0
const VIDEO_BONUS_DURATION := 7.0
const VIDEO_CROWD_MIN_ENEMIES := 3
const VIDEO_END_DURATION := 3.0

var _clip := ""
var _clip_start := 0


func _init(clip: String) -> void:
	_clip = clip


func run() -> void:
	match _clip:
		"launch":
			await run_launch()
		"gameplay":
			await run_gameplay()
		"video":
			await run_video()
		_:
			push_error("Démo inconnue : " + _clip)
	get_tree().quit()


func run_launch() -> void:
	clip_start()
	await wait_scene(TITLE_SCENE)
	await wait_until(func(): return get_tree().current_scene.get("_can_continue") == true)
	await wait(1.0)
	# L'écran titre attend une vraie touche, pas une action
	press_key(KEY_ENTER)
	await wait_scene(MENU_SCENE)
	await wait(MENU_DURATION)
	clip_end()


func run_gameplay() -> void:
	await wait_scene(TITLE_SCENE)
	await start_level(1)
	await wait_until(is_target_close)
	clip_start()
	await wait(FIGHT_DURATION)
	await wait_at_most(is_storm_ready, STORM_WAIT_MAX)
	await storm("lightning.png")
	await wait(AFTER_STORM_DURATION)
	clip_end()


func run_video() -> void:
	# ScreenshotTour coupe le son : la vidéo le garde (enregistré en WAV par le Movie Maker)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	clip_start()
	await wait_scene(TITLE_SCENE)
	await wait_until(func(): return get_tree().current_scene.get("_can_continue") == true)
	await wait(VIDEO_TITLE_DURATION)
	press_key(KEY_ENTER)
	await wait_scene(MENU_SCENE)
	await wait(MENU_DURATION)

	await start_level(1)
	await wait(VIDEO_FIGHT_DURATION)
	await wait_at_most(is_storm_ready, STORM_WAIT_MAX)
	await storm()
	await wait(AFTER_STORM_DURATION)

	await start_bonus()
	await wait(VIDEO_BONUS_DURATION)

	await start_level(3)
	await wait(VIDEO_FIGHT_DURATION)
	await wait_at_most(func(): return count_enemies_near(STORM_DISTANCE) >= VIDEO_CROWD_MIN_ENEMIES, STORM_WAIT_MAX * 3)
	await storm()
	await wait(VIDEO_END_DURATION)
	clip_end()


# Orage d'éclairs (attaque mana), avec capture facultative à l'impact
func storm(screenshot := "") -> void:
	var group := _bot_group
	release_all()
	_bot_group = ""
	press_action(PlayerStateMachine.INPUT_ATTACK_MANA)
	await wait(STORM_IMPACT_DELAY)
	if screenshot != "":
		Game.takeScreenshot(screenshot)
	_bot_group = group


# Avec --write-movie, le jeu tourne plus lentement que le temps réel : les délais
# d'attente sont comptés en temps de jeu
func wait_until(condition: Callable) -> void:
	await wait_at_most(condition, STEP_TIMEOUT)
	if not condition.call():
		push_warning("Démo : situation attendue non atteinte, on continue quand même")


func wait_at_most(condition: Callable, duration: float) -> void:
	var timer := get_tree().create_timer(duration, true, false, true)
	while not condition.call() and timer.time_left > 0.0:
		await get_tree().process_frame


func is_storm_ready() -> bool:
	return count_enemies_near(STORM_TRIGGER_DISTANCE) >= STORM_MIN_ENEMIES and count_enemies_near(STORM_CLEAR_DISTANCE) == 0


func is_target_close() -> bool:
	var player := get_player()
	if player == null:
		return false
	var target := find_target(player)
	return target != null and target.global_position.distance_to(player.global_position) < TARGET_CLOSE_DISTANCE


# Le bot ne vise que les ennemis de son côté de la prochaine barrière fermée :
# sinon il reste collé à la barrière sans rien toucher
func find_target(player: Player) -> Node2D:
	var limit_x := INF
	var barriers = get_tree().current_scene.get("_electricalBarriers")
	if barriers:
		for group in barriers.get_children():
			for barrier in group.get_children():
				if not barrier.is_open() and barrier.global_position.x > player.global_position.x:
					limit_x = min(limit_x, barrier.global_position.x)

	var nearest: Node2D = null
	for actor in get_tree().get_nodes_in_group(_bot_group):
		if actor.get("_is_dying") == true or actor.global_position.x >= limit_x:
			continue
		if nearest == null or actor.global_position.distance_to(player.global_position) < nearest.global_position.distance_to(player.global_position):
			nearest = actor
	return nearest


func press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func clip_start() -> void:
	_clip_start = Engine.get_frames_drawn()


func clip_end() -> void:
	print("Demo clip : %d %d" % [_clip_start, Engine.get_frames_drawn()])
