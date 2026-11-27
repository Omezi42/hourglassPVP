shader_type canvas_item;
// 終点(テルミヌス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は金の柱頭を戴いた濃緑の鋳鉄の駅の柱、板は濃緑の鋳鉄に金の縁と、枕木の上を走って右端の車止めで終わる二本のレール。
// 天板の上のレールの終わりに紅白の梁の車止めが据わり、頂の角灯が黄昏の色に灯る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 CAST = vec3(0.16, 0.30, 0.24);
const vec3 SLEEPER = vec3(0.40, 0.28, 0.18);
const vec3 RAIL = vec3(0.74, 0.76, 0.80);
const vec3 STOP_RED = vec3(0.84, 0.18, 0.14);
const vec3 STOP_WHITE = vec3(0.94, 0.92, 0.86);
const vec2 SLAB_HALF = vec2(0.82, 0.088);
const float POST_R = 0.052;
// 板のレールの終わり(車止め)の位置、天板の上のレールの高さ、車止めの中心と半幅、角灯の中心
const float SLAB_STOP_X = 0.62;
const float RAIL_Y = 1.206;
const vec2 STOP = vec2(0.080, 1.262);
const vec2 STOP_HALF = vec2(0.064, 0.060);
const vec2 LAMP = vec2(0.080, 1.346);

// 濃緑の鋳鉄の柱。縦の溝と、上下に金の唐草の柱頭
void station_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, CAST, 0.6);
	float lx = f.p.x - cx;
	if (abs(lx) < POST_R - 0.006 && f.ay < POST_H - 0.12) {
		float flute = abs(fract(lx / 0.026 + 0.5) - 0.5) * 0.026;
		over(acc, CAST * 0.55, cov(flute - 0.003, f.px) * 0.7);
	}
	vec2 c = vec2(lx, f.ay - 0.880);
	if (abs(c.x) < 0.10 && abs(c.y) < 0.07) {
		float d_cap = max(abs(c.x) - 0.030 - 0.050 * smoothstep(-0.05, 0.05, c.y), abs(c.y) - 0.050);
		float scroll = abs(length(vec2(abs(c.x) - 0.060, c.y - 0.026)) - 0.016) - 0.006;
		vec3 n = normalize(vec3(c.x * 8.0, 0.3, 0.8));
		part(acc, min(d_cap, scroll), ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.086, 0.030), CAST, 0.6);
	draw_band(acc, f, vec2(cx, f.side * 0.920), vec2(0.070, 0.008), GOLD, 1.0);
}

void track_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, CAST, 0.6, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = sd_round_box(q, SLAB_HALF - vec2(0.020, 0.016), 0.02);
	inlay(acc, d, GOLD, cov(abs(rim) - 0.005, f.px), f);
	float bed = step(abs(q.y), 0.050) * step(-0.68, q.x) * step(q.x, SLAB_STOP_X);
	float tie = abs(fract(q.x / 0.060 + 0.5) - 0.5) * 0.060;
	inlay(acc, d, ink_of(SLEEPER), cov(tie - 0.016, f.px) * bed, f);
	inlay(acc, d, SLEEPER, cov(tie - 0.012, f.px) * bed, f);
	for (int k = 0; k < 2; k++) {
		float y = k == 0 ? 0.022 : -0.022;
		float d_rail = max(abs(q.y - y) - 0.007, max(-0.70 - q.x, q.x - SLAB_STOP_X));
		inlay(acc, d, ink_of(RAIL), cov(d_rail - 0.004, f.px), f);
		inlay(acc, d, mix(RAIL, vec3(1.0), step(y, q.y) * 0.4), cov(d_rail, f.px), f);
	}
	vec2 s = q - vec2(SLAB_STOP_X + 0.024, 0.0);
	float d_stop = sd_round_box(s, vec2(0.020, 0.052), 0.004);
	inlay(acc, d, ink_of(STOP_RED), cov(d_stop - 0.004, f.px), f);
	inlay(acc, d, mix(STOP_RED, STOP_WHITE, step(0.5, fract(s.y / 0.030))), cov(d_stop, f.px), f);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.022, GOLD, 1.0);
	}
}

// レールの終わりの紅白の車止めと、頂で黄昏の色に灯る角灯
void buffer_stop(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.32 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	float d_bed = max(abs(q.y - 1.196) - 0.008, max(-0.28 - q.x, q.x - STOP.x - 0.080));
	part(acc, d_bed, ink_of(SLEEPER), SLEEPER, f.ow * 0.6, f.px);
	float d_rail = max(abs(q.y - RAIL_Y) - 0.009, max(-0.30 - q.x, q.x - STOP.x));
	part(acc, d_rail, ink_of(RAIL), shade_mat(RAIL, vec3(0.0, 0.6, 0.8), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	float d_strut = sd_segment(q, vec2(STOP.x + 0.110, 1.196), STOP + vec2(0.030, 0.034)) - 0.012;
	part(acc, d_strut, ink_of(SLEEPER), shade_mat(SLEEPER, vec3(0.3, 0.3, 0.9), 0.0, 0.3, 1.0), f.ow * 0.8, f.px);
	vec2 s = q - STOP;
	float d_frame = sd_round_box(s, STOP_HALF, 0.006);
	part(acc, d_frame, ink_of(SLEEPER), shade_mat(SLEEPER * 0.8, vec3(0.0, 0.2, 0.95), 0.0, 0.3, 1.0), f.ow, f.px);
	vec2 b = q - vec2(STOP.x - 0.010, STOP.y + 0.010);
	float d_beam = sd_round_box(b, vec2(0.096, 0.024), 0.004);
	float stripe = step(0.5, fract((b.x - b.y) / 0.034));
	part(acc, d_beam, ink_of(STOP_RED), mix(STOP_RED, STOP_WHITE, stripe), f.ow * 0.8, f.px);
	for (int k = 0; k < 2; k++) {
		vec2 bc = vec2(STOP.x - 0.124, STOP.y + 0.010 + (k == 0 ? -0.012 : 0.012));
		float d_buf = sd_round_box(q - bc, vec2(0.026, 0.010), 0.008);
		part(acc, d_buf, ink_of(RAIL), shade_mat(RAIL, vec3(0.0, 0.5, 0.85), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
	float d_pole = max(abs(q.x - LAMP.x) - 0.008, max(STOP.y + STOP_HALF.y - q.y, q.y - LAMP.y));
	part(acc, d_pole, ink_of(CAST), CAST, f.ow * 0.5, f.px);
	vec2 l = q - LAMP;
	float d_lamp = sd_round_box(l, vec2(0.026, 0.020), 0.006);
	part(acc, d_lamp, ink_of(CAST), mix(sand_color, vec3(1.0), 0.35), f.ow * 0.8, f.px);
	float d_cap = max(abs(l.x) * 0.6 + l.y - 0.036, 0.018 - l.y);
	part(acc, d_cap, ink_of(CAST), shade_mat(CAST, vec3(0.0, 0.6, 0.8), 0.6, 1.0, 1.0), f.ow * 0.7, f.px);
	add_light(acc, sand_color, exp(-dot(l, l) / 0.0016) * 0.8);
	add_light(acc, vec3(1.0), star4(l, 0.060) * 0.7);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2((f.p.x - 0.09) * 1.2, f.p.y - 1.32);
	add_light(acc, sand_color, exp(-dot(d, d) / 0.014) * 0.45 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	station_post(acc, f, -POST_X);
	station_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	track_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		buffer_stop(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
