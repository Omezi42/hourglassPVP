shader_type canvas_item;
// 位相(フェイズ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱に2本の螺旋がずれて巻きつき、板にはずれた2つの波。天板の上に重なり合う2つの環。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 SLATE = vec3(0.20, 0.22, 0.30);
const vec3 COPPER = vec3(0.82, 0.48, 0.30);
const vec3 CYAN = vec3(0.42, 0.78, 0.86);
const float POST_R = 0.044;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 RINGS = vec2(0.0, 1.222);

void helix_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	part(acc, d, ink_of(SLATE), shade_mat(SLATE, n, 0.4, 1.0, f.ao), f.ow, f.px);
	// ずれた2本の螺旋(手前の半周だけ)
	for (int k = 0; k < 2; k++) {
		float ph = f.p.y * 2.0 * 6.2832 + float(k) * 1.9;
		float rx = 0.066 * sin(ph);
		float front = cos(ph);
		float d_wire = max(abs(lx - rx) - 0.012 * (0.6 + 0.4 * front), f.ay - POST_H + 0.06);
		vec3 wc = k == 0 ? COPPER : mix(CYAN, sand_color, 0.3);
		if (front > -0.2) {
			part(acc, d_wire, ink_of(wc), mix(wc * 0.7, wc * 1.15, 0.5 + 0.5 * front), f.ow * 0.6, f.px);
		}
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), COPPER, 1.0);
}

void wave_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, SLATE, 0.4, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	for (int k = 0; k < 2; k++) {
		float w = 0.030 * sin(q.x * 11.0 + float(k) * 1.9);
		float a = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.8), abs(q.y - w) - 0.006);
		inlay(acc, d, k == 0 ? COPPER : CYAN, a * step(abs(q.x), 0.76), f);
	}
	inlay(acc, d, sand_color, cov(length(q) - 0.030, f.px), f);
}

// 重なる2つの環: 銅の環と砂の色の環が半分ずれて組み合う
void phase_rings(inout vec4 acc, Px f) {
	vec2 q = f.p - RINGS;
	if (abs(q.x) > 0.24 + f.pad || abs(q.y) > 0.15 + f.pad) {
		return;
	}
	vec2 c0 = vec2(-0.060, 0.0);
	vec2 c1 = vec2(0.060, 0.0);
	float d0 = abs(length(q - c0) - 0.085) - 0.019;
	float d1 = abs(length(q - c1) - 0.085) - 0.019;
	vec3 col1 = mix(sand_color, CYAN, 0.2);
	vec3 n0 = normalize(vec3((q - c0) / 0.12 * 0.5, 0.8));
	vec3 n1 = normalize(vec3((q - c1) / 0.12 * 0.5, 0.8));
	// 上半分は銅の環が手前、下半分は砂の環が手前に組む
	if (q.y > 0.0) {
		part(acc, d1, ink_of(col1), shade_mat(col1, n1, 0.6, 1.0, 1.0), f.ow * 0.8, f.px);
		part(acc, d0, ink_of(COPPER), shade_mat(COPPER, n0, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	} else {
		part(acc, d0, ink_of(COPPER), shade_mat(COPPER, n0, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
		part(acc, d1, ink_of(col1), shade_mat(col1, n1, 0.6, 1.0, 1.0), f.ow * 0.8, f.px);
	}
	draw_ball(acc, f, RINGS, 0.022, mix(vec3(1.0), CYAN, 0.3), 1.0);
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - RINGS;
	float halo = exp(-dot(q, q) / 0.006);
	add_light(acc, mix(sand_color, CYAN, 0.4), halo * 0.45);
}

void art_frame(inout vec4 acc, Px f) {
	helix_post(acc, f, -POST_X);
	helix_post(acc, f, POST_X);
	draw_collars(acc, f, COPPER, 1.0);
	wave_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		phase_rings(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
