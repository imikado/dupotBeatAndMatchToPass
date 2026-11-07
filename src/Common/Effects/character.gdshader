shader_type canvas_item;

// Personnages : contour d'un pixel autour de la silhouette pour les détacher
// les uns des autres, et assombrissement quand un autre personnage est devant.
// Pour les ennemis : dissolution par pixels à la mort, silhouette carbonisée
// (mort par l'éclair) et flash de l'éclair.

uniform vec4 outline_color : source_color = vec4(0.078, 0.047, 0.11, 1.0);
// 0 = normal, 1 = complètement dans l'ombre du personnage de devant
uniform float depth_shade : hint_range(0.0, 1.0) = 0.0;

// 0 = entier, 1 = complètement dissous. Bruit d'un tirage par pixel de la texture
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
// Bord de la dissolution (couleur de l'ennemi, ou cendres) ; energy > 1 : glow HDR
uniform vec4 dissolve_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float dissolve_energy = 1.0;
// 0 = normal, 1 = silhouette noire carbonisée
uniform float char_amount : hint_range(0.0, 1.0) = 0.0;
// Flash de l'éclair, par-dessus le modulate (ne gêne pas le flash blanc/rouge des coups)
uniform vec4 flash_color : source_color = vec4(0.75, 0.88, 1.0, 1.0);
uniform float flash_energy = 1.2;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

// Part du bruit occupée par le bord coloré pendant la dissolution
const float DISSOLVE_EDGE = 0.15;
const vec3 CHAR_COLOR = vec3(0.02, 0.018, 0.018);

// Couleur du sommet = modulate du nœud (flash blanc ou rouge quand on est touché).
// Dans fragment(), COLOR contient déjà la texture : on repart donc de cette valeur-là.
varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

// Hash sans sin() (précis aussi sur mobile), une valeur 0..1 par pixel de texture
float pixel_noise(vec2 uv, vec2 px) {
	vec2 p = floor(uv / px);
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float noise = pixel_noise(UV, TEXTURE_PIXEL_SIZE);
	// seuil qui va de 0 à 1 + DISSOLVE_EDGE : rien au début, tout dissous à la fin
	float limit = dissolve * (1.0 + DISSOLVE_EDGE);
	bool is_edge = false;
	bool is_body = color.a >= 0.1;

	if (!is_body) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float neighbours = texture(TEXTURE, UV + vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a
			+ texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (neighbours > 0.0) {
			color = outline_color;
			// le contour part un peu plus tôt, pour ne pas laisser un cadre vide
			if (noise < limit * 1.3) {
				color.a = 0.0;
			}
		}
	} else {
		color.rgb = mix(color.rgb, color.rgb * vec3(0.45, 0.45, 0.6), depth_shade);
		float luminance = dot(color.rgb, vec3(0.3, 0.59, 0.11));
		color.rgb = mix(color.rgb, CHAR_COLOR + luminance * 0.08, char_amount);

		if (noise < limit - DISSOLVE_EDGE) {
			color.a = 0.0;
		} else if (noise < limit) {
			color = vec4(dissolve_color.rgb * dissolve_energy, 1.0);
			is_edge = true;
		}
	}

	if (is_edge) {
		// le bord garde sa couleur, seul l'alpha du modulate compte
		COLOR = vec4(color.rgb, color.a * node_modulate.a);
	} else {
		COLOR = color * node_modulate;
		if (is_body) {
			COLOR.rgb = mix(COLOR.rgb, flash_color.rgb * flash_energy, flash);
		}
	}
}
