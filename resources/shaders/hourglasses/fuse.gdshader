shader_type canvas_item;
// 導火線(フューズ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は麻の導火線を螺旋に巻いた黒漆の棒、板は胡桃の木に黒色火薬の煤の溝と、そこを這う導火線の火の点。
// 天板の上には導火線を巻いた木の糸巻きが寝かせてあり、ほどけた端の先で火の点がはぜる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 POWDER = vec3(0.11, 0.10, 0.10);
const vec3 HEMP = vec3(0.86, 0.68, 0.40);
const vec3 ASH = vec3(0.40, 0.38, 0.37);
const vec3 SPARK = vec3(1.0, 0.70, 0.24);
const vec3 SPARK_HOT = vec3(1.0, 0.97, 0.80);
const vec3 LACQUER = vec3(0.17, 0.15, 0.15);
const vec3 WALNUT = vec3(0.50, 0.32, 0.20);
const vec3 BRASS = vec3(0.90, 0.70, 0.36);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.052;
// 板の導火線が燃えている位置
const float LIT_X = 0.24;
// 糸巻きの中心・胴の半幅と半径・鍔の厚さと半径、ほどけた端の先
const vec2 SPOOL = vec2(-0.07, 1.276);
const vec2 BARREL_HALF = vec2(0.104, 0.056);
const float FLANGE_HALF = 0.024;
const float FLANGE_R = 0.084;
const vec2 FREE_TIP = vec2(0.265, 1.302);

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

// 導火線を螺旋に巻いた黒漆の柱
void wound_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, LACQUER, 0.0);
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay < 0.93) {
		float u = clamp(lx / POST_R, -1.0, 1.0);
		float s = fract(f.p.y * 6.0 + u * 0.32);
		float band = abs(s - 0.5) - 0.20;
		vec3 n = lathe_normal(u, (s - 0.5) * 1.2);
		float edge = max(abs(lx) - POST_R + 0.004, -1.0);
		float a = cov(band / 6.0, f.px) * cov(edge, f.px);
		over(acc, ink_of(HEMP), cov((band - 0.05) / 6.0, f.px) * cov(edge, f.px));
		vec3 hemp = HEMP * (0.85 + 0.25 * step(0.5, fract(s * 6.0 + u)));
		over(acc, shade_mat(hemp, n, 0.0, 0.5, f.ao), a);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), BRASS, 1.0);
}

void walnut_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, WALNUT, 0.0, 0.7);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	fuse_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, BRASS, 1.0);
	}
}

// ほどけた端: 胴の上から右へ弧を描いて垂れる
float free_end(vec2 p, out float along) {
	float best = 9.0;
	along = 0.0;
	vec2 a = SPOOL + vec2(0.05, BARREL_HALF.y - 0.004);
	vec2 prev = a;
	for (int i = 1; i <= 10; i++) {
		float t = float(i) / 10.0;
		vec2 b = mix(a, FREE_TIP, t) + vec2(0.0, 0.052 * sin(t * 2.9));
		float dd = sd_segment(p, prev, b);
		if (dd < best) {
			best = dd;
			along = t;
		}
		prev = b;
	}
	return best;
}

void spool(inout vec4 acc, Px f) {
	vec2 q = f.p - SPOOL;
	if (q.x < -0.16 || q.x > 0.40 || abs(q.y) > 0.12) {
		return;
	}
	// 胴に巻いた導火線(縦の巻き目)
	float d_coil = sd_round_box(q, BARREL_HALF, 0.03);
	float wind = fract(q.x * 26.0 + q.y * 3.0);
	vec3 n = normalize(vec3(0.0, clamp(q.y / BARREL_HALF.y, -1.0, 1.0) * 0.8, 0.6));
	vec3 hemp = mix(HEMP * 0.62, HEMP * 1.05, smoothstep(0.1, 0.5, wind) * smoothstep(1.0, 0.7, wind));
	part(acc, d_coil, ink_of(HEMP), shade_mat(hemp, n, 0.0, 0.6, 1.0), f.ow, f.px);
	// 鍔(木)
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		vec2 fq = q - vec2(sx * (BARREL_HALF.x + FLANGE_HALF - 0.004), 0.0);
		float d_fl = sd_round_box(fq, vec2(FLANGE_HALF, FLANGE_R), 0.016);
		vec3 fn = normalize(vec3(clamp(fq.x / FLANGE_HALF, -1.0, 1.0) * 0.5, clamp(fq.y / FLANGE_R, -1.0, 1.0) * 0.4, 0.75));
		part(acc, d_fl, ink_of(WALNUT), shade_mat(WALNUT * 1.25, fn, 0.0, 0.8, 1.0), f.ow, f.px);
	}
	// ほどけた端と火の点
	float along;
	float d_end = free_end(f.p, along) - 0.013;
	float tw = fract(along * 24.0);
	part(acc, d_end, ink_of(HEMP), mix(HEMP * 0.75, HEMP * 1.08, step(0.45, tw)), f.ow * 0.8, f.px);
	vec2 s = f.p - FREE_TIP;
	add_light(acc, SPARK, exp(-dot(s, s) / 0.0022) * 0.95);
	add_light(acc, SPARK_HOT, star4(s, 0.085));
	for (int k = 0; k < 5; k++) {
		float a = 0.5 + 1.25 * float(k);
		vec2 o = s - vec2(cos(a), sin(a)) * (0.050 + 0.014 * float(k % 2));
		over(acc, SPARK_HOT, cov(length(o) - 0.008, f.px));
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - FREE_TIP;
	add_light(acc, SPARK, exp(-dot(d, d) / 0.014) * 0.6 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	wound_post(acc, f, -POST_X);
	wound_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	walnut_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		spool(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
