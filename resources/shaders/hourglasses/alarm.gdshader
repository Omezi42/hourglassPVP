shader_type canvas_item;
// 目覚まし(アラーム)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は銀の口金をはめた赤い琺瑯の管、板は磨いた銀に朝空の七宝と真鍮の音の輪。天板の上で、二つの鐘を背負った赤い目覚まし時計が震えて鳴る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.94, 0.74, 0.36);
const vec3 SKY = vec3(0.62, 0.82, 0.98);
const vec3 SKY_DEEP = vec3(0.30, 0.48, 0.82);
const vec3 DAYBREAK = vec3(1.0, 0.76, 0.52);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec3 RED = vec3(0.84, 0.18, 0.18);
const vec3 CHROME = vec3(0.84, 0.87, 0.92);
const vec3 DIAL = vec3(0.97, 0.95, 0.88);
const float POST_R = 0.052;
const vec2 CLOCK_C = vec2(0.0, 1.256);
const float CLOCK_R = 0.074;

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

void enamel_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, RED, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.50), vec2(0.066, 0.022), CHROME, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.066, 0.022), CHROME, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), CHROME, 1.0);
}

void chrome_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, CHROME, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	toll_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, RED, 0.0);
	}
}

// 背の二つの鐘と、間で打つ槌
void bells(inout vec4 acc, Px f) {
	for (int k = -1; k <= 1; k += 2) {
		vec2 c = CLOCK_C + vec2(float(k) * 0.062, 0.072);
		vec2 q = rot(f.p - c, float(k) * 0.45);
		float d = max(length(q) - 0.037, -q.y - 0.004);
		vec3 n = normalize(vec3(q / 0.037 * 0.7, 0.7));
		part(acc, d, ink_of(BRASS), shade_mat(BRASS, n, 1.0, 1.0, 1.0), f.ow, f.px);
		draw_ball(acc, f, c + rot(vec2(0.0, 0.040), -float(k) * 0.45), 0.008, BRASS, 1.0);
	}
	float d_arm = sd_segment(f.p, CLOCK_C + vec2(0.0, CLOCK_R - 0.01), CLOCK_C + vec2(0.012, 0.104)) - 0.005;
	part(acc, d_arm, vec3(0.05), CHROME * 0.8, f.ow * 0.6, f.px);
	draw_ball(acc, f, CLOCK_C + vec2(0.014, 0.108), 0.012, CHROME, 1.0);
}

void legs(inout vec4 acc, Px f) {
	for (int k = -1; k <= 1; k += 2) {
		vec2 a = CLOCK_C + vec2(float(k) * 0.045, -0.060);
		vec2 b = vec2(CLOCK_C.x + float(k) * 0.070, PLATE_Y + 0.090);
		part(acc, sd_segment(f.p, a, b) - 0.010, vec3(0.05), CHROME * 0.8, f.ow * 0.7, f.px);
	}
}

// 赤い胴、銀の縁、白い文字盤。針は朝の6時
void clock_face(inout vec4 acc, Px f) {
	vec2 q = f.p - CLOCK_C;
	float r = length(q);
	if (r > CLOCK_R + f.pad) {
		return;
	}
	vec3 n = normalize(vec3(q / CLOCK_R * 0.7, 0.7));
	part(acc, r - CLOCK_R, ink_of(RED), shade_mat(RED, n, 0.0, 1.0, 1.0), f.ow, f.px);
	over(acc, shade_mat(CHROME, n, 1.0, 1.0, 1.0), cov(r - 0.066, f.px));
	over(acc, DIAL, cov(r - 0.056, f.px));
	for (int k = 0; k < 12; k++) {
		float a = float(k) * 0.5236;
		vec2 dir = vec2(sin(a), cos(a));
		float len = k % 3 == 0 ? 0.012 : 0.006;
		over(acc, vec3(0.2), cov(sd_segment(q, dir * (0.048 - len), dir * 0.048) - 0.003, f.px));
	}
	over(acc, vec3(0.12), cov(sd_segment(q, vec2(0.0), vec2(0.0, -0.030)) - 0.005, f.px));
	over(acc, vec3(0.12), cov(sd_segment(q, vec2(0.0), vec2(0.0, 0.042)) - 0.004, f.px));
	over(acc, RED, cov(sd_segment(q, vec2(0.0), vec2(sin(-0.6), cos(-0.6)) * 0.036) - 0.003, f.px));
	over(acc, RED, cov(r - 0.008, f.px));
}

// 震えの線: 鐘の外側の短い弧
void shiver(inout vec4 acc, Px f) {
	vec2 q = f.p - CLOCK_C;
	float ang = atan(q.y, abs(q.x));
	float mask = smoothstep(-0.10, 0.10, ang) * smoothstep(0.75, 0.55, ang);
	for (int k = 0; k < 2; k++) {
		float dr = abs(length(q) - 0.128 - 0.045 * float(k)) - (0.012 - 0.003 * float(k));
		over(acc, ink_of(RED), cov(dr - 0.007, f.px) * mask);
		over(acc, mix(RED * 1.15, BRASS, 0.3 * float(k)), cov(dr, f.px) * mask);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - CLOCK_C;
	add_light(acc, DAYBREAK, exp(-dot(d, d) / 0.02) * 0.5 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	enamel_post(acc, f, -POST_X);
	enamel_post(acc, f, POST_X);
	draw_collars(acc, f, CHROME, 1.0);
	chrome_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y && abs(f.p.x) < 0.32) {
		shiver(acc, f);
		legs(acc, f);
		bells(acc, f);
		clock_face(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
