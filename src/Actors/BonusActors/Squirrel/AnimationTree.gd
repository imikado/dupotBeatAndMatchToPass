extends AnimationTree

const IDLE:="idle"
const WALKING_RIGHT:="walking_right"
const WALKING_LEFT:="walking_left"
const ATTACKING_1_RIGHT:="attacking01_right"
const ATTACKING_1_LEFT:="attacking01_left"

onready var playback: AnimationNodeStateMachinePlayback = get("parameters/playback")

var _state:=IDLE

func _ready():
	playback.start(IDLE)
	active=true
	
func updateAttackingRight():
	updateState(ATTACKING_1_RIGHT)

func updateAttackingLeft():
	updateState(ATTACKING_1_LEFT)
	
func update(direction: Vector2):

	if direction.x > 0.0:
		updateState(WALKING_RIGHT)
	elif direction.x < 0.0:
		updateState(WALKING_LEFT)
	
	elif abs(direction.y) > 0.0:
		updateState(WALKING_RIGHT)	

	else:
		updateState(IDLE)

func updateState(newState:String):
	if _state==newState:
		return
	
	playback.start(newState)
	_state=newState

	
