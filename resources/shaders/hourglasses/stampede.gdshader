shader_type canvas_item;
// 暴走(スタンピード)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は金の帯を締めた朱漆の竿、板は鞣し革に右へ駆ける火の筋。天板の上を蹄鉄が3つ跳ねて駆け、後ろへ砂煙が流れる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 LACQUER = vec3(0.80, 0.22, 0.16);
const vec3 GOLD_BAND = vec3(0.96, 0.76, 0.34);
const vec3 TAN = vec3(0.86, 0.68, 0.46);
const vec3 SHOE = vec3(0.84, 0.86, 0.90);
const vec3 DUST = vec3(0.90, 0.80, 0.62);
const float POST_R = 0.058;
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

void lacquer_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	part(acc, d, ink_of(LACQUER), shade_mat(LACQUER, n, 0.0, 1.0, f.ao), f.ow, f.px);
	for (int k = -1; k <= 1; k++) {
		draw_band(acc, f, vec2(cx, float(k) * 0.48), vec2(0.072, 0.018), GOLD_BAND, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.030), GOLD_BAND, 1.0);
}

void leather_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, TAN, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 縁の縫い目
	float stitch = step(0.5, fract(q.x * 26.0)) * cov(abs(abs(q.y) - 0.062) - 0.004, f.px) * step(abs(q.x), 0.76);
	inlay(acc, d, TAN * 0.55, stitch, f);
	blaze_streaks(acc, f, d, q);
	draw_ball(acc, f, vec2(0.0, cy), 0.026, GOLD_BAND, 1.0);
}

// 蹄鉄: 下へ開いたU字に釘穴。tilt は駆ける勢いの傾き
void horseshoe(inout vec4 acc, Px f, vec2 c, float r, float tilt) {
	vec2 q = rot(f.p - c, tilt);
	if (length(q) > r * 1.5 + f.pad) {
		return;
	}
	float ring = abs(length(q) - r) - r * 0.34;
	// 下を開ける(真下から左右へ55度ずつ)
	float a = atan(q.x, -q.y);
	ring = max(ring, (0.95 - abs(a)) * r);
	vec3 n = normalize(vec3(q / r * 0.5, 0.8));
	part(acc, ring, ink_of(SHOE * 0.6), shade_mat(SHOE, n, 1.0, 1.0, 1.0), f.ow, f.px);
	for (int i = 0; i < 6; i++) {
		float a = mix(-0.30, 3.44, float(i) / 5.0);
		vec2 h = vec2(cos(a), sin(a)) * r;
		over(acc, ink_of(SHOE), cov(length(q - h) - r * 0.085, f.px));
	}
}

// 後ろへ流れる砂煙の玉
void dust_puff(inout vec4 acc, Px f, vec2 c, float r) {
	float d = 9.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		d = min(d, length(f.p - c - vec2(-fi * r * 0.9, (fi - 1.0) * r * 0.25)) - r * (1.0 - fi * 0.22));
	}
	part(acc, d, DUST * 0.6, DUST, f.ow * 0.7, f.px);
}

void herd(inout vec4 acc, Px f) {
	if (abs(f.p.x) > 0.56 || f.p.y < PLATE_Y) {
		return;
	}
	dust_puff(acc, f, vec2(-0.36, 1.226), 0.036);
	dust_puff(acc, f, vec2(-0.09, 1.232), 0.034);
	dust_puff(acc, f, vec2(0.19, 1.226), 0.036);
	horseshoe(acc, f, vec2(-0.22, 1.262), 0.062, 0.30);
	horseshoe(acc, f, vec2(0.06, 1.292), 0.064, 0.18);
	horseshoe(acc, f, vec2(0.34, 1.258), 0.062, 0.36);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.45, f.p.y - 1.26);
	add_light(acc, FLAME, exp(-dot(d, d) / 0.02) * 0.45 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	lacquer_post(acc, f, -POST_X);
	lacquer_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD_BAND, 1.0);
	leather_slab(acc, f, f.side * PLATE_Y);
	herd(acc, f);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
