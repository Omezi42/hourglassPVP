shader_type canvas_item;
// 釣瓶の桶(バケツ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は麻縄を巻いた灰色の丸太と、錆びた鉄の角棒。板は風雨にさらされた板と錆びた鉄板を継いだ板に銅の吸い管。
// 天板の上に鉄の箍を2本締めた木の桶が置かれ、針金の弦が弧を描いて、縁まで汲んだ砂が一滴こぼれる。

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

const vec3 DRIFTWOOD = vec3(0.60, 0.56, 0.50);
const vec3 ROPE = vec3(0.80, 0.66, 0.42);
const vec3 RUST = vec3(0.56, 0.28, 0.16);
const vec3 TUB_WOOD = vec3(0.70, 0.46, 0.24);
const vec2 SLAB_HALF = vec2(0.82, 0.088);
const float POST_R = 0.058;
// 桶の底と縁の高さ、底と縁の半幅、箍の高さ、弦の頂
const float TUB_Y0 = 1.196;
const float TUB_Y1 = 1.316;
const float TUB_W0 = 0.096;
const float TUB_W1 = 0.130;
const float BAIL_TOP = 1.388;

// 麻縄を巻いた灰色の丸太
void log_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
		float crack = abs(sin(lx * 90.0 + vnoise(vec2(lx * 30.0, f.p.y * 6.0)) * 4.0));
		vec3 col = DRIFTWOOD * mix(0.82, 1.04, smoothstep(0.1, 0.5, crack));
		float coil = abs(fract((f.p.y + lx * 0.5) / 0.036) - 0.5);
		float roped = step(0.30, f.ay) * step(f.ay, 0.62);
		col = mix(col, ROPE * mix(0.78, 1.08, coil * 2.0), roped);
		part(acc, d, ink_of(DRIFTWOOD), shade_mat(col, n, 0.0, 0.3, f.ao), f.ow, f.px);
		over(acc, ink_of(ROPE), cov(coil * 0.036 - 0.002, f.px) * roped * step(abs(lx), POST_R) * 0.7);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), DRIFTWOOD * 0.85, 0.0);
}

// 錆びた鉄の角棒
void rust_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	float r = POST_R - 0.010;
	if (abs(lx) <= r + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - r, f.ay - POST_H);
		vec3 n = normalize(vec3(smoothstep(r * 0.5, r, abs(lx)) * sign(lx) * 0.8, 0.0, 0.7));
		float pit = vnoise(vec2(lx * 60.0, f.p.y * 40.0));
		vec3 col = mix(RUST, STAPLE, smoothstep(0.55, 0.75, pit));
		part(acc, d, ink_of(RUST), shade_mat(col, n, 0.5, 0.4, f.ao), f.ow, f.px);
	}
	for (int k = 0; k < 4; k++) {
		draw_ball(acc, f, vec2(cx, f.side * (0.18 + 0.22 * float(k))), 0.012, STAPLE, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), RUST, 0.5);
}

void bucket_slab(inout vec4 acc, Px f, float cy) {
	float d = patch_slab(acc, f, cy, SLAB_HALF, DRIFTWOOD, 0.0, RUST, 0.4);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float plank = abs(q.y - 0.040) - 0.002;
	inlay(acc, d, ink_of(DRIFTWOOD), cov(plank, f.px) * step(seam_dist(q), 0.0), f);
	inlay(acc, d, ink_of(DRIFTWOOD), cov(abs(q.y + 0.044) - 0.002, f.px) * step(seam_dist(q), 0.0), f);
	patch_seam(acc, f, d, q);
	draw_pipe(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.020, STAPLE, 1.0);
	}
}

// 鉄の箍を締めた木の桶と針金の弦、縁まで汲んだ砂とこぼれる一滴
void tub(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.22 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	vec2 bc = q - vec2(0.0, TUB_Y1 - 0.004);
	float d_bail = max(abs(length(bc * vec2(1.0, (TUB_W1 + 0.004) / (BAIL_TOP - TUB_Y1)))  - TUB_W1 - 0.004) - 0.0055, -bc.y);
	part(acc, d_bail, ink_of(STAPLE), shade_mat(STAPLE, vec3(0.0, 0.6, 0.8), 1.0, 0.8, 1.0), f.ow * 0.6, f.px);
	float t = clamp((q.y - TUB_Y0) / (TUB_Y1 - TUB_Y0), 0.0, 1.0);
	float w = mix(TUB_W0, TUB_W1, t);
	float d_tub = max(abs(q.x) - w, max(TUB_Y0 - q.y, q.y - TUB_Y1));
	float u = clamp(q.x / w, -1.0, 1.0);
	float stave = abs(fract(u * 3.5 + 0.5) - 0.5);
	vec3 n = lathe_normal(u, 0.0);
	part(acc, d_tub, ink_of(TUB_WOOD), shade_mat(TUB_WOOD * mix(0.84, 1.04, smoothstep(0.02, 0.12, stave)), n, 0.0, 0.4, 1.0), f.ow, f.px);
	over(acc, ink_of(TUB_WOOD), cov(stave * 0.07 - 0.0018, f.px) * cov(d_tub + 0.004, f.px) * 0.7);
	for (int k = 0; k < 2; k++) {
		float y = k == 0 ? 1.222 : 1.292;
		float wy = mix(TUB_W0, TUB_W1, (y - TUB_Y0) / (TUB_Y1 - TUB_Y0));
		float d_hoop = max(abs(q.x) - wy - 0.006, abs(q.y - y) - 0.010);
		part(acc, d_hoop, ink_of(STAPLE), shade_mat(STAPLE, n, 1.0, 0.8, 1.0), f.ow * 0.6, f.px);
	}
	vec2 rim = q - vec2(0.0, TUB_Y1);
	float d_sand = sd_ellipse(rim, vec2(TUB_W1 - 0.008, 0.022));
	part(acc, d_sand, ink_of(sand_color), sand_color * mix(0.85, 1.08, smoothstep(-0.02, 0.02, rim.y)), f.ow * 0.6, f.px);
	float heap = sd_ellipse(rim - vec2(-0.020, 0.012), vec2(0.070, 0.022));
	over(acc, min(sand_color * 1.12, vec3(1.0)), cov(max(heap, -rim.y + 0.006), f.px));
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -TUB_W1 - 0.004 : TUB_W1 + 0.004, TUB_Y1 - 0.004), 0.010, STAPLE, 1.0);
	}
	vec2 dq = q - vec2(TUB_W1 + 0.020, TUB_Y1 - 0.060);
	float d_drop = min(length(dq * vec2(1.0, 0.8)) - 0.013, max(abs(dq.x) - 0.005 * (dq.y / 0.03), max(-dq.y, dq.y - 0.030)));
	part(acc, d_drop, ink_of(sand_color), sand_color, f.ow * 0.7, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.3, f.p.y - 1.28);
	add_light(acc, vec3(1.0, 0.86, 0.50), exp(-dot(d, d) / 0.012) * 0.22 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	log_post(acc, f, -POST_X);
	rust_post(acc, f, POST_X);
	draw_collars(acc, f, STAPLE, 1.0);
	bucket_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		tub(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
