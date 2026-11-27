shader_type canvas_item;
// 移し替え(デカンタ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は面を切った切子硝子の棒に銀の輪、板は胡桃材に銀の縁と素焼きの樋。
// 天板の上に丸い胴の硝子のデカンタが立ち、胴の下に砂の色の葡萄酒を湛え、首に銀の輪、口に切子の栓。

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
const vec3 CRYSTAL = vec3(0.80, 0.88, 0.94);
const vec3 WALNUT = vec3(0.40, 0.25, 0.16);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.056;
const float FACETS = 5.0;
// デカンタの平たい胴の中心と半径、首の半幅と口の高さ、栓の大きさ、葡萄酒の水面、脇の杯の中心
const vec2 BULB = vec2(-0.05, 1.236);
const vec2 BULB_R = vec2(0.112, 0.052);
const float NECK_W = 0.022;
const float MOUTH_Y = 1.330;
const float STOPPER_R = 0.020;
const float WINE_Y = 1.244;
const vec2 GOBLET = vec2(0.150, 1.272);

// 面を切った切子硝子の棒。面ごとに明暗が変わり、銀の輪で留める
void crystal_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		float u = clamp(lx / POST_R, -1.0, 1.0);
		float facet = floor((asin(u) / 3.14159 + 0.5) * FACETS);
		float fu = sin(((facet + 0.5) / FACETS - 0.5) * 3.14159);
		vec3 n = lathe_normal(fu, 0.0);
		vec3 glass_c = shade_mat(CRYSTAL, n, 0.4, 1.0, f.ao);
		glass_c = mix(glass_c, sand_color, 0.10 + 0.10 * step(0.5, mod(facet + floor(f.p.y * 6.0), 2.0)));
		part(acc, d, ink_of(CRYSTAL) * 1.4, glass_c, f.ow, f.px);
	}
	for (int k = 0; k < 3; k++) {
		float y = 0.16 + 0.34 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(POST_R + 0.010, 0.014), SILVER, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), SILVER, 1.0);
}

void walnut_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, WALNUT, 0.0, 0.7);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float grain = sin(q.y * 180.0 + sin(q.x * 6.0 + cy * 2.0) * 4.0);
	inlay(acc, d, WALNUT * 1.3, smoothstep(0.7, 1.0, grain) * 0.35, f);
	float rim = sd_round_box(q, SLAB_HALF - vec2(0.020, 0.016), 0.02);
	inlay(acc, d, SILVER, cov(abs(rim) - 0.005, f.px), f);
	pour_trough(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.74 : 0.74, cy), 0.022, SILVER, 1.0);
	}
}

// 平たい胴の硝子のデカンタと胴に湛えた葡萄酒、脇に注がれた杯
void decanter(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.26 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	vec2 b = q - BULB;
	float d_bulb = max(sd_ellipse(b, BULB_R), 1.188 - q.y);
	float flare = 0.012 * smoothstep(MOUTH_Y - 0.016, MOUTH_Y, q.y);
	float d_neck = max(abs(b.x) - NECK_W - flare, max(BULB.y - q.y, q.y - MOUTH_Y));
	float d_body = min(d_bulb, d_neck);
	vec3 n = normalize(vec3(clamp(b / BULB_R, -1.0, 1.0) * 0.7, 0.7));
	part(acc, d_body, ink_of(CRYSTAL) * 1.4, mix(CRYSTAL * 0.5, CRYSTAL * 0.95, 0.4 + 0.3 * n.x), f.ow, f.px);
	float wave = WINE_Y + 0.004 * sin(q.x * 70.0);
	float d_wine = max(d_bulb + 0.010, q.y - wave);
	over(acc, mix(sand_color * 0.55, sand_color, smoothstep(1.19, wave, q.y)), cov(d_wine, f.px));
	over(acc, mix(sand_color, vec3(1.0), 0.6), cov(abs(q.y - wave) - 0.003, f.px) * cov(d_bulb + 0.012, f.px));
	float d_hi = sd_segment(b, vec2(-0.078, 0.010), vec2(-0.040, 0.034)) - 0.007;
	over(acc, vec3(1.0), cov(d_hi, f.px) * 0.75);
	over(acc, vec3(1.0), cov(abs(b.x + NECK_W * 0.4) - 0.0035, f.px) * step(BULB.y + 0.06, q.y) * step(q.y, MOUTH_Y - 0.012) * 0.6);
	draw_band(acc, f, vec2(BULB.x, BULB.y + 0.058), vec2(NECK_W + 0.010, 0.008), SILVER, 1.0);
	draw_band(acc, f, vec2(BULB.x, MOUTH_Y), vec2(NECK_W + 0.016, 0.008), SILVER, 1.0);
	vec2 s = q - vec2(BULB.x, MOUTH_Y + STOPPER_R + 0.004);
	float d_stop = sd_rhombus(s, vec2(STOPPER_R * 1.1, STOPPER_R * 1.05));
	vec3 sn = normalize(vec3(sign(s.x) * 0.6, sign(s.y) * 0.4, 0.7));
	part(acc, d_stop, ink_of(CRYSTAL) * 1.4, shade_mat(CRYSTAL, sn, 0.5, 1.0, 1.0), f.ow * 0.8, f.px);
	add_light(acc, vec3(1.0), star4(s - vec2(-0.006, 0.008), 0.040) * 0.8);
	vec2 g = q - GOBLET;
	float d_cup = max(sd_ellipse(g, vec2(0.040, 0.044)), g.y - 0.024);
	float d_stem = max(abs(g.x) - 0.006, max(-0.084 - g.y, g.y + 0.040));
	float d_foot = sd_ellipse(g - vec2(0.0, -0.078), vec2(0.034, 0.008));
	float d_glass = min(min(d_cup, d_stem), d_foot);
	part(acc, d_glass, ink_of(CRYSTAL) * 1.4, CRYSTAL * 0.7, f.ow * 0.8, f.px);
	float d_pour = max(d_cup + 0.008, g.y - 0.004);
	over(acc, mix(sand_color * 0.6, sand_color, smoothstep(-0.04, 0.004, g.y)), cov(d_pour, f.px));
	over(acc, vec3(1.0), cov(sd_segment(g, vec2(-0.026, 0.0), vec2(-0.018, 0.016)) - 0.004, f.px) * 0.7);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2((f.p.x - 0.03) * 1.3, f.p.y - 1.27);
	add_light(acc, sand_color, exp(-dot(d, d) / 0.008) * 0.32 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	crystal_post(acc, f, -POST_X);
	crystal_post(acc, f, POST_X);
	draw_collars(acc, f, SILVER, 1.0);
	walnut_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		decanter(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
