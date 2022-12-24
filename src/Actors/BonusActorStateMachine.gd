class_name BonusActorStateMachine
extends AbstractStateMachine


const STATE_IDLE="Idle"
const STATE_WALK="Walk"
const STATE_ATTACK01="Attack01"
const STATE_ATTACK02="Attack02"
const STATE_DAMAGED="Damaged"
const STATE_DIED="Died"

func set_state_damaged():
	_change_state(STATE_DAMAGED)
	
func set_state_attack01():
	_change_state(STATE_ATTACK01)

func set_state_died():
	_change_state(STATE_DIED)
	
func set_state_walk():
	_change_state(STATE_WALK)
	
func set_state_idle():
	_change_state(STATE_IDLE)

func _ready():
	states_map = {
		STATE_IDLE: get_node(STATE_IDLE),
		STATE_WALK: get_node(STATE_WALK),

		STATE_DAMAGED:get_node(STATE_DAMAGED),
		STATE_DIED:get_node(STATE_DIED)
	}
	
	START_STATE=STATE_IDLE

func _change_state(state_name):
	
	print("change state:"+state_name)
	"""
	The base state_machine interface this node extends does most of the work
	"""
	if not _active:
		return
	if state_name in [STATE_ATTACK01,STATE_DAMAGED]:
		states_stack.push_front(states_map[state_name])
	
	._change_state(state_name)

func _input(event):
	"""
	Here we only handle input that can interrupt states, attacking in this case
	otherwise we let the state node handle it
	"""
	current_state.handle_input(event)
