extends CanvasLayer

signal movePlayer(joystickVector_)

signal pushButton
signal releaseButton
 
var joystick_speed = 0;
var joystick_angle = 0;
var joystick_vector = Vector2();

var _isEnable=true

var keyboardEnabled=false

func _ready():
	if Game.isControlsEnabled():
		enable()
	else:
		disable()


func enable():
	if not Game.isControlsEnabled():
		return
		
	_isEnable=true
	$button.visible=true
	$"joystick-big".visible=true

func disable():
	_isEnable=false
	$button.visible=false
	$"joystick-big".visible=false

func _on_button_pushButton():
	if _isEnable:
		emit_signal("pushButton")

func _on_button_releaseButton():
	if _isEnable:
		emit_signal("releaseButton")

func _on_joystickbig_moveJoystick(joystickVector_):
	if _isEnable:
		emit_signal("movePlayer",joystickVector_)

func enableButton():
	$button.visible=true

func _on_HUD_refreshTouchUi():
	if Game.isControlsEnabled():
		enable()
	else:
		disable()
	pass # Replace with function body.


func _on_player_useKeyboard():
	keyboardEnabled=true
	_on_HUD_refreshTouchUi()
