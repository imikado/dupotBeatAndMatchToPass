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
# Mana gagnée par kill à l'épée / bonus de combo (pas pour un kill par l'orage)
# et toutes les 5 s (ManaTimer) ; l'orage en coûte attack_amount_mana
const MANA_PER_KILL = 0.5
const MANA_PER_TICK = 0.5

var two_players := false

# Gems (par joueur) : gagnées en tuant des ennemis, dépensées dans la boutique du niveau bonus
const GEMS_ANT = 3
const GEMS_BEETLE = 5
const GEMS_SPIDER = 6
# fin de niveau : 1 gem tous les LIFE_PER_GEM points de vie restants
const LIFE_PER_GEM = 5

var gems := [0, 0]
# gems de bonus de vie gagnées au dernier niveau terminé (écran LevelCompleted)
var last_life_bonus := [0, 0]

var _score = 0
var life = START_LIFE
var life2 = START_LIFE
var mana = START_MANA
var mana2 = START_MANA
var _level = 1

var attack_amount_mana = 20
# Attaque lourde : coûte un peu de mana (gratuite à l'entraînement)
const HEAVY_ATTACK_MANA = 5.0
var heavy_attack_free := false

var kill_streak = 0

# Progression par joueur : niveau d'attaque (dégâts de l'épée) et niveau de mana (orage).
# Seuls les power-ups ramassés sur le trajet font progresser : POWER_UPS_PER_LEVEL par niveau
# (« xp » = nombre de power-ups ramassés vers le niveau suivant, affichés en crans dans le HUD).
const PROGRESS_ATTACK = "attack"
const PROGRESS_MANA = "mana"
const ATTACK_MAX_LEVEL = 10
const MANA_MAX_LEVEL = 5
# niveau 1 : 45 % des dégâts de base, +10 % par niveau (135 % au niveau 10)
const ATTACK_DAMAGE_START = 0.45
const ATTACK_DAMAGE_STEP = 0.1
# orage : 70 % au niveau 1, +12 % par niveau
const MANA_DAMAGE_START = 0.7
const MANA_DAMAGE_STEP = 0.12
const POWER_UPS_PER_LEVEL = 4
const POWER_UP_XP = 1
# salves d'orage : une par niveau de mana jusqu'à 3, puis des éclairs en plus
const MAX_STORM_SALVOS = 3
const STORM_BOLTS_BASE = 8
# par joueur : {"attack": {"level", "xp"}, "mana": {"level", "xp"}}
var progress := [ {}, {}]

# Armes : l'épée au départ, la double hache et les bombes s'achètent à la boutique.
# L'arme utilisée se choisit en haut de l'écran (HUD) ou avec l'action « weapon ».
const WEAPON_SWORD = "sword"
const WEAPON_AXE = "axe"
const WEAPON_BOMB = "bomb"
const WEAPONS := [WEAPON_SWORD, WEAPON_AXE, WEAPON_BOMB]
const WEAPON_PRICES := {WEAPON_AXE: 680, WEAPON_BOMB: 225}
const WEAPON_TITLES := {WEAPON_SWORD: "SWORD", WEAPON_AXE: "DOUBLE AXE", WEAPON_BOMB: "BOMBS"}
var owned_weapons := [[WEAPON_SWORD], [WEAPON_SWORD]]
var current_weapon := [WEAPON_SWORD, WEAPON_SWORD]


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
	progress = [new_progress(), new_progress()]
	owned_weapons = [[WEAPON_SWORD], [WEAPON_SWORD]]
	current_weapon = [WEAPON_SWORD, WEAPON_SWORD]


func _init():
	progress = [new_progress(), new_progress()]


func has_weapon(weapon: String, index := 0) -> bool:
	return owned_weapons[index].has(weapon)


func get_weapon(index := 0) -> String:
	return current_weapon[index]


func set_weapon(weapon: String, index := 0) -> bool:
	if not has_weapon(weapon, index):
		return false
	current_weapon[index] = weapon
	return true


# Arme suivante parmi celles achetées (dans l'ordre de WEAPONS)
func next_weapon(index := 0) -> String:
	var owned: Array = WEAPONS.filter(func(weapon): return has_weapon(weapon, index))
	return owned[(owned.find(get_weapon(index)) + 1) % owned.size()]


# true si l'arme vient d'être achetée (et équipée)
func buy_weapon(weapon: String, index := 0) -> bool:
	if has_weapon(weapon, index) or gems[index] < WEAPON_PRICES[weapon]:
		return false
	gems[index] -= WEAPON_PRICES[weapon]
	owned_weapons[index].append(weapon)
	current_weapon[index] = weapon
	return true


func new_progress() -> Dictionary:
	return {PROGRESS_ATTACK: {"level": 1, "xp": 0}, PROGRESS_MANA: {"level": 1, "xp": 0}}


func progress_level(kind: String, index := 0) -> int:
	return progress[index][kind]["level"]


func progress_xp(kind: String, index := 0) -> int:
	return progress[index][kind]["xp"]


func progress_max_level(kind: String) -> int:
	return MANA_MAX_LEVEL if kind == PROGRESS_MANA else ATTACK_MAX_LEVEL


func is_progress_maxed(kind: String, index := 0) -> bool:
	return progress_level(kind, index) >= progress_max_level(kind)


func xp_to_next(_kind: String, _index := 0) -> int:
	return POWER_UPS_PER_LEVEL


# 0..1 vers le niveau suivant (1 au niveau max)
func progress_ratio(kind: String, index := 0) -> float:
	if is_progress_maxed(kind, index):
		return 1.0
	return float(progress_xp(kind, index)) / xp_to_next(kind, index)


# Ajoute de l'XP ; renvoie le nombre de niveaux gagnés
func add_xp(kind: String, amount: int, index := 0) -> int:
	var data: Dictionary = progress[index][kind]
	var gained := 0
	data["xp"] += amount
	while not is_progress_maxed(kind, index) and data["xp"] >= xp_to_next(kind, index):
		data["xp"] -= xp_to_next(kind, index)
		data["level"] += 1
		gained += 1
	if is_progress_maxed(kind, index):
		data["xp"] = 0
	return gained


func attack_level_factor(index := 0) -> float:
	return ATTACK_DAMAGE_START + ATTACK_DAMAGE_STEP * (progress_level(PROGRESS_ATTACK, index) - 1)


func mana_level_factor(index := 0) -> float:
	return MANA_DAMAGE_START + MANA_DAMAGE_STEP * (progress_level(PROGRESS_MANA, index) - 1)


# 1 orage au niveau 1, 2 au niveau 2, 3 à partir du niveau 3
func storm_salvos(index := 0) -> int:
	return mini(progress_level(PROGRESS_MANA, index), MAX_STORM_SALVOS)


# au-delà du niveau 3 : un éclair de plus par salve et par niveau
func storm_bolts(index := 0) -> int:
	return STORM_BOLTS_BASE + maxi(progress_level(PROGRESS_MANA, index) - MAX_STORM_SALVOS, 0)


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


func can_heavy_attack(index := 0) -> bool:
	return heavy_attack_free or get_mana(index) >= HEAVY_ATTACK_MANA


# true si de la mana a réellement été dépensée (effet lumineux)
func use_heavy_attack_mana(index := 0) -> bool:
	if heavy_attack_free:
		return false
	use_amount_mana(minf(HEAVY_ATTACK_MANA, get_mana(index)), index)
	Events.player_mana_changed.emit(index)
	return true


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
