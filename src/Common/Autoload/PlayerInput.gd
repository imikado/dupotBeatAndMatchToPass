extends Node

# Chaque joueur a ses propres actions (« p1_attack », « p2_ui_left », « solo_dash »…)
# créées à la volée dans l'InputMap à partir de la configuration choisie dans l'écran
# des contrôles (coop_setup) : joueurs 1 et 2 en mode 2 joueurs, SOLO en mode 1 joueur.
# Les actions solo gardent en plus les touches d'origine du projet (manette, télécommande
# Fire TV, boutons tactiles) tant qu'elles ne servent pas déjà à une autre action.

enum Device { KEYBOARD, GAMEPAD }

const PATH_CONFIG := "user://controls_2p.cfg"

# index de la configuration du mode 1 joueur (0 et 1 : joueurs du mode 2 joueurs)
const SOLO := 2
const COOP_INDICES := [0, 1]
const SOLO_INDICES := [SOLO]

const ACTIONS := ["ui_left", "ui_right", "ui_up", "ui_down", "attack", "attack_mana", "dash"]
const ACTION_LABELS := {
	"ui_left": "LEFT",
	"ui_right": "RIGHT",
	"ui_up": "UP",
	"ui_down": "DOWN",
	"attack": "ATTACK",
	"attack_mana": "STORM",
	"dash": "DASH",
}

const LAYOUTS := ["azerty", "qwerty"]

# P1 : main gauche sur ZQSD / WASD, main droite sur F G H
# P2 : main droite sur les flèches, main gauche sur J K L
# Solo : flèches, Espace, Ctrl, Maj (touches d'origine du jeu)
const PRESETS := {
	"azerty": [
		{"ui_left": KEY_Q, "ui_right": KEY_D, "ui_up": KEY_Z, "ui_down": KEY_S, "attack": KEY_F, "attack_mana": KEY_G, "dash": KEY_H},
		{"ui_left": KEY_LEFT, "ui_right": KEY_RIGHT, "ui_up": KEY_UP, "ui_down": KEY_DOWN, "attack": KEY_L, "attack_mana": KEY_K, "dash": KEY_J},
		{"ui_left": KEY_LEFT, "ui_right": KEY_RIGHT, "ui_up": KEY_UP, "ui_down": KEY_DOWN, "attack": KEY_SPACE, "attack_mana": KEY_CTRL, "dash": KEY_SHIFT},
	],
	"qwerty": [
		{"ui_left": KEY_A, "ui_right": KEY_D, "ui_up": KEY_W, "ui_down": KEY_S, "attack": KEY_F, "attack_mana": KEY_G, "dash": KEY_H},
		{"ui_left": KEY_LEFT, "ui_right": KEY_RIGHT, "ui_up": KEY_UP, "ui_down": KEY_DOWN, "attack": KEY_L, "attack_mana": KEY_K, "dash": KEY_J},
		{"ui_left": KEY_LEFT, "ui_right": KEY_RIGHT, "ui_up": KEY_UP, "ui_down": KEY_DOWN, "attack": KEY_SPACE, "attack_mana": KEY_CTRL, "dash": KEY_SHIFT},
	],
}

const GAMEPAD_BUTTONS := {
	"ui_left": JOY_BUTTON_DPAD_LEFT,
	"ui_right": JOY_BUTTON_DPAD_RIGHT,
	"ui_up": JOY_BUTTON_DPAD_UP,
	"ui_down": JOY_BUTTON_DPAD_DOWN,
	"attack": JOY_BUTTON_A,
	"attack_mana": JOY_BUTTON_B,
	"dash": JOY_BUTTON_X,
}
const GAMEPAD_AXES := {
	"ui_left": [JOY_AXIS_LEFT_X, -1.0],
	"ui_right": [JOY_AXIS_LEFT_X, 1.0],
	"ui_up": [JOY_AXIS_LEFT_Y, -1.0],
	"ui_down": [JOY_AXIS_LEFT_Y, 1.0],
}
const GAMEPAD_MOVE_LABEL := "STICK / PAD"

# Boutons d'action modifiables à la manette (le déplacement reste croix + stick gauche).
# Valeur >= TRIGGER_BASE : gâchette analogique (TRIGGER_BASE + axe)
const GAMEPAD_REMAPPABLE := ["attack", "attack_mana", "dash"]
const TRIGGER_BASE := 100
const TRIGGER_THRESHOLD := 0.6
# Réservés : déplacement (croix) et pause (Start, Select, Home)
const GAMEPAD_RESERVED := [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
	JOY_BUTTON_START, JOY_BUTTON_BACK, JOY_BUTTON_GUIDE]
const BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_MISC1: "SHARE", JOY_BUTTON_TOUCHPAD: "TOUCHPAD",
	JOY_BUTTON_PADDLE1: "P1", JOY_BUTTON_PADDLE2: "P2", JOY_BUTTON_PADDLE3: "P3", JOY_BUTTON_PADDLE4: "P4",
	TRIGGER_BASE + JOY_AXIS_TRIGGER_LEFT: "LT", TRIGGER_BASE + JOY_AXIS_TRIGGER_RIGHT: "RT",
}

const DEADZONE := 0.5

var layout := "qwerty"
# false pendant la démo enregistrée (DemoTour) : la config du joueur n'est pas écrasée
var save_enabled := true
# un dictionnaire par joueur : {"device": Device, "keys": {action: keycode}, "buttons": {action: bouton}}
var players := []


func _ready() -> void:
	layout = detect_layout()
	players = [
		{"device": Device.KEYBOARD, "keys": PRESETS[layout][0].duplicate(), "buttons": default_buttons()},
		{"device": Device.GAMEPAD if Input.get_connected_joypads().size() > 0 else Device.KEYBOARD, "keys": PRESETS[layout][1].duplicate(), "buttons": default_buttons()},
		{"device": Device.KEYBOARD, "keys": PRESETS[layout][SOLO].duplicate(), "buttons": default_buttons()},
	]
	load_config()
	# les héros lisent leurs actions dès le premier niveau
	apply()


func default_buttons() -> Dictionary:
	var buttons := {}
	for action in GAMEPAD_REMAPPABLE:
		buttons[action] = GAMEPAD_BUTTONS[action]
	return buttons


func is_remappable(index: int, action: String) -> bool:
	if players[index]["device"] == Device.GAMEPAD:
		return GAMEPAD_REMAPPABLE.has(action)
	return true


func set_button(index: int, action: String, button: int) -> void:
	players[index]["buttons"][action] = button


func reset_buttons(index: int) -> void:
	players[index]["buttons"] = default_buttons()


# Bouton (ou gâchette) d'une manette pour la redéfinition, -1 si l'événement ne convient pas
func button_from_event(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.pressed and not GAMEPAD_RESERVED.has(event.button_index):
		return event.button_index
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] and event.axis_value > TRIGGER_THRESHOLD:
		return TRIGGER_BASE + event.axis
	return -1


func button_label(button: int) -> String:
	return BUTTON_NAMES.get(button, "BUTTON %d" % button)


static func prefix(index: int) -> String:
	return "solo_" if index == SOLO else "p%d_" % (index + 1)


static func indices(two_players: bool) -> Array:
	return COOP_INDICES if two_players else SOLO_INDICES


func detect_layout() -> String:
	var language := ""
	if DisplayServer.has_method("keyboard_get_layout_language"):
		language = DisplayServer.keyboard_get_layout_language(DisplayServer.keyboard_get_current_layout())
	if language == "":
		language = OS.get_locale_language()
	return "azerty" if language.to_lower().begins_with("fr") or language.to_lower().begins_with("be") else "qwerty"


func set_layout(new_layout: String) -> void:
	layout = new_layout
	for i in range(players.size()):
		players[i]["keys"] = PRESETS[layout][i].duplicate()


func set_device(index: int, device: int) -> void:
	players[index]["device"] = device


func set_key(index: int, action: String, keycode: int) -> void:
	players[index]["keys"][action] = keycode


func key_label(keycode: int) -> String:
	return OS.get_keycode_string(keycode).to_upper()


func action_label(index: int, action: String) -> String:
	if players[index]["device"] == Device.GAMEPAD:
		if GAMEPAD_REMAPPABLE.has(action):
			return button_label(players[index]["buttons"][action])
		return GAMEPAD_MOVE_LABEL
	return key_label(players[index]["keys"][action])


# Manette attribuée au joueur : les manettes branchées, dans l'ordre, aux joueurs « manette »
func gamepad_for(index: int) -> int:
	var pads := Input.get_connected_joypads()
	var rank := 0
	# le joueur seul prend la première manette ; en 2 joueurs, le joueur 2 prend la
	# deuxième si le joueur 1 est aussi à la manette
	if index != SOLO:
		for i in range(index):
			if players[i]["device"] == Device.GAMEPAD:
				rank += 1
	if players[index]["device"] != Device.GAMEPAD or rank >= pads.size():
		return -1
	return pads[rank]


func gamepad_name(index: int) -> String:
	var pad := gamepad_for(index)
	if pad < 0:
		return ""
	return Input.get_joy_name(pad).to_upper()


# Touches en double entre les joueurs clavier donnés (et pour un même joueur)
func conflicting_keys(player_indices: Array = COOP_INDICES) -> Array:
	var seen := {}
	var conflicts := []
	for i in player_indices:
		if players[i]["device"] != Device.KEYBOARD:
			continue
		for action in ACTIONS:
			var keycode: int = players[i]["keys"][action]
			if seen.has(keycode):
				conflicts.append(keycode)
			seen[keycode] = true
	return conflicts


# Boutons en double pour un même joueur manette (renvoie les actions concernées)
func conflicting_buttons(index: int) -> Array:
	var conflicts := []
	if players[index]["device"] != Device.GAMEPAD:
		return conflicts
	var buttons: Dictionary = players[index]["buttons"]
	for action in GAMEPAD_REMAPPABLE:
		for other in GAMEPAD_REMAPPABLE:
			if other != action and buttons[other] == buttons[action] and not conflicts.has(action):
				conflicts.append(action)
	return conflicts


# "" si la configuration des joueurs donnés est jouable, sinon le message à afficher
func validation_error(player_indices: Array = COOP_INDICES) -> String:
	for i in player_indices:
		if players[i]["device"] == Device.GAMEPAD and gamepad_for(i) < 0:
			return "PLUG A GAMEPAD" if i == SOLO else "PLUG A GAMEPAD FOR PLAYER %d" % (i + 1)
	if not conflicting_keys(player_indices).is_empty():
		return "SAME KEY USED TWICE"
	for i in player_indices:
		if not conflicting_buttons(i).is_empty():
			return "SAME BUTTON USED TWICE"
	return ""


# Actions p1_* / p2_* dans l'InputMap
func apply() -> void:
	for i in range(players.size()):
		var pad := gamepad_for(i)
		for action in ACTIONS:
			var action_name: String = prefix(i) + action
			if InputMap.has_action(action_name):
				InputMap.erase_action(action_name)
			InputMap.add_action(action_name, DEADZONE)
			if players[i]["device"] == Device.KEYBOARD:
				var key := InputEventKey.new()
				key.keycode = players[i]["keys"][action]
				InputMap.action_add_event(action_name, key)
			elif pad >= 0:
				var button_index: int = players[i]["buttons"].get(action, GAMEPAD_BUTTONS[action])
				if button_index >= TRIGGER_BASE:
					var trigger := InputEventJoypadMotion.new()
					trigger.device = pad
					trigger.axis = button_index - TRIGGER_BASE
					trigger.axis_value = 1.0
					InputMap.action_add_event(action_name, trigger)
				else:
					var button := InputEventJoypadButton.new()
					button.device = pad
					button.button_index = button_index
					InputMap.action_add_event(action_name, button)
				if GAMEPAD_AXES.has(action):
					var motion := InputEventJoypadMotion.new()
					motion.device = pad
					motion.axis = GAMEPAD_AXES[action][0]
					motion.axis_value = GAMEPAD_AXES[action][1]
					InputMap.action_add_event(action_name, motion)
		if i == SOLO:
			add_solo_defaults()


# Joueur seul : les touches d'origine restent valables (manette quel que soit le choix,
# télécommande Fire TV, réglages de SETTINGS) sauf celles déjà prises par une autre action
func add_solo_defaults() -> void:
	for action in ACTIONS:
		# actions d'origine du projet (modifiées par SETTINGS), jamais touchées par apply()
		for event in InputMap.action_get_events(action):
			var taken := false
			for other in ACTIONS:
				for existing in InputMap.action_get_events(prefix(SOLO) + other):
					if same_input(event, existing):
						taken = true
			if not taken:
				InputMap.action_add_event(prefix(SOLO) + action, event)


# Même touche / même bouton, que l'événement soit par keycode ou par touche physique
static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var key_a: int = a.keycode if a.keycode != KEY_NONE else a.physical_keycode
		var key_b: int = b.keycode if b.keycode != KEY_NONE else b.physical_keycode
		return key_a == key_b
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


func save_config() -> void:
	if not save_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("general", "layout", layout)
	for i in range(players.size()):
		config.set_value("player%d" % (i + 1), "device", players[i]["device"])
		config.set_value("player%d" % (i + 1), "keys", players[i]["keys"])
		config.set_value("player%d" % (i + 1), "buttons", players[i]["buttons"])
	config.save(PATH_CONFIG)


func load_config() -> void:
	var config := ConfigFile.new()
	if config.load(PATH_CONFIG) != OK:
		return
	var saved_layout: String = config.get_value("general", "layout", layout)
	if LAYOUTS.has(saved_layout):
		layout = saved_layout
	for i in range(players.size()):
		var section := "player%d" % (i + 1)
		var device = config.get_value(section, "device", players[i]["device"])
		if device in [Device.KEYBOARD, Device.GAMEPAD]:
			players[i]["device"] = device
		var keys = config.get_value(section, "keys", {})
		var merged: Dictionary = PRESETS[layout][i].duplicate()
		if keys is Dictionary:
			for action in ACTIONS:
				if keys.has(action) and typeof(keys[action]) == TYPE_INT:
					merged[action] = keys[action]
		players[i]["keys"] = merged
		var buttons = config.get_value(section, "buttons", {})
		var merged_buttons := default_buttons()
		if buttons is Dictionary:
			for action in GAMEPAD_REMAPPABLE:
				if buttons.has(action) and typeof(buttons[action]) == TYPE_INT:
					merged_buttons[action] = buttons[action]
		players[i]["buttons"] = merged_buttons
