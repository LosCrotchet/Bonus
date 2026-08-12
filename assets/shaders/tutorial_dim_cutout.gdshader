shader_type canvas_item;

uniform vec4 overlay_color : source_color = vec4(0.01, 0.015, 0.015, 0.55);
uniform vec4 cutout_rect = vec4(-1.0, -1.0, -1.0, -1.0);
uniform float feather = 0.0025;

void fragment() {
	float signed_edge_distance = min(
		min(UV.x - cutout_rect.x, cutout_rect.z - UV.x),
		min(UV.y - cutout_rect.y, cutout_rect.w - UV.y)
	);
	float cutout = smoothstep(-feather, feather, signed_edge_distance);
	COLOR = vec4(overlay_color.rgb, overlay_color.a * (1.0 - cutout));
}
