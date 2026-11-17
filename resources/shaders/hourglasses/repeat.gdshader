shader_type canvas_item;
// 繰り返し(リピート)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱に楽譜の反復記号を刻み、板は五線。天板の上に針を下ろしたレコード盤。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 IVORY = vec3(0.92, 0.88, 0.80);
const vec3 EBONY = vec3(0.12, 0.11, 0.13);
const vec3 VINYL = vec3(0.10, 0.09, 0.11);
const vec3 WALNUT = vec3(0.46, 0.30, 0.18);
const float POST_HALF = 0.056;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 DISC = vec2(0.0, 1.225);

// 反復記号を縦に並べた象牙の柱
void repeat_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(IVORY, n, 0.0, 0.7, f.ao);
	float span = 0.34;
	float ly = fract((f.p.y + 0.85) / span) * span - span * 0.5;
	float bars = step(abs(ly - 0.050), 0.012) + step(abs(ly - 0.012), 0.005);
	float dots = step(length(vec2(lx - 0.016, ly + 0.050)), 0.011) + step(length(vec2(lx + 0.016, ly + 0.050)), 0.011);
	float mark = min(bars + dots, 1.0) * step(abs(lx), 0.040) * step(abs(f.p.y), 0.80);
	c = mix(c, EBONY, mark);
	part(acc, d, ink_of(IVORY * 0.6), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), EBONY, 0.3);
}

void staff_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, EBONY, 0.3, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float line = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.7), abs(fract(q.y / 0.020 + 0.5) - 0.5) * 0.020 - 0.002);
	inlay(acc, d, IVORY * 0.8, line * step(abs(q.y), 0.042) * step(abs(q.x), 0.76), f);
	// 両端の反復記号と、真ん中の砂の色の音符
	for (int s = -1; s <= 1; s += 2) {
		vec2 rq = vec2(q.x * float(s) - 0.66, q.y);
		float bar = step(abs(rq.x - 0.040), 0.010) + step(abs(rq.x - 0.016), 0.004);
		float dots = step(length(rq - vec2(-0.010, 0.010)), 0.008) + step(length(rq - vec2(-0.010, -0.010)), 0.008);
		inlay(acc, d, IVORY, min(bar * step(abs(q.y), 0.042) + dots, 1.0), f);
	}
	inlay(acc, d, sand_color, cov(sd_ellipse(q - vec2(-0.010, -0.010), vec2(0.024, 0.018)), f.px), f);
	inlay(acc, d, sand_color, step(abs(q.x - 0.012), 0.004) * step(-0.012, q.y) * step(q.y, 0.044), f);
}

// レコード盤: 斜めから見た黒い盤、溝の光、砂の色のラベル、トーンアーム
void record_disc(inout vec4 acc, Px f) {
	vec2 q = f.p - DISC;
	if (abs(q.x) > 0.26 + f.pad || abs(q.y) > 0.15 + f.pad) {
		return;
	}
	vec2 eq = q / vec2(1.0, 0.55);
	float r = length(eq);
	float d_plinth = sd_round_box(q - vec2(0.0, -0.040), vec2(0.215, 0.045), 0.016);
	part(acc, d_plinth, ink_of(EBONY), shade_mat(WALNUT, normalize(vec3(0.0, 0.4, 0.8)), 0.0, 0.6, 1.0), f.ow, f.px);
	float grooves = 0.5 + 0.5 * sin(r * 260.0);
	float sheen = smoothstep(0.5, 1.0, cos(atan(eq.y, eq.x) * 2.0 - 0.6));
	vec3 vc = mix(VINYL, VINYL * 2.2, grooves * 0.3 * smoothstep(0.03, 0.012, f.px)) + vec3(0.45) * sheen * 0.35;
	part(acc, (r - 0.175) * 0.55, vec3(0.02), vc, f.ow, f.px);
	over(acc, sand_color, cov((r - 0.060) * 0.55, f.px));
	over(acc, IVORY, cov((r - 0.012) * 0.55, f.px));
	// トーンアーム
	float d_arm = sd_segment(q, vec2(0.200, 0.075), vec2(0.090, -0.020)) - 0.008;
	part(acc, d_arm, vec3(0.05), SILVER, f.ow * 0.6, f.px);
	draw_ball(acc, f, DISC + vec2(0.200, 0.075), 0.020, SILVER, 1.0);
	part(acc, sd_round_box(rot(q - vec2(0.085, -0.025), 0.7), vec2(0.022, 0.012), 0.004), vec3(0.05), EBONY, f.ow * 0.6, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	repeat_post(acc, f, -POST_X);
	repeat_post(acc, f, POST_X);
	draw_collars(acc, f, EBONY, 0.3);
	staff_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		record_disc(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
