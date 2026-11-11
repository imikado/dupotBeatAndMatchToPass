extends CanvasLayer

@onready var _attackManaButton:=get_node("manaAttack")

# boutons tactiles (mode 1 joueur) : actions du joueur seul (PlayerInput)
const TOUCH_ACTIONS := {
	"move_left": "ui_left", "move_right": "ui_right", "move_up": "ui_up", "move_down": "ui_down",
	"attack": "attack", "attack_mana": "attack_mana", "dash": "dash",
}


func _ready() -> void:
	if(!Game.isControlsEnabled()):
		visible=false
	for button in get_children():
		if button is TouchScreenButton and TOUCH_ACTIONS.has(button.action):
			button.action = PlayerInput.prefix(PlayerInput.SOLO) + TOUCH_ACTIONS[button.action]


func enable_mana_button():
	_attackManaButton.set_modulate(Color(1,1,1,1))

func disable_mana_button():
	_attackManaButton.set_modulate(Color(1,1,1,0.5))
	
