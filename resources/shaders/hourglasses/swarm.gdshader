shader_type canvas_item;
// 群れの巣(スウォーム)。GameDesign.md 9章 / Architecture.md 10.19節。
// 板と柱は六角の巣房を刻んだ蜜蝋色、天板の上と柱のまわりに小さな蜂の群れ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 WAX = vec3(0.86, 0.66, 0.26);
const vec3 WAX_DARK = vec3(0.56, 0.36, 0.12);
const vec3 BEE_BODY = vec3(0.98, 0.80, 0.22);
const vec3 BEE_INK = vec3(0.10, 0.08, 0.06);
const float POST_R = 0.060;
const vec2 SLAB_HALF = vec2(0.82, 0.088);

// 六角の巣房: 戻り値は房の縁からの距離(0=縁)
float hex_cells(vec2 p, float size) {
	vec2 s = vec2(1.0, 1.7320508);
	vec2 a = mod(p / size, s) - s * 0.5;
	vec2 b = mod(p / size - s * 0.5, s) - s * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 h = abs(g);
	return (0.5 - max(h.x * 0.866 + h.y * 0.5, h.y)) * size;
}

vec3 comb_color(vec2 p, vec3 base, float px) {
	float e = hex_cells(p, 0.060);
	float fine = smoothstep(0.03, 0.012, px);
	vec3 c = mix(base * 0.62, base, smoothstep(0.004, 0.012, e) * fine + (1.0 - fine) * 0.8);
	// 房の中の蜜の照り
	return mix(c, mix(base, sand_color, 0.55), smoothstep(0.020, 0.032, e) * 0.5 * fine);
}

void comb_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + 0.03 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = comb_color(f.p, WAX, f.px) * (0.75 + 0.35 * clamp(dot(n, LIGHT_DIR), 0.0, 1.0)) * f.ao;
	part(acc, d, ink_of(WAX_DARK), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.086, 0.028), WAX_DARK, 0.6);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.078, 0.020), WAX_DARK, 0.6);
}

void comb_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.04, WAX, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	inlay(acc, d, comb_color(q + vec2(0.0, cy * 3.0), WAX, f.px), 1.0, f);
	// 板から垂れる蜜
	if (cy > 0.0) {
		float drip_x = abs(fract(q.x * 2.2 + 0.3) - 0.5) / 2.2;
		float len = 0.02 + 0.04 * hash21(vec2(floor(q.x * 2.2 + 0.3), 2.0));
		float d_drip = max(drip_x - 0.016, max(q.y + SLAB_HALF.y + len, -(q.y + SLAB_HALF.y - 0.01)));
		d_drip = min(d_drip, length(vec2(drip_x, q.y + SLAB_HALF.y + len)) - 0.020);
		over(acc, mix(sand_color, WAX, 0.35), cov(d_drip, f.px) * step(abs(q.x), 0.74));
	}
}

// 蜂1匹。dir は向き(-1/1)
void bee(inout vec4 acc, Px f, vec2 c, float s, float dir) {
	vec2 q = (f.p - c) / s;
	q.x *= dir;
	float ps = f.px / s;
	if (abs(q.x) > 1.4 + ps * 3.0 || abs(q.y) > 1.3 + ps * 3.0) {
		return;
	}
	float ow = f.ow / s * 0.6;
	// 翅(半透明)
	for (int k = 0; k < 2; k++) {
		vec2 wq = rot(q - vec2(-0.15 - 0.35 * float(k), 0.55), 0.5 - 0.4 * float(k));
		float dw = sd_ellipse(wq, vec2(0.30, 0.55));
		over(acc, BEE_INK, cov(dw - ow, ps) - cov(dw, ps));
		over(acc, vec3(0.92, 0.97, 1.0), cov(dw, ps) * 0.75);
	}
	float d_body = sd_ellipse(q, vec2(1.0, 0.62));
	float stripe = step(0.5, fract(q.x * 1.6 + 0.2)) * step(-0.6, q.x);
	vec3 col = mix(BEE_BODY, BEE_INK, stripe * 0.9);
	col *= 0.8 + 0.25 * smoothstep(-0.5, 0.5, q.y);
	part(acc, d_body, BEE_INK, col, ow, ps);
	over(acc, BEE_INK, cov(length(q - vec2(1.0, 0.05)) - 0.38, ps));
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	comb_post(acc, f, -POST_X);
	comb_post(acc, f, POST_X);
	draw_collars(acc, f, WAX_DARK, 0.6);
	comb_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > 0.2) {
		bee(acc, f, vec2(-0.24, 1.27), 0.070, 1.0);
		bee(acc, f, vec2(0.05, 1.31), 0.060, -1.0);
		bee(acc, f, vec2(0.34, 1.26), 0.066, -1.0);
		bee(acc, f, vec2(-0.88, 0.66), 0.058, 1.0);
		bee(acc, f, vec2(0.89, 0.30), 0.058, -1.0);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
