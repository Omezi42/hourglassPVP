shader_type canvas_item;
// 時を刻む歯車(ティック)。GameDesign.md 9章 / Architecture.md 10.19節。
// 真鍮の柱の中ほどに歯車、天板の上に返すたびに鳴る小さな鐘。板の中央にも歯車。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 COPPER = vec3(0.78, 0.46, 0.26);
const vec3 BRASS = vec3(0.88, 0.68, 0.34);
const float POST_R = 0.042;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float BELL_Y = 1.262;

// 歯車の距離(歯の数 teeth、外の半径 r、穴の半径 hole)
float sd_gear(vec2 q, float r, float teeth, float hole) {
	float a = atan(q.y, q.x);
	float tooth = smoothstep(-0.25, 0.25, cos(a * teeth)) * r * 0.16;
	float d = length(q) - (r * 0.84 + tooth);
	return max(d * 0.85, -(length(q) - hole));
}

void draw_gear(inout vec4 acc, Px f, vec2 c, float r, float teeth, vec3 col) {
	vec2 q = f.p - c;
	if (length(q) > r + f.pad) {
		return;
	}
	float d = sd_gear(q, r, teeth, r * 0.22);
	vec3 n = normalize(vec3(q / r * 0.35, 0.85));
	part(acc, d, ink_of(col), shade_mat(col, n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	// 肉抜きの穴と中心の軸
	float a = atan(q.y, q.x);
	float spoke = abs(fract(a / 6.2832 * 4.0 + 0.125) - 0.5);
	float window = step(0.16, spoke) * step(r * 0.34, length(q)) * step(length(q), r * 0.62);
	over(acc, ink_of(col) * 1.4, window * cov(d, f.px) * 0.9);
	draw_ball(acc, f, c, r * 0.20, SILVER, 1.0);
}

void brass_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, BRASS, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.028), COPPER, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.50), vec2(0.064, 0.016), COPPER, 1.0);
	draw_gear(acc, f, vec2(cx, 0.0), 0.120, 10.0, COPPER);
}

void copper_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, COPPER, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 目盛りの刻み
	float tick = step(abs(fract(q.x * 12.0) - 0.5), 0.07) * step(0.030, abs(q.y)) * step(abs(q.y), 0.060);
	inlay(acc, d, ink_of(COPPER) * 1.6, tick * step(0.14, abs(q.x)) * step(abs(q.x), 0.74), f);
}

// 天板の上の鐘と、それを叩く小槌
void bell(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, BELL_Y);
	if (abs(q.x) > 0.20 + f.pad || abs(q.y) > 0.14 + f.pad) {
		return;
	}
	float yy = clamp((0.095 - q.y) / 0.16, 0.0, 1.0);
	float half_w = mix(0.035, 0.095, yy * yy) + 0.02 * smoothstep(0.85, 1.0, yy);
	float d = max(abs(q.x) - half_w, max(q.y - 0.095, -q.y - 0.065));
	d = min(d, length(q - vec2(0.0, 0.10)) - 0.025);
	vec3 n = normalize(vec3(q.x / 0.09, 0.2 - yy * 0.4, 0.75));
	part(acc, d, ink_of(BRASS), shade_mat(BRASS, n, 1.0, 1.0, 1.0), f.ow, f.px);
	over(acc, mix(sand_color, vec3(1.0), 0.2), cov(sd_round_box(q - vec2(0.0, -0.035), vec2(0.075, 0.010), 0.006), f.px) * cov(d, f.px));
	// 小槌
	float d_arm = sd_segment(q, vec2(0.17, -0.07), vec2(0.115, 0.02)) - 0.008;
	part(acc, d_arm, ink_of(COPPER), COPPER, f.ow * 0.7, f.px);
	draw_ball(acc, f, vec2(0.0, BELL_Y) + vec2(0.11, 0.03), 0.024, SILVER, 1.0);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	brass_post(acc, f, -POST_X);
	brass_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	copper_slab(acc, f, f.side * PLATE_Y);
	draw_gear(acc, f, vec2(0.0, f.side * PLATE_Y), 0.085, 8.0, BRASS);
	if (f.p.y > PLATE_Y) {
		bell(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
