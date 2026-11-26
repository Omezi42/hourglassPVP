shader_type canvas_item;
// 歯車仕掛け(クロックワーク)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は真鍮のぜんまいを巻いた鋼の棒、板は鋼に朝空の七宝と真鍮の音の輪。天板の上で大小三つの歯車が噛み合う。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.94, 0.74, 0.36);
const vec3 SKY = vec3(0.62, 0.82, 0.98);
const vec3 SKY_DEEP = vec3(0.30, 0.48, 0.82);
const vec3 DAYBREAK = vec3(1.0, 0.76, 0.52);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec3 STEEL = vec3(0.80, 0.84, 0.92);
const float POST_R = 0.050;
const vec2 BIG_C = vec2(-0.02, 1.272);
const float BIG_R = 0.098;
const vec2 SMALL_C = vec2(0.146, 1.243);
const float SMALL_R = 0.062;
const vec2 TINY_C = vec2(-0.171, 1.232);
const float TINY_R = 0.050;
const float TOOTH = 0.016;

// 早鐘の刻の印: 板に嵌めた朝空の七宝。中央の鐘の口から左右へ、真鍮の音の輪が広がる
void toll_band(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.07) {
		return;
	}
	float strip = sd_round_box(q, vec2(0.68, 0.044), 0.038);
	vec3 sky = mix(SKY_DEEP, SKY, smoothstep(-0.05, 0.05, q.y));
	sky = mix(sky, DAYBREAK, exp(-q.x * q.x / 0.03) * smoothstep(0.05, -0.04, q.y) * 0.9);
	inlay(acc, d, ink_of(BRASS), cov(strip - 0.013, f.px), f);
	inlay(acc, d, BRASS, cov(strip - 0.008, f.px), f);
	inlay(acc, d, sky, cov(strip, f.px), f);
	float inside = cov(strip + 0.003, f.px);
	for (int k = 0; k < 4; k++) {
		float j = float(k) / 3.0;
		float dr = abs(length(vec2(q.x, q.y * 4.0)) - 0.17 - 0.14 * float(k)) - mix(0.015, 0.010, j);
		inlay(acc, d, mix(BRASS * 1.15, BRASS, j), cov(dr, f.px) * inside, f);
	}
	vec2 b = q - vec2(0.0, -0.040);
	float d_dome = max(length(b) - 0.066, -b.y);
	inlay(acc, d, ink_of(BRASS), cov(d_dome - 0.010, f.px), f);
	vec3 n = normalize(vec3(b / 0.066 * 0.6, 0.75));
	inlay(acc, d, shade_mat(BRASS, n, 1.0, 1.0, 1.0), cov(d_dome, f.px), f);
}

// 鋼の棒に真鍮のぜんまいが巻き付く
void spring_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + 0.02 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	part(acc, d, ink_of(STEEL * 0.7), shade_mat(STEEL, n, 1.0, 1.0, f.ao), f.ow, f.px);
	float s = fract((f.p.y + asin(u) * POST_R * 0.9) * 11.0);
	float coil = smoothstep(0.0, 0.08, s) * smoothstep(0.50, 0.42, s) * step(f.ay, 0.86) * step(0.12, f.ay);
	vec3 cn = normalize(vec3(u, (s - 0.25) * 1.6, 0.6));
	over(acc, shade_mat(BRASS, cn, 1.0, 1.0, f.ao), coil * cov(d - 0.008, f.px));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), BRASS, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.070, 0.022), BRASS, 1.0);
}

void steel_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, STEEL, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	toll_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, BRASS, 1.0);
	}
}

// 歯車1つ: 歯の付いた輪と、肉抜きの窓、軸
void gear(inout vec4 acc, Px f, vec2 c, float r, float teeth, float phase, vec3 col, float windows) {
	vec2 q = f.p - c;
	float l = length(q);
	if (l > r + TOOTH + f.pad) {
		return;
	}
	float a = atan(q.y, q.x) * teeth + phase;
	float tooth = smoothstep(-0.35, 0.35, cos(a));
	float d = l - r - TOOTH * tooth;
	float wa = fract(atan(q.y, q.x) * windows / 6.2832 + phase * 0.1);
	float win = max(max(r * 0.30 - l, l - r * 0.70), (0.22 - abs(wa - 0.5)) * l);
	d = max(d, -win);
	vec3 n = normalize(vec3(q / r * (l > r * 0.78 ? 0.55 : 0.2), 0.8));
	vec3 c2 = shade_mat(col, n, 1.0, 1.0, 1.0);
	c2 = mix(c2, c2 * 0.75, cov(abs(l - r * 0.78) - 0.004, f.px));
	part(acc, d, ink_of(col), c2, f.ow, f.px);
	draw_ball(acc, f, c, r * 0.13, col * 0.9, 1.0);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.6, f.p.y - 1.27);
	add_light(acc, SKY, exp(-dot(d, d) / 0.02) * 0.4 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	spring_post(acc, f, -POST_X);
	spring_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	steel_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y && abs(f.p.x) < 0.27) {
		gear(acc, f, TINY_C, TINY_R, 7.0, 0.6, STEEL, 4.0);
		gear(acc, f, SMALL_C, SMALL_R, 9.0, 1.9, STEEL, 4.0);
		gear(acc, f, BIG_C, BIG_R, 13.0, 0.0, BRASS, 5.0);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
