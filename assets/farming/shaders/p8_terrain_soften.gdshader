shader_type canvas_item;
uniform vec4 terrain_tone : source_color = vec4(0.65, 0.73, 0.57, 1.0);
uniform float detail_strength : hint_range(0.0, 1.0) = 0.0;
uniform int surface_kind = 0;
uniform float surface_detail : hint_range(0.0, 1.5) = 1.0;
varying vec4 item_tint;
varying vec2 ground_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

float surface_marks(vec2 p, bool grass) {
	vec2 cell = floor(p);
	float seed = hash21(cell + vec2(19.2, 7.1));
	vec2 center = vec2(0.3) + vec2(hash21(cell + vec2(3.0)), hash21(cell + vec2(9.0))) * 0.4;
	vec2 local = fract(p) - center;
	float angle = (hash21(cell + vec2(5.0)) - 0.5) * 1.8;
	local = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * local;
	vec2 shape = grass ? vec2(6.5, 2.4) : vec2(5.2, 5.2);
	shape *= mix(0.75, 1.4, hash21(cell + vec2(43.0)));
	float distance_to_mark = length(local * shape);
	float aa = max(fwidth(distance_to_mark), 0.08);
	float mark = 1.0 - smoothstep(0.65 - aa, 0.65 + aa, distance_to_mark);
	float density = grass ? 0.38 + soft_noise(p / 6.0) * 0.28 : 0.40;
	return mark * step(seed, density) * (hash21(cell + vec2(27.0)) * 2.0 - 1.0);
}

void vertex() {
	item_tint = COLOR;
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	// World-space detail remains continuous across the 256 transition tiles.
	float broad = soft_noise(ground_position / 95.0) - 0.5;
	float fine = soft_noise(ground_position / 5.0) - 0.5;
	float relief = broad * 0.065 + fine * 0.022;
	float marks = surface_marks(ground_position / 8.0, surface_kind == 0);
	relief += marks * 0.085;
	if (surface_kind == 1) {
		relief = broad * 0.040 + fine * 0.018 + marks * 0.070;
	} else if (surface_kind == 2) {
		float veins = 1.0 - smoothstep(0.025, 0.060, abs(soft_noise(ground_position / 18.0) - 0.5));
		relief = broad * 0.028 + fine * 0.012 + marks * 0.040 - veins * 0.010;
	} else if (surface_kind == 3) {
		// Low rounded ridges, rather than the old high-contrast pixel stripes.
		float ridges = cos(ground_position.y * 0.392699 + broad * 0.3);
		float broken_ridges = 0.3 + soft_noise(ground_position / vec2(30.0, 8.0)) * 0.7;
		relief = broad * 0.035 + fine * 0.018 + marks * 0.065 + ridges * broken_ridges * 0.004;
	}
	vec3 surface = terrain_tone.rgb + vec3(relief * surface_detail);
	COLOR = vec4(mix(surface, texel.rgb, detail_strength), texel.a) * item_tint;
}
