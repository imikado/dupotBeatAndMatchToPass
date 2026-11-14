class_name PlayerStateMachine
extends AbstractStateMachine

const STATE_IDLE = "Idle"
const STATE_WALK = "Walk"
const STATE_ATTACK01 = "Attack01"
const STATE_ATTACK02 = "Attack02"
const STATE_ATTACK03 = "Attack03"
const STATE_ATTACK04 = "Attack04"
const STATE_DAMAGED = "Damaged"
const STATE_ATTACK_MANA01 = "AttackMana01"
const STATE_GET_LIFE_BOTTLE = "GetLifeBottle"
const STATE_GAMEOVER = "Gameover"
const STATE_DASH = "Dash"
const STATE_DASH_ATTACK = "DashAttack"

var combo_sequence := ""
# coup demandé par l'événement en cours ("R", "H" ou "") : uniquement au moment de l'appui
var attack_press := ""
var _attack_held := {}

const INPUT_ATTACK = "attack"
const INPUT_ATTACK_MANA = "attack_mana"
const INPUT_DASH = "dash"

# états depuis lesquels on peut esquiver (les coups d'épée peuvent être annulés par l'esquive)
const DASH_FROM = [STATE_IDLE, STATE_WALK, STATE_ATTACK01, STATE_ATTACK02, STATE_ATTACK03, STATE_ATTACK04]


func set_damaged():
	_change_state(STATE_DAMAGED)
	
func get_life_bottle():
	_change_state(STATE_GET_LIFE_BOTTLE)

func gameover():
	_change_state(STATE_GAMEOVER)

func _ready():
	states_map = {
		STATE_IDLE: get_node(STATE_IDLE),
		STATE_WALK: get_node(STATE_WALK),
		STATE_ATTACK01: get_node(STATE_ATTACK01),
		STATE_ATTACK02: get_node(STATE_ATTACK02),
		STATE_ATTACK03: get_node(STATE_ATTACK03),
		STATE_ATTACK04: get_node(STATE_ATTACK04),
		STATE_ATTACK_MANA01: get_node(STATE_ATTACK_MANA01),
		STATE_DAMAGED: get_node(STATE_DAMAGED),
		STATE_GET_LIFE_BOTTLE: get_node(STATE_GET_LIFE_BOTTLE),
		STATE_GAMEOVER: get_node(STATE_GAMEOVER),
		STATE_DASH: get_node(STATE_DASH),
		STATE_DASH_ATTACK: get_node(STATE_DASH_ATTACK)
	}
	super._ready()


func _change_state(state_name):
	
	if not _active:
		return
		
	if get_current_state_name() == STATE_GAMEOVER:
		return

	if get_current_state_name() == STATE_ATTACK_MANA01 and state_name!=STATE_GAMEOVER:
		return

	if not state_name in [STATE_ATTACK01, STATE_ATTACK02, STATE_ATTACK03, STATE_ATTACK04]:
		combo_sequence = ""

	super._change_state(state_name)


func _input(event):
	attack_press = _read_attack_press(event)
	# l'appui qui lance une action n'est pas transmis au nouvel état
	# (sinon l'appui qui lance Attack01 compterait déjà pour enchaîner Attack02)
	if _handle_interrupt_input(event):
		return
	super._input(event)


# front d'appui uniquement : ignore l'auto-répétition et les gâchettes analogiques
# qui envoient un événement "pressé" à chaque mouvement de l'axe
func _read_attack_press(event) -> String:
	var result := ""
	for kind in [CombatChain.HEAVY, CombatChain.LIGHT]:
		var action: String = owner.action("attack_heavy" if kind == CombatChain.HEAVY else INPUT_ATTACK)
		if not event.is_action(action):
			continue
		var pressed: bool = event.is_action_pressed(action)
		if pressed and result == "" and not (event is InputEventJoypadMotion and _attack_held.get(kind, false)):
			result = kind
		_attack_held[kind] = pressed
	return result


func _handle_interrupt_input(event) -> bool:
	"""
	Here we only handle input that can interrupt states, attacking in this case
	otherwise we let the state node handle it
	"""
	if event.is_action_pressed(owner.action(INPUT_DASH)):
		if current_state == get_node(STATE_DASH) or not owner.can_dash():
			return false
		if not current_state.name in DASH_FROM:
			return false
		_change_state(STATE_DASH)
		return true

	if attack_press != "":
		# esquive + attaque (pendant la ruée ou juste après) : attaque en puissance
		if current_state.name == STATE_DASH or (current_state.name in [STATE_IDLE, STATE_WALK] and owner.just_dashed()):
			_change_state(STATE_DASH_ATTACK)
			return true
		if not current_state.name in [STATE_IDLE, STATE_WALK]:
			return false
		if attack_press == CombatChain.HEAVY and not GlobalPlayer.can_heavy_attack(owner.player_index):
			owner.combo_feedback.emit("NOT ENOUGH MANA")
			return true
		combo_sequence = attack_press
		_change_state(STATE_ATTACK01)
		return true

	if (
		event.is_action_pressed(owner.action(INPUT_ATTACK_MANA))
		and GlobalPlayer.can_use_amount_mana(GlobalPlayer.attack_amount_mana, owner.player_index)
	):
		if [get_node(STATE_ATTACK_MANA01)].has(current_state):
			return false
		_change_state(STATE_ATTACK_MANA01)
		Events.emit_signal("player_launch_mana_attack", owner)
		return true

	return false
