shader_type canvas_item;

uniform sampler2D noise_texture : source_color;
uniform vec4 fog_color = vec4(0.9, 0.7, 0.3, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.25;
uniform float speed_x : hint_range(-1.0, 1.0) = 0.02;
uniform float speed_y : hint_range(-1.0, 1.0) = 0.01;
uniform float pulse_speed : hint_range(0.01, 5.0) = 0.5;

void fragment() {
	vec2 speed = vec2(speed_x, speed_y);
	vec2 uv = UV + speed * TIME;
	float noise = texture(noise_texture, uv).r;
	float local_time = TIME * pulse_speed + noise * 20.0;
	float pulse = 0.5 + 0.5 * sin(local_time);
	float shape = smoothstep(0.3, 1.0, noise);
	float fog = shape * pulse;
	COLOR = vec4(fog_color.rgb, fog * density * fog_color.a);}
