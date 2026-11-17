shader_type canvas_item;
// 巡り(サイクル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱に新月から満月までの月の満ち欠けを並べ、天板の上に互いを追いかける2本の円の矢印。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 NIGHT = vec3(0.22, 0.16, 0.34);
const vec3 MOON = vec3(0.94, 0.92, 0.84);
const float POST_HALF = 0.058;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 CIRCLE = vec2(0.0, 1.250);
const int PHASES = 6;

// 月の満ち欠け: phase 0=新月 〜 1=満月
float moon_lit(vec2 q, float r, float phase) {
	float disc = step(length(q), r);
	float shift = mix(r * 2.0, 0.0, phase);
	float shadow = step(length(q - vec2(-shift, 0.0)), r);
	return disc * (phase >= 1.0 ? 1.0 : 1.0 - shadow);
}

void phase_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(NIGHT, n, 0.3, 1.0, f.ao);
	float span = 1.70 / float(PHASES);
	float k = clamp(floor((f.p.y + 0.85) / span), 0.0, float(PHASES - 1));
	vec2 mq = vec2(lx, f.p.y + 0.85 - (k + 0.5) * span);
	float ph = (cx > 0.0 ? k : float(PHASES - 1) - k) / float(PHASES - 1);
	float r = 0.034;
	float lit = moon_lit(mq * vec2(cx > 0.0 ? 1.0 : -1.0, 1.0), r, ph);
	c = mix(c, NIGHT * 0.6, step(length(mq), r));
	c = mix(c, mix(MOON, sand_color, 0.25), lit);
	part(acc, d, ink_of(NIGHT), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), SILVER, 1.0);
}

void night_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, NIGHT, 0.3, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.054) - 0.005);
	inlay(acc, d, SILVER, rim * step(abs(q.x), 0.76), f);
	for (int k = -2; k <= 2; k++) {
		vec2 mq = q - vec2(float(k) * 0.16, 0.0);
		float ph = float(k + 2) / 4.0;
		inlay(acc, d, NIGHT * 0.6, step(length(mq), 0.026), f);
		inlay(acc, d, mix(MOON, sand_color, 0.25), moon_lit(mq, 0.026, ph), f);
	}
}

// 互いを追う2本の円弧の矢印と、中心の砂の色の珠
void circle_arrows(inout vec4 acc, Px f) {
	vec2 q = f.p - CIRCLE;
	if (length(q) > 0.15 + f.pad) {
		return;
	}
	float r = length(q);
	float a = atan(q.y, q.x);
	for (int k = 0; k < 2; k++) {
		float a0 = float(k) * 3.1416;
		float rel = mod(a - a0, 6.2832);
		float d_arc = max(abs(r - 0.100) - 0.020, max(rel - 2.4, 0.15 - rel));
		// 矢じり: 弧の先(rel = 2.4)に三角
		float ta = a0 + 2.55;
		vec2 tip = vec2(cos(ta), sin(ta)) * 0.100;
		vec2 dir = vec2(-sin(ta), cos(ta));
		vec2 hq = q - tip;
		float along = dot(hq, dir);
		float across = dot(hq, vec2(dir.y, -dir.x));
		float d_head = max(abs(across) - (0.045 - along * 0.9), max(-along - 0.04, along - 0.045));
		float d = min(d_arc, d_head);
		vec3 col = k == 0 ? SILVER : mix(sand_color, MOON, 0.3);
		part(acc, d, ink_of(NIGHT), shade_mat(col, normalize(vec3(q / 0.12 * 0.4, 0.85)), 0.6, 1.0, 1.0), f.ow * 0.8, f.px);
	}
	vec3 gn = normalize(vec3(q / 0.035 * 0.6, 0.75));
	part(acc, r - 0.034, ink_of(NIGHT), shade_mat(MOON, gn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	phase_post(acc, f, -POST_X);
	phase_post(acc, f, POST_X);
	draw_collars(acc, f, SILVER, 1.0);
	night_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		circle_arrows(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
