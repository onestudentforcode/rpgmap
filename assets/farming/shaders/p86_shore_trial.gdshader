shader_type canvas_item;
uniform float shore_y = 896.0;
uniform vec4 land_tone : source_color = vec4(0.5804, 0.6784, 0.4980, 1.0);
varying vec2 ground_position;
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(c), hash21(c + vec2(1.0, 0.0)), f.x),
		mix(hash21(c + vec2(0.0, 1.0)), hash21(c + vec2(1.0)), f.x), f.y);
}
void vertex() {
	ground_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float line = shore_y + sin(ground_position.x / 55.0) * 2.0 + sin(ground_position.x / 19.0) * 0.65;
	float d = ground_position.y - line;
	float aa = max(fwidth(d), 0.65);
	float land = 1.0 - smoothstep(-aa, aa, d);
	float top_fade = smoothstep(shore_y - 12.0, shore_y - 7.0, ground_position.y);
	float wet_bank = (1.0 - smoothstep(1.0, 5.5, d)) * smoothstep(-2.5, 0.5, d);
	float shadow = (1.0 - smoothstep(4.5, 15.0, d)) * smoothstep(0.0, 4.0, d) * 0.27;
	float light_wave = (1.0 - smoothstep(0.45, 1.4, abs(d - 18.0))) * 0.19;
	float variation = (noise(ground_position / 116.0) - 0.5) * 0.090
		+ (noise(ground_position / 27.0) - 0.5) * 0.024;
	vec3 color = land_tone.rgb + vec3(variation);
	color = mix(color, vec3(0.57, 0.57, 0.40), wet_bank * 0.45);
	float coverage = max(land, wet_bank * 0.8);
	color = mix(vec3(0.23, 0.39, 0.33), color, coverage / max(0.001, coverage + shadow));
	float alpha = max(coverage, shadow);
	color = mix(color, vec3(0.79, 0.87, 0.78), light_wave / max(0.001, alpha + light_wave));
	alpha = max(alpha, light_wave);
	COLOR = vec4(color, alpha * top_fade);
}
