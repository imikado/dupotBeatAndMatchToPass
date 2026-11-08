extends TouchScreenButton

# Couleurs du libellé : clair au repos, or quand le bouton est sélectionné
# (mêmes codes que le menu pause et le HUD)
const LABEL_COLOR_NORMAL = Color("c9ccff")
const LABEL_COLOR_SELECTED = Color("ffd34d")
# Bouton sélectionné : liseré doré
const TEXTURE_SELECTED = preload("res://src/UI/menu/buttonSelected.png")

@export var title="text"
@onready var _label=$Label

@onready var _lifeBottle=$lifeBottle
@onready var _texture_normal: Texture2D = texture_normal

# Marge interne : le libellé tient dans le bouton (64 px) moins 4 px de chaque côté
const LABEL_FONT_SIZE = 8
const LABEL_MARGIN_X = 4.0
const LABEL_OFFSET_Y = -1.0

func _ready() -> void:
	_label.text=title.to_upper()
	_fit_label()
	_label.add_theme_color_override("font_color", LABEL_COLOR_NORMAL)
	pass

func select()->void:
	_lifeBottle.visible=true
	_lifeBottle.play()
	_label.add_theme_color_override("font_color", LABEL_COLOR_SELECTED)
	texture_normal=TEXTURE_SELECTED
	pass
	
func deselect()->void:
	_lifeBottle.visible=false
	_lifeBottle.stop()
	_label.add_theme_color_override("font_color", LABEL_COLOR_NORMAL)
	texture_normal=_texture_normal
	pass


# Taille 8 (la seule où la police Pixeled reste nette) ; libellé trop long pour la
# largeur intérieure : lettres resserrées d'1 px plutôt qu'une taille floue.
# La ligne entière est centrée (le Label ne peut pas être moins haut qu'elle).
func _fit_label() -> void:
	var font: Font = _label.get_theme_font("font")
	var inner_width: float = texture_normal.get_width() - 2.0 * LABEL_MARGIN_X
	if font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x > inner_width:
		var tight := FontVariation.new()
		tight.base_font = font
		tight.spacing_glyph = -1
		font = tight
		_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	var line_height: float = font.get_height(LABEL_FONT_SIZE)
	_label.size = Vector2(inner_width, line_height)
	_label.position = Vector2(LABEL_MARGIN_X, round((texture_normal.get_height() - line_height) / 2.0) + LABEL_OFFSET_Y)
