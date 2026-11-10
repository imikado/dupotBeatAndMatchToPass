class_name Coop

# Mise en place du mode 2 joueurs dans un niveau (LevelTemplate, LevelBonus)

# chargé à l'exécution, pas en preload : le boot charge LevelTemplate et LevelBonus dans
# des threads en parallèle, et un preload de Player2.tscn (mêmes scripts que Player.tscn) ici les bloque mutuellement
# joueur 2 : copie du joueur avec la fourrure bleu-gris (tools/generate_player2.py)
const PLAYER2_SCENE_PATH := "res://src/Actors/Players/Player2.tscn"
# Le joueur 2 démarre un peu derrière et en dessous du joueur 1
const P2_OFFSET := Vector2(-14, 22)


# Crée le joueur 2 et la caméra partagée ; les points d'apparition des ennemis
# (enfants du joueur 1 en solo) suivent la caméra. Renvoie [joueur 2, caméra].
static func setup_level(level: Node2D, player1: Player, ysort: Node2D, limit_rect: ReferenceRect, spawn_markers: Array) -> Array:
	PlayerInput.apply()

	var player2: Player = load(PLAYER2_SCENE_PATH).instantiate()
	ysort.add_child(player2)
	player2.global_position = player1.global_position + P2_OFFSET

	var camera := CoopCamera.new()
	camera.name = "CoopCamera"
	level.add_child(camera)

	player1.setup_coop(0, camera)
	player2.setup_coop(1, camera)
	player1.set_life(GlobalPlayer.life)
	player2.set_life(GlobalPlayer.life2)

	for marker in spawn_markers:
		marker.reparent(camera, false)

	camera.setup([player1, player2], limit_rect)

	for player in [player1, player2]:
		if not player.is_alive():
			player.down()
			player.visible = false
	return [player2, camera]
