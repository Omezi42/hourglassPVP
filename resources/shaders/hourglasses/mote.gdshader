shader_type canvas_item;
// ひと粒(モート)。GameDesign.md 9章 / Architecture.md 10.19節。
// いちばん小さな器: 銀の細い針金の柱と薄い板だけ。天板の上にひと粒の砂がきらめく。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const float WIRE_X = 0.64;
const float WIRE_R = 0.020;
const vec2 SLAB_HALF = vec2(0.72, 0.060);
const vec2 SPECK = vec2(0.0, 1.250);

// 針金を2本撚った細い柱と、要所の玉
void wire_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.06 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - WIRE_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / WIRE_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(SILVER, n, 1.0, 1.0, f.ao);
	float twist = abs(fract((f.p.y + lx * 1.2) * 14.0) - 0.5);
	c = mix(c * 0.72, c, smoothstep(0.05, 0.25, twist));
	part(acc, d, ink_of(SILVER), c, f.ow * 0.8, f.px);
	draw_ball(acc, f, vec2(cx, 0.0), 0.040, SILVER, 1.0);
	draw_ball(acc, f, vec2(cx, f.side * 0.50), 0.028, mix(SILVER, sand_color, 0.35), 0.8);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.060, 0.020), SILVER, 1.0);
}

void thin_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, SILVER, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 点を並べた細い線と、中央の砂の色の小粒
	float dots = step(length(vec2(fract(q.x / 0.08) - 0.5, q.y / 0.08)), 0.18);
	inlay(acc, d, SILVER * 0.6, dots * step(0.08, abs(q.x)) * step(abs(q.x), 0.66), f);
	vec3 gn = normalize(vec3(q / 0.03 * 0.6, 0.8));
	part(acc, length(q) - 0.028, ink_of(SILVER), shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.6, f.px);
}

// 天板の上の小さな台と、その上に浮くひと粒
void speck(inout vec4 acc, Px f) {
	draw_band(acc, f, vec2(0.0, 1.150), vec2(0.060, 0.016), SILVER, 1.0);
	draw_column(acc, f, 0.0, 0.010, 1.150, 1.205, SILVER, 1.0);
	vec2 q = f.p - SPECK;
	vec3 n = normalize(vec3(q / 0.045 * 0.6, 0.8));
	part(acc, length(q) - 0.044, ink_of(sand_color), shade_mat(sand_color, n, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
}

// ひと粒のきらめき
void art_back(inout vec4 acc, Px f) {
	add_light(acc, mix(sand_color, vec3(1.0), 0.5), star4(f.p - SPECK, 0.26) * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	wire_post(acc, f, -WIRE_X);
	wire_post(acc, f, WIRE_X);
	draw_collars(acc, f, SILVER, 1.0);
	thin_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		speck(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
