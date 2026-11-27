shader_type canvas_item;
// 吸い移し(サイフォン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は輪を重ねた真鍮の柱と、銅の帯で留めた硝子の管。板は真鍮と胡桃材を継いだ板に銅の吸い管。
// 天板の上で、高い台に載ったフラスコから硝子の曲がり管が弧を描いて低いビーカーへ下り、緑の砂が移っていく。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

// 第3弾の土台: 借り物の部材の寄せ集め。左右の柱は同じ寸法で素材が違い、板は斜めの継ぎ目で左右の部材が違う。
// 継ぎ目は金継ぎの線でふさぎ、鉄の鎹2本で留める
const vec3 KINTSUGI = vec3(1.0, 0.76, 0.24);
const vec3 STAPLE = vec3(0.32, 0.31, 0.34);
const float SEAM_X = -0.40;
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

const vec3 BRASS = vec3(0.80, 0.62, 0.30);
const vec3 WALNUT = vec3(0.40, 0.26, 0.16);
const vec3 GLASS = vec3(0.78, 0.88, 0.94);
const vec3 TUBE_COPPER = vec3(0.86, 0.50, 0.28);
const vec2 SLAB_HALF = vec2(0.82, 0.088);
const float POST_R = 0.056;
// フラスコの胴の中心と半径・首の半幅と上端、台の高さ、ビーカーの中心と半寸法、曲がり管の弧
const vec2 FLASK = vec2(-0.140, 1.276);
const float FLASK_R = 0.056;
const float NECK_W = 0.018;
const float NECK_TOP = 1.352;
const float STAND_Y = 1.212;
const vec2 BEAKER = vec2(0.150, 1.230);
const vec2 BEAKER_HALF = vec2(0.058, 0.040);
const vec2 ARC_C = vec2(0.005, 1.306);
const vec2 ARC_R = vec2(0.145, 0.070);

// 輪を重ねた真鍮の柱
void brass_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R - 0.006, -POST_H, POST_H, BRASS, 0.9);
	for (int k = 0; k < 5; k++) {
		draw_band(acc, f, vec2(cx, f.side * (0.10 + 0.19 * float(k))), vec2(POST_R + 0.006, 0.011), BRASS * 0.9, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), BRASS, 0.9);
}

// 銅の帯で留めた硝子の管。中ほどまで緑の砂が満ちている
void glass_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		float u = clamp(lx / POST_R, -1.0, 1.0);
		vec3 inside = mix(vec3(0.16, 0.20, 0.24), sand_color * 0.8, step(f.p.y, 0.30) * step(abs(lx), POST_R * 0.62));
		part(acc, d, ink_of(GLASS) * 1.6, mix(inside, GLASS, 0.35 + 0.3 * abs(u)), f.ow, f.px);
		over(acc, vec3(1.0), cov(abs(u + 0.45) * POST_R - 0.006, f.px) * 0.6 * step(abs(lx), POST_R));
	}
	for (int k = 0; k < 3; k++) {
		draw_band(acc, f, vec2(cx, f.side * (0.14 + 0.32 * float(k))), vec2(POST_R + 0.008, 0.014), TUBE_COPPER, 0.8);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), TUBE_COPPER, 0.8);
}

void siphon_slab(inout vec4 acc, Px f, float cy) {
	float d = patch_slab(acc, f, cy, SLAB_HALF, BRASS, 0.8, WALNUT, 0.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	patch_seam(acc, f, d, q);
	draw_pipe(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.020, BRASS, 1.0);
	}
}

// 硝子の器の面。中の砂は `level` の高さまで
void glass_fill(inout vec4 acc, Px f, float d, float level, vec2 hl) {
	part(acc, d, ink_of(GLASS) * 1.4, mix(vec3(0.14, 0.18, 0.22), GLASS, 0.30), f.ow * 0.8, f.px);
	over(acc, sand_color * mix(0.8, 1.05, smoothstep(level - 0.04, level, f.p.y)), cov(max(d + 0.006, f.p.y - level), f.px));
	over(acc, min(sand_color * 1.3, vec3(1.0)), cov(max(d + 0.006, abs(f.p.y - level) - 0.003), f.px));
	over(acc, vec3(1.0), cov(length(f.p - hl) - 0.008, f.px) * 0.7);
}

// 台に載ったフラスコ、低いビーカー、二つをつなぐ硝子の曲がり管と、管の中を移る緑の筋
void siphon_pair(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.25 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	float d_stand = min(sd_round_box(q - vec2(FLASK.x, STAND_Y), vec2(0.070, 0.008), 0.004), max(abs(q.x - FLASK.x) - 0.010, max(1.186 - q.y, q.y - STAND_Y)));
	part(acc, d_stand, ink_of(BRASS), shade_mat(BRASS, vec3(0.0, 0.5, 0.86), 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	draw_band(acc, f, vec2(FLASK.x, 1.192), vec2(0.040, 0.008), BRASS, 1.0);
	vec2 a = q - ARC_C;
	float ring = sd_ellipse(a, ARC_R);
	float d_arc = max(abs(ring) - 0.010, -a.y);
	float d_leg_l = max(abs(q.x - ARC_C.x + ARC_R.x) - 0.010, max(1.286 - q.y, q.y - ARC_C.y));
	float d_leg_r = max(abs(q.x - ARC_C.x - ARC_R.x) - 0.010, max(BEAKER.y - 0.006 - q.y, q.y - ARC_C.y));
	float d_tube = min(d_arc, min(d_leg_l, d_leg_r));
	part(acc, d_tube, ink_of(GLASS) * 1.4, mix(vec3(0.20, 0.24, 0.28), GLASS, 0.4), f.ow * 0.7, f.px);
	over(acc, sand_color, cov(d_tube + 0.0045, f.px));
	float d_flask = min(length(q - FLASK) - FLASK_R, max(abs(q.x - FLASK.x) - NECK_W, max(FLASK.y - q.y, q.y - NECK_TOP)));
	glass_fill(acc, f, d_flask, FLASK.y - 0.006, FLASK + vec2(-0.026, 0.022));
	over(acc, sand_color, cov(d_leg_l + 0.0045, f.px) * step(1.268, q.y));
	float d_lip = sd_round_box(q - vec2(FLASK.x, NECK_TOP), vec2(NECK_W + 0.006, 0.006), 0.003);
	part(acc, d_lip, ink_of(GLASS) * 1.4, GLASS, f.ow * 0.6, f.px);
	float d_beaker = sd_round_box(q - BEAKER, BEAKER_HALF, 0.008);
	glass_fill(acc, f, d_beaker, BEAKER.y + 0.006, BEAKER + vec2(-0.032, 0.020));
	over(acc, sand_color, cov(d_leg_r + 0.0045, f.px) * step(BEAKER.y - 0.006, q.y));
	float d_rim = sd_round_box(q - vec2(BEAKER.x, BEAKER.y + BEAKER_HALF.y), vec2(BEAKER_HALF.x + 0.006, 0.005), 0.003);
	part(acc, d_rim, ink_of(GLASS) * 1.4, GLASS, f.ow * 0.6, f.px);
	float d_clip = sd_round_box(q - vec2(ARC_C.x, ARC_C.y + ARC_R.y), vec2(0.016, 0.014), 0.004);
	part(acc, d_clip, ink_of(TUBE_COPPER), shade_mat(TUBE_COPPER, vec3(0.0, 0.5, 0.86), 0.8, 1.0, 1.0), f.ow * 0.6, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.3, f.p.y - 1.28);
	add_light(acc, vec3(0.40, 0.95, 0.60), exp(-dot(d, d) / 0.012) * 0.22 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	brass_post(acc, f, -POST_X);
	glass_post(acc, f, POST_X);
	draw_collars(acc, f, STAPLE, 1.0);
	siphon_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		siphon_pair(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
