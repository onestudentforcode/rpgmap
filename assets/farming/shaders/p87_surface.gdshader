shader_type canvas_item;
// P8.7 trial: material sampling remains in logical ground space.
uniform vec2 ground_view_scale = vec2(1.0);
// Optional P8.6 representative scene only; no TIME or production-state inputs.
uniform vec4 terrain_tone : source_color = vec4(0.58, 0.67, 0.48, 1.0);
uniform int surface_kind = 0;
varying vec2 ground_position;
varying vec4 item_tint;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}
float marks(vec2 p, bool grass) {
	vec2 cell = floor(p);
	vec2 center = vec2(0.24) + vec2(hash21(cell + 3.0), hash21(cell + 9.0)) * 0.52;
	vec2 local = fract(p) - center;
	float angle = (hash21(cell + 5.0) - 0.5) * 2.1;
	local = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * local;
	float size = mix(0.72, 1.48, hash21(cell + 43.0));
	float distance_to_mark = length(local * (grass ? vec2(7.0, 2.0) : vec2(5.5)) * size);
	float aa = max(fwidth(distance_to_mark), 0.08);
	float mark = 1.0 - smoothstep(0.66 - aa, 0.66 + aa, distance_to_mark);
	return mark * step(hash21(cell + 19.2), 0.30 + noise(p / 7.0) * 0.28)
		* (hash21(cell + 27.0) * 2.0 - 1.0);
}
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy / ground_view_scale;
	item_tint = COLOR;
}
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float broad = noise(ground_position / 116.0) - 0.5;
	float middle = noise(ground_position / 27.0) - 0.5;
	float fine = noise(ground_position / 5.5) - 0.5;
	float detail = marks(ground_position / 8.0, surface_kind == 0);
	vec3 surface = terrain_tone.rgb;
	if (surface_kind == 0) {
		surface += vec3(broad * 0.090 + middle * 0.024 + fine * 0.016 + detail * 0.068);
		surface += vec3(0.012, 0.019, -0.013) * broad;
	} else if (surface_kind == 1) {
		surface += vec3(broad * 0.075 + middle * 0.029 + fine * 0.018 + detail * 0.063);
	} else if (surface_kind == 2) {
		float seams = 1.0 - smoothstep(0.014, 0.055, abs(noise(ground_position / 28.0) - 0.47));
		surface += vec3(broad * 0.045 + middle * 0.020 + fine * 0.012 + detail * 0.038 - seams * 0.012);
	} else if (surface_kind == 3) {
		float ridge = cos(ground_position.y * 0.31 + middle * 0.45);
		surface += vec3(broad * 0.060 + middle * 0.025 + fine * 0.021 + detail * 0.064
			+ ridge * 0.006 * noise(ground_position / vec2(35.0, 9.0)));
	} else {
		float wave = sin(ground_position.y * 0.078 + sin(ground_position.x * 0.019) * 0.72
			+ noise(ground_position / 98.0) * 2.2);
		float aa = max(fwidth(wave), 0.035);
		float crest = (1.0 - smoothstep(0.035, 0.035 + aa, abs(wave)))
			* (0.28 + noise(ground_position / vec2(65.0, 29.0)) * 0.58);
		surface += vec3(broad * 0.049 + middle * 0.012);
		surface = mix(surface, vec3(0.80, 0.88, 0.81), crest * 0.20);
	}
	COLOR = vec4(surface, texel.a) * item_tint;
}
