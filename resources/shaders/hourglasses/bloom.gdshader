shader_type canvas_item;
// 開花(ブルーム)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱に蕾の付いた蔓が巻きつき、板は花びらの象嵌。天板の上に大きく開いた花と、飛び立つ2粒の種。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BIRCH = vec3(0.90, 0.88, 0.80);
const vec3 VINE = vec3(0.30, 0.54, 0.30);
const vec3 PETAL = vec3(0.98, 0.78, 0.86);
const vec3 POLLEN = vec3(1.0, 0.86, 0.36);
const float POST_R = 0.046;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 FLOWER = vec2(0.0, 1.215);
const float FLOWER_K = 1.2;

void vine_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	part(acc, d, ink_of(BIRCH * 0.6), shade_mat(BIRCH, n, 0.0, 0.6, f.ao), f.ow, f.px);
	float ph = f.p.y * 1.6 * 6.2832 + cx * 2.0;
	float rx = 0.060 * sin(ph);
	float front = cos(ph);
	float d_vine = max(abs(lx - rx) - 0.010, f.ay - POST_H + 0.06);
	if (front > -0.2) {
		part(acc, d_vine, ink_of(VINE), mix(VINE * 0.8, VINE * 1.2, 0.5 + 0.5 * front), f.ow * 0.5, f.px);
	}
	// 蔓の外側の頂点に付く蕾
	float k = floor(f.p.y * 1.6 + 0.25 + cx);
	float by = (k - 0.25 - cx) / 1.6;
	for (int s = 0; s < 2; s++) {
		float yy = by + float(s) / 1.6;
		float bph = yy * 1.6 * 6.2832 + cx * 2.0;
		vec2 bc = vec2(cx + 0.060 * sin(bph), yy);
		if (abs(yy) < POST_H - 0.08) {
			vec2 bq = f.p - bc;
			part(acc, sd_ellipse(bq, vec2(0.020, 0.026)), ink_of(PETAL), mix(PETAL, sand_color, 0.35 + 0.3 * step(0.0, bq.y)), f.ow * 0.5, f.px);
		}
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), VINE, 0.0);
}

void petal_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, BIRCH, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	for (int k = -3; k <= 3; k++) {
		vec2 fq = q - vec2(float(k) * 0.21, 0.0);
		float a = atan(fq.y, fq.x);
		float r = length(fq);
		float petals = 0.034 * (0.6 + 0.4 * abs(cos(a * 2.5)));
		vec3 c = k == 0 ? sand_color : mix(PETAL, VINE, 0.15 * float(abs(k) % 2));
		inlay(acc, d, c, cov(r - petals, f.px), f);
		inlay(acc, d, POLLEN, cov(r - 0.010, f.px), f);
	}
}

// 大きく開いた花: 外の花びら5枚、内の花びら5枚、花芯、萼と葉
void open_flower(inout vec4 acc, Px f) {
	vec2 q = (f.p - FLOWER) / FLOWER_K;
	if (abs(q.x) > 0.24 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= FLOWER_K;
	f.ow /= FLOWER_K;
	for (int s = -1; s <= 1; s += 2) {
		vec2 lq = rot(q - vec2(float(s) * 0.110, -0.075), float(s) * 1.1);
		part(acc, sd_ellipse(lq, vec2(0.022, 0.060)), ink_of(VINE), mix(VINE, VINE * 1.3, step(0.0, lq.x)), f.ow * 0.6, f.px);
	}
	vec2 fq = q / vec2(1.0, 0.78);
	float a = atan(fq.y, fq.x);
	float r = length(fq);
	float outer = 0.120 * (0.62 + 0.38 * pow(abs(cos(a * 2.5)), 0.6));
	vec3 n = normalize(vec3(fq / 0.12 * 0.5, 0.8));
	part(acc, (r - outer) * 0.78, ink_of(PETAL), shade_mat(PETAL, n, 0.0, 0.7, 1.0), f.ow, f.px);
	float inner = 0.075 * (0.62 + 0.38 * pow(abs(cos(a * 2.5 + 1.57)), 0.6));
	part(acc, (r - inner) * 0.78, ink_of(PETAL), shade_mat(mix(PETAL, sand_color, 0.55), n, 0.0, 0.7, 1.0), f.ow * 0.7, f.px);
	part(acc, length(q) - 0.026, ink_of(POLLEN), shade_mat(POLLEN, normalize(vec3(q / 0.026 * 0.6, 0.75)), 0.0, 0.8, 1.0), f.ow * 0.6, f.px);
	// 飛び立つ2粒の種
	for (int s = -1; s <= 1; s += 2) {
		vec2 sc = vec2(float(s) * 0.160, 0.060);
		vec2 sq = q - sc;
		float d_fluff = abs(length(sq - vec2(0.0, 0.012)) - 0.022) - 0.003;
		d_fluff = max(d_fluff, -sq.y + 0.004);
		part(acc, d_fluff, ink_of(BIRCH), vec3(0.98), f.ow * 0.3, f.px);
		part(acc, length(sq) - 0.010, ink_of(sand_color), sand_color, f.ow * 0.4, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - FLOWER;
	add_light(acc, mix(PETAL, sand_color, 0.4), exp(-dot(q, q) / 0.014) * 0.35);
}

void art_frame(inout vec4 acc, Px f) {
	vine_post(acc, f, -POST_X);
	vine_post(acc, f, POST_X);
	draw_collars(acc, f, VINE, 0.0);
	petal_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		open_flower(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
