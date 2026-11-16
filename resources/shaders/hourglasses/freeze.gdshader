shader_type canvas_item;
// 凍てつき(フリーズ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 霜の付いた氷の柱、雪を被った板から氷柱が垂れる。天板の上に雪の結晶。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 ICE = vec3(0.66, 0.80, 0.96);
const vec3 ICE_DEEP = vec3(0.36, 0.48, 0.80);
const vec3 ICE_INK = vec3(0.16, 0.22, 0.44);
const vec3 SNOW = vec3(0.96, 0.98, 1.0);
const float POST_R = 0.058;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 FLAKE = vec2(0.0, 1.262);

void ice_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float r = POST_R * (0.85 + 0.15 * vnoise(vec2(f.p.y * 6.0, cx)));
	float d = max(abs(lx) - r, f.ay - POST_H);
	float u = clamp(lx / r, -1.0, 1.0);
	vec3 c = mix(ICE_DEEP, ICE, smoothstep(0.8, -0.6, u));
	// 中の割れ筋と霜
	float vein = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(lx - 0.02 * sin(f.p.y * 7.0 + cx)) - 0.003);
	c = mix(c, SNOW, vein * 0.5 * smoothstep(0.03, 0.012, f.px));
	c = mix(c, SNOW, smoothstep(0.6, 0.85, vnoise(f.p * 30.0)) * 0.4);
	part(acc, d, ICE_INK, c, f.ow, f.px);
	over(acc, vec3(1.0), (1.0 - smoothstep(0.0, max(0.006, f.px), abs(u + 0.55) * r - 0.007)) * 0.8 * cov(d, f.px));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), ICE_DEEP, 0.4);
}

void snow_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || q.y > SLAB_HALF.y + 0.05 + f.pad || q.y < -SLAB_HALF.y - 0.14 - f.pad) {
		return;
	}
	float d = sd_round_box(q, SLAB_HALF, 0.03);
	// 下の縁から垂れる氷柱
	float cell = floor(q.x / 0.09 + 0.5);
	float dx = q.x - cell * 0.09;
	float len = 0.04 + 0.08 * hash21(vec2(cell, cy));
	float t = clamp((-SLAB_HALF.y - q.y) / len, 0.0, 1.0);
	float d_icicle = max(abs(dx) - 0.022 * (1.0 - t), max(q.y + SLAB_HALF.y - 0.01, -SLAB_HALF.y - len - q.y));
	d_icicle = max(d_icicle, abs(q.x) - 0.74);
	d = min(d, d_icicle);
	float v = q.y / SLAB_HALF.y;
	vec3 c = mix(ICE_DEEP, ICE, smoothstep(-1.0, 0.6, v));
	part(acc, d, ICE_INK, c, f.ow, f.px);
	// 上に積もった雪
	float cap = max(abs(q.x) - SLAB_HALF.x + 0.01, max(SLAB_HALF.y - 0.025 - q.y, q.y - SLAB_HALF.y - 0.035 * (0.6 + 0.4 * vnoise(vec2(q.x * 8.0, cy)))));
	part(acc, cap, ICE_INK, mix(SNOW * 0.9, SNOW, smoothstep(0.0, 0.04, q.y - SLAB_HALF.y)), f.ow * 0.8, f.px);
	vec3 gn = normalize(vec3(q / 0.04 * 0.6, 0.8));
	part(acc, sd_rhombus(q, vec2(0.040, 0.046)), ICE_INK, shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
}

// 6本の枝の雪の結晶
void snowflake(inout vec4 acc, Px f) {
	vec2 q = f.p - FLAKE;
	if (length(q) > 0.13 + f.pad) {
		return;
	}
	float a = atan(q.y, q.x);
	float sector = 6.2832 / 6.0;
	float sa = mod(a + 1.5708 + sector * 0.5, sector) - sector * 0.5;
	vec2 lq = vec2(sin(sa), cos(sa)) * length(q);
	float d = sd_segment(lq, vec2(0.0), vec2(0.0, 0.11)) - 0.012;
	d = min(d, sd_segment(vec2(abs(lq.x), lq.y), vec2(0.0, 0.065), vec2(0.035, 0.095)) - 0.008);
	d = min(d, length(q) - 0.028);
	part(acc, d, ICE_INK, mix(SNOW, ICE, smoothstep(0.0, 0.11, length(q))), f.ow * 0.8, f.px);
	over(acc, sand_color, cov(length(q) - 0.014, f.px));
}

void art_back(inout vec4 acc, Px f) {
	add_light(acc, ICE, exp(-dot(f.p - FLAKE, f.p - FLAKE) / 0.02) * 0.5 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	ice_post(acc, f, -POST_X);
	ice_post(acc, f, POST_X);
	draw_collars(acc, f, ICE_DEEP, 0.4);
	snow_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y + 0.04) {
		snowflake(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
