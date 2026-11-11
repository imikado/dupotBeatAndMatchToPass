extends Node2D

const MIN_SPAWN_Y = 127

const LIFE_BOTTLE_HEAL = 30

const MAX_ENEMY = 5

# Taille d'une vague : 2-3 ennemis au début, puis plus avec le niveau et la difficulté
const WAVE_SIZE_MAX = 6
# Décalage vers l'extérieur quand plusieurs ennemis partagent un point d'apparition
const WAVE_SPOT_SPACING = 25.0

# Énergie à apporter à chaque barrière : 6, puis +1 tous les 2 niveaux après le niveau 3
const BARRIER_ENERGY = 6
const MAX_BARRIER_ENERGY = 10

# Groupes de barrières : 2 + niveau, au plus 5 ; un tous les BARRIER_GROUP_SPACING pixels
const BARRIER_GROUP_MIN = 2
const BARRIER_GROUP_MAX = 5
const BARRIER_GROUP_START_X = 400.0
const BARRIER_GROUP_SPACING = 510.0
const BARRIER_GROUP_Y = 115.0
# Écart horizontal entre deux barrières d'un même groupe
const BARRIER_SPACING_IN_GROUP = 20.0

const ElectricalBarrierScene := preload("res://src/Common/Levels/ElectricalBarrier.tscn")

# Délai entre deux vagues : lent à l'arrivée sur un groupe de barrières, puis de plus en plus rapide
const SPAWN_DELAY_START = 8.0
const SPAWN_DELAY_MID = 6.0
const SPAWN_DELAY_FAST = 4.0
# Vague suivante avancée quand il ne reste presque plus personne à combattre
const SPAWN_LOW_ENEMIES = 1
const SPAWN_DELAY_WHEN_LOW = 1.5
# Les ennemis d'une vague arrivent l'un après l'autre plutôt qu'en bloc
const WAVE_STAGGER = 0.35

# Mode 2 joueurs : vagues plus rapprochées et 40 % de groupes de barrières en plus
# (le niveau est rallongé d'autant, voir extend_level)
const COOP_SPAWN_DELAY_FACTOR = 0.7
const COOP_BARRIER_GROUP_FACTOR = 1.4

@onready var _ysort = get_node("Node2D")
@onready var _player = get_node("Node2D/Player")
@onready var _cameraLimitRect = get_node("CameraLimitRect")
@onready var _hud = get_node("HUD")
@onready var _controls = get_node("Controls")

@onready var _hudScore := get_node("HUD/Marker2D")

@onready var Ant := preload("res://src/Actors/SimpleEnemies/Ant.tscn")
@onready var Beetle := preload("res://src/Actors/SimpleEnemies/Beetle.tscn")
@onready var Spider := preload("res://src/Actors/SimpleEnemies/Spider.tscn")

@onready var Energie := preload("res://src/Common/Levels/Energy.tscn")

@onready var ComboPlusOne := preload("res://src/Actors/Players/ComboPlusOne.tscn")
@onready var ComboBonus := preload("res://src/Actors/Players/Player/ComboBonus.tscn")

@onready var _spawnPositionLeft := get_node("Node2D/Player/SpawnPosition2DLeft")
@onready var _spawnPositionLeft2 := get_node("Node2D/Player/SpawnPosition2DLeft2")
@onready var _spawnPositionRight := get_node("Node2D/Player/SpawnPosition2DRight")
@onready var _spawnPositionRight2 := get_node("Node2D/Player/SpawnPosition2DRight2")

@onready var _spawnTimer := get_node("Timers/SpawnTimer")
@onready var _manaTimer := get_node("Timers/ManaTimer")

@onready var _electricalBarriers := get_node("ElectricalBarriers")

@onready var _specialEffects := get_node("SpecialEffects")

@onready var _gate := get_node("Gate")

@onready var _lifeBottle := preload("res://src/Common/Items/LifeBottle.tscn")

@onready var _lifeBottles:=get_node("lifeBottles")

# Barrières des groupes déjà apparus à l'écran (les seules qui comptent pour les vagues)
var _active_barrier_list: Array[Node2D] = []

var _opened_barrier_count := 0
var _total_barrier_count := 0
# orage disponible, par joueur (index 0 / 1)
var _was_mana_ready := [false, false]
# labels « +10 » encore à l'écran (voir kill_text_position)
var _kill_texts := []

var _pause_menu: PauseMenu

var _total_wave_number = 0
var _random_combo_count = 0

var _current_barrier_group: Node2D = null

# Mode 2 joueurs : _player reste le joueur 1
var _players: Array = []


func debug():
	#_player.global_position.x +=3500
	_player.global_position.x += 450
	#_wave_number = 2

	_gate.global_position.x = 100

	GlobalPlayer.update_life(GlobalPlayer.life - 50)


func _ready() -> void:
	if Game.DEBUG_ENABLED:
		debug()
	else:
		_player.global_position.x += 450

	build_level()

	# La vie est conservée d'un niveau à l'autre (fioles du niveau bonus comprises)
	_player.set_life(GlobalPlayer.life)

	_hud.update_player_life(GlobalPlayer.life)
	_hud.update_score(GlobalPlayer.get_score())
	_hud.update_player_mana(GlobalPlayer.mana)
	_hud.update_streak(GlobalPlayer.kill_streak, GlobalPlayer.get_multiplier())

	_player.set_camera_limit_rect(_cameraLimitRect)

	_players = [_player]
	if GlobalPlayer.two_players:
		setup_coop()

	for player in _players:
		_was_mana_ready[player.player_index] = can_launch_storm(player)
	update_mana_button()

	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)

	Sound.play_music()
	Sound.play("go", 0.0)
	_hud.show_banner("LEVEL " + ("%02d" % GlobalPlayer.get_level()), "MATCH THE ENEMIES TO OPEN THE BARRIERS", Color("ffd34d"), 1.8)

	if not GlobalPlayer.two_players:
		Events.connect("player_health_changed", Callable(self, "_on_player_healt_changed"))
	Events.connect("actor_health_changed", Callable(self, "_on_actor_healt_changed"))

	Events.connect("actor_took_damage", Callable(self, "_on_actor_took_damage"))
	Events.connect("actor_took_damage_by_bullet", Callable(self, "_on_actor_took_damage_by_bullet"))

	Events.connect("player_launch_mana_attack", Callable(self, "_on_player_launch_mana_attack"))

	#life bottles
	Events.connect("player_took_lifebottle", Callable(self, "_on_player_took_lifebottle"))

	Events.player_tookadvantage_of_lifebottle.connect(_on_player_tookadvantage_of_lifebottle)

	Events.connect("player_gameover", Callable(self, "gameover"))

	_manaTimer.start()


func setup_coop() -> void:
	var result := Coop.setup_level(self, _player, _ysort, _cameraLimitRect,
		[_spawnPositionLeft, _spawnPositionLeft2, _spawnPositionRight, _spawnPositionRight2])
	_players.append(result[0])
	for player in _players:
		player.life_changed.connect(_on_coop_life_changed)
	_hud.enable_second_player()
	_hud.update_player_life(GlobalPlayer.life2, 1)
	_hud.update_player_mana(GlobalPlayer.mana2, 1)
	_controls.visible = false


# Joueur debout le plus proche d'une position (le joueur 1 si personne n'est debout)
func nearest_player(from: Vector2) -> Player:
	var best: Player = null
	for player in _players:
		if player.is_alive() and (best == null or player.global_position.distance_to(from) < best.global_position.distance_to(from)):
			best = player
	return best if best else _player


func is_anyone_storming() -> bool:
	for player in _players:
		if player.is_storming():
			return true
	return false


func _on_coop_life_changed(player: Player, newLife: float) -> void:
	var index: int = player.player_index
	if newLife < GlobalPlayer.get_player_life(index) and GlobalPlayer.kill_streak > 0:
		if GlobalPlayer.get_multiplier() > 1:
			Fx.floating_text(_specialEffects, "COMBO LOST", player.global_position + Vector2(0, -30), Color("ff4d4d"))
		GlobalPlayer.reset_streak()
		_hud.update_streak(GlobalPlayer.kill_streak, GlobalPlayer.get_multiplier())

	GlobalPlayer.set_player_life(index, newLife)
	_hud.update_player_life(newLife, index)

	if newLife > 0:
		return
	player.down()
	if GlobalPlayer.is_anyone_alive():
		_hud.show_banner("PLAYER %d DOWN" % (index + 1), "BACK AT THE NEXT LEVEL", Player.COOP_COLORS[index], 1.4)
		player.gameover()
		return

	Game.saveHighScore(GlobalPlayer.get_score())
	get_tree().paused = true
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.gameover()


func _input(event: InputEvent) -> void:
	if Game.isInputPauseButton(event) and GlobalPlayer.is_anyone_alive() and not _pause_menu.is_open():
		_pause_menu.open()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# window / browser tab focus lost: pause instead of losing the run
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and _pause_menu and GlobalPlayer.is_anyone_alive():
		_pause_menu.open()


func build_level():
	var group_count := get_barrier_group_count()
	var types := get_barrier_types()
	var energy := get_barrier_energy()

	for i in range(group_count):
		var group := create_barrier_group(Vector2(BARRIER_GROUP_START_X + BARRIER_GROUP_SPACING * i, BARRIER_GROUP_Y), types, energy)

		if GlobalPlayer.get_level() > 1:
			var newLifeBottle = _lifeBottle.instantiate()
			_lifeBottles.add_child(newLifeBottle)
			newLifeBottle.global_position = Vector2(group.global_position.x + 70, 150)

	# la porte se place un intervalle après le dernier groupe
	_gate.global_position.x = BARRIER_GROUP_START_X + BARRIER_GROUP_SPACING * group_count

	extend_level(BARRIER_GROUP_SPACING * (group_count - BARRIER_GROUP_MAX))


func get_barrier_group_count() -> int:
	var count := mini(BARRIER_GROUP_MIN + GlobalPlayer.get_level(), BARRIER_GROUP_MAX)
	if GlobalPlayer.two_players:
		count = roundi(count * COOP_BARRIER_GROUP_FACTOR)
	return count


# La scène est prévue pour BARRIER_GROUP_MAX groupes : au-delà (mode 2 joueurs), on
# prolonge vers la droite le sol, son ombre, les limites de marche et celles de la caméra
func extend_level(extra: float) -> void:
	if extra <= 0.0:
		return

	var ground: TileMap = get_node("ground")
	var tile_width: int = ground.tile_set.tile_size.x
	var used := ground.get_used_rect()
	var last_column := used.end.x - 1
	var extra_columns := ceili(extra / tile_width)
	for y in range(used.position.y, used.end.y):
		for x in range(last_column + 1, last_column + 1 + extra_columns):
			# motif du sol repris au hasard parmi les colonnes existantes
			var source_x := randi_range(used.position.x, last_column)
			var source := Vector2i(source_x, y)
			if ground.get_cell_source_id(0, source) >= 0:
				ground.set_cell(0, Vector2i(x, y), ground.get_cell_source_id(0, source), ground.get_cell_atlas_coords(0, source))

	var edge: Sprite2D = get_node("ForestBackground/GroundShade/edge")
	edge.region_rect.size.x += extra
	var shade: Sprite2D = get_node("ForestBackground/GroundShade/shade")
	shade.scale.x += extra

	for limit in [get_node("WalkingLimits/limit_walking_horiz"), get_node("WalkingLimits/limit_walking_horiz2")]:
		var collision: CollisionShape2D = limit.get_node("CollisionShape2D")
		# forme partagée entre les instances et les scènes : copie avant de l'agrandir
		var shape: RectangleShape2D = collision.shape.duplicate()
		shape.size.x += extra
		collision.shape = shape
		collision.position.x += extra / 2.0

	_cameraLimitRect.offset_right += extra


# Types de barrière d'un groupe, de gauche à droite : fourmi, puis scarabée (niveau 2+), puis araignée (niveau 3+)
func get_barrier_types() -> Array[int]:
	var types: Array[int] = [Game.ENEMY_TYPE_LIST.ANT]
	if GlobalPlayer.get_level() > 1:
		types.append(Game.ENEMY_TYPE_LIST.BEETLE)
	if GlobalPlayer.get_level() > 2:
		types.append(Game.ENEMY_TYPE_LIST.SPIDER)
	return types


func get_barrier_energy() -> int:
	return mini(BARRIER_ENERGY + ceili(GlobalPlayer.get_difficulty() / 2.0), MAX_BARRIER_ENERGY)


# Crée un groupe de barrières sous ElectricalBarriers, à la position globale donnée
func create_barrier_group(group_position: Vector2, types: Array[int], energy: int) -> Node2D:
	var group := Node2D.new()
	group.name = "BarrierGroup%02d" % (_electricalBarriers.get_child_count() + 1)
	_electricalBarriers.add_child(group)
	group.global_position = group_position

	for i in range(types.size()):
		create_barrier(group, types[i], energy, Vector2(BARRIER_SPACING_IN_GROUP * i, 0))
	return group


# Crée, configure et enregistre une barrière (position relative à son groupe)
func create_barrier(group: Node2D, type: int, energy: int, local_position: Vector2) -> Node2D:
	var barrier: Node2D = ElectricalBarrierScene.instantiate()
	barrier.setup(type, energy)
	barrier.position = local_position
	group.add_child(barrier)
	register_barrier(barrier)
	return barrier


# Branche les signaux d'une barrière et la compte pour l'ouverture de la porte
func register_barrier(barrier: Node2D) -> void:
	barrier.revealed.connect(_on_barrier_revealed)
	barrier.opened.connect(_on_barrier_opened)
	_total_barrier_count += 1


#life bottles
func _on_player_took_lifebottle(bottle, player: Player) -> void:
	Sound.play("bottle", 0.0)
	Fx.floating_text(_specialEffects, "+" + str(LIFE_BOTTLE_HEAL) + " HP", player.global_position + Vector2(0, -30), Color("7bed9f"))
	player.get_life_bottle()
	bottle.queue_free()


func _on_player_tookadvantage_of_lifebottle(player: Player) -> void:
	player.heal(LIFE_BOTTLE_HEAL)


# Première apparition d'une barrière : tout son groupe devient actif
func _on_barrier_revealed(barrier: Node2D) -> void:
	var is_first_barrier := _active_barrier_list.is_empty()

	var is_new_group := false
	if not _active_barrier_list.has(barrier):
		# tout le groupe s'active dès qu'une de ses barrières est visible :
		# les vagues mélangent ainsi tous les types du groupe
		var group: Node2D = barrier.get_parent()
		for sibling: Node2D in group.get_children():
			if not _active_barrier_list.has(sibling):
				_active_barrier_list.append(sibling)

		is_new_group = group != _current_barrier_group
		_current_barrier_group = group

	refresh_enemy_markers()

	if is_first_barrier:
		# différé : les barrières du groupe deviennent visibles dans la même image,
		# la première vague doit connaître tous leurs types
		process_spawn.call_deferred()
		start_spawn_timer()
	elif is_new_group:
		# Répit à l'arrivée sur un nouveau groupe de barrières : le rythme repart du début
		_total_wave_number = 0
		start_spawn_timer()


func _on_barrier_opened(barrier: Node2D) -> void:
	_opened_barrier_count += 1
	_player.shake_camera(3.0, 0.3)
	refresh_enemy_markers()

	var is_group_open := true
	for sibling in barrier.get_parent().get_children():
		if not sibling.is_open():
			is_group_open = false
			break

	if _opened_barrier_count >= _total_barrier_count:
		_spawnTimer.stop()
		_hud.show_banner("THE GATE IS OPEN!", "GO RIGHT >>>", Color("7fdbff"))
	elif is_group_open:
		_hud.show_banner("WAY CLEAR!", "GO RIGHT >>>", Color("7fdbff"))
	else:
		_hud.show_banner("BARRIER OPEN!", "", Color("7fdbff"), 0.8)


func _on_player_healt_changed(newLife: float):
	if newLife < GlobalPlayer.life and GlobalPlayer.kill_streak > 0:
		if GlobalPlayer.get_multiplier() > 1:
			Fx.floating_text(_specialEffects, "COMBO LOST", _player.global_position + Vector2(0, -30), Color("ff4d4d"))
		GlobalPlayer.reset_streak()
		_hud.update_streak(GlobalPlayer.kill_streak, GlobalPlayer.get_multiplier())

	GlobalPlayer.update_life(newLife)
	_hud.update_player_life(GlobalPlayer.life)

	if newLife <= 0:
		Game.saveHighScore(GlobalPlayer.get_score())
		
		get_tree().paused = true
		_player.process_mode=Node.PROCESS_MODE_ALWAYS
		_player.gameover()


func gameover():
	# coop : le premier joueur tombé finit son animation, la partie continue
	if GlobalPlayer.two_players and GlobalPlayer.is_anyone_alive():
		return
	get_tree().paused = false
	Transition.goto("res://src/UI/GameOver.tscn")


func manage_combo_for_actor(actor):
	var new_combo_plus_one = ComboPlusOne.instantiate()
	new_combo_plus_one.global_position = actor.global_position + Vector2(0, -20)

	var combo_count = actor.get_combo_count()

	# Le « +1 » se place sur le côté opposé au joueur : la colonne au-dessus de l'ennemi
	# reste libre pour le « +10 » du kill (Fx.floating_text, de y -24 à -40)
	var side = 1.0 if actor.global_position.x >= actor.get_attacker().global_position.x else -1.0

	var delta_position = Vector2.ZERO
	if combo_count == 0:
		delta_position.x = 14 * side
		delta_position.y = 5
	elif combo_count == 1:
		new_combo_plus_one.scale = Vector2(1.2, 1.2)
		delta_position.x = 16 * side
		delta_position.y = -5

	elif combo_count == 2:
		new_combo_plus_one.scale = Vector2(2.6, 2.6)
		delta_position.x = 22 * side
		delta_position.y = -12

		# « COMBO! » au-dessus du « +10 » (qui monte jusqu'à y -46 environ)
		var new_combo_bonus = ComboBonus.instantiate()
		new_combo_bonus.global_position = (actor.global_position + Vector2(0, -62)).round()
		new_combo_bonus.connect("combo_arrived", _on_combo_bonus_finished.bind(mana_receiver(actor)))
		new_combo_bonus.set_target(_hudScore)
		new_combo_bonus.set_as_top_level(true)
		Sound.play("combo", 0.0)

		_specialEffects.add_child(new_combo_bonus)

	new_combo_plus_one.global_position = (new_combo_plus_one.global_position + delta_position).round()

	new_combo_plus_one.set_as_top_level(true)
	_specialEffects.add_child(new_combo_plus_one)

	actor.increment_combo_count()


func _on_actor_healt_changed(actor: CharacterBody2D, previous_value: float, new_value: float):
	actor.update_enemy_life(previous_value, new_value)

	if actor.get_attacker().is_combo():
		manage_combo_for_actor(actor)

	else:
		actor.reset_combo_count()

	if new_value <= 0.0:
		var multiplier = GlobalPlayer.register_kill()
		var points = 10 * multiplier
		# la tempête ne se recharge pas avec ses propres victimes ; la mana va au joueur qui a tué
		increment_score(points, not is_anyone_storming(), mana_receiver(actor))
		_hud.update_streak(GlobalPlayer.kill_streak, multiplier)

		var text_color = Color.WHITE if multiplier == 1 else Color("ffd34d")
		Fx.floating_text(_specialEffects, "+" + str(points), kill_text_position(actor.global_position + Vector2(0, -24)), text_color)
		_kill_texts.append(_specialEffects.get_child(-1))
		Fx.burst(_specialEffects, actor.global_position + Vector2(0, -6), Fx.enemy_color(actor.get_type()))
		Sound.play("enemy_die")

		Game.hit_stop(0.06)
		_player.shake_camera(2.0, 0.1)

		hurry_next_wave.call_deferred()

		# barrière de ce type déjà ouverte : pas d'énergie
		var barrier_target = find_barrier_for_actor(actor)
		if barrier_target:
			var new_energy = Energie.instantiate()
			new_energy.global_position = actor.global_position
			add_child(new_energy)
			new_energy.set_target(barrier_target)


# Deux ennemis qui meurent au même endroit : le « +10 » suivant monte au-dessus
# de ceux encore visibles tout près (Fx.floating_text centre un label de 60×12)
func kill_text_position(text_position: Vector2) -> Vector2:
	_kill_texts = _kill_texts.filter(func(label): return is_instance_valid(label) and not label.is_queued_for_deletion())
	var moved := true
	var tries := 0
	while moved and tries < 4:
		moved = false
		tries += 1
		for label in _kill_texts:
			var center: Vector2 = label.global_position + Vector2(30, 6)
			if abs(center.x - text_position.x) < 18 and abs(center.y - text_position.y) < 8:
				text_position.y = center.y - 8
				moved = true
				break
	return text_position.round()


func increment_score(points: int, give_mana := true, player_index := 0):
	var new_score: int
	new_score = GlobalPlayer.get_score() + points
	GlobalPlayer.save_score(new_score)
	_hud.update_score(new_score)

	if give_mana:
		increment_mana(player_index)


func _on_combo_bonus_finished(player_index := 0):
	increment_score(10, true, player_index)


# Index du joueur qui a frappé l'ennemi (0 en solo)
func mana_receiver(actor) -> int:
	var attacker = actor.get_attacker()
	return attacker.player_index if attacker is Player else 0


# Barrière encore fermée du type de l'ennemi, la plus proche du joueur (null si aucune)
func find_barrier_for_actor(actor: CharacterBody2D) -> Node2D:
	var nearest_barrier: Node2D = null
	var nearest_distance := INF

	for barrier_loop in _active_barrier_list:
		if barrier_loop.is_open() or actor.get_type() != barrier_loop.get_type():
			continue
		var distance: float = abs(barrier_loop.global_position.x - nearest_player(actor.global_position).global_position.x)
		if distance < nearest_distance:
			nearest_barrier = barrier_loop
			nearest_distance = distance

	return nearest_barrier


# Types d'ennemis qui chargent encore une barrière
func get_wanted_types() -> Array:
	var types := []
	for barrier_loop in _active_barrier_list:
		if not barrier_loop.is_open() and not types.has(barrier_loop.get_type()):
			types.append(barrier_loop.get_type())
	return types


# Marqueur au-dessus des ennemis utiles (leur barrière est encore fermée)
func refresh_enemy_markers() -> void:
	var types := get_wanted_types()
	for enemy in get_tree().get_nodes_in_group(Game.GROUP_ENEMY):
		enemy.set_wanted(types.has(enemy.get_type()))


func _on_actor_took_damage(actor, damage):
	#if actor.has_method("get_life"):
	#	actor.update_enemy_life (actor.get_life(),actor.get_life())
	actor.took_damage(damage)


func _on_actor_took_damage_by_bullet(actor, damage, bullet):
	#if actor.has_method("get_life"):
	#	actor.update_enemy_life (actor.get_life(),actor.get_life())
	_on_actor_took_damage(actor, damage)

	bullet.explode()


func spawn_enemy_on_position(enemy_to_spawn, spawn_position, offset = Vector2.ZERO):
	var enemy_spawn = enemy_to_spawn.instantiate()

	var active_barrier = find_barrier_for_actor(enemy_spawn)
	if active_barrier == null:
		enemy_spawn.queue_free()
		return

	enemy_spawn.add_to_group(Game.GROUP_ENEMY)
	enemy_spawn.setPlayer(nearest_player(spawn_position.global_position + offset))
	enemy_spawn.apply_difficulty(GlobalPlayer.get_difficulty())

	if spawn_position.global_position.y < MIN_SPAWN_Y:
		spawn_position.global_position.y = MIN_SPAWN_Y

	enemy_spawn.set_global_position(spawn_position.global_position + offset)

	_ysort.add_child(enemy_spawn)
	enemy_spawn.set_wanted(true)


func has_too_much_enemy(enemy_to_spawn_type):
	var current_number = 0
	for enemy_still_there_loop in get_tree().get_nodes_in_group(Game.GROUP_ENEMY):
		if enemy_to_spawn_type == enemy_still_there_loop.get_type():
			current_number += 1
			if current_number >= MAX_ENEMY:
				return true
	return false


func get_enemy_by_type(type):
	var enemy
	if type == Game.ENEMY_TYPE_LIST.ANT:
		enemy = Ant
	elif type == Game.ENEMY_TYPE_LIST.BEETLE:
		enemy = Beetle
	elif type == Game.ENEMY_TYPE_LIST.SPIDER:
		enemy = Spider
	else:
		print("Error type unknown")

	return enemy


func process_spawn():
	# Porte ouverte : plus de nouveaux ennemis
	if _total_barrier_count > 0 and _opened_barrier_count >= _total_barrier_count:
		return

	var wave := build_wave()
	for i in range(wave.size()):
		if i == 0:
			spawn_wave_enemy(wave[i])
		else:
			get_tree().create_timer(WAVE_STAGGER * i, false).timeout.connect(spawn_wave_enemy.bind(wave[i]))

	_total_wave_number += 1


func spawn_wave_enemy(wave_entry: Dictionary) -> void:
	if _total_barrier_count > 0 and _opened_barrier_count >= _total_barrier_count:
		return
	if has_too_much_enemy(wave_entry["type"]):
		return
	spawn_enemy_on_position(get_enemy_by_type(wave_entry["type"]), wave_entry["position"], wave_entry["offset"])


# Plus (presque) personne à combattre : la vague suivante arrive vite
func hurry_next_wave() -> void:
	if _active_barrier_list.is_empty() or _spawnTimer.is_stopped():
		return
	var alive := 0
	for enemy in get_tree().get_nodes_in_group(Game.GROUP_ENEMY):
		if not enemy.get("_is_dying") and enemy.get_life() > 0:
			alive += 1
	if alive <= SPAWN_LOW_ENEMIES and _spawnTimer.time_left > SPAWN_DELAY_WHEN_LOW:
		_spawnTimer.start(SPAWN_DELAY_WHEN_LOW)


# Vague tirée au hasard parmi les types des barrières encore fermées :
# chaque type utile au moins une fois, sur des points d'apparition mélangés
func build_wave() -> Array:
	var types := get_wanted_types()
	if types.is_empty():
		return []
	types.shuffle()

	var size: int = clampi(GlobalPlayer.get_level() + GlobalPlayer.get_difficulty() / 2, 2, WAVE_SIZE_MAX - 1)
	size = mini(size + randi_range(0, 1), WAVE_SIZE_MAX)
	size = maxi(size, types.size())

	var spots := [_spawnPositionLeft, _spawnPositionLeft2, _spawnPositionRight, _spawnPositionRight2]
	spots.shuffle()

	var wave := []
	for i in range(size):
		var type = types[i] if i < types.size() else types.pick_random()
		var spot: Node2D = spots[i % spots.size()]
		var outward := -1.0 if spot == _spawnPositionLeft or spot == _spawnPositionLeft2 else 1.0
		var offset := Vector2(outward * WAVE_SPOT_SPACING * (i / spots.size()) + randf_range(-6, 6), 0)
		wave.append({"type": type, "position": spot, "offset": offset})
	return wave


func _on_SpawnTimer_timeout() -> void:
	process_spawn()
	start_spawn_timer()


func start_spawn_timer() -> void:
	if _opened_barrier_count >= _total_barrier_count:
		return

	var delay = SPAWN_DELAY_START
	if _total_wave_number > 8:
		delay = SPAWN_DELAY_FAST
	elif _total_wave_number > 4:
		delay = SPAWN_DELAY_MID

	# Les vagues arrivent plus vite à chaque niveau après le niveau 3 (jusqu'à -40 %)
	delay *= max(1.0 - 0.1 * GlobalPlayer.get_difficulty(), 0.6)
	if GlobalPlayer.two_players:
		delay *= COOP_SPAWN_DELAY_FACTOR

	_spawnTimer.start(delay)


func _on_ManaTimer_timeout() -> void:
	for player in _players:
		increment_mana(player.player_index)


func increment_mana(player_index := 0) -> void:
	GlobalPlayer.increment_mana(1, player_index)
	_hud.update_player_mana(GlobalPlayer.get_mana(player_index), player_index)

	update_mana_button()


func _on_player_launch_mana_attack(player: Player = null) -> void:
	var index := player.player_index if player else 0
	GlobalPlayer.use_amount_mana(GlobalPlayer.attack_amount_mana, index)
	_hud.update_player_mana(GlobalPlayer.get_mana(index), index)

	update_mana_button()


func can_launch_storm(player: Player) -> bool:
	return GlobalPlayer.can_use_amount_mana(GlobalPlayer.attack_amount_mana, player.player_index)


func update_mana_button():
	if can_launch_storm(_player):
		_controls.enable_mana_button()
	else:
		_controls.disable_mana_button()

	for player in _players:
		var is_mana_ready := can_launch_storm(player)
		if is_mana_ready and not _was_mana_ready[player.player_index]:
			Sound.play("mana_ready", 0.0)
			if player.is_alive():
				Fx.floating_text(_specialEffects, "MANA READY", player.global_position + Vector2(0, -36), Color("74b9ff"))
		_was_mana_ready[player.player_index] = is_mana_ready


func _on_Gate_player_entered_gate() -> void:
	GlobalPlayer.revive_downed()

	Transition.goto("res://src/UI/LevelCompleted.tscn")
	pass  # Replace with function body.
