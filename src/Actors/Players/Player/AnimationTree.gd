extends AnimationTree

const IDLE:="idle"
const WALKING_RIGHT:="walking_right"
const WALKING_LEFT:="walking_left"
const ATTACK_1_RIGHT:="attack_01_right"

onready var player: KinematicBody2D = owner
onready var playback: AnimationNodeStateMachinePlayback = get("parameters/playback")

var _state:=IDLE

func _ready():
	playback.start(IDLE)
	active=true
	
func updateAttackRight():
	updateState(ATTACK_1_RIGHT)
	

	
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

	
