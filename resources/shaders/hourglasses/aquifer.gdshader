shader_type canvas_item;
// 帯水層(アクイファー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は砂岩の地層と、粘板岩の地層を積んだ柱。板は砂岩と粘板岩を継いだ地層の板に銅の吸い管。
// 天板の上に石積みの井戸が口を開け、深い青の水面の上で、二本の柱に渡した梁の滑車から釣瓶が下りている。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

// 第3弾の土台: 借り物の部材の寄せ集め。左右の柱は同じ寸法で素材が違い、板は斜めの継ぎ目で左右の部材が違う。
// 継ぎ目は金継ぎの線でふさぎ、鉄の鎹2本で留める
const vec3 KINTSUGI = vec3(1.0, 0.76, 0.24);
const vec3 STAPLE = vec3(0.32, 0.31, 0.34);
const float SEAM_X = -0.42;
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

const vec3 SANDSTONE = vec3(0.78, 0.60, 0.40);
const vec3 SLATE = vec3(0.40, 0.44, 0.52);
const vec3 WELL_STONE = vec3(0.64, 0.62, 0.58);
const vec3 TIMBER = vec3(0.50, 0.32, 0.18);
const vec3 HEMP = vec3(0.82, 0.70, 0.46);
const vec2 SLAB_HALF = vec2(0.82, 0.088);
const float POST_R = 0.060;
// 井戸の胴の半幅と口の高さ、柱のx・頂、梁の高さ、滑車、釣瓶の高さ
const float WELL_W = 0.130;
const float WELL_TOP = 1.262;
const float UPRIGHT_X = 0.112;
const float BEAM_Y = 1.362;
const vec2 PULLEY = vec2(0.0, 1.338);
const float PULLEY_R = 0.022;
const float PAIL_Y = 1.292;

// 色の違う層を積んだ地層の柱
void strata_post(inout vec4 acc, Px f, float cx, vec3 rock, float layer_h) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		float wav = f.p.y + 0.010 * sin(lx * 50.0 + f.p.y * 5.0);
		float band = floor(wav / layer_h);
		vec3 col = rock * mix(0.72, 1.10, hash21(vec2(band, cx)));
		vec3 n = normalize(vec3(smoothstep(POST_R * 0.5, POST_R, abs(lx)) * sign(lx) * 0.7, 0.0, 0.7));
		part(acc, d, ink_of(rock), shade_mat(col, n, 0.0, 0.1, f.ao), f.ow, f.px);
		over(acc, ink_of(rock), cov(abs(fract(wav / layer_h) - 0.5) * layer_h - layer_h * 0.5 + 0.0025, f.px) * step(abs(lx), POST_R) * 0.6);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.032), rock * 0.85, 0.0);
}

void aquifer_slab(inout vec4 acc, Px f, float cy) {
	float d = patch_slab(acc, f, cy, SLAB_HALF, SANDSTONE, 0.0, SLATE, 0.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float wav = q.y + 0.008 * sin(q.x * 14.0);
	inlay(acc, d, ink_of(SANDSTONE) * 1.6, cov(abs(abs(wav) - 0.050) - 0.0025, f.px), f);
	inlay(acc, d, sand_color * 0.8, cov(abs(wav + 0.074) - 0.005, f.px) * 0.8, f);
	patch_seam(acc, f, d, q);
	draw_pipe(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.020, STAPLE, 1.0);
	}
}

// 石積みの井戸、深い青の水面、二本の柱と梁、滑車と下りた釣瓶
void well(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.22 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	vec3 wood = shade_mat(TIMBER, vec3(0.0, 0.3, 0.9), 0.0, 0.3, 1.0);
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		float d_up = max(abs(q.x - sx * UPRIGHT_X) - 0.012, max(WELL_TOP - 0.03 - q.y, q.y - BEAM_Y));
		part(acc, d_up, ink_of(TIMBER), wood, f.ow * 0.8, f.px);
	}
	float d_beam = sd_round_box(q - vec2(0.0, BEAM_Y), vec2(UPRIGHT_X + 0.034, 0.012), 0.004);
	part(acc, d_beam, ink_of(TIMBER), shade_mat(TIMBER, vec3(0.0, 0.6, 0.8), 0.0, 0.3, 1.0), f.ow * 0.8, f.px);
	float d_roof = max(abs(q.x) * 0.36 + q.y - BEAM_Y - 0.046, BEAM_Y + 0.010 - q.y);
	part(acc, d_roof, ink_of(TIMBER), shade_mat(TIMBER * 0.85, normalize(vec3(sign(q.x) * 0.4, 0.6, 0.7)), 0.0, 0.3, 1.0), f.ow * 0.8, f.px);
	float d_rope = max(abs(q.x - PULLEY_R * 0.0) - 0.0035, max(PAIL_Y - q.y, q.y - PULLEY.y));
	part(acc, d_rope, ink_of(HEMP), HEMP, f.ow * 0.4, f.px);
	vec2 w = q - PULLEY;
	float d_wheel = min(abs(length(w) - PULLEY_R + 0.005) - 0.005, length(w) - 0.007);
	part(acc, d_wheel, ink_of(STAPLE), shade_mat(STAPLE, normalize(vec3(w / PULLEY_R * 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	float d_wall = max(abs(q.x) - WELL_W, max(1.190 - q.y, q.y - WELL_TOP));
	vec3 n = lathe_normal(clamp(q.x / WELL_W, -1.0, 1.0), 0.0);
	float row = floor((q.y - 1.190) / 0.024);
	float off = mod(row, 2.0) * 0.026;
	vec2 cell = vec2(mod(q.x + off, 0.052), mod(q.y - 1.190, 0.024));
	float joint = min(min(cell.x, 0.052 - cell.x), min(cell.y, 0.024 - cell.y));
	vec3 stone = WELL_STONE * mix(0.84, 1.06, hash21(vec2(floor((q.x + off) / 0.052), row)));
	part(acc, d_wall, ink_of(WELL_STONE), shade_mat(stone, n, 0.0, 0.1, 1.0), f.ow, f.px);
	over(acc, ink_of(WELL_STONE), cov(joint - 0.002, f.px) * cov(d_wall + 0.003, f.px) * 0.7);
	vec2 rim = q - vec2(0.0, WELL_TOP);
	float d_rim = sd_ellipse(rim, vec2(WELL_W + 0.006, 0.026));
	part(acc, d_rim, ink_of(WELL_STONE), shade_mat(WELL_STONE * 1.05, vec3(0.0, 0.8, 0.6), 0.0, 0.1, 1.0), f.ow, f.px);
	float d_water = sd_ellipse(rim - vec2(0.0, -0.002), vec2(WELL_W - 0.018, 0.016));
	over(acc, sand_color * mix(0.55, 1.0, smoothstep(-0.016, 0.012, rim.y)), cov(d_water, f.px));
	over(acc, min(sand_color + 0.4, vec3(1.0)), cov(abs(sd_ellipse(rim - vec2(0.020, 0.0), vec2(0.040, 0.007))) - 0.0025, f.px) * cov(d_water, f.px));
	float d_pail = max(abs(q.x) - mix(0.020, 0.026, (q.y - PAIL_Y + 0.030) / 0.030), max(PAIL_Y - 0.030 - q.y, q.y - PAIL_Y));
	part(acc, d_pail, ink_of(TIMBER), shade_mat(TIMBER * 1.2, lathe_normal(clamp(q.x / 0.026, -1.0, 1.0), 0.0), 0.0, 0.4, 1.0), f.ow * 0.6, f.px);
	over(acc, STAPLE, cov(max(abs(q.x) - 0.026, abs(q.y - PAIL_Y + 0.010) - 0.003), f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.3, f.p.y - 1.28);
	add_light(acc, vec3(0.30, 0.55, 1.0), exp(-dot(d, d) / 0.012) * 0.24 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	strata_post(acc, f, -POST_X, SANDSTONE, 0.060);
	strata_post(acc, f, POST_X, SLATE, 0.036);
	draw_collars(acc, f, STAPLE, 1.0);
	aquifer_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		well(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
