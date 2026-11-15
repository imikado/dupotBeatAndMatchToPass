class_name PowerUp
extends Node2D

# Power-up posé sur le trajet : orbe d'attaque (épée, orange) ou de mana (éclair, bleu).
# Ramassé par un joueur : Events.player_took_power_up(power_up, player), le niveau donne l'XP.
# Éphémère (lifetime > 0) : BEATS battements répartis sur lifetime, chacun un éclat lumineux
# suivi d'un retour au sombre et d'une onde au sol, de plus en plus faibles ; puis il s'éteint.

const KIND_ATTACK := GlobalPlayer.PROGRESS_ATTACK
const KIND_MANA := GlobalPlayer.PROGRESS_MANA

const COLORS := {KIND_ATTACK: Color("ff9f43"), KIND_MANA: Color("74b9ff")}
const SIZE := 13
const BOB_HEIGHT := 3.0
const BOB_PERIOD := 1.2
const GLOW_SCALE := 0.22
# battements comptables : un éclat net (type sonar) par battement, chacun plus faible
const BEATS := 5
# montée et descente de l'éclat, en fraction de la période ; le reste est sombre
const FLASH_RISE := 0.05
const FLASH_DECAY := 0.8
# opacité / luminosité du dernier battement (le premier vaut 1)
const LAST_BEAT_STRENGTH := 0.3
# opacité minimale entre deux battements : l'orbe ne disparaît jamais complètement
const MIN_ALPHA := 0.1
const PING_RADIUS := 22.0

static var _textures := {}

var kind := KIND_ATTACK
# porte l'orbe et son halo, qui flottent ensemble
var _body: Node2D
var _sprite: Sprite2D
var _glow: Sprite2D
var _taken := false
# 0 : permanent
var lifetime := 0.0
var _age := 0.0
var _last_beat := -1
# power-up du trajet : les battements ne commencent qu'à son entrée à l'écran
var wait_on_screen := false
var _beating := false


static func create(kind_: String, lifetime_ := 0.0, wait_on_screen_ := false) -> PowerUp:
	var power_up := PowerUp.new()
	power_up.kind = kind_
	power_up.lifetime = lifetime_
	power_up.wait_on_screen = wait_on_screen_
	return power_up


func is_ephemeral() -> bool:
	return lifetime > 0.0


# apparu au hasard devant le joueur (pas posé sur le trajet)
func is_random_spawn() -> bool:
	return is_ephemeral() and not wait_on_screen


func start_beating() -> void:
	if _beating or _taken:
		return
	_beating = true
	set_process(true)


# 1 à l'apparition, 0 à l'extinction (toujours 1 pour un power-up permanent)
func light() -> float:
	return 1.0 if not is_ephemeral() else clampf(1.0 - _age / lifetime, 0.0, 1.0)


func _ready() -> void:
	var color: Color = COLORS[kind]
	Fx.shadow(self, 8).position = Vector2(0, 7)

	_body = Node2D.new()
	add_child(_body)

	var glow := Sprite2D.new()
	glow.texture = Fx.radial_texture()
	glow.material = Fx.additive_material()
	glow.modulate = Color(color, 0.45)
	glow.scale = Vector2(GLOW_SCALE, GLOW_SCALE)
	_body.add_child(glow)
	_glow = glow

	_sprite = Sprite2D.new()
	_sprite.texture = texture(kind)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.add_child(_sprite)

	var bob := create_tween().set_loops()
	bob.tween_property(_body, "position:y", -BOB_HEIGHT, BOB_PERIOD / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not is_ephemeral():
		bob.parallel().tween_property(glow, "modulate:a", 0.7, BOB_PERIOD / 2)
	bob.tween_property(_body, "position:y", 0.0, BOB_PERIOD / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not is_ephemeral():
		bob.parallel().tween_property(glow, "modulate:a", 0.45, BOB_PERIOD / 2)
	else:
		# le halo n'est porté que par le battement : éteint au repos, plein sur le coup
		glow.modulate.a = 1.0

	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)

	set_process(false)
	if wait_on_screen:
		_glow.self_modulate.a = 0.55
		var notifier := VisibleOnScreenNotifier2D.new()
		notifier.rect = Rect2(-10, -10, 20, 20)
		notifier.screen_entered.connect(start_beating)
		add_child(notifier)
	elif is_ephemeral():
		start_beating()
		scale = Vector2.ZERO
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _taken:
		return
	_age += delta
	var period := lifetime / BEATS
	var beat := int(_age / period)
	if beat >= BEATS:
		fade_out()
		return
	var strength := lerpf(1.0, LAST_BEAT_STRENGTH, float(beat) / maxf(BEATS - 1, 1))
	if beat != _last_beat:
		_last_beat = beat
		ping(strength)
	var intensity := strength * heartbeat(fmod(_age, period) / period)
	# clignotement : orbe pâle au repos (jamais invisible), éclat lumineux sur chaque coup
	var alpha := lerpf(MIN_ALPHA, 1.0, intensity)
	_body.modulate.a = alpha
	_glow.self_modulate.a = alpha
	_glow.scale = Vector2.ONE * GLOW_SCALE * lerpf(0.5, 1.4, intensity)
	# pas d'assombrissement au repos : une orbe noire à faible opacité serait invisible
	var brightness := lerpf(1.0, 1.8, intensity)
	_sprite.self_modulate = Color(brightness, brightness, brightness)
	_sprite.scale = Vector2.ONE * (1.0 + 0.15 * intensity)


# 0..1 sur une période : 1 sur le coup, redescend à 0 avant le battement suivant (opacité plancher MIN_ALPHA)
static func heartbeat(phase: float) -> float:
	if phase < FLASH_RISE:
		return phase / FLASH_RISE
	return pow(clampf(1.0 - (phase - FLASH_RISE) / FLASH_DECAY, 0.0, 1.0), 2)


# onde au sol à chaque battement, plus petite et plus pâle à mesure qu'il faiblit
func ping(strength: float) -> void:
	if get_parent() == null:
		return
	Fx.ring(get_parent(), global_position + Vector2(0, 7), Color(COLORS[kind], strength), PING_RADIUS * lerpf(0.5, 1.0, strength), 0.45)


func _on_body_entered(body: Node) -> void:
	if _taken or not (body is Player) or not body.is_alive():
		return
	_taken = true
	Events.player_took_power_up.emit(self, body)
	collect()


# l'orbe grossit et s'efface
func collect() -> void:
	set_process(false)
	modulate.a = 1.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


# éteint sans avoir été ramassé : l'orbe se rétracte
func fade_out() -> void:
	_taken = true
	set_process(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.3).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)


# Orbe en pixels : disque bordé, reflet, et glyphe (épée ou éclair) au centre
static func texture(kind_: String) -> ImageTexture:
	if _textures.has(kind_):
		return _textures[kind_]
	var color: Color = COLORS[kind_]
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := (SIZE - 1) / 2.0
	for y in range(SIZE):
		for x in range(SIZE):
			var distance := Vector2(x - center, y - center).length()
			if distance <= center + 0.3:
				image.set_pixel(x, y, color.darkened(0.55) if distance > center - 0.9 else color.darkened(0.15))
	for point in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4)]:
		image.set_pixelv(point, color.lightened(0.6))
	var glyph: Array
	if kind_ == KIND_MANA:
		glyph = [Vector2i(7, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
			Vector2i(7, 6), Vector2i(6, 7), Vector2i(6, 8), Vector2i(5, 9), Vector2i(5, 10)]
	else:
		# épée en diagonale, garde en croix
		glyph = [Vector2i(9, 3), Vector2i(8, 4), Vector2i(7, 5), Vector2i(6, 6), Vector2i(5, 7),
			Vector2i(3, 7), Vector2i(4, 8), Vector2i(5, 9), Vector2i(3, 9), Vector2i(2, 10)]
	for point in glyph:
		image.set_pixelv(point, Color.WHITE)
	_textures[kind_] = ImageTexture.create_from_image(image)
	return _textures[kind_]
