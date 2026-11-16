shader_type canvas_item;
// 硝子の器(グラス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 枠まで透きとおった青い硝子。角を切った柱と厚い板、銀の細い金具、硝子の宝石と雫。板の角に細いひび。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 CRYSTAL = vec3(0.42, 0.78, 1.0);
const vec3 CRYSTAL_INK = vec3(0.16, 0.26, 0.48);
const float CRYSTAL_ALPHA = 0.86;
const float PRISM_X = 0.68;
const float PRISM_R = 0.058;
const vec2 SLAB_HALF = vec2(0.80, 0.082);

// 透ける面: 輪郭は不透明に、面は半透明に重ねる。facet は面の明るさ(-1〜1)。
void glass_part(inout vec4 acc, float d, float facet, float ow, float px) {
	over(acc, CRYSTAL_INK, clamp(0.5 - (d - ow) / px, 0.0, 1.0) - clamp(0.5 - d / px, 0.0, 1.0));
	vec3 c = mix(CRYSTAL * 0.86, mix(CRYSTAL, vec3(1.0), 0.50), facet * 0.5 + 0.5);
	over(acc, c, cov(d, px) * mix(CRYSTAL_ALPHA, 0.95, max(facet, 0.0)));
}

// 角を切った柱(正面・左右の斜面の3面)
void draw_prism(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > PRISM_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - PRISM_R, f.ay - POST_H);
	float u = lx / PRISM_R;
	float facet = u < -0.45 ? 0.9 : (u > 0.45 ? -0.7 : 0.15);
	glass_part(acc, d, facet, f.ow * 0.8, f.px);
	// 稜線の照り
	float edge = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.8), abs(abs(u) - 0.45) * PRISM_R);
	over(acc, vec3(1.0), edge * 0.7 * cov(d, f.px));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.022), SILVER, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.074, 0.016), SILVER, 1.0);
}

void glass_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, SLAB_HALF, 0.03);
	float v = q.y / SLAB_HALF.y;
	float facet = v > 0.45 ? 0.9 : (v < -0.45 ? -0.6 : 0.1);
	glass_part(acc, d, facet, f.ow * 0.8, f.px);
	// 正面を斜めに走る照り
	float shine = 1.0 - smoothstep(0.0, max(0.01, f.px), abs(q.x + q.y * 1.2 + 0.42) - 0.018);
	over(acc, vec3(1.0), shine * 0.6 * cov(d + f.ow, f.px));
	// 上の板の右の角から入った細いひび
	if (cy > 0.0) {
		vec2 a = vec2(0.80, 0.06);
		vec2 b = vec2(0.66, -0.01);
		vec2 c = vec2(0.58, 0.035);
		vec2 e = vec2(0.70, -0.06);
		float crack = min(min(sd_segment(q, a, b), sd_segment(q, b, c)), sd_segment(q, b, e));
		over(acc, vec3(0.97, 0.99, 1.0), cov(crack - max(0.004, f.px * 0.5), f.px) * cov(d, f.px));
	}
}

// 銀の台に据えた、角を切った硝子の宝石(板の中央)
void glass_gem(inout vec4 acc, Px f, vec2 c, vec2 hs) {
	vec2 q = f.p - c;
	if (abs(q.x) > hs.x + 0.03 + f.pad || abs(q.y) > hs.y + 0.03 + f.pad) {
		return;
	}
	float d_mount = sd_rhombus(q, hs + vec2(0.024, 0.018));
	part(acc, d_mount, ink_of(SILVER), shade_mat(SILVER, normalize(vec3(q / hs * 0.4, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	float d = sd_rhombus(q, hs);
	float facet = q.x < 0.0 ? (q.y > 0.0 ? 0.9 : 0.1) : (q.y > 0.0 ? 0.3 : -0.7);
	glass_part(acc, d, facet, f.ow * 0.6, f.px);
	float table = sd_rhombus(q, hs * 0.42);
	over(acc, mix(CRYSTAL, vec3(1.0), 0.75), cov(table, f.px) * 0.8);
}

// 天板の上の雫の形の硝子
void glass_drop(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, 1.255);
	if (abs(q.x) > 0.12 + f.pad || abs(q.y) > 0.15 + f.pad) {
		return;
	}
	float d_ball = length(q + vec2(0.0, 0.02)) - 0.070;
	float d_tip = sd_segment(q, vec2(0.0, -0.02), vec2(0.0, 0.125)) - mix(0.068, 0.004, clamp((q.y + 0.02) / 0.145, 0.0, 1.0));
	float d = min(d_ball, d_tip);
	float facet = clamp(-q.x / 0.07 * 0.9 + 0.15, -0.7, 0.9);
	glass_part(acc, d, facet, f.ow * 0.8, f.px);
	over(acc, vec3(1.0), cov(length(q - vec2(-0.025, 0.0)) - 0.016, f.px) * 0.9);
	draw_band(acc, f, vec2(0.0, 1.176), vec2(0.070, 0.016), SILVER, 1.0);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	draw_prism(acc, f, -PRISM_X);
	draw_prism(acc, f, PRISM_X);
	draw_collars(acc, f, SILVER, 1.0);
	glass_slab(acc, f, f.side * PLATE_Y);
	glass_gem(acc, f, vec2(0.0, f.side * PLATE_Y), vec2(0.070, 0.050));
	if (f.p.y > PLATE_Y) {
		glass_drop(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
