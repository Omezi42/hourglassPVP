shader_type canvas_item;
// 泉地(オアシス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は節の重なる椰子の幹、板は砂丘の縞と水辺。天板の上に2本の椰子と澄んだ泉。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PALM = vec3(0.60, 0.44, 0.28);
const vec3 FROND = vec3(0.30, 0.62, 0.30);
const vec3 DUNE = vec3(0.90, 0.76, 0.52);
const float TRUNK_R = 0.044;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 POND = vec2(0.0, 1.205);
const float POND_K = 1.2;

// 椰子の幹: 下向きの山形の節が重なる
void palm_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - TRUNK_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / TRUNK_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(PALM, n, 0.0, 0.4, f.ao);
	float seg = fract((f.p.y + abs(lx) * 0.8) / 0.060);
	c = mix(c, PALM * 0.55, smoothstep(0.78, 0.95, seg) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(PALM), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), FROND, 0.0);
}

void dune_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, DUNE, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float ripple = abs(fract((q.y + 0.012 * sin(q.x * 9.0)) / 0.022) - 0.5);
	inlay(acc, d, DUNE * 0.78, (1.0 - smoothstep(0.06, 0.18, ripple)) * step(abs(q.x), 0.76) * smoothstep(0.03, 0.012, f.px), f);
	// 中央の水辺
	inlay(acc, d, mix(sand_color, vec3(1.0), 0.15), cov(sd_ellipse(q, vec2(0.150, 0.034)), f.px), f);
	inlay(acc, d, vec3(1.0), cov(sd_ellipse(q - vec2(-0.04, 0.010), vec2(0.040, 0.006)), f.px) * 0.6, f);
}

void palm_tree(inout vec4 acc, Px f, vec2 base, float lean) {
	vec2 q = (f.p - base) / POND_K;
	// 曲がった幹
	float t = clamp(q.y / 0.095, 0.0, 1.0);
	float x = q.x - lean * t * t * 0.060;
	float d_trunk = max(abs(x) - (0.012 - t * 0.004), max(-q.y, q.y - 0.095));
	part(acc, d_trunk, ink_of(PALM), mix(PALM, PALM * 0.7, step(0.5, fract(q.y / 0.020))), f.ow * 0.5, f.px);
	vec2 top = vec2(lean * 0.060, 0.095);
	for (int k = 0; k < 5; k++) {
		float a = -0.3 + float(k) * 0.9 - 1.2;
		vec2 dir = vec2(cos(a + 1.57), sin(a + 1.57));
		vec2 fq = q - top;
		float along = dot(fq, dir);
		float across = dot(fq, vec2(-dir.y, dir.x)) + along * along * 2.0;
		float d_frond = max(abs(across) - 0.018 * (1.0 - along / 0.080), max(-along, along - 0.080));
		part(acc, d_frond, ink_of(FROND), mix(FROND, FROND * 1.25, step(0.0, across)), f.ow * 0.5, f.px);
	}
	draw_ball(acc, f, base + (top + vec2(0.0, -0.010)) * POND_K, 0.012 * POND_K, PALM * 0.7, 0.0);
}

void oasis_scene(inout vec4 acc, Px f) {
	vec2 q = (f.p - POND) / POND_K;
	if (abs(q.x) > 0.26 + f.pad || q.y < -0.10 - f.pad || q.y > 0.19 + f.pad) {
		return;
	}
	f.px /= POND_K;
	f.ow /= POND_K;
	palm_tree(acc, f, POND + vec2(-0.090, -0.040) * POND_K, -1.0);
	palm_tree(acc, f, POND + vec2(0.100, -0.045) * POND_K, 1.0);
	// 砂の小島と泉
	part(acc, sd_ellipse(q - vec2(0.0, -0.060), vec2(0.200, 0.032)), ink_of(DUNE), shade_mat(DUNE, normalize(vec3(q.x / 0.2 * 0.4, 0.6, 0.7)), 0.0, 0.4, 1.0), f.ow * 0.7, f.px);
	vec2 wq = q - vec2(0.0, -0.058);
	part(acc, sd_ellipse(wq, vec2(0.110, 0.018)), ink_of(sand_color), mix(sand_color, vec3(1.0), 0.1 + 0.3 * step(wq.y, -0.004)), f.ow * 0.5, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	palm_post(acc, f, -POST_X);
	palm_post(acc, f, POST_X);
	draw_collars(acc, f, FROND, 0.0);
	dune_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		oasis_scene(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
