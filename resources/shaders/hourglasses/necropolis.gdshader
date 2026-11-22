shader_type canvas_item;
// 死者の都(ネクロポリス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は壁龕に人魂の灯る苔むした石、板には墓石が並ぶ。天板の上に、門の奥で人魂が揺れる霊廟。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 TOMB = vec3(0.46, 0.46, 0.50);
const vec3 MOSS = vec3(0.30, 0.40, 0.26);
const vec3 SHADOW = vec3(0.08, 0.09, 0.12);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float COL_HALF = 0.058;
const float NICHE_Y = 0.42;
const vec2 TEMPLE = vec2(0.0, 1.180);
const float TEMPLE_WIDEN = 1.5;

float flame(vec2 q, float size) {
	q /= size;
	float body = length(vec2(q.x * (1.4 + q.y * 1.2), q.y + 0.25)) - 0.55;
	return body * size;
}

// 壁龕(上下の2箇所)に人魂が灯る石の柱
void niche_column(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = sd_round_box(vec2(lx, f.ay - POST_H * 0.5), vec2(COL_HALF, POST_H * 0.5), 0.012);
	vec3 n = normalize(vec3(lx / COL_HALF * 0.6, 0.0, 0.8));
	vec3 c = shade_mat(TOMB, n, 0.0, 0.3, f.ao);
	float block = step(0.92, fract(f.ay / 0.11));
	c = mix(c, TOMB * 0.6, block * 0.8);
	c = mix(c, MOSS, smoothstep(0.55, 0.8, vnoise(f.p * vec2(18.0, 10.0) + cx)) * 0.7);
	vec2 nq = vec2(lx, f.ay - NICHE_Y);
	float d_niche = min(sd_round_box(nq - vec2(0.0, -0.015), vec2(0.030, 0.040), 0.002), length(nq - vec2(0.0, 0.025)) - 0.030);
	c = mix(c, SHADOW, cov(d_niche, f.px));
	part(acc, d, ink_of(TOMB), c, f.ow, f.px);
	float d_fl = flame(nq - vec2(0.0, -0.005), 0.040);
	over(acc, mix(sand_color, vec3(1.0), 0.35), cov(d_fl, f.px));
	add_light(acc, sand_color, cov(d_fl - 0.03, f.px) * 0.25);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.086, 0.028), TOMB * 0.8, 0.0);
}

void tomb_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, SHADOW * 1.8, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	for (int k = -3; k <= 3; k++) {
		vec2 tq = q - vec2(float(k) * 0.21, -0.022);
		float h = 0.036 + 0.010 * hash21(vec2(float(k), 3.0));
		float d_stone = min(sd_round_box(tq, vec2(0.034, h), 0.004), length(tq - vec2(0.0, h)) - 0.034);
		inlay(acc, d, TOMB * 1.5, cov(d_stone, f.px), f);
		float cross_d = min(max(abs(tq.x) - 0.005, abs(tq.y - h * 0.5) - 0.022), max(abs(tq.y - h * 0.75) - 0.005, abs(tq.x) - 0.015));
		inlay(acc, d, SHADOW, cov(cross_d, f.px), f);
	}
}

// 霊廟: 三角の破風と柱の並ぶ正面、中央の門の奥に人魂
void mausoleum(inout vec4 acc, Px f) {
	vec2 q = (f.p - TEMPLE) / vec2(TEMPLE_WIDEN, 1.0);
	if (abs(q.x) > 0.20 + f.pad || q.y < -0.01 - f.pad || q.y > 0.19 + f.pad) {
		return;
	}
	float d_base = sd_round_box(q - vec2(0.0, 0.012), vec2(0.180, 0.012), 0.003);
	float d_body = sd_round_box(q - vec2(0.0, 0.065), vec2(0.150, 0.045), 0.002);
	vec2 rq = q - vec2(0.0, 0.110);
	float d_roof = max(max(rq.y - 0.070 + abs(rq.x) * 0.42, -rq.y), abs(rq.x) - 0.170);
	float d_all = min(min(d_base, d_body), d_roof);
	vec3 n = normalize(vec3(q.x * 2.0, 0.3, 0.9));
	vec3 c = shade_mat(TOMB * 1.1, n, 0.0, 0.4, 1.0);
	for (int k = -2; k <= 2; k++) {
		if (k == 0) {
			continue;
		}
		float col = abs(q.x - float(k) * 0.060) - 0.010;
		c = mix(c, TOMB * 0.7, step(col, 0.0) * step(abs(q.y - 0.065), 0.045) * 0.6);
	}
	part(acc, d_all, ink_of(TOMB), c, f.ow, f.px);
	vec2 gq = q - vec2(0.0, 0.055);
	float d_gate = min(sd_round_box(gq, vec2(0.032, 0.035), 0.002), length(gq - vec2(0.0, 0.035)) - 0.032);
	over(acc, SHADOW, cov(d_gate, f.px));
	float d_fl = flame(gq - vec2(0.0, 0.010), 0.050);
	over(acc, mix(sand_color, vec3(1.0), 0.35), cov(d_fl, f.px));
	add_light(acc, sand_color, cov(d_fl - 0.04, f.px) * 0.3);
}

void art_back(inout vec4 acc, Px f) {
	float mist = smoothstep(-1.3, -0.4, -abs(f.p.y + 0.9)) * vnoise(f.p * vec2(2.5, 6.0));
	add_light(acc, sand_color, mist * 0.20 * canvas_window(f.p) * (1.0 - acc.a));
}

void art_frame(inout vec4 acc, Px f) {
	niche_column(acc, f, -POST_X);
	niche_column(acc, f, POST_X);
	draw_collars(acc, f, TOMB * 0.8, 0.0);
	tomb_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		mausoleum(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
