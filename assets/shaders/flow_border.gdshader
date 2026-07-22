shader_type canvas_item;

uniform bool bonus_mode = false;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform float border_width = 3.0;
uniform float corner_radius = 6.0;

vec3 rainbow(float value) {
	return 0.55 + 0.45 * cos(6.28318 * (value + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	vec2 centered = abs(UV * rect_size - rect_size * 0.5);
	vec2 rounded_box = centered - (rect_size * 0.5 - vec2(corner_radius));
	float signed_distance = length(max(rounded_box, vec2(0.0)))
		+ min(max(rounded_box.x, rounded_box.y), 0.0) - corner_radius;
	float outer = 1.0 - smoothstep(-0.75, 0.75, signed_distance);
	float inner = 1.0 - smoothstep(
		-border_width - 0.75,
		-border_width + 0.75,
		signed_distance
	);
	float border = max(0.0, outer - inner);
	float travel = fract(UV.x * 0.8 + UV.y * 0.35 + TIME * 0.22);
	vec3 gold_a = vec3(1.0, 0.56, 0.08);
	vec3 gold_b = vec3(1.0, 0.94, 0.48);
	vec3 gold = mix(gold_a, gold_b, 0.5 + 0.5 * sin(travel * 18.8495));
	vec3 color = bonus_mode ? rainbow(travel) : gold;
	COLOR = vec4(color, border * (0.78 + 0.22 * sin(TIME * 3.0 + travel * 12.0)));
}
