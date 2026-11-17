shader_type canvas_item;
// 記憶(メモリー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 象牙の柱に勿忘草の絵付け、板には紐で束ねた手紙。天板の上に鎖から下がる開いたロケット。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 IVORY = vec3(0.92, 0.88, 0.80);
const vec3 FORGET = vec3(0.46, 0.62, 0.92);
const vec3 PAPER = vec3(0.96, 0.92, 0.82);
const vec3 RIBBON = vec3(0.66, 0.34, 0.46);
const float POST_R = 0.048;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 LOCKET = vec2(0.0, 1.198);
const float LOCKET_K = 1.3;

void forget_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(IVORY, n, 0.0, 0.8, f.ao);
	// 勿忘草: 5弁の小花を散らす
	vec2 g = vec2(lx / 0.050, f.p.y / 0.11 + cx);
	vec2 cell = vec2(fract(g.x + 0.5 * mod(floor(g.y), 2.0)) - 0.5, fract(g.y) - 0.5) * vec2(0.050, 0.11);
	float a = atan(cell.y, cell.x);
	float r = length(cell);
	float flower = step(r, 0.016 * (0.65 + 0.35 * cos(a * 5.0)));
	float heart = step(r, 0.005);
	float on = step(abs(f.p.y), POST_H - 0.06) * step(abs(lx), POST_R * 0.85);
	c = mix(c, FORGET, flower * on);
	c = mix(c, mix(sand_color, vec3(1.0, 0.9, 0.4), 0.5), heart * on);
	part(acc, d, ink_of(IVORY * 0.6), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), SILVER, 1.0);
}

void letters_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, IVORY, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 斜めに重ねた封筒の束
	for (int k = -3; k <= 3; k++) {
		if (k == 0) {
			continue;
		}
		vec2 lq = rot(q - vec2(float(k) * 0.20, 0.0), 0.12 * float(k % 2 == 0 ? 1 : -1));
		float d_env = sd_round_box(lq, vec2(0.060, 0.036), 0.004);
		inlay(acc, d, PAPER * 0.9, cov(d_env, f.px), f);
		float flap = 1.0 - smoothstep(0.0, max(0.004, f.px), abs(lq.y - 0.036 + abs(lq.x) * 0.55) - 0.002);
		inlay(acc, d, IVORY * 0.6, flap * cov(d_env, f.px), f);
		inlay(acc, d, RIBBON, step(abs(lq.x), 0.006) * cov(d_env, f.px), f);
	}
	inlay(acc, d, RIBBON, cov(length(q) - 0.034, f.px), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.022, f.px), f);
}

// 開いたロケット: 左の蓋と右の写真枠、上の留め輪と鎖
void open_locket(inout vec4 acc, Px f) {
	vec2 q = (f.p - LOCKET) / LOCKET_K;
	if (abs(q.x) > 0.22 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= LOCKET_K;
	f.ow /= LOCKET_K;
	// 鎖: 両側へ垂れる弧の上に輪を並べる
	for (int s = -1; s <= 1; s += 2) {
		vec2 cq = vec2(q.x * float(s), q.y);
		float t = clamp(cq.x / 0.12, 0.0, 1.0);
		float cy0 = 0.070 + 0.030 * t - 0.030 * sin(t * 3.1416);
		float link = abs(fract(cq.x / 0.022) - 0.5);
		float d_chain = max(abs(cq.y - cy0) - 0.005, max(-cq.x + 0.02, cq.x - 0.12));
		part(acc, d_chain, ink_of(SILVER), mix(SILVER, SILVER * 0.6, step(0.3, link)), f.ow * 0.3, f.px);
	}
	part(acc, abs(length(q - vec2(0.0, 0.070)) - 0.012) - 0.004, ink_of(SILVER), SILVER, f.ow * 0.4, f.px);
	for (int s = -1; s <= 1; s += 2) {
		vec2 lq = q - vec2(float(s) * 0.050, 0.0);
		float d_case = sd_ellipse(lq, vec2(0.046, 0.060));
		vec3 n = normalize(vec3(lq / 0.05 * 0.6, 0.75));
		part(acc, d_case, ink_of(SILVER), shade_mat(mix(SILVER, GOLD, 0.6), n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
		if (s < 0) {
			// 蓋の内側の彫り(渦)
			float sw = abs(fract(length(lq) / 0.012 + atan(lq.y, lq.x) / 6.2832) - 0.5);
			over(acc, GOLD * 0.6, step(0.36, sw) * cov(d_case + 0.010, f.px));
		} else {
			// 写真: 砂の色の背景に横顔の影
			over(acc, mix(sand_color, PAPER, 0.4), cov(d_case + 0.010, f.px));
			vec2 pq = lq - vec2(0.0, -0.005);
			float d_bust = min(length(pq - vec2(0.0, 0.012)) - 0.017, max(sd_ellipse(pq - vec2(0.0, -0.040), vec2(0.032, 0.026)), -(pq.y + 0.050)));
			d_bust = max(d_bust, d_case + 0.010);
			over(acc, mix(RIBBON, vec3(0.1), 0.4), cov(d_bust, f.px));
		}
	}
	draw_ball(acc, f, LOCKET, 0.010 * LOCKET_K, SILVER, 1.0);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	forget_post(acc, f, -POST_X);
	forget_post(acc, f, POST_X);
	draw_collars(acc, f, SILVER, 1.0);
	letters_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		open_locket(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
