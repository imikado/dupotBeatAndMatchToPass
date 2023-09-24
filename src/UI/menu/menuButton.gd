extends TouchScreenButton

export var title="text"
onready var _label=$Label

func _ready() -> void:
	_label.text=title.to_upper()
	pass
	
