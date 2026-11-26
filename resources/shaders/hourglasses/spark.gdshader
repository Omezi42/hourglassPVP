shader_type canvas_item;
// 火花(スパーク)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は綾目を刻んだ磨いた鋼、板は白鋼に右へ駆ける火の筋。天板の上で鋼の火打金に火打石が打ち合い、火花が四方へ散る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEEL = vec3(0.82, 0.86, 0.92);
const vec3 BRASS = vec3(0.94, 0.72, 0.32);
const vec3 FLINT = vec3(0.50, 0.52, 0.60);
const vec3 LEATHER = vec3(0.62, 0.34, 0.20);
const float POST_R = 0.056;
const vec2 STRIKE_AT = vec2(0.10, 1.285);
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

// 磨いた鋼の柱。中ほどに綾目(握り)を刻む
void knurled_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	vec3 c = shade_mat(STEEL, n, 1.0, 1.0, f.ao);
	float fine = smoothstep(0.03, 0.012, f.px);
	float grip = step(abs(abs(f.p.y) - 0.45), 0.22);
	float a1 = abs(fract((f.p.y + asin(u) * POST_R) * 22.0) - 0.5);
	float a2 = abs(fract((f.p.y - asin(u) * POST_R) * 22.0) - 0.5);
	c *= 1.0 - grip * fine * 0.35 * smoothstep(0.18, 0.05, min(a1, a2));
	part(acc, d, ink_of(STEEL * 0.7), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.086, 0.030), BRASS, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.074, 0.020), BRASS, 1.0);
}

void steel_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, STEEL * 0.95, 0.7, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	blaze_streaks(acc, f, d, q);
	draw_ball(acc, f, vec2(0.0, cy), 0.028, BRASS, 1.0);
}

// 火打金: 横に寝たC字の鋼に革の握り。右から火打石が打ち当たる
void striker(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(-0.12, 1.250);
	if (abs(q.x) < 0.34 && q.y > -0.07 && q.y < 0.08) {
		// C字: 横長の楕円の輪の上半分を開けた形
		float ring = abs(sd_ellipse(q, vec2(0.26, 0.050))) - 0.016;
		ring = max(ring, -(q.y - 0.012 + 0.10 * smoothstep(0.12, 0.26, abs(q.x))));
		vec3 n = normalize(vec3(q.x / 0.26 * 0.4, q.y / 0.05 * 0.6, 0.7));
		part(acc, ring, ink_of(STEEL * 0.6), shade_mat(STEEL, n, 1.0, 1.0, 1.0), f.ow, f.px);
		float d_grip = sd_round_box(q - vec2(0.0, -0.050), vec2(0.13, 0.024), 0.020);
		vec3 gn = normalize(vec3(0.0, (q.y + 0.05) / 0.024 * 0.6, 0.8));
		part(acc, d_grip, ink_of(LEATHER), shade_mat(LEATHER, gn, 0.0, 0.4, 1.0), f.ow, f.px);
		float stitch = step(0.5, fract(q.x * 30.0)) * cov(abs(q.y + 0.050) - 0.004, f.px);
		over(acc, vec3(0.95, 0.85, 0.6), stitch * cov(d_grip + 0.01, f.px));
	}
	// 火打石: 割れ口の角ばった石
	vec2 s = rot(f.p - vec2(0.26, 1.262), 0.5);
	float d_flint = sd_rhombus(s, vec2(0.075, 0.048));
	float facet = step(0.0, s.x + s.y * 0.6);
	part(acc, d_flint, ink_of(FLINT), mix(FLINT, FLINT * 1.35, facet), f.ow, f.px);
}

// 打点から四方へ散る火花
void sparks(inout vec4 acc, Px f) {
	vec2 d = f.p - STRIKE_AT;
	if (abs(d.x) > 0.36 || d.y > 0.10 || d.y < -0.10) {
		return;
	}
	over(acc, FLAME_HOT, star4(d, 0.15));
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float ang = 0.35 + fi * 0.33 + 0.15 * hash21(vec2(fi, 3.0));
		float r = 0.13 + 0.20 * hash21(vec2(fi, 9.0));
		vec2 dir = vec2(cos(ang), sin(ang) * 0.55);
		vec2 tip = dir * r;
		float ds = sd_segment(d, tip * 0.55, tip) - 0.011;
		over(acc, FLAME, cov(ds - 0.004, f.px));
		over(acc, FLAME_HOT, cov(ds + 0.002, f.px));
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - STRIKE_AT;
	add_light(acc, FLAME, exp(-dot(d, d) / 0.02) * 0.7 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	knurled_post(acc, f, -POST_X);
	knurled_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	steel_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		striker(acc, f);
		sparks(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
