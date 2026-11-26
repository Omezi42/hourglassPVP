shader_type canvas_item;
// 松明(トーチ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は麻布を斜めに巻いた白木の柄、板には右へ駆ける火の筋。天板の上の真鍮の火受けで松明が燃え、炎は駆ける向きの後ろへなびく。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BIRCH = vec3(0.90, 0.79, 0.60);
const vec3 LINEN = vec3(0.97, 0.93, 0.82);
const vec3 BRASS = vec3(0.94, 0.72, 0.32);
const vec3 PITCH = vec3(0.36, 0.22, 0.16);
const vec3 FLAME_RED = vec3(0.92, 0.22, 0.08);
const vec3 FLAME = vec3(1.0, 0.58, 0.10);
const vec3 FLAME_HOT = vec3(1.0, 0.96, 0.68);
const float POST_R = 0.060;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float CUP_TOP = 1.262;
const float CUP_X = 0.22;

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

void linen_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	float fine = smoothstep(0.03, 0.012, f.px);
	vec3 wood = shade_mat(BIRCH, n, 0.0, 0.3, f.ao);
	wood *= mix(1.0, 0.9 + 0.18 * vnoise(vec2(asin(u) * 8.0 + cx * 5.0, f.p.y * 4.0)), fine);
	// 斜めに巻いた麻布。帯の境目に細い影
	float s = fract((f.p.y + asin(u) * POST_R * 0.9) * 6.5);
	float band = smoothstep(0.02, 0.05, s) * smoothstep(0.62, 0.58, s);
	vec3 cloth = shade_mat(LINEN, n, 0.0, 0.2, f.ao) * (0.92 + 0.08 * sin(s * 40.0) * fine);
	vec3 c = mix(wood, cloth, band);
	c *= 1.0 - 0.35 * smoothstep(0.62, 0.66, s) * smoothstep(0.72, 0.66, s);
	part(acc, d, ink_of(BIRCH), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.030), BRASS, 1.0);
}

void birch_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, BIRCH, 0.0, 0.35);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	blaze_streaks(acc, f, d, q);
	draw_ball(acc, f, vec2(0.0, cy), 0.030, BRASS, 1.0);
}

// 天板の上の松明: 右寄りの真鍮の火受けに脂を染ませた布の巻き。炎は駆ける向きの後ろ(左)へ長くなびく
void torch_head(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, PLATE_Y);
	if (abs(q.x) > 0.50 || q.y < 0.0) {
		return;
	}
	flame(acc, f, vec2(CUP_X - 0.02, 1.262), vec2(-0.46, 1.262), 0.058);
	flame(acc, f, vec2(CUP_X - 0.01, 1.280), vec2(-0.30, 1.318), 0.064);
	flame(acc, f, vec2(CUP_X, 1.290), vec2(-0.06, 1.338), 0.050);
	// 布の巻き(火受けの縁から盛り上がる)
	vec2 wq = f.p - vec2(CUP_X, CUP_TOP - 0.002);
	float d_wrap = sd_ellipse(wq, vec2(0.105, 0.036));
	float rows = smoothstep(0.3, 0.6, abs(fract(wq.x * 14.0 + wq.y * 6.0) - 0.5) * 2.0);
	part(acc, d_wrap, ink_of(PITCH), mix(PITCH, PITCH * 1.6, rows), f.ow * 0.8, f.px);
	// 火受け: 下へすぼまる椀と縁の輪
	float cx = f.p.x - CUP_X;
	float w = mix(0.050, 0.115, clamp((f.p.y - 1.190) / (CUP_TOP - 1.190), 0.0, 1.0));
	float d_cup = max(abs(cx) - w, max(1.192 - f.p.y, f.p.y - CUP_TOP));
	vec3 cn = normalize(vec3(clamp(cx / w, -1.0, 1.0) * 0.8, 0.1, 0.6));
	part(acc, d_cup, ink_of(BRASS), shade_mat(BRASS, cn, 1.0, 1.0, 1.0), f.ow, f.px);
	draw_band(acc, f, vec2(CUP_X, CUP_TOP), vec2(0.128, 0.017), BRASS, 1.0);
	draw_band(acc, f, vec2(CUP_X, 1.218), vec2(0.078, 0.013), BRASS * 0.85, 1.0);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2((f.p.x + 0.06) * 0.6, f.p.y - 1.30);
	add_light(acc, FLAME, exp(-dot(d, d) / 0.035) * 0.7 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	linen_post(acc, f, -POST_X);
	linen_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	birch_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		torch_head(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
