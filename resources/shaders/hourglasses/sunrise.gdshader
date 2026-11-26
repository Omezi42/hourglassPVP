shader_type canvas_item;
// 日の出(サンライズ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は朝空の帯を巻いた白磁、板は白磁に朝空の七宝と真鍮の音の輪。天板の上の真鍮の地平から朝日が半分のぞき、光の矢を放つ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.94, 0.74, 0.36);
const vec3 SKY = vec3(0.62, 0.82, 0.98);
const vec3 SKY_DEEP = vec3(0.30, 0.48, 0.82);
const vec3 DAYBREAK = vec3(1.0, 0.76, 0.52);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec3 PORCELAIN = vec3(0.96, 0.95, 0.92);
const vec3 SUN = vec3(1.0, 0.56, 0.18);
const vec3 SUN_HOT = vec3(1.0, 0.90, 0.52);
const vec3 CLOUD = vec3(0.98, 0.90, 0.88);
const float POST_R = 0.056;
const vec2 SUN_C = vec2(0.0, 1.206);
const float SUN_R = 0.112;

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

void porcelain_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, PORCELAIN, 0.0);
	float lx = f.p.x - cx;
	if (abs(lx) < POST_R && f.ay < POST_H - 0.06) {
		float s = fract(f.p.y * 3.2 + lx * 2.0);
		float band = smoothstep(0.0, 0.03, s) * smoothstep(0.30, 0.27, s);
		vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
		vec3 c = mix(SKY_DEEP, mix(SKY, DAYBREAK, smoothstep(0.1, 0.25, s)), smoothstep(0.0, 0.12, s));
		over(acc, shade_mat(c, n, 0.0, 1.0, f.ao), band * 0.9);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), BRASS, 1.0);
}

void porcelain_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, PORCELAIN, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	toll_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, BRASS, 1.0);
	}
}

// 朝日: 地平の上の半円と、長短の光の矢
void rising_sun(inout vec4 acc, Px f) {
	vec2 q = f.p - SUN_C;
	if (q.y < -0.01 || length(q) > 0.20) {
		return;
	}
	float ang = atan(q.x, q.y);
	float k = floor(ang / 0.2618 + 0.5);
	float local = ang - k * 0.2618;
	float len = mod(k, 2.0) < 0.5 ? 0.186 : 0.158;
	float d_ray = max(abs(local) * length(q) - 0.020 * (1.0 - smoothstep(SUN_R, len, length(q))), max(SUN_R + 0.012 - length(q), length(q) - len));
	over(acc, ink_of(SUN), cov(d_ray - 0.006, f.px) * step(0.0, q.y));
	over(acc, mix(SUN, SUN_HOT, 0.4), cov(d_ray, f.px) * step(0.0, q.y));
	float d = max(length(q) - SUN_R, -q.y);
	vec3 n = normalize(vec3(q / SUN_R * 0.5, 0.8));
	vec3 c = mix(SUN, SUN_HOT, smoothstep(0.0, 0.8, 1.0 - length(q) / SUN_R) * 0.8 + 0.2 * smoothstep(0.0, 0.1, q.y));
	part(acc, d, ink_of(SUN), shade_mat(c, n, 0.0, 0.4, 1.0) * 1.05, f.ow, f.px);
}

// 横に流れる朝の雲
void clouds(inout vec4 acc, Px f) {
	for (int k = -1; k <= 1; k += 2) {
		vec2 c = vec2(float(k) * 0.24, 1.252 + 0.018 * float(k));
		vec2 q = f.p - c;
		float d = min(length(q * vec2(0.55, 1.0)) - 0.026, length(q - vec2(float(k) * -0.030, 0.014)) - 0.024);
		d = max(min(d, length(q - vec2(float(k) * 0.035, 0.006)) - 0.020), -q.y - 0.018);
		part(acc, d, ink_of(DAYBREAK), mix(CLOUD, DAYBREAK, smoothstep(0.02, -0.02, q.y) * 0.6), f.ow, f.px);
	}
}

// 真鍮の地平の棒
void horizon(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, SUN_C.y - 0.006);
	float d = sd_round_box(q, vec2(0.36, 0.012), 0.010);
	part(acc, d, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(0.0, q.y / 0.012 * 0.6, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.45, f.p.y - SUN_C.y - 0.06);
	add_light(acc, mix(SUN, DAYBREAK, 0.5), exp(-dot(d, d) / 0.018) * 0.75 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	porcelain_post(acc, f, -POST_X);
	porcelain_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	porcelain_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y && abs(f.p.x) < 0.40) {
		rising_sun(acc, f);
		clouds(acc, f);
		horizon(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
