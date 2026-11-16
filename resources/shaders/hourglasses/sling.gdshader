shader_type canvas_item;
// 投石器(スリング)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は革紐を巻いた木、天板の上に二股の投石器が立ち、引き絞ったゴムに小石を挟む。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 WOOD = vec3(0.62, 0.44, 0.26);
const vec3 LEATHER = vec3(0.40, 0.26, 0.16);
const vec3 BAND = vec3(0.30, 0.62, 0.56);
const vec3 STONE = vec3(0.66, 0.64, 0.60);
const float POST_R = 0.048;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 FORK = vec2(0.0, 1.17);

void wrapped_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(WOOD, n, 0.0, 0.6, f.ao);
	// 中ほどを革紐で巻く
	float wrap_zone = step(f.ay, 0.34);
	float wrap = step(0.5, fract((f.p.y - lx * 0.9) * 9.0));
	c = mix(c, shade_mat(mix(LEATHER, LEATHER * 1.3, wrap), n, 0.0, 0.5, f.ao), wrap_zone);
	part(acc, d, ink_of(LEATHER), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), LEATHER, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.36), vec2(0.064, 0.014), BAND, 0.0);
}

void wood_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, WOOD, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 革の帯と、小石の的
	inlay(acc, d, LEATHER, step(abs(q.y), 0.034) * step(abs(q.x), 0.76), f);
	float stitch = step(abs(fract(q.x * 14.0) - 0.5), 0.18) * step(abs(abs(q.y) - 0.024), 0.004);
	inlay(acc, d, vec3(0.86, 0.78, 0.62), stitch * step(abs(q.x), 0.74), f);
	float ring = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.7), abs(length(q) - 0.042) - 0.007);
	inlay(acc, d, BAND, ring, f);
	inlay(acc, d, sand_color, cov(length(q) - 0.020, f.px), f);
}

// 二股の投石器と、引き絞ったゴム、挟んだ小石
void slingshot(inout vec4 acc, Px f) {
	vec2 q = f.p - FORK;
	if (abs(q.x) > 0.20 + f.pad || q.y < -f.pad || q.y > 0.23 + f.pad) {
		return;
	}
	vec2 tip_l = vec2(-0.14, 0.165);
	vec2 tip_r = vec2(0.14, 0.165);
	float d_handle = sd_segment(q, vec2(0.0, 0.0), vec2(0.0, 0.07)) - 0.024;
	float d_l = sd_segment(q, vec2(0.0, 0.06), tip_l) - 0.020;
	float d_r = sd_segment(q, vec2(0.0, 0.06), tip_r) - 0.020;
	float d = min(d_handle, min(d_l, d_r));
	vec3 n = normalize(vec3(sign(q.x) * 0.2, 0.3, 0.9));
	part(acc, d, ink_of(WOOD), shade_mat(WOOD, n, 0.0, 0.7, 1.0), f.ow, f.px);
	// ゴム: 両先から手前の革当てへ
	vec2 pouch = vec2(0.0, 0.105);
	float d_band = min(sd_segment(q, tip_l, pouch), sd_segment(q, tip_r, pouch)) - 0.008;
	part(acc, d_band, ink_of(BAND), BAND, f.ow * 0.6, f.px);
	vec3 sn = normalize(vec3((q - pouch) / 0.04 * 0.6, 0.75));
	part(acc, length(q - pouch) - 0.036, ink_of(STONE), shade_mat(mix(STONE, sand_color, 0.3), sn, 0.0, 0.8, 1.0), f.ow * 0.8, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	wrapped_post(acc, f, -POST_X);
	wrapped_post(acc, f, POST_X);
	draw_collars(acc, f, LEATHER, 0.0);
	wood_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		slingshot(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
