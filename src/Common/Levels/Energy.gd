extends CharacterBody2D

# Énergie libérée par un ennemi tué : vole jusqu'à sa barrière puis l'incrémente

const SPEED := 100.0
const ARRIVAL_DISTANCE := 5.0

# Barrière visée (ElectricalBarrier.gd)
var _target: Node2D = null


func _ready() -> void:
	$AnimatedSprite2D.play()


func set_target(target: Node2D) -> void:
	_target = target
	# teinte et traînée de la couleur de la barrière visée
	var color := Fx.enemy_color(target.get_type())
	$AnimatedSprite2D.self_modulate = color.lightened(0.45)
	Fx.trail(self, Color(color, 0.8), 8)


func _process(delta: float) -> void:
	if _target == null:
		return
	if not is_instance_valid(_target):
		queue_free()
		return

	# move_toward ne dépasse jamais la cible, même sur une image lente
	global_position = global_position.move_toward(_target.global_position, SPEED * delta)

	if global_position.distance_to(_target.global_position) < ARRIVAL_DISTANCE:
		# increment() ignore une barrière déjà ouverte
		_target.increment()
		_target = null
		queue_free()
