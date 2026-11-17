shader_type canvas_item;
// 輪唱(カノン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は長さの違う管を束ねたオルガンのパイプ、板には追いかけ合う2本の旋律。天板の上に竪琴。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PIPE = vec3(0.80, 0.78, 0.74);
const vec3 ROSEWOOD = vec3(0.38, 0.16, 0.14);
const vec3 STRING_COL = vec3(0.96, 0.92, 0.80);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 LYRE = vec2(0.0, 1.192);
const float LYRE_K = 1.2;

// オルガンのパイプ: 3本の管、それぞれに歌口
void organ_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	for (int k = -1; k <= 1; k++) {
		float px0 = float(k) * 0.034;
		float r = k == 0 ? 0.020 : 0.016;
		float x = lx - px0;
		float d = max(abs(x) - r, f.ay - POST_H);
		vec3 n = lathe_normal(clamp(x / r, -1.0, 1.0), 0.0);
		vec3 c = shade_mat(k == 0 ? mix(PIPE, sand_color, 0.3) : PIPE, n, 1.0, 1.0, f.ao);
		// 歌口
		float my = (k == 0 ? -0.40 : 0.10 + 0.25 * float(k));
		vec2 mq = vec2(x, f.p.y - my);
		float mouth = step(abs(mq.x), r * 0.7) * step(abs(mq.y + abs(mq.x) * 0.8), 0.016);
		c = mix(c, vec3(0.08), mouth);
		part(acc, d, ink_of(PIPE * 0.6), c, f.ow * 0.6, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), ROSEWOOD, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.70), vec2(0.070, 0.014), GOLD, 1.0);
}

void melody_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, ROSEWOOD, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 同じ旋律を少し遅らせてもう1本
	for (int k = 0; k < 2; k++) {
		float shift = float(k) * 0.12;
		float x = q.x - shift;
		float nk = floor(x / 0.12);
		float pitch = (hash21(vec2(nk, 4.0)) - 0.5) * 0.050;
		vec2 nq = vec2(fract(x / 0.12) * 0.12 - 0.06, q.y - pitch);
		float d_note = sd_ellipse(rot(nq, 0.4), vec2(0.016, 0.011));
		float d_stem = max(abs(nq.x - 0.014) - 0.003, max(-nq.y, nq.y - 0.040));
		vec3 c = k == 0 ? GOLD : mix(sand_color, vec3(1.0), 0.2);
		inlay(acc, d, c, cov(min(d_note, d_stem), f.px) * step(abs(q.x), 0.74), f);
	}
}

// 竪琴: U字の枠、横木、張った弦、砂の色の弦が1本
void lyre(inout vec4 acc, Px f) {
	vec2 q = (f.p - LYRE) / LYRE_K;
	if (abs(q.x) > 0.17 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= LYRE_K;
	f.ow /= LYRE_K;
	// 弦
	for (int k = -2; k <= 2; k++) {
		float x = float(k) * 0.022;
		float d_str = max(abs(q.x - x) - 0.003, max(-q.y - 0.070, q.y - 0.090));
		vec3 c = k == 0 ? sand_color : STRING_COL;
		part(acc, d_str, ink_of(c) * 0.5, c, f.ow * 0.2, f.px);
	}
	// U字の枠(左右の腕が外へ反る)
	for (int s = -1; s <= 1; s += 2) {
		vec2 aq = vec2(q.x * float(s), q.y);
		float t = clamp((aq.y + 0.080) / 0.200, 0.0, 1.0);
		float cxv = 0.075 + 0.030 * sin(t * 3.1416 * 1.2);
		float d_arm = max(abs(aq.x - cxv) - 0.016 * (1.0 - t * 0.4), max(-aq.y - 0.080, aq.y - 0.120));
		part(acc, d_arm, ink_of(ROSEWOOD), shade_mat(ROSEWOOD, normalize(vec3((aq.x - cxv) / 0.016 * 0.5, 0.0, 0.8)), 0.0, 0.8, 1.0), f.ow * 0.8, f.px);
		draw_ball(acc, f, LYRE + vec2(float(s) * 0.093, 0.125) * LYRE_K, 0.014 * LYRE_K, GOLD, 1.0);
	}
	float d_base = sd_round_box(q - vec2(0.0, -0.082), vec2(0.090, 0.018), 0.012);
	part(acc, d_base, ink_of(ROSEWOOD), shade_mat(ROSEWOOD, normalize(vec3(q.x / 0.09 * 0.4, 0.3, 0.85)), 0.0, 0.8, 1.0), f.ow * 0.8, f.px);
	part(acc, sd_round_box(q - vec2(0.0, 0.095), vec2(0.105, 0.008), 0.004), ink_of(GOLD), GOLD, f.ow * 0.6, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	organ_post(acc, f, -POST_X);
	organ_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	melody_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		lyre(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
