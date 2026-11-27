shader_type canvas_item;
// 手押しポンプ(ポンプ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱はフランジで継いだ鋳鉄の管と、鉄の帯を巻いた樫の角柱。板は鋳鉄と樫を継いだ板に銅の吸い管。
// 天板の上に赤く塗った鋳鉄の手押しポンプが立ち、長い柄が振り上がって、曲がった吐き口から錆色の砂が滴る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

// 第3弾の土台: 借り物の部材の寄せ集め。左右の柱は同じ寸法で素材が違い、板は斜めの継ぎ目で左右の部材が違う。
// 継ぎ目は金継ぎの線でふさぎ、鉄の鎹2本で留める
const vec3 KINTSUGI = vec3(1.0, 0.76, 0.24);
const vec3 STAPLE = vec3(0.32, 0.31, 0.34);
const float SEAM_X = 0.48;
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

const vec3 CAST_IRON = vec3(0.32, 0.35, 0.40);
const vec3 OAK = vec3(0.62, 0.40, 0.20);
const vec3 PUMP_RED = vec3(0.66, 0.16, 0.12);
const vec2 SLAB_HALF = vec2(0.82, 0.088);
const float POST_R = 0.056;
// ポンプの胴の中心x・半幅・下端と上端、吐き口の高さと口のx、柄の支点と握り
const float BODY_X = -0.030;
const float BODY_W = 0.050;
const float BODY_Y0 = 1.205;
const float BODY_Y1 = 1.330;
const float SPOUT_Y = 1.290;
const float SPOUT_X = 0.165;
const vec2 PIVOT = vec2(-0.050, 1.348);
const vec2 GRIP = vec2(-0.270, 1.368);

// フランジで継いだ鋳鉄の管
void iron_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, CAST_IRON, 0.7);
	for (int k = 0; k < 3; k++) {
		float y = 0.16 + 0.32 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(POST_R + 0.018, 0.014), CAST_IRON * 0.9, 0.8);
		draw_ball(acc, f, vec2(cx - 0.050, f.side * y), 0.007, KINTSUGI, 1.0);
		draw_ball(acc, f, vec2(cx + 0.050, f.side * y), 0.007, KINTSUGI, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), CAST_IRON, 0.8);
}

// 鉄の帯を巻いた樫の角柱
void oak_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		vec3 n = normalize(vec3(smoothstep(POST_R * 0.55, POST_R, abs(lx)) * sign(lx) * 0.8, 0.0, 0.7));
		float grain = 0.5 + 0.5 * sin(lx * 160.0 + sin(f.p.y * 9.0) * 3.0);
		part(acc, d, ink_of(OAK), shade_mat(OAK * mix(0.86, 1.04, grain), n, 0.0, 0.3, f.ao), f.ow, f.px);
	}
	for (int k = 0; k < 2; k++) {
		draw_band(acc, f, vec2(cx, f.side * (k == 0 ? 0.22 : 0.70)), vec2(POST_R + 0.008, 0.016), STAPLE, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), OAK * 0.85, 0.0);
}

void pump_slab(inout vec4 acc, Px f, float cy) {
	float d = patch_slab(acc, f, cy, SLAB_HALF, CAST_IRON, 0.7, OAK, 0.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	patch_seam(acc, f, d, q);
	draw_pipe(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.020, STAPLE, 1.0);
	}
}

// 赤い鋳鉄の手押しポンプ。台座のフランジ、帯を巻いた胴、丸い蓋、曲がった吐き口、振り上げた柄
void hand_pump(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (q.x < -0.32 || q.x > 0.24 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	vec3 iron = shade_mat(CAST_IRON, vec3(0.0, 0.4, 0.9), 0.8, 0.8, 1.0);
	float d_foot = sd_round_box(q - vec2(BODY_X, 1.198), vec2(0.090, 0.014), 0.006);
	part(acc, d_foot, ink_of(CAST_IRON), iron, f.ow, f.px);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(BODY_X + (k == 0 ? -0.066 : 0.066), 1.200), 0.008, KINTSUGI, 1.0);
	}
	float sx = clamp((q.x - BODY_X) / BODY_W, -1.0, 1.0);
	vec3 n_body = lathe_normal(sx, 0.0);
	float d_spout = min(
		sd_round_box(q - vec2((BODY_X + SPOUT_X) * 0.5 + 0.01, SPOUT_Y), vec2((SPOUT_X - BODY_X) * 0.5, 0.016), 0.010),
		sd_round_box(q - vec2(SPOUT_X, SPOUT_Y - 0.030), vec2(0.016, 0.034), 0.008));
	part(acc, d_spout, ink_of(PUMP_RED), shade_mat(PUMP_RED, vec3(0.0, 0.5, 0.86), 0.3, 0.9, 1.0), f.ow, f.px);
	float d_mouth = sd_round_box(q - vec2(SPOUT_X, SPOUT_Y - 0.066), vec2(0.022, 0.008), 0.004);
	part(acc, d_mouth, ink_of(CAST_IRON), iron, f.ow * 0.8, f.px);
	float d_body = sd_round_box(q - vec2(BODY_X, (BODY_Y0 + BODY_Y1) * 0.5), vec2(BODY_W, (BODY_Y1 - BODY_Y0) * 0.5), 0.010);
	part(acc, d_body, ink_of(PUMP_RED), shade_mat(PUMP_RED, n_body, 0.3, 1.0, 1.0), f.ow, f.px);
	for (int k = 0; k < 2; k++) {
		float y = k == 0 ? 1.232 : 1.312;
		float d_ring = sd_round_box(q - vec2(BODY_X, y), vec2(BODY_W + 0.008, 0.009), 0.004);
		part(acc, d_ring, ink_of(CAST_IRON), shade_mat(CAST_IRON, n_body, 0.8, 1.0, 1.0), f.ow * 0.7, f.px);
	}
	vec2 c = q - vec2(BODY_X, BODY_Y1);
	float d_cap = max(length(c * vec2(1.0, 1.6)) - BODY_W - 0.006, -c.y);
	part(acc, d_cap, ink_of(CAST_IRON), shade_mat(CAST_IRON, normalize(vec3(c.x / BODY_W * 0.6, 0.6, 0.6)), 0.8, 1.0, 1.0), f.ow, f.px);
	float d_link = sd_segment(q, vec2(BODY_X, BODY_Y1 + 0.020), PIVOT) - 0.008;
	part(acc, d_link, ink_of(CAST_IRON), iron, f.ow * 0.6, f.px);
	float bow = 0.012 * sin(clamp(dot(q - PIVOT, GRIP - PIVOT) / dot(GRIP - PIVOT, GRIP - PIVOT), 0.0, 1.0) * 3.1416);
	float d_lever = sd_segment(q - vec2(0.0, bow), PIVOT + vec2(0.04, -0.008), GRIP) - 0.011;
	part(acc, d_lever, ink_of(PUMP_RED), shade_mat(PUMP_RED * 0.9, vec3(0.0, 0.6, 0.8), 0.3, 0.9, 1.0), f.ow, f.px);
	draw_ball(acc, f, GRIP, 0.020, CAST_IRON, 0.8);
	draw_ball(acc, f, PIVOT, 0.012, KINTSUGI, 1.0);
	vec2 dq = q - vec2(SPOUT_X, SPOUT_Y - 0.098);
	float d_drop = min(length(dq * vec2(1.0, 0.8)) - 0.014, max(abs(dq.x) - 0.005 * (dq.y / 0.026), max(-dq.y, dq.y - 0.026)));
	part(acc, d_drop, ink_of(sand_color), sand_color, f.ow * 0.7, f.px);
	over(acc, vec3(1.0), cov(length(dq - vec2(-0.004, 0.004)) - 0.003, f.px) * 0.7);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.3, f.p.y - 1.28);
	add_light(acc, vec3(0.95, 0.50, 0.20), exp(-dot(d, d) / 0.012) * 0.24 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	iron_post(acc, f, -POST_X);
	oak_post(acc, f, POST_X);
	draw_collars(acc, f, STAPLE, 1.0);
	pump_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		hand_pump(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
