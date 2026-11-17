shader_type canvas_item;
// 反響(リバーブ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は長さの違うオルガンのパイプを3本ずつ束ねたもの、天板の上に真鍮のラッパの口。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PIPE = vec3(0.80, 0.82, 0.84);
const vec3 BRASS = vec3(0.86, 0.68, 0.34);
const vec3 TEAL_WOOD = vec3(0.24, 0.44, 0.40);
const float PIPE_R = 0.026;
const vec2 SLAB_HALF = vec2(0.82, 0.082);
const vec2 HORN = vec2(0.0, 1.17);

// パイプ1本: 下に唄口(切り欠き)、上は開いた口
void organ_pipe(inout vec4 acc, Px f, float cx, float y_top) {
	float lx = f.p.x - cx;
	if (abs(lx) > PIPE_R + f.pad || f.p.y < -POST_H - f.pad || f.p.y > y_top + f.pad) {
		return;
	}
	float d = max(abs(lx) - PIPE_R, max(-POST_H - f.p.y, f.p.y - y_top));
	vec3 n = lathe_normal(clamp(lx / PIPE_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(PIPE, n, 1.0, 1.0, f.ao);
	// 唄口
	vec2 mq = vec2(lx, f.p.y + 0.62);
	float mouth = max(abs(mq.x) - PIPE_R * 0.6, abs(mq.y) - 0.030 + mq.x * 0.0);
	c = mix(c, vec3(0.08), cov(max(mouth, -mq.y - 0.012), f.px));
	c = mix(c, c * 0.8, cov(max(mouth, mq.y + 0.012), f.px));
	part(acc, d, ink_of(PIPE), c, f.ow * 0.8, f.px);
	draw_band(acc, f, vec2(cx, y_top - 0.006), vec2(PIPE_R + 0.006, 0.010), BRASS, 1.0);
}

void pipe_bundle(inout vec4 acc, Px f, float cx) {
	if (abs(f.p.x - cx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float out_dir = sign(cx);
	organ_pipe(acc, f, cx + out_dir * 0.052, 0.55);
	organ_pipe(acc, f, cx - out_dir * 0.052, 0.78);
	organ_pipe(acc, f, cx, POST_H);
	draw_band(acc, f, vec2(cx, -0.40), vec2(0.090, 0.018), TEAL_WOOD, 0.0);
	draw_band(acc, f, vec2(cx, -0.92), vec2(0.090, 0.024), TEAL_WOOD, 0.0);
	draw_band(acc, f, vec2(cx, 0.955), vec2(0.060, 0.024), BRASS, 1.0);
}

void case_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, TEAL_WOOD, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 透かしの格子(音の抜け穴)と、中央の砂の色の円
	float grille = step(abs(fract(q.x / 0.05) - 0.5), 0.20) * step(abs(q.y), 0.032) * step(0.10, abs(q.x)) * step(abs(q.x), 0.74);
	inlay(acc, d, TEAL_WOOD * 0.45, grille, f);
	inlay(acc, d, BRASS, (1.0 - smoothstep(0.0, max(0.006, f.px * 0.7), abs(length(q) - 0.044) - 0.006)), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.026, f.px), f);
}

// ラッパの口: 細い管が右上へ曲がって広がる
void horn(inout vec4 acc, Px f) {
	vec2 q = f.p - HORN;
	if (abs(q.x) > 0.24 + f.pad || q.y < -f.pad || q.y > 0.22 + f.pad) {
		return;
	}
	float d_tube = sd_segment(q, vec2(-0.12, 0.02), vec2(0.0, 0.08)) - 0.014;
	vec2 bq = rot(q - vec2(0.0, 0.08), -1.1);
	float t = clamp(bq.y / 0.15, 0.0, 1.0);
	float d_bell = max(abs(bq.x) - mix(0.016, 0.085, t * t), max(-bq.y, bq.y - 0.15));
	float d = min(d_tube, d_bell);
	vec3 n = normalize(vec3(bq.x / 0.08 * 0.6, 0.2, 0.8));
	part(acc, d, ink_of(BRASS), shade_mat(BRASS, n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	vec2 mq = bq - vec2(0.0, 0.15);
	over(acc, ink_of(BRASS) * 1.5, cov(sd_ellipse(mq, vec2(0.075, 0.016)), f.px));
	draw_band(acc, f, HORN + vec2(-0.12, 0.012), vec2(0.040, 0.016), TEAL_WOOD, 0.0);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	pipe_bundle(acc, f, -POST_X);
	pipe_bundle(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	case_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		horn(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
