shader_type canvas_item;
// 継承(レガシー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は枝を伸ばす古木の幹、板には張り巡らせた根。天板の上に砂の色の実をつけた家系の樹。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BARK = vec3(0.42, 0.30, 0.22);
const vec3 LEAF = vec3(0.36, 0.56, 0.32);
const vec3 HEARTWOOD = vec3(0.66, 0.50, 0.34);
const float TRUNK_R = 0.050;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 TREE = vec2(0.0, 1.172);

void trunk_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.12 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float twist = 0.010 * sin(f.p.y * 5.0 + cx * 3.0);
	float x = lx - twist;
	float d = max(abs(x) - TRUNK_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(x / TRUNK_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(BARK, n, 0.0, 0.4, f.ao);
	float ridges = abs(fract(x * 50.0 + vnoise(vec2(x * 10.0, f.p.y * 3.0)) * 1.5) - 0.5);
	c = mix(c, BARK * 0.55, (1.0 - smoothstep(0.05, 0.16, ridges)) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(BARK), c, f.ow, f.px);
	// 内側へ伸びる小枝と葉
	for (int k = -1; k <= 1; k += 2) {
		float by = float(k) * 0.38;
		vec2 b0 = vec2(cx, by);
		vec2 b1 = vec2(cx - sign(cx) * 0.10, by + 0.07);
		part(acc, sd_segment(f.p, b0, b1) - 0.010, ink_of(BARK), BARK, f.ow * 0.6, f.px);
		vec2 lq = rot(f.p - b1, -sign(cx) * 0.7);
		part(acc, sd_ellipse(lq, vec2(0.016, 0.030)), ink_of(LEAF), LEAF, f.ow * 0.5, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), HEARTWOOD, 0.0);
}

void root_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, HEARTWOOD, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 中央から左右へ枝分かれして伸びる根
	float a = 0.0;
	for (int k = 0; k < 3; k++) {
		float amp = 0.020 + 0.012 * float(k);
		float w = (0.020 - abs(q.x) * 0.018) * (1.0 - 0.25 * float(k));
		float y = amp * sin(abs(q.x) * (7.0 + float(k) * 3.0) + float(k) * 2.0) * smoothstep(0.0, 0.3, abs(q.x));
		a = max(a, 1.0 - smoothstep(0.0, max(0.005, f.px), abs(q.y - y) - max(w * 0.4, 0.003)));
	}
	inlay(acc, d, BARK, a * step(abs(q.x), 0.76), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.032, f.px), f);
}

// 家系の樹: 幹と枝、丸く茂る葉、砂の色の実
void family_tree(inout vec4 acc, Px f) {
	vec2 q = f.p - TREE;
	if (abs(q.x) > 0.22 + f.pad || q.y < -0.10 - f.pad || q.y > 0.20 + f.pad) {
		return;
	}
	float d_trunk = max(abs(q.x) - (0.020 + max(-q.y, 0.0) * 0.25), max(-q.y - 0.090, q.y - 0.060));
	part(acc, d_trunk, ink_of(BARK), shade_mat(BARK, normalize(vec3(q.x / 0.03 * 0.6, 0.0, 0.8)), 0.0, 0.4, 1.0), f.ow * 0.8, f.px);
	vec3 blobs[4] = vec3[4](vec3(-0.075, 0.075, 0.065), vec3(0.075, 0.075, 0.065), vec3(0.0, 0.115, 0.075), vec3(0.0, 0.060, 0.060));
	float d_crown = 1e3;
	for (int k = 0; k < 4; k++) {
		d_crown = min(d_crown, length(q - blobs[k].xy) - blobs[k].z);
	}
	vec3 n = normalize(vec3((q - vec2(0.0, 0.09)) / 0.15 * 0.6, 0.75));
	vec3 lc = shade_mat(LEAF, n, 0.0, 0.5, 1.0);
	lc = mix(lc, LEAF * 0.7, step(0.6, vnoise(q * 40.0)) * 0.6);
	part(acc, d_crown, ink_of(LEAF), lc, f.ow, f.px);
	vec2 fruits[5] = vec2[5](vec2(-0.090, 0.060), vec2(0.085, 0.090), vec2(-0.020, 0.140), vec2(0.040, 0.045), vec2(-0.050, 0.105));
	for (int k = 0; k < 5; k++) {
		draw_ball(acc, f, TREE + fruits[k], 0.016, sand_color, 0.0);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	trunk_post(acc, f, -POST_X);
	trunk_post(acc, f, POST_X);
	draw_collars(acc, f, HEARTWOOD, 0.0);
	root_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		family_tree(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
