shader_type canvas_item;
uniform vec4 terrain_tone : source_color = vec4(0.65, 0.73, 0.57, 1.0);
uniform float detail_strength : hint_range(0.0, 1.0) = 0.4;
varying vec4 item_tint;
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	COLOR = vec4(mix(terrain_tone.rgb, texel.rgb, detail_strength), texel.a) * item_tint;
}
