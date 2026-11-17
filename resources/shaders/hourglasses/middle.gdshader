shader_type canvas_item;
// 中庸(ミドル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は真ん中に目盛りの環を締めた青銅の柱、板には中央へ寄る目盛り。天板の上に釣り合った天秤と毒の小瓶。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRONZE = vec3(0.58, 0.44, 0.26);
const vec3 VERDIGRIS = vec3(0.36, 0.62, 0.54);
const vec3 POISON = vec3(0.56, 0.86, 0.30);
const float POST_R = 0.046;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 SCALE = vec2(0.0, 1.218);
const float SCALE_K = 1.2;

void bronze_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, BRONZE, 1.0);
	// 青錆の筋
	vec2 q = vec2(f.p.x - cx, f.p.y);
	float rust = smoothstep(0.55, 0.75, vnoise(q * vec2(30.0, 6.0) + cx));
	over(acc, VERDIGRIS, rust * step(abs(q.x), POST_R * 0.9) * step(abs(q.y), POST_H - 0.04) * 0.6);
	// 真ん中の目盛りの環
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.070, 0.034), VERDIGRIS, 1.0);
	float ticks = step(abs(fract(q.x / 0.016) - 0.5), 0.18) * step(abs(q.y), 0.020) * step(abs(q.x), 0.060);
	over(acc, BRONZE * 0.5, ticks);
	draw_ball(acc, f, vec2(cx, 0.0), 0.016, sand_color, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), VERDIGRIS, 1.0);
}

void ruler_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, BRONZE, 1.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 中央ほど長い目盛り
	float len = 0.014 + 0.034 * (1.0 - abs(q.x) / 0.76);
	float tick = step(abs(fract(q.x / 0.040) - 0.5), 0.10) * step(abs(q.y), len);
	inlay(acc, d, VERDIGRIS * 0.7, tick * step(abs(q.x), 0.74) * step(0.06, abs(q.x)), f);
	// 中央の菱形
	inlay(acc, d, sand_color, cov(sd_rhombus(q, vec2(0.040, 0.044)), f.px), f);
}

// 天秤: 支柱、水平の竿、2枚の皿、片方に毒の小瓶、もう片方に砂の色の錘
void balance_scale(inout vec4 acc, Px f) {
	vec2 q = (f.p - SCALE) / SCALE_K;
	if (abs(q.x) > 0.24 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= SCALE_K;
	f.ow /= SCALE_K;
	part(acc, sd_round_box(q - vec2(0.0, -0.090), vec2(0.060, 0.012), 0.004), ink_of(BRONZE), BRONZE, f.ow * 0.7, f.px);
	float d_stand = max(abs(q.x) - 0.010, max(-q.y - 0.085, q.y - 0.110));
	float d_beam = max(abs(q.y - 0.100) - 0.008, abs(q.x) - 0.175);
	part(acc, min(d_stand, d_beam), ink_of(BRONZE), shade_mat(BRONZE, normalize(vec3(0.0, 0.4, 0.85)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	for (int s = -1; s <= 1; s += 2) {
		float x = float(s) * 0.160;
		float d_chain = min(sd_segment(q, vec2(x, 0.100), vec2(x - 0.045, 0.010)), sd_segment(q, vec2(x, 0.100), vec2(x + 0.045, 0.010))) - 0.003;
		part(acc, d_chain, ink_of(BRONZE), BRONZE * 1.2, f.ow * 0.3, f.px);
		vec2 pq = q - vec2(x, 0.005);
		float d_pan = max(length(pq * vec2(1.0, 2.2)) - 0.060, pq.y - 0.004);
		part(acc, d_pan, ink_of(BRONZE), shade_mat(BRONZE, normalize(vec3(pq.x / 0.06 * 0.6, -0.3, 0.75)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
	// 毒の小瓶(左の皿)
	vec2 vq = q - vec2(-0.160, 0.030);
	float d_vial = min(length(vq) - 0.026, sd_round_box(vq - vec2(0.0, 0.032), vec2(0.009, 0.014), 0.003));
	part(acc, d_vial, ink_of(POISON), shade_mat(POISON, normalize(vec3(vq / 0.03 * 0.6, 0.75)), 0.0, 1.0, 1.0), f.ow * 0.6, f.px);
	// 砂の色の錘(右の皿)
	part(acc, sd_round_box(q - vec2(0.160, 0.026), vec2(0.026, 0.020), 0.006), ink_of(sand_color), shade_mat(sand_color, normalize(vec3(0.0, 0.5, 0.85)), 0.6, 1.0, 1.0), f.ow * 0.6, f.px);
	draw_ball(acc, f, SCALE + vec2(0.0, 0.112) * SCALE_K, 0.016 * SCALE_K, GOLD, 1.0);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	bronze_post(acc, f, -POST_X);
	bronze_post(acc, f, POST_X);
	draw_collars(acc, f, VERDIGRIS, 1.0);
	ruler_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		balance_scale(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
