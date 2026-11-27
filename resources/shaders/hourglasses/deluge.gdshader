shader_type canvas_item;
// 大洪水(デリュージ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は金の輪で留めた流れ落ちる水の柱、板は深い藍の漆に金の青海波と素焼きの樋。
// 天板の上に渦を巻く雨雲が垂れこめ、金の縁取りの雲の下から光る雨が天板を叩いてしぶきが跳ねる。

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
const vec3 INDIGO = vec3(0.08, 0.14, 0.32);
const vec3 TORRENT = vec3(0.34, 0.66, 0.90);
const vec3 CLOUD = vec3(0.30, 0.34, 0.46);
const vec3 RAIN = vec3(0.84, 0.96, 1.0);
const vec2 SLAB_HALF = vec2(0.82, 0.088);
const float POST_R = 0.060;
// 雲の玉(中心と半径)、雲の底、雨の筋の間隔
const vec3 PUFF_A = vec3(-0.190, 1.296, 0.056);
const vec3 PUFF_B = vec3(-0.080, 1.318, 0.060);
const vec3 PUFF_C = vec3(0.046, 1.316, 0.060);
const vec3 PUFF_D = vec3(0.170, 1.298, 0.058);
const float CLOUD_BASE = 1.268;
const float RAIN_PITCH = 0.044;

// 金の輪で留めた、流れ落ちる水の柱
void torrent_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
		float streak = sin(lx * 160.0 + vnoise(vec2(lx * 40.0, f.p.y * 3.0)) * 4.0);
		float fall = fract(f.p.y * 5.0 + hash21(vec2(floor(lx * 70.0), 1.0)));
		vec3 water = mix(TORRENT * 0.7, RAIN, smoothstep(0.6, 1.0, streak) * 0.6 + smoothstep(0.85, 1.0, fall) * 0.3);
		part(acc, d, ink_of(INDIGO), shade_mat(water, n, 0.3, 1.0, f.ao), f.ow, f.px);
	}
	for (int k = 0; k < 3; k++) {
		float y = 0.16 + 0.34 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(POST_R + 0.010, 0.012), GOLD, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.032), INDIGO * 1.6, 0.4);
	draw_band(acc, f, vec2(cx, f.side * 0.918), vec2(0.074, 0.008), GOLD, 1.0);
}

void lacquer_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, INDIGO, 0.2, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	vec2 cell = vec2(0.060, 0.030);
	vec2 g = vec2(q.x + 0.5 * cell.x * mod(floor(q.y / cell.y), 2.0), q.y);
	vec2 local = vec2(mod(g.x, cell.x) - cell.x * 0.5, mod(g.y, cell.y));
	float r = length(local);
	float wave = abs(fract(r / 0.010) - 0.5) * 0.010 - 0.0016;
	inlay(acc, d, GOLD * 0.75, cov(wave, f.px) * step(r, cell.x * 0.5) * 0.7, f);
	float rim = sd_round_box(q, SLAB_HALF - vec2(0.020, 0.016), 0.02);
	inlay(acc, d, GOLD, cov(abs(rim) - 0.005, f.px), f);
	pour_trough(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.026, GOLD, 1.0);
	}
}

float puff(vec2 q, vec3 c) {
	return length(q - c.xy) - c.z;
}

// 渦を巻く雨雲と、雲の下から天板を叩く光る雨
void storm(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.32 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	float lane = floor(q.x / RAIN_PITCH);
	float lx = q.x - (lane + 0.5) * RAIN_PITCH;
	float slant = lx + (q.y - 1.19) * 0.18;
	float seed_h = hash21(vec2(lane, 7.0));
	float streak_y = fract((q.y - seed_h * 0.08) / 0.044);
	float in_rain = step(1.19, q.y) * step(q.y, CLOUD_BASE) * step(abs(q.x), 0.23);
	float d_rain = abs(slant) - 0.0065;
	over(acc, ink_of(TORRENT), cov(d_rain - 0.003, f.px) * step(0.35, streak_y) * in_rain * 0.6);
	over(acc, RAIN, cov(d_rain, f.px) * step(0.30, streak_y) * in_rain);
	for (int k = 0; k < 5; k++) {
		vec2 s = q - vec2(-0.18 + 0.09 * float(k), 1.194);
		float d_splash = max(abs(length(s * vec2(1.0, 1.5)) - 0.022) - 0.006, -s.y);
		over(acc, RAIN, cov(d_splash, f.px) * 0.85);
	}
	float d_cloud = min(min(puff(q, PUFF_A), puff(q, PUFF_B)), min(puff(q, PUFF_C), puff(q, PUFF_D)));
	d_cloud = min(d_cloud, sd_ellipse(q - vec2(-0.01, CLOUD_BASE + 0.016), vec2(0.250, 0.030)));
	d_cloud = max(d_cloud, CLOUD_BASE - q.y);
	float swirl = sin(atan(q.y - 1.30, q.x) * 3.0 + length(q - vec2(0.0, 1.30)) * 50.0);
	vec3 cloud = mix(CLOUD * 0.6, CLOUD * 1.5, smoothstep(CLOUD_BASE, 1.37, q.y)) * mix(0.9, 1.08, swirl * 0.5 + 0.5);
	part(acc, d_cloud, ink_of(INDIGO), cloud, f.ow, f.px);
	over(acc, GOLD, cov(abs(d_cloud + 0.012) - 0.005, f.px) * step(CLOUD_BASE + 0.030, q.y));
	add_light(acc, RAIN, exp(-pow((q.y - CLOUD_BASE) / 0.010, 2.0)) * step(abs(q.x), 0.22) * 0.5);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.1, f.p.y - 1.27);
	add_light(acc, mix(sand_color, TORRENT, 0.4), exp(-dot(d, d) / 0.016) * 0.45 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	torrent_post(acc, f, -POST_X);
	torrent_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	lacquer_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		storm(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
