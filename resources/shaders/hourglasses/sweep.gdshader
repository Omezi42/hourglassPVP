shader_type canvas_item;
// 箒(スイープ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は2本の箒の柄で、下の穂が底板の脇へ広がる。板は紫の紐で束ねた藁、天板の上に塵取り代わりの羽根箒。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 HANDLE = vec3(0.60, 0.44, 0.30);
const vec3 STRAW = vec3(0.90, 0.78, 0.48);
const vec3 STRAW_DARK = vec3(0.64, 0.50, 0.26);
const vec3 CORD = vec3(0.50, 0.34, 0.62);
const float BROOM_X = 0.70;
const float HANDLE_R = 0.034;
const float BRISTLE_TOP = -0.70;
const float BRISTLE_BOTTOM = -1.20;
const vec2 SLAB_HALF = vec2(0.80, 0.080);

// 穂: 下へ扇形に開き、藁の筋が走る
void bristles(inout vec4 acc, Px f, vec2 top, float h, float w0, float w1, float px) {
	vec2 q = f.p - top;
	if (q.y > f.pad || q.y < -h - f.pad || abs(q.x) > w1 + f.pad) {
		return;
	}
	float t = clamp(-q.y / h, 0.0, 1.0);
	float w = mix(w0, w1, t * t * 0.5 + t * 0.5);
	float ragged = 0.012 * sin(q.x * 120.0) * step(0.9, t);
	float d = max(abs(q.x) - w, max(q.y, -q.y - h - ragged));
	float u = q.x / max(w, 0.001);
	float strand = abs(fract(u * 7.0 + 0.5) - 0.5);
	vec3 c = mix(STRAW_DARK, STRAW, smoothstep(0.05, 0.35, strand));
	c *= 0.82 + 0.25 * smoothstep(-1.0, 0.2, -u);
	part(acc, d, ink_of(STRAW_DARK), c, f.ow, px);
	// 紫の紐の結び
	vec2 bq = q - vec2(0.0, -h * 0.14);
	float d_cord = sd_round_box(bq, vec2(mix(w0, w1, 0.14) + 0.01, 0.016), 0.012);
	part(acc, d_cord, ink_of(CORD), shade_mat(CORD, normalize(vec3(bq.x / w1 * 0.6, bq.y / 0.016 * 0.5, 0.75)), 0.0, 1.0, 1.0), f.ow * 0.8, px);
}

void broom(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, HANDLE_R, BRISTLE_TOP, POST_H, HANDLE, 0.0);
	draw_band(acc, f, vec2(cx, 0.955), vec2(0.078, 0.028), CORD, 0.3);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.060, 0.016), CORD, 0.3);
	bristles(acc, f, vec2(cx, BRISTLE_TOP), BRISTLE_TOP - BRISTLE_BOTTOM, 0.045, 0.15, f.px);
}

void straw_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.04, STRAW, 0.0, 0.4);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float strand = abs(fract(q.y * 26.0 + vnoise(q * vec2(3.0, 1.0))) - 0.5);
	inlay(acc, d, STRAW_DARK, (1.0 - smoothstep(0.05, 0.2, strand)) * 0.5 * smoothstep(0.03, 0.012, f.px), f);
	for (int k = -2; k <= 2; k++) {
		float x = float(k) * 0.33;
		vec2 bq = q - vec2(x, 0.0);
		float d_tie = sd_round_box(bq, vec2(0.022, SLAB_HALF.y + 0.008), 0.010);
		vec3 c = k == 0 ? mix(CORD, sand_color, 0.55) : CORD;
		part(acc, d_tie, ink_of(CORD), shade_mat(c, normalize(vec3(bq.x / 0.022 * 0.6, 0.0, 0.8)), 0.0, 1.0, 1.0), f.ow * 0.8, f.px);
	}
}

// 天板の上に寝かせた小さな手箒
void hand_broom(inout vec4 acc, Px f) {
	vec2 c = vec2(0.02, 1.255);
	vec2 q = rot(f.p - c, -1.45);
	if (length(f.p - c) > 0.32 + f.pad) {
		return;
	}
	float d_handle = sd_round_box(q - vec2(0.0, 0.10), vec2(0.020, 0.12), 0.012);
	part(acc, d_handle, ink_of(HANDLE), shade_mat(HANDLE, normalize(vec3(q.x / 0.02 * 0.6, 0.0, 0.8)), 0.0, 0.6, 1.0), f.ow * 0.8, f.px);
	Px g = f;
	g.p = q + c;
	bristles(acc, g, c + vec2(0.0, -0.02), 0.16, 0.028, 0.075, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	draw_collars(acc, f, CORD, 0.3);
	straw_slab(acc, f, f.side * PLATE_Y);
	broom(acc, f, -BROOM_X);
	broom(acc, f, BROOM_X);
	if (f.p.y > PLATE_Y) {
		hand_broom(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
