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

# Gems (par joueur) : gagnées en tuant des ennemis, dépensées dans la boutique du niveau bonus
const GEMS_ANT = 3
const GEMS_BEETLE = 5
const GEMS_SPIDER = 6
# fin de niveau : 1 gem tous les LIFE_PER_GEM points de vie restants
const LIFE_PER_GEM = 5

const SKILL_SPEED = "speed"
const SKILL_ATTACK = "attack"
const SKILL_RESISTANCE = "resistance"
const SKILLS := [SKILL_SPEED, SKILL_ATTACK, SKILL_RESISTANCE]
const SKILL_BONUS_PER_LEVEL = 0.05
const SKILL_MAX_LEVEL = 10
# gems versées dans la jauge à chaque achat ; la jauge pleine fait passer un niveau
const GEMS_PER_INVEST = 5
const SKILL_COST_BASE = 25
const SKILL_COST_STEP = 15

var gems := [0, 0]
# gems de bonus de vie gagnées au dernier niveau terminé (écran LevelCompleted)
var last_life_bonus := [0, 0]
# par joueur : {skill: {"level": int, "progress": int}}
var skills := [{}, {}]

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
	gems = [0, 0]
	last_life_bonus = [0, 0]
	skills = [new_skills(), new_skills()]


func _init():
	skills = [new_skills(), new_skills()]


func new_skills() -> Dictionary:
	var result := {}
	for skill in SKILLS:
		result[skill] = {"level": 0, "progress": 0}
	return result


func get_gems(index := 0) -> int:
	return gems[index]


func add_gems(value: int, index := 0) -> void:
	gems[index] = maxi(gems[index] + value, 0)


# Gems pour un ennemi tué ; moitié s'il est tué par l'orage
func gems_for_enemy(type, by_storm: bool) -> int:
	var value := 1
	match type:
		Game.ENEMY_TYPE_LIST.ANT:
			value = GEMS_ANT
		Game.ENEMY_TYPE_LIST.BEETLE:
			value = GEMS_BEETLE
		Game.ENEMY_TYPE_LIST.SPIDER:
			value = GEMS_SPIDER
	return maxi(value / 2, 1) if by_storm else value


func gems_for_life(life_value: float) -> int:
	return int(maxf(life_value, 0.0) / LIFE_PER_GEM)


# Fin de niveau : gems selon la vie restante de chaque joueur
func grant_life_bonus() -> void:
	last_life_bonus = [0, 0]
	for index in ([0, 1] if two_players else [0]):
		last_life_bonus[index] = gems_for_life(get_player_life(index))
		add_gems(last_life_bonus[index], index)


func skill_level(skill: String, index := 0) -> int:
	return skills[index][skill]["level"]


func skill_progress(skill: String, index := 0) -> int:
	return skills[index][skill]["progress"]


func skill_cost(skill: String, index := 0) -> int:
	return SKILL_COST_BASE + SKILL_COST_STEP * skill_level(skill, index)


func is_skill_maxed(skill: String, index := 0) -> bool:
	return skill_level(skill, index) >= SKILL_MAX_LEVEL


# +5 % par niveau
func skill_factor(skill: String, index := 0) -> float:
	return 1.0 + SKILL_BONUS_PER_LEVEL * skill_level(skill, index)


# Verse des gems dans la jauge ; renvoie 0 si rien n'a été versé, 1 si versé, 2 si niveau gagné
func invest_skill(skill: String, index := 0) -> int:
	if is_skill_maxed(skill, index) or gems[index] <= 0:
		return 0
	var data: Dictionary = skills[index][skill]
	var amount := mini(mini(GEMS_PER_INVEST, gems[index]), skill_cost(skill, index) - data["progress"])
	gems[index] -= amount
	data["progress"] += amount
	if data["progress"] < skill_cost(skill, index):
		return 1
	data["level"] += 1
	data["progress"] = 0
	return 2


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
