shader_type canvas_item;
// 時の神(クロノス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は月桂樹の金の蔓が這う白大理石の円柱、板には時を刻む文字の帯。天板の上に翼を広げた小さな砂時計の紋章。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 MARBLE = vec3(0.94, 0.92, 0.88);
const vec3 FEATHER = vec3(0.98, 0.96, 0.92);
const vec3 DEEP = vec3(0.20, 0.16, 0.30);
const float POST_R = 0.054;
const vec2 SLAB_HALF = vec2(0.84, 0.088);
const vec2 EMBLEM = vec2(0.0, 1.200);

void laurel_column(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(MARBLE, n, 0.0, 1.0, f.ao);
	// 縦の溝(フルート)
	float flute = abs(fract(lx / POST_R * 2.5 + 0.5) - 0.5);
	c *= 1.0 - 0.14 * (1.0 - smoothstep(0.05, 0.20, flute));
	part(acc, d, ink_of(MARBLE * 0.6), c, f.ow, f.px);
	// 這い上がる金の蔓と葉
	float ph = f.p.y * 1.3 * 6.2832 + cx * 2.0;
	float rx = 0.064 * sin(ph);
	float front = cos(ph);
	float d_vine = max(abs(lx - rx) - 0.007, f.ay - POST_H + 0.06);
	if (front > -0.2) {
		part(acc, d_vine, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, f.ao), f.ow * 0.4, f.px);
		vec2 lq = vec2(lx - rx, fract(f.p.y * 1.3 * 4.0) / 5.2 - 0.096);
		lq = rot(lq, 0.8 * sign(sin(ph * 2.0)));
		if (f.ay < POST_H - 0.07) {
			part(acc, sd_ellipse(lq, vec2(0.010, 0.022)), ink_of(GOLD), mix(GOLD, sand_color, 0.35), f.ow * 0.4, f.px);
		}
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.092, 0.030), GOLD, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.885), vec2(0.072, 0.014), GOLD, 1.0);
}

void time_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, DEEP, 0.3, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.064) - 0.005);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.80), f);
	// ローマ数字風の縦棒の組(I, II, III...)
	float k = floor(q.x / 0.13 + 0.5);
	float x0 = q.x - k * 0.13;
	float count = mod(abs(k) - 1.0, 3.0) + 1.0;
	float bars = 0.0;
	for (int b = 0; b < 3; b++) {
		float bx = (float(b) - (count - 1.0) * 0.5) * 0.016;
		bars = max(bars, step(abs(x0 - bx), 0.004) * step(float(b), count - 0.5));
	}
	bars *= step(abs(q.y), 0.030);
	float serif = step(abs(abs(q.y) - 0.030), 0.004) * step(abs(x0), count * 0.008 + 0.006);
	inlay(acc, d, GOLD, max(bars, serif) * step(0.08, abs(q.x)) * step(abs(q.x), 0.76), f);
	inlay(acc, d, sand_color, star4(q, 0.070), f);
	inlay(acc, d, mix(sand_color, vec3(1.0), 0.5), cov(length(q) - 0.014, f.px), f);
}

// 翼の砂時計: 金の小さな砂時計、左右に広げた3段の翼
void winged_hourglass(inout vec4 acc, Px f) {
	vec2 q = f.p - EMBLEM;
	if (abs(q.x) > 0.27 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	for (int s = -1; s <= 1; s += 2) {
		vec2 wq = vec2(q.x * float(s), q.y);
		for (int k = 2; k >= 0; k--) {
			float len = 0.200 - 0.040 * float(k);
			vec2 fq = rot(wq - vec2(0.040, 0.010 - 0.030 * float(k)), -0.35 - 0.20 * float(k));
			float d_f = max(sd_ellipse(fq - vec2(len * 0.5, 0.0), vec2(len * 0.5, 0.026 - 0.004 * float(k))), -fq.x);
			vec3 fc = mix(FEATHER, mix(GOLD, sand_color, 0.3), 0.25 * float(k));
			part(acc, d_f, ink_of(GOLD), shade_mat(fc, normalize(vec3(0.0, fq.y * 15.0, 0.8)), 0.0, 0.8, 1.0), f.ow * 0.6, f.px);
		}
	}
	// 砂時計: 上下の金の板と、くびれた硝子に砂の色
	vec2 hq = q - vec2(0.0, 0.0);
	float w = 0.012 + abs(hq.y) * 0.75;
	float d_glass = max(abs(hq.x) - w, abs(hq.y) - 0.060);
	vec3 gc = mix(vec3(0.90, 0.95, 1.0), sand_color, step(hq.y, -0.020) + step(0.025, hq.y) * step(abs(hq.x), w * 0.8));
	part(acc, d_glass, ink_of(GOLD), gc, f.ow * 0.7, f.px);
	for (int s = -1; s <= 1; s += 2) {
		part(acc, sd_round_box(hq - vec2(0.0, float(s) * 0.068), vec2(0.060, 0.010), 0.004), ink_of(GOLD), shade_mat(GOLD, normalize(vec3(0.0, float(s) * 0.4, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - EMBLEM;
	float r = length(q);
	float a = atan(q.y, q.x);
	float rays = smoothstep(0.6, 1.0, cos(a * 10.0)) * smoothstep(0.28, 0.10, r) * step(-0.02, q.y);
	add_light(acc, mix(GOLD, sand_color, 0.4), rays * 0.5 + exp(-r * r / 0.010) * 0.45);
}

void art_frame(inout vec4 acc, Px f) {
	laurel_column(acc, f, -POST_X);
	laurel_column(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	time_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		winged_hourglass(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
