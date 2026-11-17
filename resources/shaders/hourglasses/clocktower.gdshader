shader_type canvas_item;
// 時計塔(クロックタワー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は細い窓の並ぶ石の塔、板には時刻の刻み。天板の上に尖り屋根を戴いた時計の文字盤。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STONE = vec3(0.66, 0.62, 0.58);
const vec3 ROOF = vec3(0.24, 0.36, 0.40);
const vec3 DIAL = vec3(0.96, 0.92, 0.82);
const vec3 HAND = vec3(0.14, 0.12, 0.14);
const vec3 WINDOW = vec3(1.0, 0.86, 0.52);
const float TOWER_HALF = 0.064;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec2 FACE = vec2(0.0, 1.183);

void tower_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > TOWER_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - TOWER_HALF, f.ay - POST_H);
	vec2 g = vec2(lx / 0.064, f.p.y / 0.040);
	float row = floor(g.y);
	float joint = max(step(0.90, fract(g.y)), step(0.94, fract(g.x + 0.5 * mod(row, 2.0))));
	float face = lx / TOWER_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(STONE * (0.9 + 0.15 * hash21(vec2(floor(g.x + 0.5 * mod(row, 2.0)), row))), n, 0.0, 0.4, f.ao);
	c = mix(c, STONE * 0.6, joint * smoothstep(0.03, 0.012, f.px));
	// アーチの細窓: 灯りのともった窓とそうでない窓
	float wy = fract((f.p.y + 0.80) / 0.32) * 0.32 - 0.16;
	vec2 wq = vec2(lx, wy);
	float d_win = max(abs(wq.x) - 0.016, abs(wq.y) - 0.040);
	d_win = min(d_win, length(wq - vec2(0.0, 0.040)) - 0.016);
	float lit = step(0.45, hash21(vec2(floor((f.p.y + 0.80) / 0.32), cx)));
	vec3 wc = lit > 0.5 ? mix(WINDOW, sand_color, 0.3) : vec3(0.10, 0.10, 0.14);
	c = mix(c, wc, cov(d_win, f.px) * step(abs(f.p.y), 0.78));
	part(acc, d, ink_of(STONE * 0.6), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.028), ROOF, 0.3);
}

void hours_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, STONE, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 12の刻み: 3つごとに長い
	float k = floor(q.x / 0.12 + 0.5);
	float x0 = q.x - k * 0.12;
	float len = mod(k, 3.0) < 0.5 ? 0.050 : 0.026;
	float tick = step(abs(x0), 0.008) * step(abs(q.y), len);
	inlay(acc, d, HAND * 1.6, tick * step(abs(q.x), 0.72) * step(0.06, abs(q.x)), f);
	inlay(acc, d, GOLD, cov(length(q) - 0.040, f.px), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.028, f.px), f);
}

// 文字盤: 石の飾り枠、ローマ数字の代わりの刻み、時針と分針、上の尖り屋根と鐘
void clock_face(inout vec4 acc, Px f) {
	vec2 q = f.p - FACE;
	if (abs(q.x) > 0.18 + f.pad || abs(q.y) > 0.18 + f.pad) {
		return;
	}
	// 屋根
	vec2 rq = q - vec2(0.0, 0.070);
	float d_roof = max(abs(rq.x) * 1.15 + rq.y - 0.105, -rq.y);
	part(acc, d_roof, ink_of(ROOF), shade_mat(ROOF, normalize(vec3(sign(rq.x) * 0.5, 0.3, 0.8)), 0.3, 0.8, 1.0), f.ow * 0.8, f.px);
	draw_ball(acc, f, FACE + vec2(0.0, 0.172), 0.012, GOLD, 1.0);
	// 枠と文字盤
	vec2 dq = q - vec2(0.0, -0.005);
	float r = length(dq);
	part(acc, sd_round_box(dq, vec2(0.090, 0.090), 0.012), ink_of(STONE), shade_mat(STONE, normalize(vec3(dq / 0.09 * 0.3, 0.9)), 0.0, 0.4, 1.0), f.ow, f.px);
	part(acc, r - 0.072, ink_of(GOLD), shade_mat(GOLD, normalize(vec3(dq / 0.07 * 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	over(acc, DIAL, cov(r - 0.062, f.px));
	float a = atan(dq.y, dq.x);
	float seg = abs(fract(a / 6.2832 * 12.0) - 0.5);
	float tick = step(0.42, seg) * step(0.048, r) * step(r, 0.058);
	over(acc, HAND, tick);
	// 針: 時針は砂の色、分針は黒
	float d_hour = sd_segment(dq, vec2(0.0), vec2(0.026, 0.020)) - 0.006;
	float d_min = sd_segment(dq, vec2(0.0), vec2(-0.008, 0.050)) - 0.004;
	over(acc, HAND, cov(d_min, f.px));
	over(acc, mix(sand_color, HAND, 0.2), cov(d_hour, f.px));
	over(acc, GOLD, cov(r - 0.009, f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - FACE;
	add_light(acc, mix(WINDOW, sand_color, 0.4), exp(-dot(q, q) / 0.014) * 0.35);
}

void art_frame(inout vec4 acc, Px f) {
	tower_post(acc, f, -POST_X);
	tower_post(acc, f, POST_X);
	draw_collars(acc, f, ROOF, 0.3);
	hours_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		clock_face(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
