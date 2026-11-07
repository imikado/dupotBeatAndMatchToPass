shader_type canvas_item;

// Foreground bushes in the wind: each pixel column bobs up and down by whole pixels,
// a slow wave running along the strip.
uniform float amplitude = 1.0;   // in pixels
uniform float speed = 1.7;
uniform float wavelength = 46.0; // in pixels

varying vec4 tint; // vertex colour × modulate (fragment COLOR already holds the texture)

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	float column = floor(UV.x * size.x);
	float wave = sin(TIME * speed - column * 6.2831 / wavelength)
		+ 0.5 * sin(TIME * speed * 1.9 + column * 0.37);
	float offset = round(wave * amplitude / 1.5);
	vec2 uv = vec2(UV.x, (floor(UV.y * size.y) + offset + 0.5) * TEXTURE_PIXEL_SIZE.y);
	COLOR = texture(TEXTURE, uv) * tint;
}
