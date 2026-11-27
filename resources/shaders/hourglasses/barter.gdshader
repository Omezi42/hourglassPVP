shader_type canvas_item;
// 取り引き(バーター)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は金の輪を嵌めた朱の漆の柱と、藍の線を描いた白磁の柱。板は朱の漆と白磁を継いだ板に銅の吸い管。
// 天板の上に、口を紐で結び合わせた大小二つの巾着が並び、あいだに金貨が積まれ、背の高い藍の巾着の口から紫の砂の結晶がのぞく。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

// 第3弾の土台: 借り物の部材の寄せ集め。左右の柱は同じ寸法で素材が違い、板は斜めの継ぎ目で左右の部材が違う。
// 継ぎ目は金継ぎの線でふさぎ、鉄の鎹2本で留める
const vec3 KINTSUGI = vec3(1.0, 0.76, 0.24);
const vec3 STAPLE = vec3(0.32, 0.31, 0.34);
const float SEAM_X = 0.44;
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

const vec3 LACQUER = vec3(0.70, 0.16, 0.12);
const vec3 PORCELAIN = vec3(0.92, 0.93, 0.96);
const vec3 COBALT = vec3(0.16, 0.26, 0.62);
const vec3 INDIGO_CLOTH = vec3(0.24, 0.26, 0.50);
const vec3 OCHRE_CLOTH = vec3(0.80, 0.60, 0.30);
const vec3 CORD = vec3(0.86, 0.72, 0.44);
const vec3 COIN = vec3(0.96, 0.76, 0.30);
const vec2 SLAB_HALF = vec2(0.82, 0.088);
const float POST_R = 0.056;
// 二つの巾着の胴の中心と半径、口の高さ
const vec2 TALL = vec2(-0.125, 1.258);
const vec2 TALL_R = vec2(0.074, 0.068);
const float TALL_NECK = 1.340;
const vec2 SQUAT = vec2(0.140, 1.242);
const vec2 SQUAT_R = vec2(0.080, 0.052);
const float SQUAT_NECK = 1.306;

// 金の輪を嵌めた朱の漆の柱
void lacquer_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, LACQUER, 0.15);
	for (int k = 0; k < 3; k++) {
		draw_band(acc, f, vec2(cx, f.side * (0.16 + 0.32 * float(k))), vec2(POST_R + 0.010, 0.012), KINTSUGI, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), LACQUER * 0.8, 0.15);
}

// 藍の線を描いた白磁の柱
void porcelain_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
		float wave = abs(fract(f.p.y / 0.15 + 0.08 * sin(lx * 60.0)) - 0.5);
		float scroll = abs(lx - 0.022 * sin(f.p.y * 28.0));
		vec3 col = mix(PORCELAIN, COBALT, max(step(wave, 0.04), step(scroll, 0.006) * step(0.06, wave)));
		part(acc, d, ink_of(COBALT), shade_mat(col, n, 0.0, 1.0, f.ao), f.ow, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), COBALT, 0.2);
}

void barter_slab(inout vec4 acc, Px f, float cy) {
	float d = patch_slab(acc, f, cy, SLAB_HALF, LACQUER, 0.15, PORCELAIN, 0.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float right = step(0.0, seam_dist(q));
	inlay(acc, d, COBALT, cov(abs(abs(q.y) - 0.062) - 0.004, f.px) * right, f);
	inlay(acc, d, KINTSUGI * 0.9, cov(abs(abs(q.y) - 0.062) - 0.003, f.px) * (1.0 - right), f);
	patch_seam(acc, f, d, q);
	draw_pipe(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.020, KINTSUGI, 1.0);
	}
}

// 口を紐で絞った巾着。胴・絞った首・口の襞を描く
void pouch(inout vec4 acc, Px f, vec2 c, vec2 r, float neck, vec3 cloth) {
	vec2 q = f.p - c;
	float d_body = sd_ellipse(q, r);
	float t = clamp((f.p.y - c.y) / (neck - c.y), 0.0, 1.0);
	float d_neck = max(abs(q.x) - mix(r.x * 0.62, 0.016, t), max(-q.y, f.p.y - neck));
	float d_frill = sd_ellipse(f.p - vec2(c.x, neck + 0.014), vec2(r.x * 0.50, 0.020));
	float d = min(min(d_body, d_neck), d_frill);
	vec3 n = normalize(vec3(q.x / r.x * 0.8, q.y / r.y * 0.5, 0.7));
	float fold = 0.5 + 0.5 * sin(q.x / r.x * 9.0 + q.y * 30.0);
	part(acc, d, ink_of(cloth), shade_mat(cloth * mix(0.86, 1.04, fold), n, 0.0, 0.2, 1.0), f.ow, f.px);
	float d_tie = sd_round_box(f.p - vec2(c.x, neck - 0.004), vec2(0.024, 0.006), 0.003);
	part(acc, d_tie, ink_of(CORD), CORD, f.ow * 0.6, f.px);
}

// 大小二つの巾着、二つを結ぶ紐、あいだの金貨、藍の巾着の口の紫の結晶
void trade(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.25 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	float x0 = TALL.x;
	float x1 = SQUAT.x;
	float s = clamp((q.x - x0) / (x1 - x0), 0.0, 1.0);
	float sag = mix(TALL_NECK - 0.004, SQUAT_NECK - 0.004, s) - 0.040 * sin(s * 3.1416);
	float d_cord = max(abs(q.y - sag) - 0.005, max(x0 - q.x, q.x - x1));
	part(acc, d_cord, ink_of(CORD), CORD, f.ow * 0.6, f.px);
	pouch(acc, f, SQUAT, SQUAT_R, SQUAT_NECK, OCHRE_CLOTH);
	pouch(acc, f, TALL, TALL_R, TALL_NECK, INDIGO_CLOTH);
	for (int k = 0; k < 3; k++) {
		vec2 cc = q - vec2(0.020 + 0.004 * float(k), 1.196 + 0.014 * float(k));
		float d_coin = sd_ellipse(cc, vec2(0.036, 0.011));
		part(acc, d_coin, ink_of(COIN), shade_mat(COIN, normalize(vec3(cc.x * 6.0, 0.7, 0.6)), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	}
	for (int k = 0; k < 3; k++) {
		vec2 g = q - vec2(TALL.x - 0.020 + 0.020 * float(k), TALL_NECK + 0.030 + 0.006 * float(k == 1));
		float d_gem = sd_rhombus(g, vec2(0.012, 0.018));
		part(acc, d_gem, ink_of(sand_color), mix(sand_color, vec3(1.0), 0.25 * step(g.x, 0.0)), f.ow * 0.5, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.3, f.p.y - 1.28);
	add_light(acc, vec3(0.80, 0.60, 1.0), exp(-dot(d, d) / 0.012) * 0.22 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	lacquer_post(acc, f, -POST_X);
	porcelain_post(acc, f, POST_X);
	draw_collars(acc, f, KINTSUGI * 0.8, 1.0);
	barter_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		trade(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
