shader_type canvas_item;
// 返し(バーブ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱に有刺鉄線を巻き、板には返しの付いた鉤の列。天板の上に糸から下がる大きな釣り針。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 TAR = vec3(0.26, 0.22, 0.20);
const vec3 RUST = vec3(0.62, 0.36, 0.22);
const vec3 WIRE = vec3(0.62, 0.64, 0.66);
const float POST_R = 0.044;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 HOOK = vec2(0.0, 1.222);
const float HOOK_K = 1.3;

void wired_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	part(acc, d, ink_of(TAR), shade_mat(TAR, n, 0.0, 0.6, f.ao), f.ow, f.px);
	// 斜めに巻いた鉄線と、ところどころの棘
	float ph = f.p.y * 1.8 * 6.2832 + cx * 2.0;
	float rx = 0.058 * sin(ph);
	float front = cos(ph);
	float d_wire = max(abs(lx - rx) - 0.008, f.ay - POST_H + 0.06);
	if (front > -0.3) {
		part(acc, d_wire, vec3(0.05), mix(WIRE * 0.6, WIRE * 1.2, 0.5 + 0.5 * front), f.ow * 0.5, f.px);
	}
	float knot = fract(f.p.y * 1.8 * 2.0 + cx);
	vec2 kq = vec2(lx - rx, (knot - 0.5) / 3.6);
	float d_spike = max(abs(kq.y) - 0.004, abs(kq.x) - 0.034);
	d_spike = min(d_spike, max(abs(kq.x) - 0.004, abs(kq.y) - 0.024));
	if (front > 0.0 && f.ay < POST_H - 0.06) {
		part(acc, d_spike, vec3(0.05), mix(WIRE, sand_color, 0.35), f.ow * 0.4, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), RUST, 0.6);
}

void hook_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, TAR, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 返しの付いた矢じりの列(のこぎりの歯)
	float saw = abs(fract(q.x / 0.080) - 0.5) * 0.080;
	float d_saw = max(abs(q.y) - (0.034 - saw * 0.8), abs(q.x) - 0.74);
	inlay(acc, d, RUST, cov(d_saw, f.px) * step(0.08, abs(q.x)), f);
	inlay(acc, d, RUST * 0.6, (1.0 - smoothstep(0.0, max(0.006, f.px), abs(q.y) - 0.004)) * step(abs(q.x), 0.74), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.032, f.px), f);
}

// 釣り針: 上の輪、軸、曲がり、先端の返し、糸
void fish_hook(inout vec4 acc, Px f) {
	vec2 q = (f.p - HOOK) / HOOK_K;
	if (abs(q.x) > 0.18 + f.pad || abs(q.y) > 0.17 + f.pad) {
		return;
	}
	f.px /= HOOK_K;
	f.ow /= HOOK_K;
	float d_line = max(abs(q.x) - 0.004, max(-q.y, q.y - 0.11));
	part(acc, d_line, vec3(0.05), vec3(0.92), f.ow * 0.3, f.px);
	float d_eye = abs(length(q - vec2(0.0, 0.085)) - 0.018) - 0.007;
	float d_shank = max(abs(q.x) - 0.009, max(-q.y - 0.040, q.y - 0.068));
	vec2 bq = q - vec2(0.045, -0.040);
	float d_bend = max(abs(length(bq) - 0.045) - 0.009, bq.y);
	float d_tip = max(abs(q.x - 0.090) - 0.008, max(-q.y - 0.040, q.y - 0.020));
	vec2 tq = q - vec2(0.090, 0.020);
	float d_barb = sd_segment(tq, vec2(0.0), vec2(-0.028, -0.034)) - 0.007;
	float d_hook = min(min(d_eye, d_shank), min(d_bend, min(d_tip, d_barb)));
	vec3 n = normalize(vec3(sin(q.x * 40.0) * 0.4, 0.3, 0.85));
	part(acc, d_hook, vec3(0.04), shade_mat(mix(WIRE, sand_color, 0.35), n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	wired_post(acc, f, -POST_X);
	wired_post(acc, f, POST_X);
	draw_collars(acc, f, RUST, 0.6);
	hook_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		fish_hook(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
