extends Node

const START_SCORE = 0
const START_LIFE = 100
const START_MANA = 10
# 4 tempêtes en réserve au plus
const MAX_MANA = 40

const STREAK_STEP = 5
const MAX_MULTIPLIER = 4

# Les niveaux 1 à 3 introduisent les ennemis, la difficulté augmente ensuite
const DIFFICULTY_START_LEVEL = 3

# Mode 2 joueurs sur le même écran (score et combo partagés, une vie et une mana chacun)
const REVIVE_LIFE = 50
# mana gagnée divisée par deux en mode 2 joueurs (deux orages possibles)
const COOP_MANA_GAIN_FACTOR = 0.5

var two_players := false

var _score = 0
var life = START_LIFE
var life2 = START_LIFE
var mana = START_MANA
var mana2 = START_MANA
var _level = 1

var attack_amount_mana = 10

var kill_streak = 0


func set_level(level):
	_level = level


func get_level():
	return _level


# 0 jusqu'au niveau 3, puis +1 par niveau
func get_difficulty() -> int:
	return max(0, _level - DIFFICULTY_START_LEVEL)


func reset_game():
	_level = 1
	_score = START_SCORE
	life = START_LIFE
	life2 = START_LIFE
	mana = START_MANA
	mana2 = START_MANA
	kill_streak = 0


func get_score():
	return _score


func save_score(score):
	_score = score


# index : 0 joueur 1 (et solo), 1 joueur 2
func get_mana(index := 0) -> float:
	return mana2 if index == 1 else mana


func set_mana(value, index := 0) -> void:
	if index == 1:
		mana2 = value
	else:
		mana = value


func increment_mana(value, index := 0):
	if two_players:
		value *= COOP_MANA_GAIN_FACTOR
	set_mana(min(get_mana(index) + value, MAX_MANA), index)


func use_amount_mana(value, index := 0):
	set_mana(get_mana(index) - value, index)


func can_use_amount_mana(value, index := 0):
	return get_mana(index) >= value


func decrease_health(value):
	life -= value


func update_life(value):
	life = value


func register_kill() -> int:
	kill_streak += 1
	return get_multiplier()


func get_multiplier() -> int:
	return min(1 + kill_streak / STREAK_STEP, MAX_MULTIPLIER)


func reset_streak():
	kill_streak = 0


func get_player_life(index: int) -> float:
	return life2 if index == 1 else life


func set_player_life(index: int, value: float) -> void:
	if index == 1:
		life2 = value
	else:
		life = value


func is_anyone_alive() -> bool:
	if two_players:
		return life > 0 or life2 > 0
	return life > 0


# Fin de niveau en coop : le joueur tombé revient au suivant avec la moitié de sa vie
func revive_downed() -> void:
	if not two_players:
		return
	if life <= 0:
		life = REVIVE_LIFE
	if life2 <= 0:
		life2 = REVIVE_LIFE
