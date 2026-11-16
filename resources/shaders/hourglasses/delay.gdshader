shader_type canvas_item;
// 振り子(ディレイ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 器の後ろに振り子を吊るし、天板の上に小さな文字盤。柱は銅の細い管、板は胡桃の木。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 COPPER = vec3(0.80, 0.50, 0.30);
const vec3 WALNUT = vec3(0.42, 0.26, 0.16);
const vec3 DIAL = vec3(0.96, 0.92, 0.82);
const float POST_R = 0.042;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 PIVOT = vec2(0.0, 1.00);
const float SWING = 0.16;
const float ROD_LEN = 1.22;
const vec2 DIAL_C = vec2(0.0, 1.262);

// 振り子(止めた角度は片側へ振れたところ)
void pendulum(inout vec4 acc, Px f) {
	vec2 dir = vec2(sin(SWING), -cos(SWING));
	vec2 bob = PIVOT + dir * ROD_LEN;
	float d_rod = sd_segment(f.p, PIVOT, bob) - 0.010;
	part(acc, d_rod, ink_of(COPPER), shade_mat(COPPER, normalize(vec3(0.3, 0.2, 0.9)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	vec2 q = f.p - bob;
	if (length(q) < 0.12 + f.pad) {
		vec3 n = normalize(vec3(q / 0.11 * 0.6, 0.75));
		part(acc, length(q) - 0.105, ink_of(COPPER), shade_mat(COPPER, n, 1.0, 1.0, 1.0), f.ow, f.px);
		vec3 gn = normalize(vec3(q / 0.05 * 0.6, 0.8));
		part(acc, length(q) - 0.048, ink_of(COPPER), shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
}

void copper_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, COPPER, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.028), WALNUT, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.36), vec2(0.064, 0.016), WALNUT, 0.0);
	draw_ball(acc, f, vec2(cx, 0.0), 0.058, WALNUT, 0.0);
}

void walnut_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, WALNUT, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.054) - 0.005);
	inlay(acc, d, COPPER, rim * step(abs(q.x), 0.76), f);
	// 振り子の振れ幅を示す弧の目盛り
	float r = length(q - vec2(0.0, 0.20));
	float arc = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.7), abs(r - 0.21) - 0.004);
	float ang = atan(q.x, -(q.y - 0.20));
	inlay(acc, d, COPPER, arc * step(abs(ang), 0.55), f);
	float ticks = step(abs(fract(ang / 0.11) - 0.5), 0.12) * step(abs(r - 0.225), 0.016) * step(abs(ang), 0.55);
	inlay(acc, d, COPPER, ticks, f);
}

// 小さな文字盤: 真鍮の縁、数字の代わりの点、2本の針
void dial(inout vec4 acc, Px f) {
	vec2 q = f.p - DIAL_C;
	if (length(q) > 0.13 + f.pad) {
		return;
	}
	vec3 rn = normalize(vec3(q / 0.12 * 0.6, 0.75));
	part(acc, length(q) - 0.115, ink_of(COPPER), shade_mat(GOLD, rn, 1.0, 1.0, 1.0), f.ow, f.px);
	over(acc, DIAL, cov(length(q) - 0.092, f.px));
	float a = atan(q.y, q.x);
	float pip = step(abs(fract(a / 6.2832 * 12.0 + 0.5) - 0.5), 0.09) * step(abs(length(q) - 0.075), 0.010);
	over(acc, WALNUT, pip);
	float hand_h = sd_segment(q, vec2(0.0), vec2(-0.030, 0.040)) - 0.008;
	float hand_m = sd_segment(q, vec2(0.0), vec2(0.060, 0.030)) - 0.005;
	over(acc, WALNUT, cov(min(hand_h, hand_m), f.px));
	over(acc, sand_color, cov(length(q) - 0.014, f.px));
}

void art_back(inout vec4 acc, Px f) {
	pendulum(acc, f);
}

void art_frame(inout vec4 acc, Px f) {
	copper_post(acc, f, -POST_X);
	copper_post(acc, f, POST_X);
	draw_collars(acc, f, COPPER, 1.0);
	walnut_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		dial(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
