class_name ScoreReveal
extends RefCounted

# Animates a score label counting up, then shows "NEW RECORD!" when relevant


static func count_up(owner: Node, label: Label, score: int, duration: float = 1.0) -> Tween:
	label.text = "0"
	var tween := owner.create_tween()
	if score <= 0:
		return tween
	tween.tween_interval(0.3)
	tween.tween_method(func(value: int):
		if label.text != str(value):
			label.text = str(value)
			if value % 5 == 0:
				Sound.play("energy", 0.0, -12.0, 1.0 + 0.6 * float(value) / score)
		, 0, score, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		label.pivot_offset = label.size / 2
		label.scale = Vector2(1.4, 1.4)
		owner.create_tween().tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	)
	return tween


static func show_record(owner: Node, below: Label) -> void:
	var label := Label.new()
	label.text = "NEW RECORD!"
	label.add_theme_font_override("font", Fx.FONT)
	label.add_theme_font_size_override("font_size", 5)
	label.add_theme_color_override("font_color", Color("ffd34d"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(320, 10)
	below.get_parent().add_child(label)
	label.global_position = Vector2(0, below.global_position.y + below.size.y - 2)
	label.pivot_offset = label.size / 2

	Sound.play("barrier_open", 0.0)
	label.scale = Vector2(2, 2)
	var pop := owner.create_tween()
	pop.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var blink := owner.create_tween().set_loops()
	blink.tween_property(label, "modulate", Color(1.5, 1.5, 1.5), 0.3)
	blink.tween_property(label, "modulate", Color.WHITE, 0.3)
