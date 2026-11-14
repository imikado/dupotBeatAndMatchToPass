extends RefCounted

const NORMAL := preload("res://src/UI/menu/button.png")
const SELECTED := preload("res://src/UI/menu/buttonSelected.png")
const PRESSED := preload("res://src/UI/menu/buttonPressed.png")
const FONT := preload("res://src/Common/UI/fonts/font.tres")
const TEXT := Color("c9ccff")
const GOLD := Color("ffd34d")
const DISABLED := Color(1, 1, 1, 0.35)
const HEIGHT := 16.0


static func texture_style(texture: Texture2D, tint := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 6
	style.texture_margin_right = 6
	style.texture_margin_top = 5
	style.texture_margin_bottom = 5
	style.modulate_color = tint
	style.set_content_margin_all(0)
	return style


static func fit_label(label: Label, caption: String, size: Vector2, color := TEXT, font_size := 8) -> void:
	var font: Font = FONT
	var inner_width := size.x - 4.0
	var text := caption.to_upper()
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > inner_width:
		var tight := FontVariation.new()
		tight.base_font = FONT
		tight.spacing_glyph = -1
		font = tight
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	var line_height := font.get_height(font_size)
	label.size = Vector2(size.x, line_height)
	label.position = Vector2(0, round((size.y - line_height) / 2.0) - 1.0)


static func apply(button: Button, caption: String, selected := false, font_size := 8) -> void:
	var label := button.get_node_or_null("Label") as Label
	if label == null:
		label = Label.new()
		label.name = "Label"
		button.add_child(label)
	button.text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", texture_style(SELECTED if selected else NORMAL))
	button.add_theme_stylebox_override("hover", texture_style(SELECTED))
	button.add_theme_stylebox_override("pressed", texture_style(PRESSED))
	button.add_theme_stylebox_override("disabled", texture_style(NORMAL, Color(0.55, 0.55, 0.6, 0.7)))
	button.add_theme_stylebox_override("focus", texture_style(SELECTED))
	fit_label(label, caption, button.size, DISABLED if button.disabled else (GOLD if selected else TEXT), font_size)


static func bind_interaction(button: Button, caption: String, font_size := 8) -> void:
	button.set_meta("caption", caption)
	var update := func():
		apply(button, button.get_meta("caption"), button.has_focus() or button.is_hovered(), font_size)
	button.mouse_entered.connect(update)
	button.mouse_exited.connect(update)
	button.focus_entered.connect(update)
	button.focus_exited.connect(update)
	button.resized.connect(update)
	update.call()
