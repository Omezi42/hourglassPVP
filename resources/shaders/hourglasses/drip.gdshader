shader_type canvas_item;
// 滴り(ドリップ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は継ぎ手のある銅の管で、滴が伝い落ちる。板は滴の形の象嵌。天板の上に一滴ずつ落とすドリッパー。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 COPPER = vec3(0.78, 0.46, 0.28);
const vec3 TILE = vec3(0.86, 0.84, 0.78);
const vec3 CERAMIC = vec3(0.94, 0.92, 0.88);
const float PIPE_R = 0.040;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 DRIPPER = vec2(0.0, 1.228);
const float DRIPPER_K = 1.2;

float drop_sd(vec2 q, float r) {
	// 下が丸く上が尖った滴
	float d_round = length(q) - r;
	float d_tip = max(abs(q.x) - r * (1.0 - (q.y) / (r * 2.2)), max(-q.y, q.y - r * 2.2));
	return min(d_round, d_tip);
}

void pipe_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, PIPE_R, -POST_H, POST_H, COPPER, 1.0);
	for (int k = -2; k <= 2; k++) {
		draw_band(acc, f, vec2(cx, float(k) * 0.36), vec2(0.058, 0.020), COPPER * 0.85, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), COPPER * 0.85, 1.0);
	// 管を伝う滴
	vec2 q = vec2(f.p.x - cx - PIPE_R * 0.4, fract(f.p.y * 1.6 + cx) - 0.5);
	q.y /= 1.6;
	if (abs(q.x) < 0.04 && f.ay < POST_H - 0.08) {
		float d = drop_sd(q, 0.014);
		part(acc, d, ink_of(sand_color), mix(sand_color, vec3(1.0), 0.35), f.ow * 0.4, f.px);
	}
}

void drop_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, TILE, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.056) - 0.005);
	inlay(acc, d, COPPER, rim * step(abs(q.x), 0.76), f);
	for (int k = -3; k <= 3; k++) {
		vec2 dq = q - vec2(float(k) * 0.20, -0.016);
		vec3 c = k == 0 ? sand_color : mix(COPPER, TILE, 0.3);
		inlay(acc, d, c, cov(drop_sd(dq * vec2(1.0, f.side), 0.018), f.px), f);
	}
}

// ドリッパー: 陶器の円錐、縁の取っ手、下へ落ちる一滴、受けの小皿
void dripper(inout vec4 acc, Px f) {
	vec2 q = (f.p - DRIPPER) / DRIPPER_K;
	if (abs(q.x) > 0.20 + f.pad || abs(q.y) > 0.15 + f.pad) {
		return;
	}
	f.px /= DRIPPER_K;
	f.ow /= DRIPPER_K;
	part(acc, sd_round_box(q - vec2(0.0, -0.108), vec2(0.110, 0.014), 0.006), ink_of(COPPER), shade_mat(COPPER, normalize(vec3(0.0, 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	// 円錐
	vec2 cq = q - vec2(0.0, 0.020);
	float w = 0.030 + (cq.y + 0.060) * 0.85;
	float d_cone = max(abs(cq.x) - w, max(-cq.y - 0.060, cq.y - 0.070));
	vec3 n = normalize(vec3(cq.x / max(w, 0.01) * 0.7, 0.0, 0.7));
	vec3 cc = shade_mat(CERAMIC, n, 0.0, 1.0, 1.0);
	cc = mix(cc, CERAMIC * 0.75, step(abs(fract(cq.x / 0.030) - 0.5), 0.08) * step(cq.y, 0.06));
	part(acc, d_cone, ink_of(CERAMIC * 0.6), cc, f.ow, f.px);
	part(acc, sd_round_box(cq - vec2(0.0, 0.072), vec2(0.140, 0.010), 0.006), ink_of(CERAMIC * 0.6), CERAMIC, f.ow * 0.7, f.px);
	// 落ちる一滴
	part(acc, drop_sd(q - vec2(0.0, -0.075), 0.016), ink_of(sand_color), sand_color, f.ow * 0.5, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	pipe_post(acc, f, -POST_X);
	pipe_post(acc, f, POST_X);
	draw_collars(acc, f, COPPER, 1.0);
	drop_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		dripper(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
