shader_type canvas_item;
// 行進(マーチ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は三角旗を掲げた旗竿、板には進む向きの山形の列。天板の上に撥を交差させた小太鼓。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 NAVY = vec3(0.18, 0.22, 0.40);
const vec3 SCARLET = vec3(0.74, 0.16, 0.18);
const vec3 SKIN = vec3(0.94, 0.90, 0.80);
const vec3 BIRCH = vec3(0.86, 0.74, 0.54);
const float POLE_R = 0.026;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 DRUM = vec2(0.0, 1.205);

// 旗竿: 細い竿に三角旗を2枚
void banner_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POLE_R, -POST_H, POST_H, GOLD * 0.8, 1.0);
	float dir = -sign(cx);
	for (int k = 0; k < 2; k++) {
		float y0 = 0.62 - float(k) * 0.80;
		vec2 q = vec2((f.p.x - cx) * dir - POLE_R, f.p.y - y0);
		float wave = 0.010 * sin(q.x * 30.0);
		float hh = 0.10 * (1.0 - q.x / 0.20);
		float d = max(abs(q.y - wave) - hh, max(-q.x, q.x - 0.20));
		vec3 c = k == 0 ? SCARLET : NAVY;
		c = mix(c, sand_color, step(abs(q.y - wave), hh * 0.25) * step(q.x, 0.15));
		part(acc, d, ink_of(c), shade_mat(c, normalize(vec3(0.0, 0.0, 1.0) + vec3(0.0, cos(q.x * 30.0) * 0.3, 0.0)), 0.0, 0.5, f.ao), f.ow * 0.7, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), NAVY, 0.3);
}

void chevron_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, NAVY, 0.3, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.058) - 0.004);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.76), f);
	// 右へ進む山形の列
	float u = fract((q.x + abs(q.y) * 0.8) / 0.12);
	float chev = step(abs(u - 0.5), 0.14) * step(abs(q.y), 0.040) * step(abs(q.x), 0.72) * step(0.08, abs(q.x));
	inlay(acc, d, SCARLET * 1.1, chev, f);
	inlay(acc, d, sand_color, cov(length(q) - 0.032, f.px), f);
}

// 小太鼓: 胴の締め紐、打面、交差した撥
void snare_drum(inout vec4 acc, Px f) {
	vec2 q = f.p - DRUM;
	if (abs(q.x) > 0.22 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	vec2 bq = q - vec2(0.0, -0.025);
	float d_shell = max(abs(bq.x) - 0.120, abs(bq.y) - 0.055);
	d_shell = min(d_shell, sd_ellipse(bq - vec2(0.0, -0.055), vec2(0.120, 0.026)));
	vec3 n = normalize(vec3(bq.x / 0.12 * 0.7, 0.0, 0.7));
	vec3 c = shade_mat(SCARLET, n, 0.0, 0.8, 1.0);
	// 締め紐のジグザグ
	float zig = abs(fract(bq.x / 0.06) - 0.5) * 0.06;
	float lace = 1.0 - smoothstep(0.0, max(0.004, f.px), abs(bq.y - (zig - 0.015) * 2.0) - 0.004);
	c = mix(c, SKIN, lace * step(abs(bq.y), 0.040));
	part(acc, d_shell, ink_of(SCARLET), c, f.ow, f.px);
	for (int s = -1; s <= 1; s += 2) {
		part(acc, sd_round_box(bq - vec2(0.0, float(s) * 0.050), vec2(0.124, 0.008), 0.004), ink_of(GOLD), GOLD, f.ow * 0.6, f.px);
	}
	part(acc, sd_ellipse(bq - vec2(0.0, 0.055), vec2(0.120, 0.026)), ink_of(SKIN), shade_mat(SKIN, normalize(vec3(0.0, 0.6, 0.8)), 0.0, 0.6, 1.0), f.ow * 0.8, f.px);
	// 交差した撥
	for (int s = -1; s <= 1; s += 2) {
		vec2 a = vec2(float(s) * 0.150, 0.130);
		vec2 b = vec2(float(-s) * 0.040, 0.040);
		part(acc, sd_segment(q, a, b) - 0.009, ink_of(BIRCH), BIRCH, f.ow * 0.6, f.px);
		draw_ball(acc, f, DRUM + b, 0.014, sand_color, 0.0);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	banner_post(acc, f, -POST_X);
	banner_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	chevron_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		snare_drum(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
