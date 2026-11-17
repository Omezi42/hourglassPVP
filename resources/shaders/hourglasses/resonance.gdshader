shader_type canvas_item;
// 共鳴(レゾナンス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は二股の音叉、天板の上にも小さな音叉が立ち、その左右へ音の弧が広がる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEEL = vec3(0.78, 0.80, 0.84);
const vec3 WALNUT = vec3(0.40, 0.26, 0.16);
const float FORK_X = 0.68;
const float PRONG_GAP = 0.052;
const float PRONG_R = 0.018;
const float SPLIT_Y = -0.62;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 TOP_FORK = vec2(0.0, 1.16);

// 音叉: 柄と、split_y から上で二股に分かれる腕
void tuning_fork(inout vec4 acc, Px f, vec2 base, float split_h, float top_h, float gap, float r) {
	vec2 q = f.p - base;
	if (abs(q.x) > gap + r * 2.0 + f.pad || q.y < -f.pad || q.y > top_h + f.pad) {
		return;
	}
	float d_stem = max(abs(q.x) - r, max(-q.y, q.y - split_h));
	vec2 bq = vec2(abs(q.x), q.y - split_h);
	float d_bend = max(abs(length(bq - vec2(0.0, gap)) - gap) - r, bq.y - gap);
	d_bend = max(d_bend, -bq.y);
	float d_prong = max(abs(bq.x - gap) - r, max(gap - bq.y, q.y - top_h));
	float d = min(d_stem, min(d_bend, d_prong));
	vec3 n = normalize(vec3(sign(q.x) * (abs(abs(q.x) - (q.y > split_h + gap ? gap : 0.0)) / r) * 0.6, 0.0, 0.8));
	part(acc, d, ink_of(STEEL), shade_mat(STEEL, n, 1.0, 1.0, f.ao), f.ow * 0.8, f.px);
}

void fork_post(inout vec4 acc, Px f, float cx) {
	tuning_fork(acc, f, vec2(cx, -POST_H), SPLIT_Y + POST_H, 2.0 * POST_H, PRONG_GAP, PRONG_R);
	draw_band(acc, f, vec2(cx, -0.90), vec2(0.050, 0.030), WALNUT, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), WALNUT, 0.0);
}

void walnut_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, WALNUT, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 中央から左右へ広がる波
	float amp = 0.030 * (1.0 - smoothstep(0.1, 0.76, abs(q.x)));
	float wave = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.8), abs(q.y - amp * sin(q.x * 36.0)) - 0.005);
	inlay(acc, d, mix(STEEL, sand_color, 0.5), wave * step(abs(q.x), 0.76), f);
}

// 天板の上の小さな音叉と音の弧
void top_fork(inout vec4 acc, Px f) {
	tuning_fork(acc, f, TOP_FORK, 0.05, 0.19, 0.036, 0.016);
	vec2 q = f.p - (TOP_FORK + vec2(0.0, 0.13));
	float r = length(q * vec2(1.0, 1.2));
	float a = 0.0;
	for (int k = 1; k <= 3; k++) {
		float rk = 0.07 + 0.04 * float(k);
		a = max(a, (1.0 - smoothstep(0.0, max(0.006, f.px), abs(r - rk) - 0.006)) * (1.0 - float(k) * 0.22));
	}
	a *= smoothstep(0.05, 0.09, abs(q.x)) * step(abs(q.y), 0.07);
	over(acc, mix(sand_color, vec3(1.0), 0.2), a);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	fork_post(acc, f, -FORK_X);
	fork_post(acc, f, FORK_X);
	draw_collars(acc, f, WALNUT, 0.0);
	walnut_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		top_fork(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
