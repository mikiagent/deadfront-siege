// The survivor's albedo with the look's colours (CharacterLook). mask_a and mask_b are the colour masks
// tools/blender/survivor_look_masks.py bakes for this material's atlas (base: R T-shirt, G shorts, B skin,
// A hair; face: R iris, G lips; an armour kit: R chest, G legs, B sleeves/trim, A skin). Each channel has
// a tint; a tint with alpha 0 leaves its region as painted. A tint keeps the painted shading by scaling
// the new colour with the texel's luminance over its region's mean colour (mean_*), so folds and the
// normal-map look stay. The means are source_color uniforms, decoded like the albedo texture, so the
// ratio is the same in Forward+ and in gl_compatibility. Lit like PlayerView.web_safe_mesh's material,
// which it replaces only while a colour is set.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D mask_a : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_b : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 tint_a0 : source_color = vec4(0.0);
uniform vec4 tint_a1 : source_color = vec4(0.0);
uniform vec4 tint_a2 : source_color = vec4(0.0);
uniform vec4 tint_a3 : source_color = vec4(0.0);
uniform vec4 tint_b0 : source_color = vec4(0.0);
uniform vec4 tint_b1 : source_color = vec4(0.0);
// Each channel's region's mean painted colour (survivor_look_masks.json).
uniform vec4 mean_a0 : source_color = vec4(1.0);
uniform vec4 mean_a1 : source_color = vec4(1.0);
uniform vec4 mean_a2 : source_color = vec4(1.0);
uniform vec4 mean_a3 : source_color = vec4(1.0);
uniform vec4 mean_b0 : source_color = vec4(1.0);
uniform vec4 mean_b1 : source_color = vec4(1.0);

const vec3 LUM = vec3(0.2126, 0.7152, 0.0722);

vec3 tinted(vec3 c, float l, vec4 tint, vec4 mean, float w) {
	float ref = max(dot(mean.rgb, LUM), 0.001);
	return mix(c, clamp(tint.rgb * (l / ref), 0.0, 1.0), clamp(w, 0.0, 1.0) * tint.a);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb * albedo_color.rgb;
	float l = dot(c, LUM);
	vec4 a = texture(mask_a, UV);
	vec2 b = texture(mask_b, UV).rg;
	c = tinted(c, l, tint_a0, mean_a0, a.r);
	c = tinted(c, l, tint_a1, mean_a1, a.g);
	c = tinted(c, l, tint_a2, mean_a2, a.b);
	c = tinted(c, l, tint_a3, mean_a3, a.a);
	c = tinted(c, l, tint_b0, mean_b0, b.r);
	c = tinted(c, l, tint_b1, mean_b1, b.g);
	ALBEDO = c;
	ROUGHNESS = 0.82;
}
