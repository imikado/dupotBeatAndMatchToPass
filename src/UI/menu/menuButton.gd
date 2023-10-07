extends TouchScreenButton

export var title="text"
onready var _label=$Label

onready var _lifeBottle=$lifeBottle

func _ready() -> void:
	_label.text=title.to_upper()
	pass
	
func select()->void:
	_lifeBottle.visible=true
	_lifeBottle.play()
	pass
	
func unselect()->void:
	_lifeBottle.visible=false
	_lifeBottle.stop()
	pass
