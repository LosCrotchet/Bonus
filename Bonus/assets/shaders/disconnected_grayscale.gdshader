shader_type canvas_item;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(vec3(luminance) * 0.72, source.a);
}
