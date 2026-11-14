shader_type canvas_item;

// Silhouette d'un personnage projetée au sol : une seule teinte, plus dense aux
// pieds et qui s'estompe vers la tête. Seul l'alpha du modulate compte.
uniform vec4 shadow_color : source_color = vec4(0.03, 0.03, 0.07, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.38;
uniform float frame_height = 64.0;

varying vec4 node_modulate;
varying float frame_y;

void vertex() {
	node_modulate = COLOR;
	frame_y = VERTEX.y / frame_height + 0.5;
}

void fragment() {
	// les effets translucides (traînée d'épée) ne font pas d'ombre
	float body = step(0.95, texture(TEXTURE, UV).a);
	float fade = mix(0.35, 1.0, smoothstep(0.2, 1.0, frame_y));
	COLOR = vec4(shadow_color.rgb, body * strength * fade * node_modulate.a);
}
