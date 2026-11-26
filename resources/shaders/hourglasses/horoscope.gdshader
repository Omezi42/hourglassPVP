shader_type canvas_item;
// 天宮図(ホロスコープ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は金の星を散らした夜の黒漆、板は黒漆に金の縁と深い藍の帯・銀の星図の線。
// 天板の上の台に金の渾天儀が据わり、傾いた黄道の輪の中で小さな藍の天球が光る。

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
const vec3 LACQUER = vec3(0.10, 0.10, 0.17);
const vec3 GILT = vec3(0.96, 0.76, 0.34);
const vec3 GLOBE = vec3(0.18, 0.26, 0.66);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.056;
// 渾天儀の中心・半径・輪の太さ、黄道の輪の傾き
const vec2 SPHERE = vec2(0.0, 1.284);
const float SPHERE_R = 0.074;
const float RING_W = 0.0065;
const float ECLIPTIC_TILT = 0.42;

void lacquer_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, LACQUER, 0.2);
	float lx = f.p.x - cx;
	if (abs(lx) < POST_R && f.ay < POST_H - 0.08) {
		vec2 cell = vec2(floor(f.p.y / 0.11), cx);
		float y = (floor(f.p.y / 0.11) + 0.5) * 0.11;
		vec2 s = vec2(lx - (hash21(cell) - 0.5) * POST_R, f.p.y - y);
		over(acc, GILT, cov(length(s) - 0.007, f.px));
		add_light(acc, GILT, star4(s, 0.024) * 0.7);
	}
	for (int k = 0; k < 2; k++) {
		draw_band(acc, f, vec2(cx, f.side * (0.30 + 0.40 * float(k))), vec2(POST_R + 0.006, 0.010), GILT, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), GILT, 1.0);
}

void lacquer_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, LACQUER, 0.2, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = sd_round_box(q, SLAB_HALF - vec2(0.020, 0.016), 0.02);
	inlay(acc, d, GILT, cov(abs(rim) - 0.004, f.px), f);
	star_chart(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.022, GILT, 1.0);
	}
}

float ring_d(vec2 q, float tilt, vec2 radii) {
	vec2 r = rot(q, tilt);
	return abs(sd_ellipse(r, radii)) - RING_W;
}

// 台の上の金の渾天儀(子午線の輪・赤道の輪・傾いた黄道の輪と、芯の天球)
void armillary(inout vec4 acc, Px f) {
	vec2 q = f.p - SPHERE;
	if (abs(q.x) > 0.16 || q.y < -0.12 || q.y > 0.10) {
		return;
	}
	vec3 gilt = shade_mat(GILT, normalize(vec3(0.2, 0.4, 0.8)), 1.0, 1.0, 1.0);
	float d_stem = sd_segment(f.p, vec2(0.0, 1.190), vec2(0.0, SPHERE.y - SPHERE_R)) - 0.010;
	float d_foot = sd_ellipse(f.p - vec2(0.0, 1.196), vec2(0.060, 0.014));
	part(acc, min(d_stem, d_foot), ink_of(GILT), gilt * 0.9, f.ow * 0.8, f.px);
	vec3 n = normalize(vec3(q / SPHERE_R * 0.5, 0.8));
	float d_globe = length(q) - 0.026;
	vec3 globe = shade_mat(GLOBE, n, 0.0, 1.0, 1.0);
	globe = mix(globe, CHART, step(0.86, hash21(floor(q * 220.0))) * 0.8);
	part(acc, d_globe, ink_of(GLOBE), globe, f.ow * 0.7, f.px);
	float d_rings = min(abs(length(q) - SPHERE_R) - RING_W, ring_d(q, 0.0, vec2(SPHERE_R, SPHERE_R * 0.26)));
	d_rings = min(d_rings, ring_d(q, 0.0, vec2(SPHERE_R * 0.30, SPHERE_R)));
	part(acc, d_rings, ink_of(GILT), gilt, f.ow * 0.7, f.px);
	float d_ecl = ring_d(q, ECLIPTIC_TILT, vec2(SPHERE_R * 1.02, SPHERE_R * 0.40)) - 0.004;
	vec3 band = mix(gilt, shade_mat(GILT * 1.1, n, 1.0, 1.0, 1.0), 0.5);
	part(acc, d_ecl, ink_of(GILT), band, f.ow * 0.7, f.px);
	vec2 sun = rot(vec2(SPHERE_R * 1.02, 0.0), -ECLIPTIC_TILT) * vec2(0.72, 1.0) + vec2(0.0, 0.020);
	add_light(acc, vec3(1.0, 0.95, 0.80), star4(q - sun, 0.040));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - SPHERE;
	add_light(acc, GILT, exp(-dot(d, d) / 0.008) * 0.40 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	lacquer_post(acc, f, -POST_X);
	lacquer_post(acc, f, POST_X);
	draw_collars(acc, f, GILT, 1.0);
	lacquer_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		armillary(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
