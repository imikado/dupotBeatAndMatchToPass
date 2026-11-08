extends Node2D

# Barrière électrique : bloque le passage tant qu'elle n'a pas reçu max_energy énergies
# (une par ennemi de son type tué). Configuration : setup(type, max_energy) avant ou après
# l'ajout à l'arbre, puis on lit is_open() / get_type() et on écoute les signaux.

# Émis une seule fois, la première fois que la barrière apparaît à l'écran
signal revealed(barrier: Node2D)
# Émis une seule fois, quand la dernière énergie ouvre la barrière
signal opened(barrier: Node2D)

const DEFAULT_MAX_ENERGY := 6
# La jauge a 7 images (0 à 6) quel que soit max_energy
const PROGRESS_LAST_FRAME := 6

# Arc vertical, en coordonnées du nœud barrier (comme l'ancien Line2D)
const ARC_TOP := Vector2(1, 1)
const ARC_BOTTOM := Vector2(1, 85)
# Instabilité selon la charge (0 = vide, 1 = pleine)
const JAGGEDNESS_MIN := 0.035
const JAGGEDNESS_MAX := 0.09
const REGEN_SLOW := 0.08
const REGEN_FAST := 0.05
const SHORT_CIRCUIT_TIME := 0.4

# Réglable dans l'inspecteur (anciens niveaux) ou par setup()/set_type()
# valeurs de Game.ENEMY_TYPE_LIST (même ordre)
@export_enum("ANT", "SPIDER", "BEETLE") var type: int = Game.ENEMY_TYPE_LIST.ANT: set = set_type
@export_range(1, 20) var max_energy: int = DEFAULT_MAX_ENERGY: set = set_max_energy

var energy_count: int = 0

@onready var _animatedSprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _animatedSpriteProgress: AnimatedSprite2D = $AnimatedSprite2
@onready var _barrier: Node2D = $barrier
@onready var _bolt: Bolt = $barrier/Bolt
@onready var _bolt_back: Bolt = $barrier/BoltBack
@onready var _halo: Sprite2D = $barrier/Halo
@onready var _sparks_top: CPUParticles2D = $barrier/SparksTop
@onready var _sparks_bottom: CPUParticles2D = $barrier/SparksBottom
@onready var _arc_timer: Timer = $barrier/Timer
@onready var _collision: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var _icons: Node2D = $icons
# Grand détecteur (barrière + jauge + icône) : déclenche revealed
@onready var _reveal_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
# Détecteur de l'arc seul : met en pause l'animation hors écran
@onready var _arc_notifier: VisibleOnScreenNotifier2D = $barrier/VisibleOnScreenNotifier2D

@onready var _type_icon_list := {
	Game.ENEMY_TYPE_LIST.ANT: $icons/ant,
	Game.ENEMY_TYPE_LIST.SPIDER: $icons/spider,
	Game.ENEMY_TYPE_LIST.BEETLE: $icons/beetle,
}

var _color := Color.WHITE
# 1 juste après un increment(), redescend à 0
var _flash := 0.0
var _flash_tween: Tween
var _short_circuit_tween: Tween
var _short_circuit := false
var _revealed := false


func _ready() -> void:
	add_to_group(Game.GROUP_BARRIER)
	if Game.DEBUG_ENABLED:
		max_energy = 1

	_animatedSprite.play()

	_arc_timer.timeout.connect(_on_arc_tick)
	_arc_notifier.screen_entered.connect(func(): _arc_timer.paused = false)
	_arc_notifier.screen_exited.connect(func(): _arc_timer.paused = true)
	_reveal_notifier.screen_entered.connect(_on_reveal_notifier_screen_entered)

	_apply_type()
	_update_progress()
	_reset_arcs()


# --- API publique ---

# Configuration complète en un appel ; utilisable avant add_child (appliquée dans _ready)
func setup(barrier_type: int, energy: int = DEFAULT_MAX_ENERGY) -> Node2D:
	type = barrier_type
	max_energy = energy
	return self


func set_type(value: int) -> void:
	type = value
	if is_node_ready():
		_apply_type()


func get_type() -> int:
	return type


# En mode debug, une seule énergie suffit (forcée dans _ready et ici)
func set_max_energy(value: int) -> void:
	max_energy = 1 if Game.DEBUG_ENABLED else maxi(value, 1)
	if is_node_ready():
		_update_progress()


func get_max_energy() -> int:
	return max_energy


func is_open() -> bool:
	return energy_count >= max_energy


func is_revealed() -> bool:
	return _revealed


# Une énergie arrive (Energy.gd) ; ignorée si la barrière est déjà ouverte
func increment() -> void:
	if is_open():
		return
	energy_count += 1

	_update_progress()
	Sound.play("energy", 0.0, 0.0, 1.0 + 0.08 * energy_count)
	pulse()

	if is_open():
		disable_barrier()
		Sound.play("barrier_open", 0.0)
		opened.emit(self)
	else:
		_charge_arc()


# Referme la barrière (énergie remise à zéro, collision et arcs rétablis)
func enable_barrier() -> void:
	if _short_circuit_tween:
		_short_circuit_tween.kill()
	_short_circuit = false
	energy_count = 0
	_update_progress()
	_barrier.visible = true
	_collision.set_deferred("disabled", false)
	_arc_timer.start()
	_reset_arcs()


# Abscisse de l'arc (centre de la forme de collision), pour repérer les traversées
func get_arc_x() -> float:
	return _collision.global_position.x


# La collision tombe tout de suite ; seul l'effet visuel (court-circuit) dure un peu
func disable_barrier() -> void:
	# différé : sûr même si l'appel vient d'un rappel physique
	_collision.set_deferred("disabled", true)
	_start_short_circuit()


func pulse() -> void:
	var tween := create_tween()
	tween.tween_property(_animatedSpriteProgress, "scale", Vector2(1.4, 1.4), 0.08)
	tween.tween_property(_animatedSpriteProgress, "scale", Vector2.ONE, 0.12)


# --- interne ---

func _on_reveal_notifier_screen_entered() -> void:
	if _revealed:
		return
	_revealed = true
	revealed.emit(self)


# Icône et couleur des arcs selon le type
func _apply_type() -> void:
	for icon_loop in _icons.get_children():
		icon_loop.visible = false
	var icon: Node2D = _type_icon_list.get(type)
	if icon:
		icon.visible = true
	_apply_color()


func _update_progress() -> void:
	_animatedSpriteProgress.frame = int(floor(energy_count * PROGRESS_LAST_FRAME / float(max_energy)))


func _charge_ratio() -> float:
	return clampf(energy_count / float(max_energy), 0.0, 1.0)

func _apply_color() -> void:
	_color = Fx.enemy_color(type)
	_bolt.color = _color
	_bolt_back.color = _color.lightened(0.2)
	var spark := _color.lightened(0.5)
	_sparks_top.color = Color(spark.r * 1.5, spark.g * 1.5, spark.b * 1.5)
	_sparks_bottom.color = _sparks_top.color
	_update_look()


func _reset_arcs() -> void:
	_bolt.set_ends(ARC_TOP, ARC_BOTTOM)
	_bolt_back.set_ends(ARC_TOP, ARC_BOTTOM)
	_regenerate_arcs()
	_update_look()


# Plus la barrière est chargée, plus l'arc est tordu et change vite
func _regenerate_arcs() -> void:
	var ratio := _charge_ratio()
	var jaggedness := lerpf(JAGGEDNESS_MIN, JAGGEDNESS_MAX, ratio) * (1.0 + 1.5 * _flash)
	_bolt.jaggedness = jaggedness
	# branche seulement en fin de charge ou sur un arc de charge : elle déborde sur la barrière voisine
	_bolt.branch_count = 1 if ratio >= 0.8 or _flash > 0.5 else 0
	_bolt_back.jaggedness = jaggedness * 1.4
	_bolt.regenerate()
	_bolt_back.regenerate()
	_arc_timer.wait_time = lerpf(REGEN_SLOW, REGEN_FAST, ratio) * randf_range(0.8, 1.2)


func _update_look() -> void:
	if _short_circuit:
		return
	var ratio := _charge_ratio()
	_bolt.set_intensity(1.0 + 0.25 * ratio + 0.5 * _flash)
	_bolt_back.set_intensity(0.55 + 0.25 * ratio + 0.4 * _flash)
	_halo.self_modulate = Color(_color, 0.16 + 0.12 * ratio + 0.15 * _flash)
	var sparks := ratio >= 0.5 or _flash > 0.0
	_sparks_top.emitting = sparks
	_sparks_bottom.emitting = sparks
	_sparks_top.speed_scale = 0.6 + ratio
	_sparks_bottom.speed_scale = _sparks_top.speed_scale


func _on_arc_tick() -> void:
	if _short_circuit:
		_short_circuit_tick()
	else:
		_regenerate_arcs()


# Arc bref et plus brillant à chaque énergie reçue
func _charge_arc() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash = 1.0
	_regenerate_arcs()
	_update_look()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(value: float):
		_flash = value
		_update_look()
	, 1.0, 0.0, 0.25)


# Ouverture : arcs brisés qui crépitent puis s'éteignent
func _start_short_circuit() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash = 0.0
	_short_circuit = true
	_sparks_top.emitting = true
	_sparks_bottom.emitting = true
	_sparks_top.speed_scale = 2.0
	_sparks_bottom.speed_scale = 2.0
	var middle: Vector2 = _barrier.global_position + (ARC_TOP + ARC_BOTTOM) * 0.5
	Fx.burst(self, _barrier.global_position + ARC_TOP, _color.lightened(0.4), 14)
	Fx.burst(self, middle, _color.lightened(0.4), 10)
	_bolt.set_intensity(2.0)
	_bolt_back.set_intensity(1.6)
	_halo.self_modulate = Color(_color, 0.6)
	_short_circuit_tick()
	# le minuteur peut être en pause hors écran : un tween garantit la fin
	_arc_timer.paused = false
	_arc_timer.start(0.04)

	if _short_circuit_tween:
		_short_circuit_tween.kill()
	_short_circuit_tween = create_tween()
	_short_circuit_tween.tween_method(func(value: float):
		_bolt.set_intensity(value)
		_bolt_back.set_intensity(value * 0.8)
		_halo.self_modulate = Color(_color, 0.3 * value)
	, 2.0, 0.0, SHORT_CIRCUIT_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_short_circuit_tween.tween_callback(_end_short_circuit)


func _short_circuit_tick() -> void:
	# coupure à une hauteur au hasard : deux tronçons séparés par un trou
	var cut := randi_range(int(ARC_TOP.y) + 16, int(ARC_BOTTOM.y) - 24)
	var gap := randi_range(5, 14)
	_bolt.jaggedness = 0.3
	_bolt.branch_count = 1
	_bolt_back.jaggedness = 0.3
	_bolt.set_ends(ARC_TOP, Vector2(ARC_TOP.x, cut))
	_bolt_back.set_ends(Vector2(ARC_TOP.x, cut + gap), ARC_BOTTOM)
	_bolt.regenerate()
	_bolt_back.regenerate()
	_arc_timer.wait_time = 0.04


func _end_short_circuit() -> void:
	_short_circuit = false
	_arc_timer.stop()
	_sparks_top.emitting = false
	_sparks_bottom.emitting = false
	_barrier.visible = false
