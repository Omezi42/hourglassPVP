shader_type canvas_item;
// 噴水(ファウンテン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は細い水の筋が伝い落ちる白い石灰華の柱に帆立貝の柱頭、板は石灰華に素焼きの樋。
// 天板の上に二段の水盤が立ち、上の盃の中心から水が噴き上がり、盃の縁から下の水盤へ弧を描いて落ちる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 TROUGH_CLAY = vec3(0.84, 0.44, 0.22);
const vec3 POOL_DEEP = vec3(0.03, 0.28, 0.34);
const vec3 POOL_LIT = vec3(0.30, 0.82, 0.78);
const vec3 SPILL = vec3(0.88, 1.0, 0.97);
// 樋の切り欠き(水が溢れ落ちる所)の位置
const float SPILL_X = 0.44;
// 注砂の刻の印: 板に嵌めた舟形の素焼きの樋に青緑の水が縁まで満ち、右寄りで縁を越えて板の下の縁まで溢れ落ちる
void pour_trough(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.09) {
		return;
	}
	float w = mix(0.56, 0.64, clamp((q.y + 0.040) / 0.080, 0.0, 1.0));
	float trough = sd_round_box(vec2(q.x * 0.64 / w, q.y), vec2(0.64, 0.040), 0.030);
	inlay(acc, d, ink_of(TROUGH_CLAY), cov(trough - 0.022, f.px), f);
	vec3 clay = TROUGH_CLAY * mix(0.74, 1.14, smoothstep(-0.06, 0.06, q.y));
	inlay(acc, d, clay, cov(trough - 0.015, f.px), f);
	inlay(acc, d, ink_of(TROUGH_CLAY), cov(trough - 0.002, f.px), f);
	float depth = clamp((0.026 - q.y) / 0.064, 0.0, 1.0);
	float swell = 0.5 + 0.5 * sin(q.x * 38.0 + sin(q.x * 7.0) * 2.0 + q.y * 60.0);
	vec3 water = mix(POOL_LIT, POOL_DEEP, depth) * mix(0.9, 1.08, swell);
	inlay(acc, d, water, cov(trough + 0.002, f.px), f);
	float inside = cov(trough + 0.004, f.px);
	float surface = abs(q.y - 0.020 - 0.004 * sin(q.x * 30.0 + 0.6)) - 0.006;
	inlay(acc, d, SPILL, cov(surface, f.px) * inside, f);
	vec2 s = q - vec2(SPILL_X, 0.0);
	float wob = 0.003 * sin(q.y * 120.0);
	float spread = mix(0.030, 0.014, clamp((0.0 - q.y) / 0.05, 0.0, 1.0));
	float fall = max(abs(s.x + wob) - spread, max(q.y - 0.018, -0.084 - q.y));
	inlay(acc, d, ink_of(POOL_DEEP), cov(fall - 0.007, f.px), f);
	inlay(acc, d, mix(POOL_LIT, SPILL, 0.45 + 0.3 * sin(q.y * 80.0)), cov(fall, f.px), f);
	inlay(acc, d, SPILL, cov(abs(s.x + wob + 0.005) - 0.004, f.px) * cov(fall, f.px), f);
	for (int k = 0; k < 2; k++) {
		vec2 c = vec2(k == 0 ? -0.040 : 0.042, k == 0 ? -0.060 : -0.072);
		float drop = length((s - c) * vec2(1.0, 0.8)) - 0.008;
		inlay(acc, d, ink_of(POOL_DEEP), cov(drop - 0.005, f.px), f);
		inlay(acc, d, SPILL, cov(drop, f.px), f);
	}
}
const vec3 TRAVERTINE = vec3(0.90, 0.86, 0.76);
const vec3 JET = vec3(0.86, 0.97, 1.0);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.058;
// 下の水盤の中心・半幅・高さ、上の盃の中心・半幅、噴き上がる頂、縁から落ちる弧の落ち口
const vec2 LOWER = vec2(0.0, 1.226);
const vec2 LOWER_HALF = vec2(0.190, 0.034);
const vec2 UPPER = vec2(0.0, 1.300);
const vec2 UPPER_HALF = vec2(0.088, 0.022);
const float JET_TOP = 1.378;
const float FALL_X = 0.160;

// 帆立貝の柱頭を載せた石灰華の柱。片側を水の筋が伝う
void travertine_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, TRAVERTINE, 0.0);
	float lx = f.p.x - cx;
	if (abs(lx) < POST_R && f.ay < POST_H) {
		float pore = step(0.93, hash21(floor(f.p * vec2(90.0, 30.0))));
		over(acc, TRAVERTINE * 0.66, pore * 0.5);
		float rill_x = 0.020 * sin(f.p.y * 9.0 + cx * 4.0);
		float rill = abs(lx - rill_x) - 0.008;
		over(acc, ink_of(POOL_DEEP), cov(rill - 0.004, f.px) * 0.6);
		over(acc, mix(POOL_LIT, SPILL, 0.5 + 0.5 * sin(f.p.y * 50.0)), cov(rill, f.px));
	}
	vec2 sh = vec2(lx, f.ay - 0.900);
	if (abs(sh.x) < 0.11 && abs(sh.y) < 0.07) {
		float d_shell = max(length(sh * vec2(1.0, 1.3)) - 0.074, sh.y - 0.040);
		float rib = abs(fract(atan(sh.x, -sh.y + 0.06) / 3.14159 * 6.0) - 0.5);
		vec3 n = normalize(vec3(sh.x * 6.0, 0.4, 0.8));
		vec3 c = shade_mat(TRAVERTINE, n, 0.0, 0.5, 1.0) * mix(0.82, 1.0, smoothstep(0.08, 0.3, rib));
		part(acc, d_shell, ink_of(TRAVERTINE), c, f.ow, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.030), TRAVERTINE, 0.0);
}

void travertine_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, TRAVERTINE, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float band = abs(fract(q.y * 18.0 + vnoise(q * 9.0) * 0.8) - 0.5);
	inlay(acc, d, TRAVERTINE * 0.80, smoothstep(0.08, 0.0, band) * 0.4, f);
	pour_trough(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.74 : 0.74, cy), 0.022, POOL_LIT, 0.0);
	}
}

// 水盤の鉢: 上縁が平らで下へすぼまる
float bowl_sd(vec2 p, vec2 half_size) {
	float w = mix(half_size.x * 0.55, half_size.x, clamp((p.y + half_size.y) / (2.0 * half_size.y), 0.0, 1.0));
	return sd_round_box(vec2(p.x * half_size.x / w, p.y), half_size, 0.010);
}

// 二段の水盤と、上の盃から噴き上がる水、縁から弧を描いて落ちる水
void fountain(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.30 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	vec3 stone = shade_mat(TRAVERTINE, vec3(0.0, 0.3, 0.95), 0.0, 0.4, 1.0);
	float d_stem = max(abs(q.x) - 0.020 - 0.010 * smoothstep(1.27, 1.24, q.y), max(1.19 - q.y, q.y - UPPER.y));
	part(acc, d_stem, ink_of(TRAVERTINE), stone * 0.92, f.ow * 0.8, f.px);
	vec2 l = q - LOWER;
	float d_lower = bowl_sd(l, LOWER_HALF);
	part(acc, d_lower, ink_of(TRAVERTINE), stone, f.ow, f.px);
	over(acc, sand_color, cov(max(d_lower + 0.012, l.y - LOWER_HALF.y + 0.008), f.px));
	over(acc, JET, cov(abs(l.y - LOWER_HALF.y + 0.010) - 0.003, f.px) * cov(d_lower + 0.010, f.px));
	vec2 u = q - UPPER;
	float d_upper = bowl_sd(u, UPPER_HALF);
	part(acc, d_upper, ink_of(TRAVERTINE), stone, f.ow * 0.9, f.px);
	over(acc, sand_color, cov(max(d_upper + 0.010, u.y - UPPER_HALF.y + 0.006), f.px));
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		float t = clamp((sx * q.x - UPPER_HALF.x) / (FALL_X - UPPER_HALF.x), 0.0, 1.0);
		float arc_y = UPPER.y + UPPER_HALF.y + 0.016 * sin(t * 1.6) - (UPPER.y + UPPER_HALF.y - LOWER.y - LOWER_HALF.y) * t * t;
		float d_arc = max(abs(q.y - arc_y) - mix(0.009, 0.013, t), max(UPPER_HALF.x - sx * q.x, sx * q.x - FALL_X));
		part(acc, d_arc, ink_of(POOL_DEEP), mix(JET, sand_color, 0.35 + 0.25 * t), f.ow * 0.5, f.px);
	}
	float h = clamp((q.y - UPPER.y) / (JET_TOP - UPPER.y), 0.0, 1.0);
	float d_jet = max(abs(q.x) - mix(0.017, 0.008, h), max(UPPER.y - q.y, q.y - JET_TOP + 0.012));
	part(acc, d_jet, ink_of(POOL_DEEP), mix(JET, vec3(1.0), h), f.ow * 0.5, f.px);
	for (int k = 0; k < 5; k++) {
		float a = (float(k) - 2.0) * 0.55;
		vec2 dp = vec2(sin(a) * 0.044, JET_TOP - 0.022 - 0.012 * abs(float(k) - 2.0));
		float d_drop = length(q - dp) - 0.009;
		part(acc, d_drop, ink_of(POOL_DEEP), JET, f.ow * 0.4, f.px);
	}
	add_light(acc, JET, exp(-pow(q.x / 0.03, 2.0)) * step(UPPER.y, q.y) * step(q.y, JET_TOP) * 0.35);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.2, f.p.y - 1.28);
	add_light(acc, JET, exp(-dot(d, d) / 0.010) * 0.35 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	travertine_post(acc, f, -POST_X);
	travertine_post(acc, f, POST_X);
	draw_collars(acc, f, TRAVERTINE, 0.0);
	travertine_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		fountain(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
