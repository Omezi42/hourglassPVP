shader_type canvas_item;
// 追手(チェイサー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は革の握りを巻いた白樺、板は淡い白木に右へ駆ける火の筋。天板の上を、炎の尾を引く火矢が右へ飛ぶ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BARK = vec3(0.93, 0.91, 0.86);
const vec3 LENTICEL = vec3(0.22, 0.20, 0.20);
const vec3 LEATHER = vec3(0.60, 0.34, 0.20);
const vec3 ASHWOOD = vec3(0.88, 0.82, 0.70);
const vec3 STEEL = vec3(0.80, 0.84, 0.90);
const vec3 FEATHER = vec3(0.84, 0.22, 0.18);
const float POST_R = 0.058;
const float ARROW_Y = 1.262;
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

// 白樺: 白い樹皮に黒い横の皮目。中ほどに革紐の握り
void birch_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + 0.008 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	vec3 c = shade_mat(BARK, n, 0.0, 0.3, f.ao);
	float fine = smoothstep(0.03, 0.012, f.px);
	vec2 g = vec2(asin(u) * 1.6 + cx * 3.0, f.p.y * 9.0);
	vec2 gi = floor(g);
	vec2 gf = fract(g) - 0.5;
	float len = 0.12 + 0.3 * hash21(gi);
	float mark = step(0.45, hash21(gi + 7.0)) * cov(max(abs(gf.x) - len, abs(gf.y) - 0.06), 0.08);
	c = mix(c, LENTICEL, mark * fine * 0.85);
	part(acc, d, ink_of(BARK * 0.8), c, f.ow, f.px);
	// 革紐の握り(斜めに巻く)
	if (abs(f.p.y) < 0.20) {
		float d_grip = max(abs(lx) - POST_R - 0.008, abs(f.p.y) - 0.18);
		float s = fract((f.p.y + asin(u) * POST_R * 0.8) * 16.0);
		vec3 gc = shade_mat(LEATHER, lathe_normal(clamp(lx / (POST_R + 0.008), -1.0, 1.0), 0.0), 0.0, 0.4, f.ao);
		part(acc, d_grip, ink_of(LEATHER), gc * mix(0.7, 1.05, smoothstep(0.0, 0.3, s)), f.ow * 0.8, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.030), LEATHER, 0.0);
}

void ash_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, ASHWOOD, 0.0, 0.35);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	blaze_streaks(acc, f, d, q);
	draw_ball(acc, f, vec2(0.0, cy), 0.026, STEEL, 1.0);
}

// 火矢: 矢柄・赤い矢羽・鋼の鏃。鏃の後ろから炎が尾を引く
void fire_arrow(inout vec4 acc, Px f) {
	vec2 q = rot(f.p - vec2(0.0, ARROW_Y), -0.08);
	if (abs(q.x) > 0.52 || abs(q.y) > 0.13) {
		return;
	}
	// 尾を引く炎(矢柄の上へ流れる)
	flame(acc, f, vec2(0.24, ARROW_Y + 0.025), vec2(-0.16, ARROW_Y + 0.058), 0.048);
	flame(acc, f, vec2(0.22, ARROW_Y + 0.010), vec2(-0.30, ARROW_Y + 0.012), 0.040);
	float d_shaft = max(abs(q.y) - 0.012, abs(q.x - 0.0) - 0.40);
	part(acc, d_shaft, ink_of(ASHWOOD), shade_mat(ASHWOOD, normalize(vec3(0.0, q.y / 0.012 * 0.7, 0.7)), 0.0, 0.4, 1.0), f.ow * 0.8, f.px);
	// 矢羽: 上下2枚
	for (int k = 0; k < 2; k++) {
		float sy = k == 0 ? 1.0 : -1.0;
		vec2 fq = vec2(q.x + 0.33, q.y * sy);
		float d_f = max(max(-fq.y + 0.008, fq.y - 0.055 + fq.x * 0.25), abs(fq.x) - 0.075);
		d_f = max(d_f, fq.y - 0.012 - (0.075 - fq.x) * 0.5);
		part(acc, d_f, ink_of(FEATHER), shade_mat(FEATHER, vec3(0.0, sy * 0.4, 0.9), 0.0, 0.3, 1.0), f.ow * 0.8, f.px);
	}
	// 鏃(右向きの菱形)
	vec2 hq = q - vec2(0.43, 0.0);
	float d_head = sd_rhombus(hq, vec2(0.075, 0.038));
	vec3 hn = normalize(vec3(0.3, hq.y > 0.0 ? 0.5 : -0.4, 0.8));
	part(acc, d_head, ink_of(STEEL * 0.6), shade_mat(STEEL, hn, 1.0, 1.0, 1.0), f.ow, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2((f.p.x - 0.05) * 0.5, f.p.y - 1.28);
	add_light(acc, FLAME, exp(-dot(d, d) / 0.025) * 0.55 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	birch_post(acc, f, -POST_X);
	birch_post(acc, f, POST_X);
	draw_collars(acc, f, STEEL, 1.0);
	ash_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		fire_arrow(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
