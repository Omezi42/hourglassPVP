shader_type canvas_item;
// 竪坑(シャフト)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は鉄の帯で締めた角の坑木、板は鋲を打った黒鉄に深い藍の帯と銀の星図の線。
// 天板の上に赤錆の竪坑櫓が立ち、頂の滑車から綱が坑口へまっすぐ垂れる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 LAPIS = vec3(0.07, 0.09, 0.27);
const vec3 CHART = vec3(0.86, 0.90, 1.0);
const vec3 NEXT_STAR = vec3(0.74, 0.84, 1.0);

// 星図の星の位置(帯の中の座標)。右端の5番が「まだ来ない」星
vec2 chart_star(int k) {
	return vec2(-0.60 + 0.228 * float(k), 0.017 * sin(float(k) * 2.3 + 0.4));
}
// 先触の刻の印: 板に嵌めた深い藍の帯を銀の星図の線がつなぎ、点線の先の右端の星だけが明るく瞬く
void star_chart(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.075) {
		return;
	}
	float strip = sd_round_box(q, vec2(0.68, 0.040), 0.036);
	inlay(acc, d, ink_of(SILVER), cov(strip - 0.013, f.px), f);
	inlay(acc, d, SILVER * 0.9, cov(strip - 0.007, f.px), f);
	float fleck = step(0.95, hash21(floor(q * 160.0)));
	vec3 lapis = mix(LAPIS, LAPIS * 1.7, vnoise(q * 22.0) * 0.7);
	inlay(acc, d, mix(lapis, CHART, fleck * 0.45), cov(strip, f.px), f);
	float inside = cov(strip + 0.004, f.px);
	for (int k = 0; k < 4; k++) {
		float dl = sd_segment(q, chart_star(k), chart_star(k + 1)) - 0.0035;
		inlay(acc, d, CHART * 0.82, cov(dl, f.px) * inside, f);
	}
	vec2 a = chart_star(4);
	vec2 b = chart_star(5);
	float dash = step(0.45, fract(dot(q - a, normalize(b - a)) * 30.0));
	inlay(acc, d, CHART * 0.7, cov(sd_segment(q, a, b) - 0.003, f.px) * dash * inside, f);
	for (int k = 0; k < 5; k++) {
		float r = k % 2 == 0 ? 0.012 : 0.009;
		inlay(acc, d, CHART, cov(length(q - chart_star(k)) - r, f.px), f);
	}
	vec2 s = q - b;
	add_light(acc, NEXT_STAR, exp(-dot(s, s) / 0.0014) * 0.95);
	add_light(acc, vec3(1.0), star4(s, 0.075));
}
const vec3 TIMBER = vec3(0.56, 0.38, 0.22);
const vec3 IRON = vec3(0.36, 0.37, 0.40);
const vec3 RUST = vec3(0.66, 0.30, 0.18);
const vec3 BRASS = vec3(0.90, 0.70, 0.36);
const vec3 ROPE = vec3(0.82, 0.68, 0.46);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.058;
// 櫓の脚の足元の開き・高さと頂、滑車の半径
const float FOOT_X = 0.25;
const float FOOT_Y = 1.188;
const vec2 APEX = vec2(0.0, 1.310);
const float SHEAVE_R = 0.056;

// 鉄の帯と鋲で締めた角の坑木
void timber_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		float edge = smoothstep(POST_R * 0.55, POST_R, abs(lx)) * sign(lx);
		vec3 n = normalize(vec3(edge * 0.85, 0.0, 0.72));
		float grain = sin(lx * 150.0 + sin(f.p.y * 9.0 + cx * 7.0) * 2.6);
		vec3 wood = mix(TIMBER * 0.74, TIMBER * 1.06, grain * 0.5 + 0.5);
		part(acc, d, ink_of(TIMBER), shade_mat(wood, n, 0.0, 0.2, f.ao), f.ow, f.px);
	}
	for (int k = 0; k < 3; k++) {
		float y = 0.20 + 0.32 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(POST_R + 0.008, 0.018), IRON, 1.0);
		draw_ball(acc, f, vec2(cx, f.side * y), 0.009, BRASS, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.086, 0.030), IRON, 1.0);
}

void iron_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, IRON, 0.9, 0.7);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	star_chart(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.022, BRASS, 1.0);
	}
}

// 赤錆の竪坑櫓と、頂の滑車から坑口へ垂れる綱
void headframe(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.30 || q.y < 1.16 || q.y > 1.38) {
		return;
	}
	vec3 rust = shade_mat(RUST, normalize(vec3(0.25, 0.3, 0.8)), 0.4, 0.6, 1.0);
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		float d_leg = sd_segment(q, vec2(sx * FOOT_X, FOOT_Y), APEX + vec2(sx * 0.012, -0.010)) - 0.015;
		part(acc, d_leg, ink_of(RUST), rust, f.ow, f.px);
	}
	for (int k = 0; k < 2; k++) {
		float y = 1.222 + 0.044 * float(k);
		float hx = FOOT_X * (APEX.y - y) / (APEX.y - FOOT_Y);
		float d_bar = sd_segment(q, vec2(-hx, y), vec2(hx, y)) - 0.009;
		part(acc, d_bar, ink_of(RUST), rust * 0.92, f.ow * 0.8, f.px);
	}
	float hx0 = FOOT_X * (APEX.y - 1.222) / (APEX.y - FOOT_Y);
	float hx1 = FOOT_X * (APEX.y - 1.266) / (APEX.y - FOOT_Y);
	float d_x = min(sd_segment(q, vec2(-hx0, 1.222), vec2(hx1, 1.266)), sd_segment(q, vec2(hx0, 1.222), vec2(-hx1, 1.266))) - 0.006;
	part(acc, d_x, ink_of(RUST), rust * 0.85, f.ow * 0.7, f.px);
	float rope_x = SHEAVE_R - 0.012;
	float d_rope = sd_segment(q, APEX + vec2(rope_x, 0.0), vec2(rope_x, FOOT_Y)) - 0.007;
	float twist = step(0.5, fract((q.y + q.x) * 70.0));
	part(acc, d_rope, ink_of(ROPE), ROPE * mix(0.82, 1.05, twist), f.ow * 0.6, f.px);
	vec2 w = q - APEX;
	float r = length(w);
	float seg = 3.14159 / 3.0;
	float a2 = mod(atan(w.y, w.x) + seg * 0.5, seg) - seg * 0.5;
	float d_rim = abs(r - SHEAVE_R + 0.010) - 0.010;
	float d_spoke = max(abs(sin(a2) * r) - 0.005, r - SHEAVE_R + 0.012);
	float d_wheel = min(min(d_rim, d_spoke), r - 0.016);
	vec3 n = normalize(vec3(w / SHEAVE_R * 0.5, 0.8));
	part(acc, d_wheel, ink_of(BRASS), shade_mat(BRASS, n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	draw_ball(acc, f, APEX, 0.010, IRON, 1.0);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - APEX;
	add_light(acc, NEXT_STAR, exp(-dot(d, d) / 0.006) * 0.35 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	timber_post(acc, f, -POST_X);
	timber_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	iron_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		headframe(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
