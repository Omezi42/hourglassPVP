shader_type canvas_item;
// 組鐘(カリヨン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は鐘楼の窓を穿った白い石、板は石灰岩に朝空の七宝と真鍮の音の輪。天板の上の樫の梁に、大きさの揃った七つの鐘が吊られる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.94, 0.74, 0.36);
const vec3 SKY = vec3(0.62, 0.82, 0.98);
const vec3 SKY_DEEP = vec3(0.30, 0.48, 0.82);
const vec3 DAYBREAK = vec3(1.0, 0.76, 0.52);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec3 LIMESTONE = vec3(0.90, 0.86, 0.76);
const vec3 OAK = vec3(0.44, 0.29, 0.18);
const vec3 BRONZE = vec3(0.90, 0.64, 0.30);
const float POST_HALF = 0.060;
const float BEAM_Y = 1.368;
const float BEAM_HALF = 0.56;

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

// 鐘の形。q は冠の上からの位置(下が負)。t は冠(0)から口(1)まで
float bell_sd(vec2 q, float h, float m, out float t) {
	t = clamp(-q.y / h, 0.0, 1.0);
	float hw = mix(m * 0.40, m * 0.68, smoothstep(0.0, 0.35, t));
	hw = mix(hw, m, smoothstep(0.62, 1.0, t));
	float d_body = max(abs(q.x) - hw, max(q.y + h * 0.12, -h - q.y));
	float d_crown = max(length(q - vec2(0.0, -h * 0.17)) - m * 0.42, -h * 0.17 - q.y);
	return min(d_body, d_crown);
}

// 鐘楼の窓を穿った角柱
void belfry_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.6 ? 0.55 : (face < -0.6 ? -0.55 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(LIMESTONE, n, 0.0, 0.3, f.ao);
	for (int k = 0; k < 2; k++) {
		float y = 0.34 + 0.34 * float(k);
		vec2 w = vec2(lx, f.ay - y);
		float d_win = max(abs(w.x) - 0.020, abs(w.y) - 0.070);
		d_win = min(d_win, length(w - vec2(0.0, 0.070)) - 0.020);
		d_win = max(d_win, -(w.y + 0.070));
		c = mix(c, SKY_DEEP * 0.45, cov(d_win, f.px));
		c = mix(c, BRONZE, cov(length(w - vec2(0.0, 0.030)) - 0.012, f.px));
	}
	part(acc, d, ink_of(LIMESTONE * 0.8), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.086, 0.030), BRASS, 1.0);
}

void stone_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, LIMESTONE, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	toll_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, BRASS, 1.0);
	}
}

// 樫の梁と両端の支柱
void beam(inout vec4 acc, Px f) {
	vec3 wood = shade_mat(OAK, normalize(vec3(0.0, 0.4, 0.8)), 0.0, 0.6, 1.0);
	for (int k = -1; k <= 1; k += 2) {
		float x = float(k) * BEAM_HALF;
		float d_leg = max(abs(f.p.x - x) - 0.018, max(PLATE_Y - f.p.y, f.p.y - BEAM_Y));
		part(acc, d_leg, ink_of(OAK), wood, f.ow, f.px);
	}
	float d = sd_round_box(f.p - vec2(0.0, BEAM_Y), vec2(BEAM_HALF + 0.04, 0.016), 0.010);
	part(acc, d, ink_of(OAK), wood * 1.08, f.ow, f.px);
}

// 七つの鐘。左の大きな鐘から右の小さな鐘へ
void bells(inout vec4 acc, Px f) {
	int i = int(clamp(floor((f.p.x + 0.525) / 0.15), 0.0, 6.0));
	for (int k = max(i - 1, 0); k <= min(i + 1, 6); k++) {
		float s = mix(1.0, 0.62, float(k) / 6.0);
		float h = 0.140 * s;
		float m = 0.070 * s;
		vec2 top = vec2(-0.45 + 0.15 * float(k), BEAM_Y - 0.020);
		vec2 q = f.p - top;
		if (abs(q.x) > m + 0.03 || q.y > 0.03 || q.y < -h - 0.03) {
			continue;
		}
		over(acc, vec3(0.20, 0.14, 0.10), cov(max(abs(q.x) - 0.006, max(q.y - 0.016, -q.y - 0.004)), f.px));
		float t;
		float d = bell_sd(q, h, m, t);
		vec3 n = normalize(vec3(clamp(q.x / (m * 0.8), -1.0, 1.0) * 0.75, 0.15, 0.65));
		vec3 c = shade_mat(BRONZE, n, 1.0, 1.0, 1.0);
		c = mix(c, c * 0.62, cov(abs(t - 0.60) - 0.03, f.px / h));
		part(acc, d, ink_of(BRONZE), c, f.ow, f.px);
		vec2 mq = q - vec2(0.0, -h);
		part(acc, sd_round_box(mq, vec2(m + 0.005, 0.009), 0.007), ink_of(BRONZE), shade_mat(BRONZE * 1.1, normalize(vec3(mq.x / m * 0.6, 0.2, 0.75)), 1.0, 1.0, 1.0), f.ow, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.35, f.p.y - 1.29);
	add_light(acc, DAYBREAK, exp(-dot(d, d) / 0.02) * 0.45 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	belfry_post(acc, f, -POST_X);
	belfry_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	stone_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y && abs(f.p.x) < BEAM_HALF + 0.08) {
		beam(acc, f);
		bells(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
