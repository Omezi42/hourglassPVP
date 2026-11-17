shader_type canvas_item;
// 刻の鐘(アワー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 天板は両端の反り上がった瓦屋根、その頂に梵鐘を吊るす。柱は黒漆に若草色の帯、底板に十二刻の目盛り。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 LACQUER = vec3(0.16, 0.14, 0.14);
const vec3 TILE = vec3(0.36, 0.40, 0.42);
const vec3 BRONZE = vec3(0.56, 0.62, 0.42);
const vec3 TRIM = vec3(0.70, 0.80, 0.42);
const float POST_R = 0.048;
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const vec2 BELL = vec2(0.0, 1.245);

void lacquer_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, LACQUER, 0.2);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), TRIM, 0.3);
	draw_band(acc, f, vec2(cx, f.side * 0.62), vec2(0.064, 0.014), TRIM, 0.3);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.068, 0.022), BRONZE, 1.0);
}

// 瓦屋根の天板: 両端が反り上がり、瓦の縦筋
void roof(inout vec4 acc, Px f) {
	vec2 q = vec2(f.p.x, f.p.y - PLATE_Y);
	if (abs(q.x) > 0.96 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	float ax = abs(q.x);
	float lift = 0.10 * smoothstep(0.55, 0.94, ax) * smoothstep(0.55, 0.94, ax);
	float top = 0.060 + lift;
	float bottom = -0.070 + lift * 1.1;
	float d = max(max(q.y - top, bottom - q.y), ax - 0.94);
	float tile = abs(fract(q.x * 14.0) - 0.5);
	vec3 c = mix(TILE * 0.78, TILE * 1.2, smoothstep(0.1, 0.4, tile));
	c = mix(c, TILE * 0.6, smoothstep(0.0, -0.05, q.y - bottom - 0.03));
	part(acc, d, vec3(0.06), c, f.ow, f.px);
	// 棟の縁
	float ridge = max(abs(q.y - top + 0.012) - 0.014, ax - 0.93);
	part(acc, ridge, vec3(0.06), TILE * 1.35, f.ow * 0.7, f.px);
}

void base_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, LACQUER, 0.2, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 十二刻の目盛り
	float tick = step(abs(fract(q.x / 0.12 + 0.5) - 0.5), 0.06) * step(abs(q.y), 0.030) * step(abs(q.x), 0.70);
	inlay(acc, d, TRIM, tick, f);
	inlay(acc, d, TRIM * 0.8, (1.0 - smoothstep(0.0, max(0.006, f.px), abs(abs(q.y) - 0.056) - 0.004)) * step(abs(q.x), 0.76), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.030, f.px), f);
}

// 梵鐘: 竜頭の吊り輪、乳の粒、撞座
void temple_bell(inout vec4 acc, Px f) {
	vec2 q = (f.p - BELL) / 1.2;
	if (abs(q.x) > 0.11 + f.pad || abs(q.y) > 0.14 + f.pad) {
		return;
	}
	f.px /= 1.2;
	f.ow /= 1.2;
	float yy = clamp((0.075 - q.y) / 0.15, 0.0, 1.0);
	float hw = mix(0.060, 0.085, yy) * (yy < 0.08 ? sqrt(yy / 0.08) * 0.4 + 0.6 : 1.0);
	float d = max(abs(q.x) - hw, max(q.y - 0.075, -q.y - 0.075));
	vec3 n = normalize(vec3(q.x / hw * 0.8, 0.1, 0.6));
	vec3 c = shade_mat(BRONZE, n, 1.0, 0.9, 1.0);
	// 乳(上の段の粒)と帯
	vec2 nq = vec2(fract(q.x / 0.024) - 0.5, (q.y - 0.040) / 0.024);
	c = mix(c, c * 1.25, step(length(nq), 0.32) * step(abs(q.y - 0.040), 0.024));
	c = mix(c, c * 0.72, step(abs(q.y + 0.010), 0.005) + step(abs(q.y + 0.055), 0.005));
	part(acc, d, ink_of(BRONZE), c, f.ow, f.px);
	// 撞座と、竜頭の吊り輪
	over(acc, mix(sand_color, BRONZE, 0.3), cov(length(q - vec2(0.0, -0.032)) - 0.016, f.px));
	float d_loop = max(abs(length(q - vec2(0.0, 0.098)) - 0.022) - 0.008, -(q.y - 0.084));
	part(acc, d_loop, ink_of(BRONZE), BRONZE, f.ow * 0.7, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	lacquer_post(acc, f, -POST_X);
	lacquer_post(acc, f, POST_X);
	draw_collars(acc, f, BRONZE, 1.0);
	if (f.p.y > 0.0) {
		roof(acc, f);
		temple_bell(acc, f);
	} else {
		base_slab(acc, f, -PLATE_Y);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
