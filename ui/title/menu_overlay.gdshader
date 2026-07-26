shader_type canvas_item;

uniform float hover_amount : hint_range(0.0, 1.0) = 0.0;
uniform float focus_amount : hint_range(0.0, 1.0) = 0.0;
uniform float pressed_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * 7.0;
	float nearby_alpha = 0.0;
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + px).a);
	nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - px).a);
	nearby_alpha = max(
		nearby_alpha,
		texture(TEXTURE, UV + vec2(px.x, -px.y)).a
	);
	nearby_alpha = max(
		nearby_alpha,
		texture(TEXTURE, UV + vec2(-px.x, px.y)).a
	);

	float halo = max(nearby_alpha - source.a, 0.0);
	float halo_strength = max(hover_amount * 0.92, focus_amount);
	vec3 hover_color = vec3(1.0, 0.45, 0.08);
	vec3 focus_color = vec3(0.55, 0.9, 1.0);
	vec3 halo_color = mix(
		hover_color,
		focus_color,
		focus_amount / max(hover_amount + focus_amount, 0.001)
	);
	vec3 ink = mix(
		source.rgb,
		min(source.rgb * 1.08 + hover_color * 0.12, vec3(1.0)),
		hover_amount
	);
	ink *= mix(1.0, 0.76, pressed_amount);

	float output_alpha = max(source.a, halo * halo_strength);
	vec3 output_color = mix(halo_color, ink, source.a);
	COLOR = vec4(output_color, output_alpha);
}
