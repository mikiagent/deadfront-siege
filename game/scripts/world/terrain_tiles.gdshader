shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
#include "res://shaders/sky/sky_shadow.gdshaderinc"

// Durango-style ground: one continuous surface. Bands come from height (grass -> sand ->
// wet sand -> shallow bottom -> deep) with noise-perturbed edges; the tile map only
// carries overrides (bare/harvested, mud, dirt, rock, ash). No visible tiles unless the
// grid is switched on (build mode).
uniform sampler2D tile_map_tex : filter_nearest, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// Static override masks (R rock, G ash, B mud, A dirt), mipmapped: read at a fixed LOD they are the
// tile map blurred over 2-3 m, so rock and mud patches have no 1 m (or 2.6 m cell) stair steps.
uniform sampler2D soft_tex : filter_linear_mipmap, repeat_disable;
uniform float soft_lod_rock = 1.6;
uniform float soft_lod_mud = 0.6;
// Biome zones (BiomeZones): per-2 m zone tint (linear) and layer mix (R dirt, G sand, B rock),
// mipmapped. Read at the LOD of the edge width at two noise-warped points: soft, wandering borders.
uniform sampler2D zone_tint_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D zone_mix_tex : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform float zone_texel_m = 2.0;
uniform float biome_on = 1.0;
uniform float biome_edge_m = 8.0;
uniform float biome_blend = 0.7;

uniform vec3 tint_grass = vec3(0.42, 0.62, 0.32);
uniform vec3 tint_dry = vec3(0.56, 0.54, 0.35);
uniform vec3 tint_dirt = vec3(0.44, 0.34, 0.24);
uniform vec3 tint_sand = vec3(0.79, 0.72, 0.54);
uniform vec3 tint_wet = vec3(0.55, 0.49, 0.38);
uniform vec3 tint_shallow = vec3(0.58, 0.77, 0.83);
uniform vec3 tint_rock = vec3(0.47, 0.46, 0.44);
uniform vec3 tint_mud = vec3(0.35, 0.27, 0.20);
uniform vec3 tint_bare = vec3(0.44, 0.33, 0.23);
uniform vec3 tint_deep = vec3(0.16, 0.24, 0.30);
uniform vec3 tint_ash = vec3(0.34, 0.33, 0.33);

uniform float map_size = 240.0;
uniform float tex_scale = 4.0;
uniform float h_grass = 0.55;
uniform float h_sand = 0.25;
uniform float h_wet = 0.15;
uniform float h_shallow = -0.05;
uniform float h_deep = -0.6;
// Biome knobs (BiomeMaterial sets them from biomes.json); defaults reproduce the pre-biome look.
uniform float slope_dry_lo = 0.12;
uniform float slope_dry_hi = 0.30;
uniform float slope_rock_lo = 0.32;
uniform float slope_rock_hi = 0.50;
uniform float macro_strength = 0.20;
uniform float macro_scale = 15.0;
uniform float grid_enabled = 0.0;
uniform float grid_width = 0.03;
uniform float grid_fade = 25.0;
uniform vec3 focus_pos = vec3(0.0);
// LOOKPASS: a town's ground mask (TownDress._ground_look), 1 texel per metre over town_rect
// (x0, z0, width, depth): R = wear (trodden dirt near streets, door paths and walls), G = inside the
// town (greens varied). Black (no town) leaves the ground as it was.
uniform sampler2D town_tex : hint_default_black, filter_linear, repeat_disable;
uniform vec4 town_rect = vec4(0.0, 0.0, 1.0, 1.0);

varying vec3 world_pos;
varying vec4 v_color;
varying float v_slope;

// Two samples at different scales and a rotation, blended by low-frequency noise:
// kills the visible repeat of a single tiling texture.
vec3 tex2(sampler2D t, vec2 p) {
	vec2 uv1 = p / tex_scale;
	vec2 uv2 = (mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p) / (tex_scale * 1.83);
	float k = texture(noise_tex, p / 23.0).r;
	return mix(texture(t, uv1).rgb, texture(t, uv2).rgb, clamp(k * 1.4 - 0.2, 0.0, 1.0));
}

// Override colour for a tile id, weight 1 when the id is an override type. Only BARE (harvested)
// changes at runtime; rock, ash, mud and dirt come from soft_tex.
vec4 override_for(float id, vec3 dirt) {
	if (id > 6.5 && id < 7.5) { return vec4(dirt * (tint_bare / tint_dirt), 1.0); }
	return vec4(0.0);
}

// Bilinear override mask at p: rgb = weighted colour sum, a = override weight (0..1).
vec4 override_soft(vec2 p, vec3 dirt) {
	ivec2 sz = textureSize(tile_map_tex, 0);
	vec2 t = p + vec2(map_size * 0.5) - vec2(0.5);
	vec2 i0 = floor(t);
	vec2 f = t - i0;
	vec4 acc = vec4(0.0);
	for (int k = 0; k < 4; k++) {
		vec2 c = vec2(float(k & 1), float(k >> 1));
		ivec2 ti = clamp(ivec2(i0 + c), ivec2(0), sz - ivec2(1));
		float id = floor(texelFetch(tile_map_tex, ti, 0).r * 255.0 + 0.5);
		vec2 wv = mix(vec2(1.0) - f, f, c);
		float w = wv.x * wv.y;
		vec4 o = override_for(id, dirt);
		acc += vec4(o.rgb * o.a * w, o.a * w);
	}
	return acc;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_color = COLOR;
	vec3 wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	v_slope = 1.0 - clamp(wn.y, 0.0, 1.0);
}

global uniform float weather_wet;  // WEATHER: 0 dry .. 1 soaked (WorldWeather.wet_ground)

void fragment() {
	vec2 p = world_pos.xz;
	float n = texture(noise_tex, p / 9.0).r - 0.5;
	float h = world_pos.y + n * 0.35;

	// Zone colour: the zone textures blurred to the edge width (mip LOD), read at two points warped by
	// low-frequency noise (18 m and 9 m wavelengths) and averaged, so a border is a soft band of about
	// biome_edge_m that wanders, not a line along the tile grid.
	float bw = clamp(biome_blend, 0.0, 1.0) * biome_on;
	float zlod = log2(max(biome_edge_m * (0.5 + 0.5 * bw), zone_texel_m) / zone_texel_m) * biome_on;
	vec2 w1 = vec2(texture(noise_tex, p / 414.0).r - 0.5, texture(noise_tex, p / 414.0 + vec2(0.61)).r - 0.5) * biome_edge_m;
	vec2 w2 = vec2(texture(noise_tex, p / 207.0 + vec2(0.23)).r - 0.5, texture(noise_tex, p / 207.0 + vec2(0.83)).r - 0.5) * biome_edge_m * 0.5;
	vec2 zuv1 = (p + w1 + vec2(map_size * 0.5)) / map_size;
	vec2 zuv2 = (p + w2 + vec2(map_size * 0.5)) / map_size;
	vec3 zone_t = (textureLod(zone_tint_tex, zuv1, zlod).rgb + textureLod(zone_tint_tex, zuv2, zlod).rgb) * 0.5;
	vec3 zone_m = (textureLod(zone_mix_tex, zuv1, zlod).rgb + textureLod(zone_mix_tex, zuv2, zlod).rgb) * 0.5;
	vec3 grass = tex2(grass_tex, p) * tint_grass;
	vec3 dry = tex2(grass_tex, p) * tint_dry;
	vec3 sand = tex2(sand_tex, p) * tint_sand;
	vec3 wet = tex2(sand_tex, p) * tint_wet;
	vec3 dirt = tex2(dirt_tex, p) * tint_dirt;
	vec3 rock = tex2(rock_tex, p) * tint_rock;

	vec3 base = mix(wet, sand, smoothstep(h_wet - 0.08, h_wet + 0.08, h));
	base = mix(base, grass, smoothstep(h_sand, h_grass, h));
	base = mix(wet * 0.85, base, smoothstep(h_shallow - 0.10, h_shallow + 0.05, h));
	base = mix(tint_deep, base, smoothstep(h_deep - 0.3, h_deep + 0.2, h));
	float above_sand = smoothstep(h_sand, h_sand + 0.2, h);
	base = mix(base, dry, smoothstep(slope_dry_lo, slope_dry_hi, v_slope) * above_sand);
	base = mix(base, rock, smoothstep(slope_rock_lo, slope_rock_hi, v_slope));
	// Zone layer mix (dirt, sand, rock) on dry land only; the beach band keeps its own sand.
	float on_land = smoothstep(h_sand, h_grass, h) * biome_on;
	base = mix(base, dirt, zone_m.r * on_land);
	base = mix(base, sand, zone_m.g * on_land);
	base = mix(base, rock, zone_m.b * on_land);
	// Paint the zone over whatever layer won: the tint is normalised to unit luminance so it moves
	// the hue without also darkening dark zones into black, and a per-zone brightness floor keeps
	// basalt a dark grey rock rather than a hole. Dark, near-neutral zones also flatten toward
	// their own colour at the surface's texture detail, or a multiply over a brown baked set stays brown.
	// Bright zones multiply exactly as their colour says; only dark tints are lifted toward a
	// 0.55 floor, so a near-black tint (basalt) cannot crush the ground to black while a pale one
	// (beach, rocky) never brightens past white.
	float z_luma = dot(zone_t, vec3(0.30, 0.59, 0.11));
	vec3 zt = clamp(zone_t * (1.0 + max(0.0, 0.55 - z_luma) * 1.6), 0.0, 1.0);
	float luma_b = dot(base, vec3(0.30, 0.59, 0.11));
	// The flat target is the climate's rock texture under the zone's hue, not the grass texture that
	// lost the layer fight: basalt and canyon then read as stone of that colour, not as tinted grass.
	float flat_w = clamp((1.0 - max(zone_t.r, max(zone_t.g, zone_t.b))) * 1.5, 0.0, 0.85) * biome_on;
	// Stone zones take their hue from the tint (normalised, so a near-black basalt tint still
	// names a hue) and their brightness from the rock texture with a floor: the baked volcanic set
	// is so dark that a plain multiply would render the whole island black.
	vec3 flat_hue = zone_t / max(max(zone_t.r, max(zone_t.g, zone_t.b)), 0.02);
	vec3 flat_col = flat_hue * clamp(dot(rock, vec3(0.30, 0.59, 0.11)) * 2.2, 0.34, 0.72);
	// Neutral stone stays neutral: the tint's own saturation decides, so black basalt does not
	// inherit the warm hue of a volcanic baked rock (it read maroon before this).
	float tint_sat = max(max(zone_t.r, zone_t.g), zone_t.b) - min(min(zone_t.r, zone_t.g), zone_t.b);
	float neutral = clamp(1.0 - tint_sat * 2.2, 0.0, 1.0) * flat_w;
	flat_col = mix(flat_col, vec3(dot(flat_col, vec3(0.30, 0.59, 0.11))), neutral);
	base = mix(base * zt, flat_col, flat_w);

	// Static overrides from the blurred masks, read at a point warped by ~4 m-wavelength noise so the
	// patch outlines wander instead of following the grid.
	vec2 sw = vec2(texture(noise_tex, p / 92.0).r - 0.5, texture(noise_tex, p / 92.0 + vec2(0.41)).r - 0.5) * 2.4;
	vec2 suv = (p + sw + vec2(map_size * 0.5)) / map_size;
	vec4 s_wide = textureLod(soft_tex, suv, soft_lod_rock);
	vec4 s_fine = textureLod(soft_tex, suv, soft_lod_mud);
	base = mix(base, rock, smoothstep(0.25, 0.6, s_wide.r));
	base = mix(base, rock * (tint_ash / tint_rock), smoothstep(0.25, 0.6, s_wide.g));
	base = mix(base, dirt * (tint_mud / tint_dirt), smoothstep(0.35, 0.75, s_fine.b));
	base = mix(base, dirt, smoothstep(0.35, 0.75, s_fine.a));
	// Harvested (BARE) tiles change at runtime: a bilinear mask over the 1 m tile grid, read at two
	// noise-warped points and sharpened back to a ~0.5 m edge that wanders with the noise.
	vec2 off = vec2(texture(noise_tex, p / 60.0).r - 0.5, texture(noise_tex, p / 60.0 + vec2(0.37)).r - 0.5) * 1.6;
	vec4 o0 = override_soft(p, dirt);
	vec4 o1 = override_soft(p + off, dirt);
	float ow = smoothstep(0.2, 0.8, (o0.a + o1.a) * 0.5);
	vec3 ocol = (o0.rgb + o1.rgb) / max(o0.a + o1.a, 0.001);
	vec3 albedo = mix(base, ocol, ow);

	// LOOKPASS town ground: two greens (a deeper and a sun-dried one) in ~12 m patches instead of one
	// pale wash, and worn dirt that frays out from the streets by the mask plus ~2.5 m noise.
	vec2 tn = vec2(texture(noise_tex, p / 138.0).r, texture(noise_tex, p / 138.0 + vec2(0.53)).r) - 0.5;  // noise_tex: ~23 cycles per UV, so p / (L * 23) has wavelength L m
	vec2 tw = texture(town_tex, (p + tn * 1.5 - town_rect.xy) / town_rect.zw).rg;
	float gpatch = smoothstep(0.3, 0.7, texture(noise_tex, p / (12.0 * 23.0)).r);
	vec3 greens = albedo * mix(vec3(0.62, 0.80, 0.54), vec3(0.92, 0.90, 0.64), gpatch);
	albedo = mix(albedo, greens, tw.g * on_land);
	float wn = texture(noise_tex, p / 57.0).r - 0.5;
	// Worn ground leans toward the street colour (TownDress road tint) so it reads as the path's
	// trodden edge, not a dark border.
	vec3 worn = mix(dirt, vec3(0.46, 0.39, 0.31), 0.6) * (0.88 + 0.24 * texture(noise_tex, p / 23.0).r);
	albedo = mix(albedo, worn, smoothstep(0.45, 0.75, tw.r + wn * 0.7) * on_land);

	// Macro variation: three octaves with wavelengths of 41 m, macro_scale (15 m) and 6.5 m. noise_tex
	// holds ~23 noise cycles across its tile, hence the 23.0 that turns a wavelength into a UV scale.
	float macro = texture(noise_tex, p / (41.0 * 23.0)).r * 0.5 + texture(noise_tex, p / (macro_scale * 23.0)).r * 0.3
		+ texture(noise_tex, p / (6.5 * 23.0)).r * 0.2;
	albedo *= 1.0 - macro_strength * 0.5 + macro * macro_strength;
	albedo *= v_color.rgb;

	float gx = min(fract(p.x), 1.0 - fract(p.x));
	float gz = min(fract(p.y), 1.0 - fract(p.y));
	float line = 1.0 - smoothstep(0.0, grid_width, min(gx, gz));
	float fade = 1.0 - smoothstep(grid_fade * 0.7, grid_fade, distance(p, focus_pos.xz));
	albedo *= (1.0 - 0.10 * grid_enabled * line * fade);

	// Cloud cover and flyer shadows (SKYSHADOWS), per pixel: the shapes need it on open ground.
	albedo *= sky_shade(p);

	ALBEDO = albedo * (1.0 - 0.22 * weather_wet);  // rain darkens the ground and gives it a sheen
	ROUGHNESS = mix(mix(0.55, 1.0, smoothstep(h_wet - 0.05, h_wet + 0.12, h)), 0.35, 0.6 * weather_wet);
	SPECULAR = mix(0.05, 0.3, weather_wet);
}
