shader_type canvas_item;

// Personnages : contour d'un pixel autour de la silhouette pour les détacher
// les uns des autres, et assombrissement quand un autre personnage est devant.

uniform vec4 outline_color : source_color = vec4(0.078, 0.047, 0.11, 1.0);
// 0 = normal, 1 = complètement dans l'ombre du personnage de devant
uniform float depth_shade : hint_range(0.0, 1.0) = 0.0;

// Couleur du sommet = modulate du nœud (flash blanc ou rouge quand on est touché).
// Dans fragment(), COLOR contient déjà la texture : on repart donc de cette valeur-là.
varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	if (color.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float neighbours = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
			+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (neighbours > 0.0) {
			color = outline_color;
		}
	} else {
		color.rgb = mix(color.rgb, color.rgb * vec3(0.45, 0.45, 0.6), depth_shade);
	}

	COLOR = color * node_modulate;
}
