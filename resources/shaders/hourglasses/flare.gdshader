shader_type canvas_item;
// 信号弾(フレア)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は赤と生成りの帯を巻いた信号筒、板は生成りの漆に右へ駆ける火の筋。天板の上の小さな筒から信号弾が弧を描いて昇り、白く弾ける。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 CREAM = vec3(0.95, 0.91, 0.82);
const vec3 SIGNAL = vec3(0.86, 0.20, 0.16);
const vec3 BRASS = vec3(0.94, 0.72, 0.32);
const vec3 SMOKE = vec3(0.92, 0.92, 0.96);
const vec3 DAWN = vec3(0.86, 0.94, 1.0);
const float POST_R = 0.060;
const vec2 BURST = vec2(0.22, 1.305);
const vec2 MUZZLE = vec2(-0.28, 1.268);
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

// 信号筒: 赤と生成りの帯を交互に巻き、真鍮の口金
void signal_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	float s = fract(f.p.y * 2.6 + 0.25);
	float red = smoothstep(0.48, 0.52, s);
	vec3 c = shade_mat(mix(CREAM, SIGNAL, red), n, 0.0, 0.6, f.ao);
	c *= 1.0 - 0.3 * cov(abs(s - 0.5) - 0.012, f.px * 2.6);
	part(acc, d, ink_of(SIGNAL), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.030), BRASS, 1.0);
}

void cream_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, CREAM, 0.0, 0.7);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	blaze_streaks(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.022, SIGNAL, 0.0);
	}
}

// 斜めに据えた発射筒と、筒から信号弾までの煙の弧
void launcher(inout vec4 acc, Px f) {
	// 煙の弧: 筒口から信号弾へ、上へふくらむ二次曲線。先ほど細く白む
	vec2 a = MUZZLE;
	vec2 b = BURST;
	float best = 9.0;
	float best_t = 0.0;
	for (int i = 0; i <= 28; i++) {
		float t = float(i) / 28.0;
		vec2 c = mix(a, b, t) + vec2(0.0, 0.10 * sin(t * 3.1416) - 0.02 * t);
		float dd = length(f.p - c) - mix(0.024, 0.010, t);
		if (dd < best) {
			best = dd;
			best_t = t;
		}
	}
	over(acc, SMOKE * 0.6, cov(best - 0.006, f.px) * 0.8);
	over(acc, mix(SMOKE, FLAME_HOT, best_t), cov(best, f.px));
	// 筒: 右上へ傾けた赤い筒に真鍮の帯
	vec2 q = rot(f.p - vec2(-0.33, 1.232), -0.75);
	float d_tube = sd_round_box(q, vec2(0.030, 0.060), 0.008);
	vec3 n = normalize(vec3(clamp(q.x / 0.03, -1.0, 1.0) * 0.8, 0.0, 0.6));
	part(acc, d_tube, ink_of(SIGNAL), shade_mat(SIGNAL, n, 0.0, 0.7, 1.0), f.ow, f.px);
	float d_ring = sd_round_box(q - vec2(0.0, 0.050), vec2(0.036, 0.012), 0.006);
	part(acc, d_ring, ink_of(BRASS), shade_mat(BRASS, n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
}

// 弾けた信号弾: 白い芯と夜明けの色の光条
void burst(inout vec4 acc, Px f) {
	vec2 d = f.p - BURST;
	if (abs(d.x) > 0.22 || abs(d.y) > 0.12) {
		return;
	}
	float ang = atan(d.y, d.x);
	float rays = pow(abs(cos(ang * 4.0)), 8.0) * exp(-length(d) / 0.06);
	over(acc, DAWN, clamp(rays * 1.4, 0.0, 1.0) * 0.9);
	over(acc, FLAME_HOT, star4(d, 0.20));
	part(acc, length(d) - 0.044, FLAME * 0.9, vec3(1.0, 0.99, 0.94), f.ow * 0.7, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - BURST;
	add_light(acc, DAWN, exp(-dot(d, d) / 0.04) * 0.8 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	signal_post(acc, f, -POST_X);
	signal_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	cream_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		launcher(acc, f);
		burst(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
