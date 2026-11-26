shader_type canvas_item;
// 望遠鏡(スコープ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は継ぎ目ごとに細くなる真鍮の引き筒、板は胡桃の木に深い藍の帯と銀の星図の線。
// 天板の上の三脚に真鍮の望遠鏡が右上の空へ向き、対物の硝子がきらりと光る。

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
const vec3 BRASS = vec3(0.92, 0.72, 0.36);
const vec3 WALNUT = vec3(0.40, 0.24, 0.14);
const vec3 LEATHER = vec3(0.46, 0.18, 0.12);
const vec3 LENS = vec3(0.56, 0.78, 1.0);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
// 引き筒の継ぎ目の高さと、各段の半径
const float JOINT_A = 0.36;
const float JOINT_B = 0.70;
const vec3 TUBE_R = vec3(0.064, 0.054, 0.045);
// 望遠鏡の接眼の端・対物の端と、それぞれの半径。三脚の雲台と足元
const vec2 EYE_END = vec2(-0.27, 1.238);
const vec2 LENS_END = vec2(0.22, 1.316);
const vec2 TUBE_HALF = vec2(0.022, 0.034);
const vec2 MOUNT = vec2(-0.03, 1.262);
const float FOOT_Y = 1.188;

void draw_tube_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, TUBE_R.x, -JOINT_A, JOINT_A, BRASS, 1.0);
	draw_column(acc, f, cx, TUBE_R.y, JOINT_A, JOINT_B, BRASS, 1.0);
	draw_column(acc, f, cx, TUBE_R.y, -JOINT_B, -JOINT_A, BRASS, 1.0);
	draw_column(acc, f, cx, TUBE_R.z, JOINT_B, POST_H, BRASS, 1.0);
	draw_column(acc, f, cx, TUBE_R.z, -POST_H, -JOINT_B, BRASS, 1.0);
	draw_band(acc, f, vec2(cx, f.side * JOINT_A), vec2(TUBE_R.x + 0.008, 0.016), BRASS * 0.85, 1.0);
	draw_band(acc, f, vec2(cx, f.side * JOINT_B), vec2(TUBE_R.y + 0.008, 0.014), BRASS * 0.85, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(TUBE_R.x + 0.004, 0.060), LEATHER, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), BRASS, 1.0);
}

void walnut_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, WALNUT, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float grain = sin(q.y * 160.0 + sin(q.x * 11.0) * 3.0);
	inlay(acc, d, WALNUT * 1.18, smoothstep(0.6, 1.0, grain) * 0.35, f);
	star_chart(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, BRASS, 1.0);
	}
}

// 三脚の上の真鍮の望遠鏡(接眼から対物へ太る筒に、革の帯と真鍮の輪)
void telescope(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (q.x < -0.32 || q.x > 0.30 || q.y < 1.16 || q.y > 1.39) {
		return;
	}
	for (int k = 0; k < 3; k++) {
		vec2 foot = vec2(MOUNT.x + (float(k) - 1.0) * 0.11, FOOT_Y);
		float d_leg = sd_segment(q, MOUNT, foot) - (k == 1 ? 0.007 : 0.009);
		vec3 wood = k == 1 ? WALNUT * 0.7 : WALNUT;
		part(acc, d_leg, ink_of(WALNUT), shade_mat(wood, normalize(vec3(0.2, 0.3, 0.8)), 0.0, 0.6, 1.0), f.ow * 0.8, f.px);
	}
	draw_ball(acc, f, MOUNT, 0.018, BRASS, 1.0);
	vec2 ba = LENS_END - EYE_END;
	vec2 pa = q - EYE_END;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	vec2 axis = normalize(ba);
	vec2 across = vec2(-axis.y, axis.x);
	float radius = mix(TUBE_HALF.x, TUBE_HALF.y, h);
	float off = dot(pa - ba * h, across);
	float d_tube = length(pa - ba * h) - radius;
	float u = clamp(off / radius, -1.0, 1.0);
	vec3 n = normalize(vec3(across * u * 0.9, sqrt(max(1.0 - u * u, 0.0)) + 0.05));
	vec3 body = shade_mat(BRASS, n, 1.0, 1.0, 1.0);
	body = mix(body, shade_mat(LEATHER, n, 0.0, 0.5, 1.0), step(0.38, h) * step(h, 0.60));
	float ring = max(step(abs(h - 0.20), 0.018), step(abs(h - 0.80), 0.022));
	body = mix(body, shade_mat(BRASS * 0.8, n, 1.0, 1.0, 1.0), ring);
	part(acc, d_tube, ink_of(BRASS), body, f.ow, f.px);
	vec2 lq = q - LENS_END;
	float d_lens = sd_ellipse(vec2(dot(lq, axis), dot(lq, across)), vec2(0.010, TUBE_HALF.y - 0.004));
	part(acc, d_lens, ink_of(BRASS), mix(LENS, vec3(1.0), smoothstep(0.0, -0.02, dot(lq, across)) * 0.5), f.ow * 0.6, f.px);
	add_light(acc, vec3(1.0), star4(lq + across * 0.012, 0.055));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - LENS_END - vec2(0.05, 0.03);
	add_light(acc, LENS, exp(-dot(d, d) / 0.006) * 0.45 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	draw_tube_post(acc, f, -POST_X);
	draw_tube_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	walnut_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		telescope(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
