shader_type canvas_item;
// 木の器(サンド)。GameDesign.md 9章 / Architecture.md 10.19節。
// どこにでもある砂時計: ろくろで挽いた木の柱と木の板、真鍮の受け金だけ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 WOOD = vec3(0.60, 0.37, 0.19);
const vec3 WOOD_DARK = vec3(0.42, 0.24, 0.12);
const vec3 BRASS = vec3(0.86, 0.66, 0.34);
const vec2 SLAB_HALF = vec2(0.80, 0.084);

// 木目: 長さの向きに沿った揺らぐ筋
float wood_grain(vec2 q, float px) {
	float n = vnoise(q * vec2(2.0, 9.0)) * 1.4;
	float g = abs(fract(q.y * 11.0 + n) - 0.5);
	return (1.0 - smoothstep(0.06, 0.16, g)) * smoothstep(0.03, 0.012, px);
}

void turned_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.12 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float r = post_body_r(f.ay);
	float slope = (post_body_r(f.ay + 0.01) - r) / 0.01;
	float d = max(abs(lx) - r, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), slope * f.side);
	vec3 c = shade_mat(WOOD, n, 0.0, 0.45, f.ao);
	float g = wood_grain(vec2(lx * 3.0, f.p.y * 0.25 + cx), f.px);
	c = mix(c, c * 0.86, g * 0.35);
	part(acc, d, ink_of(WOOD_DARK), c, f.ow, f.px);
	draw_ball(acc, f, vec2(cx, 0.0), BEAD_R * 0.86, WOOD, 0.0);
	draw_band(acc, f, vec2(cx, f.side * RING_Y), vec2(0.078, 0.020), WOOD_DARK, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), BRASS, 1.0);
}

void wood_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.04, WOOD, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float g = wood_grain(vec2(q.y * 6.0 + cy, q.x * 0.6), f.px);
	inlay(acc, d, WOOD_DARK, g * 0.22, f);
	// 中央の真鍮の銘板(小さな砂時計の刻み)
	float d_plate = sd_round_box(q, vec2(0.12, 0.046), 0.016);
	vec3 pn = normalize(vec3(q.x / 0.12 * 0.3, q.y / 0.046 * 0.3, 0.9));
	part(acc, d_plate, ink_of(BRASS), shade_mat(BRASS, pn, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	vec2 hq = vec2(abs(q.x), abs(q.y));
	float d_mark = max(hq.x - 0.008 - hq.y * 0.55, hq.y - 0.030);
	over(acc, ink_of(BRASS) * 1.6, cov(d_mark, f.px) * 0.8);
	// 四隅の真鍮の鋲
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		draw_ball(acc, f, vec2(sx * 0.70, cy), 0.026, BRASS, 1.0);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	turned_post(acc, f, -POST_X);
	turned_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	wood_slab(acc, f, f.side * PLATE_Y);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
