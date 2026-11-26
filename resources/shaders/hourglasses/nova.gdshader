shader_type canvas_item;
// 超新星(ノヴァ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は金の星屑を散らした菫色の漆、板は金に黒色火薬の煤の溝と、そこを這う導火線の火の点。
// 天板の上の金の受け皿で、星が白く弾けて長短八本の光芒を放ち、菫色の衝撃の輪が広がる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 POWDER = vec3(0.11, 0.10, 0.10);
const vec3 HEMP = vec3(0.86, 0.68, 0.40);
const vec3 ASH = vec3(0.40, 0.38, 0.37);
const vec3 SPARK = vec3(1.0, 0.70, 0.24);
const vec3 SPARK_HOT = vec3(1.0, 0.97, 0.80);
const vec3 BRASS = vec3(0.94, 0.74, 0.36);
const vec3 VIOLET = vec3(0.34, 0.22, 0.52);
const vec3 NOVA_GLOW = vec3(0.78, 0.60, 1.0);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.050;
const float LIT_X = 0.24;
// 星の中心・芯の半径・長い光芒と短い光芒の長さ、衝撃の輪の半径
const vec2 STAR_C = vec2(0.0, 1.294);
const float CORE_R = 0.043;
const float RAY_LONG = 0.058;
const float RAY_SHORT = 0.034;
const float SHOCK_R = 0.140;

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

// 金の星屑を散らした菫色の漆の柱
void violet_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, VIOLET, 0.0);
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R - 0.006 && f.ay < 0.92) {
		vec2 cell = floor(vec2(lx, f.p.y) * vec2(30.0, 18.0));
		vec2 jit = hash22(cell) - 0.5;
		vec2 local = (fract(vec2(lx, f.p.y) * vec2(30.0, 18.0)) - 0.5 - jit * 0.4) / vec2(30.0, 18.0);
		float s = star4(local, 0.016) * step(0.55, hash21(cell + 3.0));
		over(acc, mix(BRASS, SPARK_HOT, 0.4), s);
	}
	for (int k = 0; k < 2; k++) {
		draw_band(acc, f, vec2(cx, f.side * (0.30 + 0.40 * float(k))), vec2(0.064, 0.016), BRASS, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), BRASS, 1.0);
}

void gold_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, BRASS, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	fuse_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, VIOLET, 0.0);
	}
}

// 星を受ける金の皿(三日月形)
void cradle(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, 1.214);
	if (abs(q.x) > 0.12 || abs(q.y) > 0.06) {
		return;
	}
	float d_bowl = max(sd_ellipse(q, vec2(0.090, 0.034)), -sd_ellipse(q - vec2(0.0, 0.022), vec2(0.080, 0.030)));
	vec3 n = normalize(vec3(q.x / 0.09 * 0.6, -0.3, 0.75));
	part(acc, d_bowl, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(abs(n.x), 0.4, 0.75)), 1.0, 1.0, 1.0), f.ow, f.px);
	float d_foot = sd_round_box(q - vec2(0.0, -0.030), vec2(0.030, 0.010), 0.006);
	part(acc, d_foot, ink_of(BRASS), BRASS, f.ow, f.px);
}

void nova_star(inout vec4 acc, Px f) {
	vec2 q = f.p - STAR_C;
	if (length(q) > SHOCK_R + 0.04) {
		return;
	}
	// 衝撃の輪(横長の楕円。上下は欠けて弧になる)
	float ring = abs(length(q * vec2(1.0, 1.7)) - SHOCK_R) - 0.006;
	float arc = smoothstep(0.35, 0.75, abs(q.x) / SHOCK_R);
	over(acc, VIOLET, cov(ring - 0.006, f.px) * arc);
	over(acc, NOVA_GLOW, cov(ring, f.px) * arc);
	// 光芒: 縦横の長い4本と斜めの短い4本
	float ang = atan(q.y, q.x);
	float c4 = cos(ang * 4.0);
	float rad = CORE_R * 0.7 + RAY_LONG * pow(max(c4, 0.0), 14.0) + RAY_SHORT * pow(max(-c4, 0.0), 14.0);
	float d_ray = length(q) - rad;
	over(acc, NOVA_GLOW, cov(d_ray - 0.006, f.px));
	over(acc, mix(SPARK_HOT, vec3(1.0), 0.5), cov(d_ray, f.px));
	add_light(acc, NOVA_GLOW, exp(-dot(q, q) / 0.004) * 0.8);
	vec3 cn = normalize(vec3(q / CORE_R * 0.6, 0.75));
	part(acc, length(q) - CORE_R, NOVA_GLOW * 0.7, mix(vec3(1.0, 0.98, 0.92), SPARK_HOT, clamp(-cn.x, 0.0, 1.0)), f.ow * 0.6, f.px);
	add_light(acc, vec3(1.0), exp(-dot(q, q) / 0.0006) * 0.9);
	// 散る星屑
	for (int k = 0; k < 6; k++) {
		float a = 0.4 + 1.047 * float(k);
		vec2 o = q - vec2(cos(a), sin(a) * 0.62) * (0.092 + 0.012 * float(k % 2));
		over(acc, SPARK_HOT, cov(length(o) - 0.0065, f.px));
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.7, f.p.y - STAR_C.y);
	add_light(acc, NOVA_GLOW, exp(-dot(d, d) / 0.012) * 0.7 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	violet_post(acc, f, -POST_X);
	violet_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	gold_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		cradle(acc, f);
		nova_star(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
