class_name ControlsTestArea
extends Node2D

# Bande de sol en bas des écrans de contrôles (1 et 2 joueurs) : le ou les héros y
# sont posés pour essayer les touches. Bornée par des murs invisibles : on ne peut pas
# en sortir. Les héros ne bougent qu'en mode essai (set_testing), sinon les touches
# de déplacement serviraient à la fois au menu et aux héros.

const PLAYER_SCENE := "res://src/Actors/Players/Player.tscn"
const PLAYER2_SCENE := "res://src/Actors/Players/Player2.tscn"
const GROUND_TEXTURE := preload("res://src/Levels/LevelTemplate/ground.png")

# sol visible, et zone de collision des héros (vue 320x180) : leur boîte de collision
# fait 12x11 au-dessus des pieds, les pieds vont donc de y 167 à 177 (les oreilles
# restent sous le panneau du menu)
# sol sur toute la largeur, juste sous le panneau du menu (pas de fond d'écran autour)
const GROUND_RECT := Rect2(0, 126, 320, 54)
const WALK_RECT := Rect2(28, 156, 264, 22)
# ombre dégradée sur le haut du sol, comme ForestBackground
const SHADE_HEIGHT := 44.0
const WALL_THICKNESS := 20.0
const SPAWN_X := [120.0, 200.0]

var players: Array[Player] = []
var _testing := false


# two_players : héros 1 et 2 avec leurs actions p1_* / p2_*, sinon héros seul avec
# les actions solo_* (PlayerInput.apply() fait avant). camera : caméra de l'écran.
func setup(two_players: bool, camera: Camera2D) -> void:
	# devant le décor de l'écran (TileMap)
	z_index = 1
	build_ground()
	build_walls()

	var count := 2 if two_players else 1
	for i in range(count):
		var player: Player = load(PLAYER2_SCENE if i == 1 else PLAYER_SCENE).instantiate()
		# la caméra du héros prendrait la main sur celle de l'écran
		player.get_node("Camera2D").enabled = false
		player.position = Vector2(SPAWN_X[i] if two_players else 160.0, WALK_RECT.end.y - 4)
		add_child(player)
		if two_players:
			player.setup_coop(i, camera)
		if i == 1:
			player.set_look_direction(Vector2.LEFT)
			player.get_node("BodyPivot").scale.x = -1
		players.append(player)

	set_testing(false)


func build_ground() -> void:
	var ground := TextureRect.new()
	ground.texture = GROUND_TEXTURE
	ground.stretch_mode = TextureRect.STRETCH_TILE
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.position = GROUND_RECT.position
	ground.size = GROUND_RECT.size
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var shade := TextureRect.new()
	shade.texture = ground_shade_texture()
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = GROUND_RECT.position
	shade.size = Vector2(GROUND_RECT.size.x, SHADE_HEIGHT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


# même dégradé que GroundShade/shade de ForestBackground.tscn
func ground_shade_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets = PackedFloat32Array([0, 0.114, 0.25, 0.386, 0.545, 0.727, 0.909])
	gradient.colors = PackedColorArray([
		Color(0, 0.01, 0.03, 0.12), Color(0, 0.01, 0.03, 0.32), Color(0, 0.01, 0.03, 0.24),
		Color(0, 0.01, 0.03, 0.17), Color(0, 0.01, 0.03, 0.11), Color(0, 0.01, 0.03, 0.06),
		Color(0, 0, 0, 0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1
	texture.height = int(SHADE_HEIGHT)
	texture.fill_to = Vector2(0, 1)
	return texture


func build_walls() -> void:
	var r := WALK_RECT
	var t := WALL_THICKNESS
	for rect in [
		Rect2(r.position.x - t, r.position.y - t, r.size.x + 2 * t, t),
		Rect2(r.position.x - t, r.end.y, r.size.x + 2 * t, t),
		Rect2(r.position.x - t, r.position.y, t, r.size.y),
		Rect2(r.end.x, r.position.y, t, r.size.y),
	]:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		shape.position = rect.get_center()
		wall.add_child(shape)
		add_child(wall)


func is_testing() -> bool:
	return _testing


func set_testing(value: bool) -> void:
	_testing = value
	# orage disponible pendant l'essai (rien n'est décompté hors d'un niveau)
	if value:
		GlobalPlayer.mana = GlobalPlayer.MAX_MANA
		GlobalPlayer.mana2 = GlobalPlayer.MAX_MANA
	for player in players:
		var machine: PlayerStateMachine = player.get_node("StateMachine")
		if not value and machine.get_current_state_name() != PlayerStateMachine.STATE_IDLE:
			machine._change_state(PlayerStateMachine.STATE_IDLE)
		machine.set_process_input(value)
		machine.set_physics_process(value)
		if not value:
			player.velocity = Vector2.ZERO
