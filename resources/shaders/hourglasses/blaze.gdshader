shader_type canvas_item;
// 烈火(ブレイズ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は炎の舌が螺旋に駆け上がる真鍮の柱、板は白い釉の陶板に右へ駆ける火の筋。天板の上の長い火樋から、炎の壁が後ろへなびいて燃え立つ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.94, 0.72, 0.32);
const vec3 GLAZE = vec3(0.95, 0.90, 0.80);
const vec3 IRON = vec3(0.40, 0.36, 0.34);
const float POST_R = 0.058;
const float TROUGH_Y = 1.222;
const vec2 TROUGH_HALF = vec2(0.40, 0.034);
const vec3 FLAME_RED = vec3(0.92, 0.22, 0.08);
const vec3 FLAME = vec3(1.0, 0.58, 0.10);
const vec3 FLAME_HOT = vec3(1.0, 0.96, 0.68);
const vec2 SLAB_HALF = vec2(0.82, 0.086);

// 右上へ駆ける火の筋1本。t は尾(0)から頭(1)までの位置
float comet(vec2 q, vec2 head, float len, float r, out float t) {
	vec2 dir = vec2(0.94, 0.34);
	vec2 pa = q - (head - dir * len);
	t = clamp(dot(pa, dir) / len, 0.0, 1.0);
	return length(pa - dir * len * t) - mix(r * 0.15, r, t * t);
}

// 烈砂の刻の印: 板の左右を右へ駆ける火の筋
void blaze_streaks(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.07) {
		return;
	}
	for (int k = 0; k < 6; k++) {
		float j = float(k % 3);
		float hx = k < 3 ? -0.16 - 0.20 * j : 0.33 + 0.20 * j;
		float t;
		float ds = comet(q, vec2(hx, 0.026), 0.17, 0.026, t);
		inlay(acc, d, FLAME_RED * 0.5, cov(ds - 0.007, f.px), f);
		inlay(acc, d, mix(FLAME_RED, FLAME, smoothstep(0.0, 0.7, t)), cov(ds, f.px), f);
		inlay(acc, d, FLAME_HOT, cov(ds + 0.008, f.px) * smoothstep(0.55, 0.9, t), f);
	}
}

// 炎の舌: 根元から先へ細り、先は上へ反る
float tongue(vec2 q, vec2 root, vec2 tip, float r0, out float t) {
	vec2 ba = tip - root;
	t = clamp(dot(q - root, ba) / dot(ba, ba), 0.0, 1.0);
	vec2 bend = vec2(0.0, 0.025 * t * t - 0.008 * sin(t * 9.0));
	return length(q - root - ba * t - bend) - mix(0.004, r0, pow(1.0 - t, 0.55));
}

void flame(inout vec4 acc, Px f, vec2 root, vec2 tip, float r0) {
	float t;
	float d = tongue(f.p, root, tip, r0, t);
	over(acc, FLAME_RED * 0.55, cov(d - 0.012, f.px));
	over(acc, FLAME_RED, cov(d - 0.006, f.px));
	over(acc, FLAME, cov(d, f.px));
	over(acc, FLAME_HOT, cov(d + 0.018, f.px) * smoothstep(0.8, 0.1, t));
}

// 真鍮の柱に、炎の舌が螺旋に巻いて駆け上がる
void flame_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + 0.02 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	part(acc, d, ink_of(BRASS), shade_mat(BRASS, n, 1.0, 1.0, f.ao), f.ow, f.px);
	// 螺旋の炎: 斜めの帯の中で、上へ尖る舌の形
	float s = fract((f.p.y - asin(u) * POST_R * 1.1) * 4.2);
	float tip = 1.0 - abs(fract(asin(u) * 1.1 + f.p.y * 2.0) - 0.5) * 2.0;
	float body = smoothstep(0.62, 0.56, s) * smoothstep(0.0, 0.06, s);
	float lick = step(s, 0.30 + 0.30 * tip);
	float a = body * lick * cov(d, f.px);
	vec3 fc = mix(FLAME_RED, FLAME, smoothstep(0.0, 0.45, s));
	fc = mix(fc, FLAME_HOT, smoothstep(0.30, 0.10, s) * 0.6);
	over(acc, shade_mat(fc, n, 0.0, 0.6, 1.0) * 1.08, a);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.030), BRASS, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.078, 0.022), BRASS, 1.0);
}

void glaze_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, GLAZE, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	blaze_streaks(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.022, BRASS, 1.0);
	}
}

// 天板の上の長い火樋と、そこから立つ炎の壁
void fire_wall(inout vec4 acc, Px f) {
	if (abs(f.p.x) > 0.50 || f.p.y < PLATE_Y) {
		return;
	}
	for (int k = 0; k < 5; k++) {
		float x = (float(k) - 2.0) * 0.16 + 0.05;
		float h = k == 2 ? 0.130 : (k == 1 || k == 3 ? 0.105 : 0.075);
		flame(acc, f, vec2(x, TROUGH_Y + 0.02), vec2(x - 0.10 - h * 0.4, TROUGH_Y + h), 0.060);
	}
	vec2 q = f.p - vec2(0.0, TROUGH_Y);
	float d = sd_round_box(q, TROUGH_HALF, 0.012);
	vec3 n = normalize(vec3(clamp(q.x / TROUGH_HALF.x, -1.0, 1.0) * 0.3, q.y / TROUGH_HALF.y * 0.6, 0.75));
	part(acc, d, ink_of(IRON), shade_mat(BRASS, n, 1.0, 1.0, 1.0), f.ow, f.px);
	// 樋の正面の透かし(中の火が透ける)
	float d_slot = sd_round_box(vec2(mod(q.x + 0.05, 0.10) - 0.05, q.y), vec2(0.022, 0.010), 0.008);
	over(acc, mix(FLAME, FLAME_HOT, 0.4), cov(max(d_slot, abs(q.x) - 0.34), f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.5, f.p.y - 1.28);
	add_light(acc, FLAME, exp(-dot(d, d) / 0.03) * 0.65 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	flame_post(acc, f, -POST_X);
	flame_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	glaze_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		fire_wall(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
