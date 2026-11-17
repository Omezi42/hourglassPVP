shader_type canvas_item;
// 疾風(ゲイル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 白い柱に風のリボンが巻きつき、天板の上の風見の矢と、吹き流される木の葉。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PALE = vec3(0.88, 0.92, 0.90);
const vec3 WIND = vec3(0.56, 0.86, 0.72);
const vec3 IRON = vec3(0.24, 0.26, 0.28);
const vec3 LEAF = vec3(0.40, 0.70, 0.36);
const float POST_R = 0.044;
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const vec2 VANE = vec2(0.0, 1.16);

void wind_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	part(acc, d, ink_of(PALE * 0.6), shade_mat(PALE, n, 0.0, 0.8, f.ao), f.ow, f.px);
	// 巻きつく風のリボン(手前の半周だけ見せる)
	float ph = f.p.y * 2.2 * 6.2832 + cx * 3.0;
	float rx = 0.070 * sin(ph);
	float front = cos(ph);
	float d_rib = abs(lx - rx) - 0.014 * (0.6 + 0.4 * front);
	d_rib = max(d_rib, f.ay - POST_H + 0.06);
	if (front > -0.2) {
		part(acc, d_rib, ink_of(WIND), mix(WIND, mix(WIND, sand_color, 0.4), 0.5 + 0.5 * front), f.ow * 0.6, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), WIND * 0.8, 0.0);
}

void breeze_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, PALE, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 渦を巻いて流れる風の線
	float a = 0.0;
	for (int k = -1; k <= 1; k++) {
		float y0 = float(k) * 0.026;
		float wave = y0 + 0.012 * sin(q.x * 14.0 + float(k) * 1.7);
		a = max(a, 1.0 - smoothstep(0.0, max(0.006, f.px * 0.8), abs(q.y - wave) - 0.004));
	}
	inlay(acc, d, WIND, a * step(abs(q.x), 0.76) * step(0.4, fract(q.x * 2.0 + 0.2)), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.028, f.px), f);
}

// 風見: 柱、東西の棒、矢羽根の付いた矢
void weather_vane(inout vec4 acc, Px f) {
	vec2 q = f.p - VANE;
	if (abs(q.x) > 0.26 + f.pad || q.y < -f.pad || q.y > 0.22 + f.pad) {
		return;
	}
	float d_pole = max(abs(q.x) - 0.010, max(-q.y, q.y - 0.145));
	float d_cross = max(abs(q.y - 0.07) - 0.006, abs(q.x) - 0.08);
	part(acc, min(d_pole, d_cross), vec3(0.05), IRON, f.ow * 0.6, f.px);
	// 矢
	vec2 aq = q - vec2(0.0, 0.135);
	float d_shaft = max(abs(aq.y) - 0.008, abs(aq.x) - 0.17);
	float d_head = max(abs(aq.y) - (0.045 - (aq.x - 0.12) * 0.9), max(0.12 - aq.x, aq.x - 0.22));
	vec2 fq = aq - vec2(-0.16, 0.0);
	float d_fletch = max(abs(fq.y) - (0.050 - abs(fq.x) * 0.6), abs(fq.x) - 0.06);
	part(acc, min(d_shaft, min(d_head, d_fletch)), vec3(0.05), shade_mat(IRON * 1.4, normalize(vec3(0.0, aq.y * 6.0, 0.9)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	draw_ball(acc, f, VANE + vec2(0.0, 0.135), 0.016, mix(sand_color, GOLD, 0.4), 1.0);
	// 吹き流される木の葉
	for (int k = 0; k < 2; k++) {
		vec2 lq = rot(q - vec2(-0.20 + 0.36 * float(k), 0.035 + 0.06 * float(k)), 0.8 + float(k) * 1.2);
		float d_leaf = sd_ellipse(lq, vec2(0.016, 0.034));
		part(acc, d_leaf, ink_of(LEAF), mix(LEAF, LEAF * 1.3, step(0.0, lq.x)), f.ow * 0.5, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	wind_post(acc, f, -POST_X);
	wind_post(acc, f, POST_X);
	draw_collars(acc, f, WIND * 0.8, 0.0);
	breeze_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		weather_vane(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
