shader_type canvas_item;
// 汽缶(ボイラー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は鉄のつば輪で継いだ銅の管、板は鋲を打った銅に朝空の七宝と真鍮の音の輪。天板の上に寝かせた銅の釜が、圧力計を立て、汽笛から湯気を噴く。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.94, 0.74, 0.36);
const vec3 SKY = vec3(0.62, 0.82, 0.98);
const vec3 SKY_DEEP = vec3(0.30, 0.48, 0.82);
const vec3 DAYBREAK = vec3(1.0, 0.76, 0.52);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec3 COPPER = vec3(0.86, 0.48, 0.30);
const vec3 IRON = vec3(0.30, 0.30, 0.34);
const vec3 STEAM = vec3(0.95, 0.97, 1.0);
const vec3 GAUGE = vec3(0.97, 0.94, 0.86);
const vec3 NEEDLE = vec3(0.84, 0.16, 0.14);
const float POST_R = 0.052;
const vec2 TANK_C = vec2(-0.06, 1.252);
const vec2 TANK_HALF = vec2(0.27, 0.062);
const vec2 GAUGE_C = vec2(-0.22, 1.342);
const vec2 WHISTLE = vec2(0.12, 1.308);

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

void pipe_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, COPPER, 1.0);
	for (int k = 0; k < 2; k++) {
		float y = 0.30 + 0.40 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(0.074, 0.026), IRON, 1.0);
		draw_ball(acc, f, vec2(cx - 0.044, f.side * y), 0.010, BRASS, 1.0);
		draw_ball(acc, f, vec2(cx + 0.044, f.side * y), 0.010, BRASS, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), IRON, 1.0);
}

void copper_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, COPPER, 1.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	toll_band(acc, f, d, q);
	for (int k = 0; k < 4; k++) {
		float x = (k < 2 ? -1.0 : 1.0) * 0.76;
		float y = (k % 2 == 0 ? -1.0 : 1.0) * 0.046;
		draw_ball(acc, f, vec2(x, cy + y), 0.014, IRON * 1.4, 1.0);
	}
}

// 寝かせた銅の釜: 胴に鋲の列と真鍮の帯、下に鉄の受け
void tank(inout vec4 acc, Px f) {
	for (int k = -1; k <= 1; k += 2) {
		vec2 sq = f.p - vec2(TANK_C.x + float(k) * 0.17, PLATE_Y + 0.105);
		part(acc, sd_round_box(sq, vec2(0.030, 0.030), 0.008), vec3(0.05), shade_mat(IRON, normalize(vec3(0.0, 0.4, 0.8)), 1.0, 0.6, 1.0), f.ow, f.px);
	}
	vec2 q = f.p - TANK_C;
	float d = sd_round_box(q, TANK_HALF, TANK_HALF.y * 0.95);
	vec3 n = normalize(vec3(clamp(q.x / TANK_HALF.x, -1.0, 1.0) * 0.35, q.y / TANK_HALF.y * 0.8, 0.6));
	vec3 c = shade_mat(COPPER, n, 1.0, 1.0, 1.0);
	float seam = step(abs(abs(q.x) - 0.17), 0.012);
	c = mix(c, shade_mat(BRASS, n, 1.0, 1.0, 1.0), seam);
	float rivet = cov(length(vec2(abs(q.x) - 0.10, mod(q.y + 0.0125, 0.025) - 0.0125)) - 0.006, f.px);
	c = mix(c, c * 0.55, rivet * step(abs(q.y), 0.045));
	part(acc, d, ink_of(COPPER), c, f.ow, f.px);
}

// 圧力計: 真鍮の縁に白い盤、赤い針が振り切れる手前
void gauge(inout vec4 acc, Px f) {
	float d_stem = max(abs(f.p.x - GAUGE_C.x) - 0.010, max(TANK_C.y - f.p.y, f.p.y - GAUGE_C.y));
	part(acc, d_stem, vec3(0.05), BRASS * 0.8, f.ow * 0.7, f.px);
	vec2 q = f.p - GAUGE_C;
	if (length(q) > 0.060) {
		return;
	}
	part(acc, length(q) - 0.046, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(q / 0.046 * 0.6, 0.75)), 1.0, 1.0, 1.0), f.ow, f.px);
	over(acc, GAUGE, cov(length(q) - 0.034, f.px));
	vec2 tip = vec2(sin(1.1), cos(1.1)) * 0.028;
	over(acc, NEEDLE, cov(sd_segment(q, vec2(0.0), tip) - 0.005, f.px));
	over(acc, vec3(0.15), cov(length(q) - 0.007, f.px));
}

// 汽笛と、そこから右へ流れる湯気
void whistle(inout vec4 acc, Px f) {
	vec2 q = f.p - WHISTLE;
	float d = sd_round_box(q - vec2(0.0, 0.020), vec2(0.020, 0.026), 0.006);
	part(acc, d, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(clamp(q.x / 0.02, -1.0, 1.0) * 0.7, 0.0, 0.7)), 1.0, 1.0, 1.0), f.ow, f.px);
	float d_cap = sd_round_box(q - vec2(0.0, 0.052), vec2(0.028, 0.008), 0.006);
	part(acc, d_cap, ink_of(BRASS), BRASS * 1.1, f.ow, f.px);
	for (int k = 0; k < 4; k++) {
		float j = float(k);
		vec2 c = WHISTLE + vec2(0.058 + 0.068 * j, 0.040 + 0.006 * sin(j * 2.0));
		float r = 0.022 + 0.005 * j;
		float d_puff = length(f.p - c) - r;
		float a = 1.0 - 0.12 * j;
		over(acc, vec3(0.62, 0.66, 0.74), cov(d_puff - 0.008, f.px) * a);
		over(acc, mix(STEAM, SKY, 0.15 + 0.1 * j), cov(d_puff, f.px) * a);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2((f.p.x - 0.20) * 0.6, f.p.y - 1.36);
	add_light(acc, SKY, exp(-dot(d, d) / 0.02) * 0.35 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	pipe_post(acc, f, -POST_X);
	pipe_post(acc, f, POST_X);
	draw_collars(acc, f, COPPER, 1.0);
	copper_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y && abs(f.p.x) < 0.55) {
		gauge(acc, f);
		tank(acc, f);
		whistle(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
