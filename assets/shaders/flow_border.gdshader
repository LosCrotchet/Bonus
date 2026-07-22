shader_type canvas_item;

uniform bool bonus_mode = false;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float border_width = 3.0;

vec3 rainbow(float value) {
	return 0.55 + 0.45 * cos(6.28318 * (value + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	vec2 pixel_distance = min(UV, vec2(1.0) - UV) * rect_size;
	float edge_distance = min(pixel_distance.x, pixel_distance.y);
	float border = 1.0 - smoothstep(border_width * 0.55, border_width, edge_distance);
	float travel = fract(UV.x * 0.8 + UV.y * 0.35 + TIME * 0.22);
	vec3 gold_a = vec3(1.0, 0.56, 0.08);
	vec3 gold_b = vec3(1.0, 0.94, 0.48);
	vec3 gold = mix(gold_a, gold_b, 0.5 + 0.5 * sin(travel * 18.8495));
	vec3 color = bonus_mode ? rainbow(travel) : gold;
	COLOR = vec4(color, border * (0.78 + 0.22 * sin(TIME * 3.0 + travel * 12.0)));
}
