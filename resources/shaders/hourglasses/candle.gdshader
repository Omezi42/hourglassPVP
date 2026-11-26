shader_type canvas_item;
// 時刻蝋燭(キャンドル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は時の目盛りの朱の輪を巻いた白い蝋、板は白鑞に黒色火薬の煤の溝と、そこを這う導火線の火の点。
// 天板の上の白鑞の燭台で、朱の目盛りを刻んだ時刻蝋燭がまっすぐな炎を灯す。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 POWDER = vec3(0.11, 0.10, 0.10);
const vec3 HEMP = vec3(0.86, 0.68, 0.40);
const vec3 ASH = vec3(0.40, 0.38, 0.37);
const vec3 SPARK = vec3(1.0, 0.70, 0.24);
const vec3 SPARK_HOT = vec3(1.0, 0.97, 0.80);
const vec3 BRASS = vec3(0.90, 0.70, 0.36);
const vec3 WAX = vec3(0.98, 0.94, 0.84);
const vec3 VERMILION = vec3(0.86, 0.22, 0.16);
const vec3 PEWTER = vec3(0.70, 0.72, 0.76);
const vec3 FLAME = vec3(1.0, 0.62, 0.18);
const vec3 FLAME_CORE = vec3(1.0, 0.94, 0.66);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.056;
const float LIT_X = 0.24;
// 燭台の皿の高さ、蝋燭の胴(下端・半幅・高さ)、炎の根元と先
const float DISH_Y = 1.198;
const float CANDLE_X = 0.0;
const vec2 CANDLE_HALF = vec2(0.058, 0.064);
const float CANDLE_BASE = 1.204;
const vec2 FLAME_ROOT = vec2(0.0, 1.346);
const float FLAME_TIP = 1.390;

float fuse_y(float x) {
	return 0.016 * sin(x * 15.0 + 0.6);
}
// 導火の刻の印: 板に掘った黒色火薬の煤の溝を麻の導火線が波打って這い、右寄りで火の点が燃える(先は燃え尽きた灰)
void fuse_band(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.075) {
		return;
	}
	float strip = sd_round_box(q, vec2(0.68, 0.040), 0.036);
	inlay(acc, d, POWDER * 0.5, cov(strip - 0.010, f.px), f);
	float grain = step(0.80, hash21(floor(q * 110.0))) * 0.5;
	inlay(acc, d, mix(POWDER, vec3(0.30, 0.28, 0.27), grain), cov(strip, f.px), f);
	float dy = q.y - fuse_y(q.x);
	float inside = cov(strip + 0.004, f.px);
	float d_cord = max(abs(dy) - 0.015, max(q.x - LIT_X, -0.62 - q.x));
	float twist = fract((q.x * 0.9 + dy * 0.7) * 30.0);
	vec3 hemp = mix(HEMP * 0.70, HEMP * 1.08, smoothstep(0.15, 0.45, twist) * smoothstep(0.95, 0.65, twist));
	vec3 n = normalize(vec3(0.0, clamp(dy / 0.015, -1.0, 1.0) * 0.7, 0.7));
	inlay(acc, d, ink_of(HEMP), cov(d_cord - 0.006, f.px) * inside, f);
	inlay(acc, d, shade_mat(hemp, n, 0.0, 0.5, 1.0), cov(d_cord, f.px) * inside, f);
	float d_ash = max(abs(dy) - 0.008, max(LIT_X - q.x, q.x - 0.62));
	float flake = step(0.28, fract(q.x * 26.0));
	inlay(acc, d, ASH, cov(d_ash, f.px) * flake * inside, f);
	vec2 cap = q - vec2(-0.635, fuse_y(-0.635));
	inlay(acc, d, ink_of(BRASS), cov(length(cap) - 0.028, f.px), f);
	inlay(acc, d, shade_mat(BRASS, normalize(vec3(cap / 0.028 * 0.6, 0.75)), 1.0, 1.0, 1.0), cov(length(cap) - 0.020, f.px), f);
	vec2 s = q - vec2(LIT_X, fuse_y(LIT_X));
	add_light(acc, SPARK, exp(-dot(s, s) / 0.0018) * 0.95);
	add_light(acc, SPARK_HOT, star4(s, 0.075));
	for (int k = 0; k < 4; k++) {
		float a = 0.9 + 1.55 * float(k);
		vec2 o = s - vec2(cos(a), sin(a)) * (0.040 + 0.012 * float(k % 2));
		over(acc, SPARK_HOT, cov(length(o) - 0.0065, f.px));
	}
}

// 時の目盛りの朱の輪を巻いた白い蝋の柱
void wax_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, WAX, 0.0);
	for (int k = 0; k < 4; k++) {
		float y = 0.20 + 0.20 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(POST_R + 0.004, 0.010 + 0.004 * float(k % 2)), VERMILION, 0.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), PEWTER, 1.0);
}

void pewter_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, PEWTER, 0.8, 0.9);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	fuse_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, VERMILION, 0.0);
	}
}

// 白鑞の燭台と、朱の目盛りを刻んだ蝋燭
void candlestick(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(CANDLE_X, DISH_Y);
	if (abs(q.x) > 0.26 || q.y < -0.05 || q.y > 0.20) {
		return;
	}
	float d_dish = sd_ellipse(q, vec2(0.190, 0.030));
	vec2 hq = q - vec2(0.205, 0.012);
	float d_ring = abs(length(hq) - 0.030) - 0.010;
	part(acc, d_ring, ink_of(PEWTER), shade_mat(PEWTER, normalize(vec3(hq / 0.04 * 0.6, 0.75)), 1.0, 1.0, 1.0), f.ow, f.px);
	part(acc, d_dish, ink_of(PEWTER), shade_mat(PEWTER, normalize(vec3(q.x / 0.19 * 0.4, 0.5, 0.75)), 1.0, 1.0, 1.0), f.ow, f.px);
	vec2 cq = f.p - vec2(CANDLE_X, CANDLE_BASE + CANDLE_HALF.y);
	float d_body = sd_round_box(cq, CANDLE_HALF, 0.012);
	vec3 n = normalize(vec3(clamp(cq.x / CANDLE_HALF.x, -1.0, 1.0) * 0.7, 0.0, 0.7));
	vec3 wax = shade_mat(WAX, n, 0.0, 0.7, 1.0);
	wax = mix(wax, wax * vec3(1.0, 0.90, 0.72), smoothstep(-0.02, CANDLE_HALF.y, cq.y) * 0.45);
	// 朱の目盛り: 太い輪と細い輪を交互に
	for (int k = 0; k < 3; k++) {
		float y = -CANDLE_HALF.y + 0.030 + 0.030 * float(k);
		float w = k == 1 ? 0.0045 : 0.0028;
		wax = mix(wax, shade_mat(VERMILION, n, 0.0, 0.6, 1.0), cov(abs(cq.y - y) - w, f.px));
	}
	part(acc, d_body, WAX * 0.42, wax, f.ow, f.px);
	// 上面のくぼみに溜まった蝋
	float d_pool = sd_ellipse(cq - vec2(0.0, CANDLE_HALF.y - 0.004), vec2(CANDLE_HALF.x - 0.012, 0.008));
	over(acc, vec3(1.0, 0.97, 0.88), cov(d_pool, f.px));
	// 芯
	float d_wick = sd_segment(f.p, vec2(CANDLE_X, CANDLE_BASE + 2.0 * CANDLE_HALF.y - 0.006), FLAME_ROOT + vec2(0.0, 0.004)) - 0.006;
	part(acc, d_wick, vec3(0.03), vec3(0.12, 0.09, 0.08), f.ow * 0.6, f.px);
}

// まっすぐ立つ炎: 根元は丸く、先は細く尖る
void flame(inout vec4 acc, Px f) {
	vec2 q = f.p - FLAME_ROOT;
	float h = FLAME_TIP - FLAME_ROOT.y;
	if (abs(q.x) > 0.05 || q.y < -0.03 || q.y > h + 0.01) {
		return;
	}
	float t = clamp(q.y / h, 0.0, 1.0);
	float w = mix(0.027, 0.0, pow(t, 1.25));
	float d_tongue = max(abs(q.x) - w, max(q.y - h, -q.y));
	float d_flame = min(length(q) - 0.027, d_tongue);
	over(acc, FLAME * 0.75, cov(d_flame - 0.006, f.px));
	over(acc, mix(FLAME, FLAME_CORE, smoothstep(0.7, 0.1, t)), cov(d_flame, f.px));
	float d_core = min(length(q - vec2(0.0, 0.004)) - 0.011, max(abs(q.x) - w * 0.45, max(q.y - h * 0.55, -q.y)));
	over(acc, vec3(1.0, 0.99, 0.92), cov(d_core, f.px));
	over(acc, vec3(0.55, 0.72, 1.0), cov(length(q + vec2(0.0, 0.012)) - 0.008, f.px) * 0.8);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2((f.p.x - FLAME_ROOT.x) * 0.8, f.p.y - FLAME_ROOT.y - 0.01);
	add_light(acc, FLAME, exp(-dot(d, d) / 0.010) * 0.85 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	wax_post(acc, f, -POST_X);
	wax_post(acc, f, POST_X);
	draw_collars(acc, f, PEWTER, 1.0);
	pewter_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		candlestick(acc, f);
		flame(acc, f);
		add_light(acc, FLAME_CORE, star4(f.p - FLAME_ROOT - vec2(0.0, 0.006), 0.06) * 0.5);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
