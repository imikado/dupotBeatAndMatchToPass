shader_type canvas_item;

// Atmospheric perspective for the tree layers: far layers fade toward a dark blue fog,
// the nearest one gets more contrast. The layer modulate (storm tint) still applies on top.
uniform vec4 fog_color : source_color = vec4(0.04, 0.09, 0.16, 1.0);
uniform float fog : hint_range(0.0, 1.0) = 0.0;
uniform float brightness = 1.0;
uniform float contrast = 1.0;

varying vec4 tint; // vertex colour × modulate (fragment COLOR already holds the texture)

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = c.rgb;
	float luma = dot(rgb, vec3(0.3, 0.59, 0.11));
	rgb = mix(vec3(luma), rgb, 1.0 - fog * 0.5);  // fog also desaturates
	rgb = (rgb - 0.06) * contrast + 0.06;
	rgb = mix(rgb * brightness, fog_color.rgb, fog);
	COLOR = vec4(clamp(rgb, 0.0, 1.0), c.a) * tint;
}
