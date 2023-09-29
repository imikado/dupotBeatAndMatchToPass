extends Control


onready var _menuButton:=get_node("menuButton")

onready var _controlsBoxEnabled :=get_node("Control/VBoxContainer/HBoxContainer/contolsEnabled")
onready var _controlsBoxDisabled :=get_node("Control/VBoxContainer/HBoxContainer/contolsDisabled")

onready var _controlsMap := get_node("controlsMap")

onready var _modal:=get_node("modalKey")

var recordingEnabled=false
var recordingAction

func _ready() -> void:
	close_modal()
	_menuButton.connect("released",self,"goto_menu")
	update_controlsEnabled_toggle(Game.isControlsEnabled())
	


func open_modal():
	_modal.visible=true
	
func close_modal():
	_modal.visible=false

func open_controlsMap():
	_controlsMap.visible=true
	
func close_controlsMap():
	_controlsMap.visible=false
	


func goto_menu():
	get_tree().change_scene("res://src/UI/menu.tscn")


func update_controlsEnabled_toggle(enabled: bool) -> void:
	_controlsBoxEnabled.visible=false
	_controlsBoxDisabled.visible=false
	
	if enabled:
		_controlsBoxEnabled.visible=true
		close_controlsMap()
	else:
		_controlsBoxDisabled.visible=true
		open_controlsMap()


func update_and_save_controlsEnabled_toggle(enabled:bool)->void:
	update_controlsEnabled_toggle(enabled)
	Game.setControlsEnabled(enabled)
	
	
func _on_contolsEnabled_pressed() -> void:
	update_and_save_controlsEnabled_toggle(false)

func _on_contolsDisabled_pressed() -> void:
	update_and_save_controlsEnabled_toggle(true)

func record_keymap(action):
	print('record:'+str(action))
	recordingAction=action
	recordingEnabled=true
	open_modal()
	
func _unhandled_key_input(event: InputEventKey) -> void:
	if event is InputEventKey and event.pressed and recordingEnabled:
		
		var ev = InputEventKey.new()
		ev.scancode =event.scancode
		
		#if InputMap.has_action(recordingAction):
		#	InputMap.erase_action(recordingAction)
		InputMap.action_add_event(recordingAction,ev)
		
		close_modal()
		recordingEnabled=false
	
		return
	

func _on_right_pressed() -> void:
	record_keymap(PlayerAbstractState.INPUT_RIGHT)

func _on_left_pressed() -> void:
	record_keymap(PlayerAbstractState.INPUT_LEFT)
	
func _on_down_pressed() -> void:
	record_keymap(PlayerAbstractState.INPUT_DOWN)

func _on_up_pressed() -> void:
	record_keymap(PlayerAbstractState.INPUT_UP)


func _on_attack_pressed() -> void:
	record_keymap(PlayerAbstractState.INPUT_ATTACK)


func _on_manaAttack_pressed() -> void:
	record_keymap(PlayerAbstractState.INPUT_ATTACK_MANA)
