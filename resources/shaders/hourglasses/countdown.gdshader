shader_type canvas_item;
// 秒読み(カウントダウン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は三本の金の帯を締めた白い大理石、板は金で縁取った黒漆に黒色火薬の煤の溝と、そこを這う導火線の火の点。
// 天板の上に黒い丸爆弾が据えられ、胴の三つの灯が秒を読み、短い導火線の先で火の点がはぜる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 POWDER = vec3(0.11, 0.10, 0.10);
const vec3 HEMP = vec3(0.86, 0.68, 0.40);
const vec3 ASH = vec3(0.40, 0.38, 0.37);
const vec3 SPARK = vec3(1.0, 0.70, 0.24);
const vec3 SPARK_HOT = vec3(1.0, 0.97, 0.80);
const vec3 BRASS = vec3(0.96, 0.76, 0.36);
const vec3 MARBLE = vec3(0.92, 0.91, 0.88);
const vec3 LACQUER = vec3(0.13, 0.12, 0.13);
const vec3 BOMB = vec3(0.20, 0.21, 0.24);
const vec3 LAMP = vec3(1.0, 0.24, 0.18);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.054;
const float LIT_X = 0.24;
// 爆弾の中心と半径、口金の向き、導火線の先、灯の間隔・半径
const vec2 BOMB_C = vec2(-0.025, 1.276);
const float BOMB_R = 0.086;
const float NECK_ANGLE = 0.62;
const vec2 FUSE_TIP = vec2(0.14, 1.360);
const float LAMP_GAP = 0.042;
const float LAMP_R = 0.0155;

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

// 三本の金の帯を締めた白い大理石の柱
void marble_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, MARBLE, 0.0);
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R - 0.004 && f.ay < POST_H) {
		float vein = abs(vnoise(vec2(lx * 40.0 + f.p.y * 6.0, f.p.y * 3.0)) - 0.5);
		float fine = smoothstep(0.03, 0.012, f.px);
		over(acc, vec3(0.62, 0.62, 0.66), smoothstep(0.05, 0.0, vein) * 0.5 * fine);
	}
	for (int k = 0; k < 3; k++) {
		draw_band(acc, f, vec2(cx, f.side * (0.26 + 0.22 * float(k))), vec2(POST_R + 0.006, 0.014), BRASS, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.086, 0.030), BRASS, 1.0);
}

void lacquer_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, LACQUER, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float frame = abs(sd_round_box(q, vec2(0.725, 0.058), 0.05)) - 0.004;
	inlay(acc, d, BRASS, cov(frame, f.px), f);
	fuse_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.775 : 0.775, cy), 0.022, BRASS, 1.0);
	}
}

void bomb(inout vec4 acc, Px f) {
	vec2 q = f.p - BOMB_C;
	if (length(q) > BOMB_R + 0.12) {
		return;
	}
	vec2 neck_dir = vec2(sin(NECK_ANGLE), cos(NECK_ANGLE));
	vec2 neck = neck_dir * (BOMB_R + 0.004);
	// 導火線: 口金から右上へ反って伸びる
	vec2 a = neck + neck_dir * 0.012;
	vec2 tip = FUSE_TIP - BOMB_C;
	vec2 prev = a;
	float best = 9.0;
	for (int i = 1; i <= 8; i++) {
		float t = float(i) / 8.0;
		vec2 b = mix(a, tip, t) + vec2(-0.018, 0.012) * sin(t * 3.1416);
		best = min(best, sd_segment(q, prev, b));
		prev = b;
	}
	part(acc, best - 0.009, ink_of(HEMP), HEMP, f.ow * 0.7, f.px);
	// 胴
	vec3 n = normalize(vec3(q / BOMB_R * 0.8, 0.6));
	vec3 c = shade_mat(BOMB, n, 0.6, 1.0, 1.0);
	part(acc, length(q) - BOMB_R, vec3(0.02), c, f.ow, f.px);
	// 口金
	vec2 nq = rot(q - neck, NECK_ANGLE);
	float d_neck = sd_round_box(nq, vec2(0.030, 0.016), 0.006);
	vec3 nn = normalize(vec3(clamp(nq.x / 0.03, -1.0, 1.0) * 0.7, 0.2, 0.7));
	part(acc, d_neck, ink_of(BRASS), shade_mat(BRASS, nn, 1.0, 1.0, 1.0), f.ow, f.px);
	// 秒を読む三つの灯(左だけが灯る)
	for (int k = 0; k < 3; k++) {
		vec2 lq = q - vec2(LAMP_GAP * float(k - 1), -0.010);
		vec3 ln = normalize(vec3(lq / LAMP_R * 0.6, 0.75));
		vec3 lamp = k == 0 ? mix(LAMP, vec3(1.0, 0.86, 0.70), clamp(ln.z - 0.4, 0.0, 1.0)) : shade_mat(LAMP * 0.35, ln, 0.0, 1.0, 1.0);
		part(acc, length(lq) - LAMP_R, ink_of(BRASS), lamp, f.ow * 0.8, f.px);
		if (k == 0) {
			add_light(acc, LAMP, exp(-dot(lq, lq) / 0.0009) * 0.7);
		}
	}
}

void fuse_spark(inout vec4 acc, Px f) {
	vec2 s = f.p - FUSE_TIP;
	add_light(acc, SPARK, exp(-dot(s, s) / 0.0020) * 0.95);
	add_light(acc, SPARK_HOT, star4(s, 0.075));
	for (int k = 0; k < 5; k++) {
		float a = -0.3 + 1.3 * float(k);
		vec2 o = s - vec2(cos(a), sin(a)) * (0.044 + 0.012 * float(k % 2));
		over(acc, SPARK_HOT, cov(length(o) - 0.0075, f.px));
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - FUSE_TIP;
	add_light(acc, SPARK, exp(-dot(d, d) / 0.010) * 0.55 * canvas_window(f.p));
	vec2 d2 = vec2(f.p.x * 0.7, f.p.y - BOMB_C.y);
	add_light(acc, LAMP, exp(-dot(d2, d2) / 0.016) * 0.25 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	marble_post(acc, f, -POST_X);
	marble_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	lacquer_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		bomb(acc, f);
		fuse_spark(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
