shader_type canvas_item;
// ルーン石(ルーン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は石を積んだ立石で、ところどころに刻んだ文字が菫の光を灯す。板は花崗岩に深い藍の帯と銀の星図の線。
// 天板の上に頭の丸いルーン石が立ち、刻んだ文字が菫色に光る。両脇に小石。

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
const vec3 STONE = vec3(0.56, 0.56, 0.60);
const vec3 GRANITE = vec3(0.46, 0.46, 0.50);
const vec3 RUNE_LIGHT = vec3(0.70, 0.56, 1.0);
const vec3 RUNE_HOT = vec3(0.94, 0.90, 1.0);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.064;
const float COURSE = 0.204;
// ルーン石の中心・半幅・半分の高さ
const vec2 TABLET = vec2(0.0, 1.276);
const vec2 TABLET_HALF = vec2(0.098, 0.088);

// 刻んだ1文字(縦の幹から右上へ2本の枝)。s は大きさ
float glyph(vec2 q, float s) {
	q /= s;
	float d = sd_segment(q, vec2(-0.012, -0.046), vec2(-0.012, 0.046));
	d = min(d, sd_segment(q, vec2(-0.012, 0.044), vec2(0.026, 0.020)));
	d = min(d, sd_segment(q, vec2(-0.012, 0.010), vec2(0.026, -0.014)));
	return d * s;
}

void carve(inout vec4 acc, Px f, vec2 q, float s, float a) {
	float d = glyph(q, s) - 0.0075 * s;
	over(acc, ink_of(STONE) * 0.6, cov(d - 0.004, f.px) * a);
	over(acc, mix(RUNE_LIGHT, RUNE_HOT, 0.35), cov(d, f.px) * a);
	add_light(acc, RUNE_LIGHT, exp(-dot(q, q) / (0.0035 * s * s)) * 0.45 * a);
}

void standing_stone(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + 0.03 || f.ay > POST_H + f.pad) {
		return;
	}
	float wobble = (vnoise(vec2(f.p.y * 9.0, cx * 3.0)) - 0.5) * 0.010;
	float d = max(abs(lx) - POST_R - wobble, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 stone = STONE * (0.86 + 0.24 * vnoise(f.p * 40.0));
	part(acc, d, ink_of(STONE), shade_mat(stone, n, 0.0, 0.15, f.ao), f.ow, f.px);
	float joint = abs(fract(f.p.y / COURSE + 0.5) - 0.5) * COURSE;
	over(acc, ink_of(STONE), cov(joint - 0.004, f.px) * cov(d + 0.006, f.px) * 0.7);
	for (int k = 0; k < 2; k++) {
		float y = 0.42 + 0.30 * float(k);
		carve(acc, f, vec2(lx, f.p.y - f.side * y), 0.9, cov(d + 0.01, f.px));
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), STONE * 0.8, 0.0);
}

void granite_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, GRANITE, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float speck = step(0.86, hash21(floor(q * 130.0)));
	inlay(acc, d, mix(GRANITE * 0.6, vec3(0.9), step(0.5, hash21(floor(q * 130.0) + 7.0))), speck * 0.5, f);
	star_chart(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, RUNE_LIGHT, 0.0);
	}
}

// 頭の丸いルーン石と両脇の小石
void rune_tablet(inout vec4 acc, Px f) {
	vec2 q = f.p - TABLET;
	if (abs(q.x) > 0.26 || q.y < -0.10 || q.y > 0.10) {
		return;
	}
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		vec2 pq = f.p - vec2(sx * (0.168 + 0.012 * float(k)), 1.206 - 0.004 * float(k));
		float d_peb = sd_ellipse(pq, vec2(0.038 - 0.008 * float(k), 0.022));
		vec3 n = normalize(vec3(pq / 0.04 * 0.6, 0.8));
		part(acc, d_peb, ink_of(STONE), shade_mat(STONE * 0.9, n, 0.0, 0.2, 1.0), f.ow * 0.8, f.px);
	}
	float top_r = TABLET_HALF.x;
	vec2 bq = q - vec2(0.0, -0.02);
	float d_body = sd_round_box(bq, vec2(TABLET_HALF.x, TABLET_HALF.y - 0.02), 0.012);
	float d_head = length(q - vec2(0.0, TABLET_HALF.y - top_r)) - top_r;
	float d = min(d_body, max(d_head, -(q.y - 0.0)));
	vec3 n = normalize(vec3(clamp(q.x / TABLET_HALF.x, -1.0, 1.0) * 0.6, smoothstep(0.02, TABLET_HALF.y, q.y) * 0.5, 0.75));
	vec3 stone = STONE * (0.88 + 0.22 * vnoise(f.p * 46.0));
	part(acc, d, ink_of(STONE), shade_mat(stone, n, 0.0, 0.15, 1.0), f.ow, f.px);
	carve(acc, f, q - vec2(0.0, 0.004), 1.45, cov(d + 0.01, f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - TABLET;
	add_light(acc, RUNE_LIGHT, exp(-dot(d, d) / 0.010) * 0.55 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	standing_stone(acc, f, -POST_X);
	standing_stone(acc, f, POST_X);
	draw_collars(acc, f, STONE * 0.85, 0.0);
	granite_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		rune_tablet(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
