shader_type canvas_item;
// 蛭(リーチ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は赤い革紐を巻いた黒檀と、節の膨らんだ骨の柱。板は黒檀と骨を継いだ板に銅の吸い管。
// 天板の上で、太った蛭が背を弓なりに丸めて両端の吸盤で板に噛みつき、頭の吸盤から赤い滴が垂れる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

// 第3弾の土台: 借り物の部材の寄せ集め。左右の柱は同じ寸法で素材が違い、板は斜めの継ぎ目で左右の部材が違う。
// 継ぎ目は金継ぎの線でふさぎ、鉄の鎹2本で留める
const vec3 KINTSUGI = vec3(1.0, 0.76, 0.24);
const vec3 STAPLE = vec3(0.32, 0.31, 0.34);
const float SEAM_X = -0.36;
const float SEAM_SLANT = 0.70;

float seam_dist(vec2 q) {
	return q.x - SEAM_X - q.y * SEAM_SLANT - 0.030 * abs(fract(q.y * 9.0 + 0.3) - 0.5);
}

float patch_slab(inout vec4 acc, Px f, float cy, vec2 hs, vec3 left, float left_metal, vec3 right, float right_metal) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	float d = sd_round_box(q, hs, 0.018);
	if (abs(q.x) > hs.x + f.pad || abs(q.y) > hs.y + f.pad) {
		return d;
	}
	float v = q.y / hs.y;
	float ny = smoothstep(0.38, 0.54, v) * 0.75 - smoothstep(0.42, 0.58, -v) * 0.8;
	float end_round = smoothstep(hs.x - 0.07, hs.x, abs(q.x)) * sign(q.x);
	vec3 n = normalize(vec3(q.x / hs.x * 0.22 + end_round * 0.9, ny, 0.72));
	float k = clamp(0.5 + seam_dist(q) / f.px, 0.0, 1.0);
	vec3 fill = mix(shade_mat(left, n, left_metal, 0.4, 1.0), shade_mat(right, n, right_metal, 0.4, 1.0), k);
	part(acc, d, mix(ink_of(left), ink_of(right), k), fill, f.ow, f.px);
	return d;
}

void patch_seam(inout vec4 acc, Px f, float d, vec2 q) {
	float s = abs(seam_dist(q));
	inlay(acc, d, ink_of(KINTSUGI), cov(s - 0.020, f.px), f);
	inlay(acc, d, KINTSUGI, cov(s - 0.011, f.px), f);
	inlay(acc, d, vec3(1.0, 0.95, 0.76), cov(s - 0.0035, f.px) * 0.9, f);
	for (int k = 0; k < 2; k++) {
		float y = k == 0 ? 0.052 : -0.056;
		vec2 r = q - vec2(SEAM_X + y * SEAM_SLANT, y);
		float bar = sd_round_box(r, vec2(0.054, 0.012), 0.005);
		inlay(acc, d, ink_of(STAPLE), cov(bar - 0.006, f.px), f);
		inlay(acc, d, shade_mat(STAPLE, vec3(0.0, 0.5, 0.86), 1.0, 0.8, 1.0), cov(bar, f.px), f);
		for (int j = 0; j < 2; j++) {
			inlay(acc, d, KINTSUGI * 0.85, cov(length(r - vec2(j == 0 ? -0.042 : 0.042, 0.0)) - 0.0065, f.px), f);
		}
	}
}

// 汲砂の刻の印: 板に嵌めた銅の吸い管。左の口は板の下の縁へ曲がって他人の色の砂の滴を吸い上げ、
// 覗き窓にはその他人の色の粒が流れている(奪った砂は自分の色に染まらない)
const vec3 PIPE_COPPER = vec3(0.86, 0.50, 0.28);
const vec3 FOREIGN_SAND = vec3(0.92, 0.88, 0.76);
const float PIPE_Y = -0.002;
const float PIPE_R = 0.017;
const float PIPE_X0 = -0.56;
const float PIPE_X1 = 0.60;
const float BEND = 0.034;
const float MOUTH_Y = -0.040;
const vec2 WINDOW = vec2(0.16, 0.40);

void draw_pipe(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.095 || q.x < PIPE_X0 - BEND - 0.05 || q.x > PIPE_X1 + 0.04) {
		return;
	}
	vec2 c = vec2(PIPE_X0, PIPE_Y - BEND);
	vec2 e = q - c;
	float elbow = (e.x <= 0.0 && e.y >= 0.0) ? abs(length(e) - BEND) - PIPE_R : 9.0;
	float run = max(abs(q.y - PIPE_Y) - PIPE_R, max(PIPE_X0 - q.x, q.x - PIPE_X1));
	float drop_leg = max(abs(q.x - PIPE_X0 + BEND) - PIPE_R, max(MOUTH_Y - q.y, q.y - c.y));
	float tube = min(min(run, elbow), drop_leg);
	float mouth = sd_round_box(q - vec2(PIPE_X0 - BEND, MOUTH_Y), vec2(PIPE_R + 0.008, 0.007), 0.003);
	float joint = sd_round_box(q - vec2(PIPE_X1, PIPE_Y), vec2(0.012, PIPE_R + 0.007), 0.004);
	float all_d = min(min(tube, mouth), joint);
	inlay(acc, d, ink_of(PIPE_COPPER), cov(all_d - 0.007, f.px), f);
	float v = clamp((q.y - PIPE_Y) / PIPE_R, -1.0, 1.0);
	float u = clamp((q.x - PIPE_X0 + BEND) / PIPE_R, -1.0, 1.0);
	vec3 n = run < min(elbow, drop_leg) ? normalize(vec3(0.0, v, sqrt(1.0 - v * v) + 0.05)) : normalize(vec3(u, 0.2, sqrt(1.0 - u * u) + 0.05));
	inlay(acc, d, shade_mat(PIPE_COPPER, n, 0.8, 0.9, 1.0), cov(tube, f.px), f);
	inlay(acc, d, shade_mat(PIPE_COPPER * 0.85, vec3(0.0, 0.3, 0.9), 0.8, 0.9, 1.0), cov(min(mouth, joint), f.px), f);
	float slot = max(abs(q.y - PIPE_Y) - PIPE_R * 0.55, max(WINDOW.x - q.x, q.x - WINDOW.y));
	inlay(acc, d, vec3(0.10, 0.09, 0.10), cov(slot, f.px), f);
	vec2 cell = vec2(floor(q.x / 0.026), 0.0);
	vec2 g = vec2(q.x - (cell.x + 0.5) * 0.026, q.y - PIPE_Y - (hash21(cell) - 0.5) * 0.010);
	inlay(acc, d, FOREIGN_SAND, cov(length(g) - 0.0055, f.px) * cov(slot, f.px), f);
	vec2 dq = q - vec2(PIPE_X0 - BEND, MOUTH_Y - 0.026);
	float drip = min(length(dq * vec2(1.0, 0.85)) - 0.012, max(abs(dq.x) - 0.0025 * (1.0 - dq.y / 0.026), max(-dq.y, dq.y - 0.026)));
	inlay(acc, d, ink_of(FOREIGN_SAND), cov(drip - 0.005, f.px), f);
	inlay(acc, d, FOREIGN_SAND, cov(drip, f.px), f);
}

const vec3 EBONY = vec3(0.22, 0.16, 0.15);
const vec3 LEATHER = vec3(0.66, 0.16, 0.14);
const vec3 BONE = vec3(0.90, 0.85, 0.72);
const vec3 LEECH = vec3(0.28, 0.31, 0.18);
const vec3 LEECH_STRIPE = vec3(0.90, 0.56, 0.22);
const vec3 BLOOD = vec3(0.74, 0.08, 0.12);
const vec2 SLAB_HALF = vec2(0.82, 0.088);
const float POST_R = 0.058;
// 蛭の背の弧(楕円の上半分)の中心と半径、尾と頭の太さ
const vec2 ARCH_C = vec2(0.0, 1.200);
const vec2 ARCH_R = vec2(0.190, 0.118);
const float TAIL_W = 0.050;
const float HEAD_W = 0.026;

// 赤い革紐を斜めに巻いた黒檀の柱
void ebony_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
		float wrap = abs(fract((f.p.y + lx * 0.7) / 0.11) - 0.5);
		vec3 col = mix(EBONY, LEATHER, step(wrap, 0.17) * step(0.16, f.ay) * step(f.ay, 0.86));
		part(acc, d, ink_of(EBONY), shade_mat(col, n, 0.0, 0.7, f.ao), f.ow, f.px);
		over(acc, ink_of(LEATHER), cov(abs(wrap - 0.17) * 0.11 - 0.002, f.px) * step(0.16, f.ay) * step(f.ay, 0.86) * step(abs(lx), POST_R));
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), EBONY, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.12), vec2(0.074, 0.020), LEATHER, 0.0);
}

// 節ごとに膨らんだ骨の柱
void bone_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	float seg = abs(fract(f.p.y / 0.17) - 0.5) * 2.0;
	float r = POST_R - 0.010 + 0.020 * pow(seg, 5.0);
	if (abs(lx) <= POST_R + 0.012 + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - r, f.ay - POST_H);
		vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), 0.0);
		part(acc, d, ink_of(BONE), shade_mat(BONE * mix(0.92, 1.0, seg), n, 0.0, 0.5, f.ao), f.ow, f.px);
		over(acc, ink_of(BONE), cov(abs(seg - 0.94) * 0.085 - 0.0018, f.px) * step(abs(lx), r) * 0.7);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), BONE * 0.9, 0.0);
}

void leech_slab(inout vec4 acc, Px f, float cy) {
	float d = patch_slab(acc, f, cy, SLAB_HALF, EBONY, 0.0, BONE, 0.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	patch_seam(acc, f, d, q);
	draw_pipe(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.020, KINTSUGI, 1.0);
	}
}

// 背を弓なりに丸めて両端の吸盤で板に噛みつく蛭と、頭から垂れる赤い滴
void leech_body(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.30 || q.y < 1.14 || q.y > 1.40) {
		return;
	}
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		vec2 s = q - vec2(sx * ARCH_R.x, ARCH_C.y - 0.004);
		float d_sucker = sd_ellipse(s, k == 0 ? vec2(0.062, 0.020) : vec2(0.040, 0.015));
		part(acc, d_sucker, ink_of(LEECH), shade_mat(LEECH * 0.8, vec3(0.0, 0.6, 0.8), 0.0, 0.6, 1.0), f.ow, f.px);
	}
	vec2 e = q - ARCH_C;
	float t = clamp(0.5 + e.x / (ARCH_R.x * 2.0), 0.0, 1.0);
	float w = mix(TAIL_W, HEAD_W, t * t) * (0.78 + 0.42 * sin(min(t * 1.25, 1.0) * 3.1416));
	float ring = sd_ellipse(e, ARCH_R);
	float d_body = max(abs(ring) - w, -e.y);
	vec2 out_dir = normalize(e / (ARCH_R * ARCH_R));
	float v = clamp(ring / w, -1.0, 1.0);
	vec3 n = normalize(vec3(out_dir * v, sqrt(1.0 - v * v) + 0.05));
	float a = atan(e.y / ARCH_R.y, e.x / ARCH_R.x);
	float rings = abs(fract(a * 16.0 / 3.1416) - 0.5);
	vec3 skin = LEECH * mix(0.82, 1.06, smoothstep(0.08, 0.3, rings));
	part(acc, d_body, ink_of(LEECH), shade_mat(skin, n, 0.0, 1.0, 1.0), f.ow, f.px);
	float stripe = abs(ring - w * 0.38) - w * 0.16;
	over(acc, LEECH_STRIPE * mix(0.8, 1.0, smoothstep(0.08, 0.3, rings)), cov(stripe, f.px) * cov(d_body + 0.004, f.px));
	float dots = length(vec2((fract(a * 8.0 / 3.1416) - 0.5) * 0.06, ring + w * 0.30)) - 0.0055;
	over(acc, ink_of(LEECH), cov(dots, f.px) * cov(d_body + 0.004, f.px) * 0.9);
	vec2 dq = q - vec2(ARCH_R.x + 0.036, ARCH_C.y - 0.040);
	float d_drop = min(length(dq * vec2(1.0, 0.8)) - 0.018, max(abs(dq.x) - 0.006 * (dq.y / 0.034), max(-dq.y, dq.y - 0.034)));
	part(acc, d_drop, ink_of(BLOOD), BLOOD, f.ow * 0.8, f.px);
	over(acc, vec3(1.0, 0.8, 0.8), cov(length(dq - vec2(-0.004, 0.003)) - 0.0035, f.px) * 0.8);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.3, f.p.y - 1.27);
	add_light(acc, vec3(0.80, 0.20, 0.18), exp(-dot(d, d) / 0.012) * 0.24 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	ebony_post(acc, f, -POST_X);
	bone_post(acc, f, POST_X);
	draw_collars(acc, f, STAPLE, 1.0);
	leech_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		leech_body(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
