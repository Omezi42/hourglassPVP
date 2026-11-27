shader_type canvas_item;
// 大渦(メイルストロム)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は螺旋の溝を刻んだ青銅と、螺旋に捩れた螺鈿の柱。板は青銅と螺鈿を継いだ板に銅の吸い管、両端に金の玉。
// 天板の上で、光る青緑の大渦が三本の腕を巻いて暗い目へ沈み、縁から飛沫が立ちのぼって、呑まれかけた器のかけらが渦に乗る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

// 第3弾の土台: 借り物の部材の寄せ集め。左右の柱は同じ寸法で素材が違い、板は斜めの継ぎ目で左右の部材が違う。
// 継ぎ目は金継ぎの線でふさぎ、鉄の鎹2本で留める
const vec3 KINTSUGI = vec3(1.0, 0.76, 0.24);
const vec3 STAPLE = vec3(0.32, 0.31, 0.34);
const float SEAM_X = 0.40;
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

const vec3 BRONZE = vec3(0.50, 0.36, 0.22);
const vec3 NACRE = vec3(0.70, 0.86, 0.88);
const vec3 ABYSS = vec3(0.02, 0.10, 0.16);
const vec3 SPRAY = vec3(0.90, 1.0, 1.0);
const vec3 SHARD = vec3(0.86, 0.80, 0.70);
const vec2 SLAB_HALF = vec2(0.82, 0.090);
const float POST_R = 0.058;
// 渦の中心と半径(手前へ倒した楕円)、腕の数と巻きの強さ、目の半径
const vec2 SWIRL = vec2(0.0, 1.262);
const vec2 SWIRL_R = vec2(0.255, 0.086);
const float ARMS = 3.0;
const float WIND = 2.4;
const float EYE = 0.16;

// 螺旋の溝を刻んだ捩れ柱。`pearl` が1なら螺鈿の虹色をのせる
void twist_post(inout vec4 acc, Px f, float cx, vec3 col, float metal, float pearl) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		float u = clamp(lx / POST_R, -1.0, 1.0);
		float ph = fract(f.p.y / 0.12 + asin(u) / 3.1416 * 0.5);
		vec3 n = normalize(lathe_normal(u, 0.0) + vec3(0.0, (ph - 0.5) * 0.9, 0.0));
		vec3 c = col;
		if (pearl > 0.5) {
			c = mix(NACRE, vec3(0.86, 0.72, 0.92), 0.5 + 0.5 * sin(ph * 6.2832 + f.p.y * 9.0));
		}
		part(acc, d, ink_of(col), shade_mat(c, n, metal, 1.0, f.ao), f.ow, f.px);
		over(acc, ink_of(col), cov(abs(ph - 0.5) * 0.12 - 0.054, f.px) * step(abs(lx), POST_R) * 0.6);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.034), KINTSUGI, 1.0);
	draw_ball(acc, f, vec2(cx, 0.0), 0.024, KINTSUGI, 1.0);
}

void maelstrom_slab(inout vec4 acc, Px f, float cy) {
	float d = patch_slab(acc, f, cy, SLAB_HALF, BRONZE, 0.8, NACRE, 0.2);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float right = step(0.0, seam_dist(q));
	vec3 sheen = mix(NACRE, vec3(0.86, 0.72, 0.92), 0.5 + 0.5 * sin(q.x * 30.0 + q.y * 50.0));
	inlay(acc, d, sheen, right * 0.45 * cov(abs(q.y) - SLAB_HALF.y + 0.024, f.px), f);
	patch_seam(acc, f, d, q);
	draw_pipe(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.026, KINTSUGI, 1.0);
	}
}

// 三本の腕を巻いて暗い目へ沈む大渦、立ちのぼる飛沫、渦に乗った器のかけら
void whirlpool(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.30 || q.y < 1.15 || q.y > 1.40) {
		return;
	}
	vec2 e = (q - SWIRL) / SWIRL_R;
	float r = length(e);
	float d_disc = (r - 1.0) * SWIRL_R.y;
	float a = atan(e.y, e.x);
	float arm = fract((a + log(max(r, 0.02)) * WIND) / 6.2832 * ARMS);
	float crest = smoothstep(0.35, 0.0, abs(arm - 0.5) - 0.12);
	float depth = smoothstep(EYE, 1.0, r);
	vec3 water = mix(ABYSS, sand_color, depth * (0.55 + 0.45 * crest));
	water = mix(water, SPRAY, crest * smoothstep(0.55, 0.95, r) * 0.55);
	part(acc, d_disc, ink_of(sand_color), water, f.ow, f.px);
	over(acc, SPRAY, cov(abs(d_disc + 0.006) - 0.003, f.px) * step(0.0, e.y) * 0.8);
	over(acc, ABYSS, cov((r - EYE) * SWIRL_R.y, f.px));
	vec2 sh = rot(q - (SWIRL + vec2(0.120, -0.032)), 0.5);
	float d_shard = max(sd_ellipse(sh, vec2(0.040, 0.016)), sh.y - 0.004);
	part(acc, d_shard, ink_of(SHARD), shade_mat(SHARD, vec3(0.0, 0.5, 0.86), 0.0, 1.0, 1.0), f.ow * 0.6, f.px);
	over(acc, KINTSUGI, cov(abs(sh.y - 0.002) - 0.0025, f.px) * cov(d_shard + 0.004, f.px));
	for (int k = 0; k < 9; k++) {
		float fk = float(k);
		float s = (fk + 0.5) / 9.0 * 2.0 - 1.0;
		vec2 c = SWIRL + vec2(s * SWIRL_R.x * 0.92, SWIRL_R.y * sqrt(max(1.0 - s * s, 0.0)) * 0.6 + 0.024 + 0.050 * hash21(vec2(fk, 3.0)) * (1.0 - abs(s) * 0.6));
		float rad = 0.007 + 0.006 * hash21(vec2(fk, 7.0));
		float d_drop = length((q - c) * vec2(1.0, 0.8)) - rad;
		part(acc, d_drop, ink_of(sand_color), SPRAY, f.ow * 0.5, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.0, (f.p.y - 1.27) * 1.4);
	add_light(acc, vec3(0.40, 0.95, 1.0), exp(-dot(d, d) / 0.020) * 0.36 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	twist_post(acc, f, -POST_X, BRONZE, 0.8, 0.0);
	twist_post(acc, f, POST_X, NACRE, 0.2, 1.0);
	draw_collars(acc, f, KINTSUGI, 1.0);
	maelstrom_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		whirlpool(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
