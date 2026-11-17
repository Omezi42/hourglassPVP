shader_type canvas_item;
// 救い(リリーフ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は包帯を巻いた白木、板には薬草の浮き彫り。天板の上に月桂樹の葉で囲んだ心臓の印。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 ASH = vec3(0.84, 0.78, 0.66);
const vec3 LINEN = vec3(0.96, 0.94, 0.90);
const vec3 CROSS = vec3(0.80, 0.22, 0.24);
const vec3 LAUREL = vec3(0.40, 0.58, 0.34);
const float POST_R = 0.048;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 HEART = vec2(0.0, 1.222);
const float HEART_K = 1.2;

float heart_sd(vec2 p, float s) {
	p /= s;
	p.x = abs(p.x);
	p.y += 0.25;
	float d;
	if (p.y + p.x > 1.0) {
		d = length(p - vec2(0.25, 0.75)) - 0.3536;
	} else {
		d = min(length(p - vec2(0.0, 1.0)), length(p - 0.5 * max(p.x + p.y, 0.0))) * sign(p.x - p.y);
	}
	return d * s;
}

void bandage_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(ASH, n, 0.0, 0.5, f.ao);
	// 斜めに巻いた包帯(中ほど)
	float wrap = fract(f.p.y / 0.050 + lx / POST_R * 0.35);
	float band = step(abs(f.p.y), 0.42);
	vec3 lin = shade_mat(LINEN, n, 0.0, 0.5, f.ao) * (0.86 + 0.14 * smoothstep(0.0, 0.25, wrap));
	c = mix(c, lin, band);
	part(acc, d, ink_of(ASH * 0.7), c, f.ow, f.px);
	// 包帯の上の赤十字
	vec2 q = vec2(lx, f.p.y);
	float crs = min(sd_round_box(q, vec2(0.010, 0.028), 0.002), sd_round_box(q, vec2(0.028, 0.010), 0.002));
	over(acc, CROSS, cov(crs, f.px));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), LAUREL, 0.0);
}

void herb_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, ASH, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 浮き彫りの蔓: 波打つ茎と葉
	float stem = 1.0 - smoothstep(0.0, max(0.005, f.px), abs(q.y - 0.022 * sin(q.x * 10.0)) - 0.004);
	inlay(acc, d, ASH * 0.72, stem * step(abs(q.x), 0.74) * step(0.08, abs(q.x)), f);
	for (int k = -4; k <= 4; k++) {
		if (k == 0) {
			continue;
		}
		float x = float(k) * 0.16;
		float y = 0.022 * sin(x * 10.0);
		vec2 lq = rot(q - vec2(x, y + 0.020 * (k % 2 == 0 ? 1.0 : -1.0)), k % 2 == 0 ? 0.6 : -0.6);
		inlay(acc, d, LAUREL, cov(sd_ellipse(lq, vec2(0.024, 0.011)), f.px), f);
	}
	inlay(acc, d, CROSS, cov(heart_sd(q, 0.040), f.px), f);
}

// 心臓の印と、左右から囲む月桂樹の枝
void heart_wreath(inout vec4 acc, Px f) {
	vec2 q = (f.p - HEART) / HEART_K;
	if (abs(q.x) > 0.22 + f.pad || abs(q.y) > 0.15 + f.pad) {
		return;
	}
	f.px /= HEART_K;
	f.ow /= HEART_K;
	for (int s = -1; s <= 1; s += 2) {
		for (int k = 0; k < 5; k++) {
			float a = -2.2 + float(k) * 0.55;
			vec2 c = vec2(cos(a) * float(s), sin(a)) * 0.115 * vec2(1.0, 1.0) + vec2(0.0, 0.020);
			c.x = -c.x;
			vec2 lq = rot(q - c, a * float(s) + 1.57 * float(s));
			part(acc, sd_ellipse(lq, vec2(0.014, 0.032)), ink_of(LAUREL), mix(LAUREL, LAUREL * 1.3, step(0.0, lq.x)), f.ow * 0.5, f.px);
		}
	}
	vec3 hc = mix(CROSS, sand_color, 0.35);
	vec3 n = normalize(vec3(q / 0.09 * 0.6, 0.75));
	part(acc, heart_sd(q - vec2(0.0, 0.010), 0.085), ink_of(CROSS), shade_mat(hc, n, 0.0, 1.0, 1.0), f.ow, f.px);
	float crs = min(sd_round_box(q - vec2(0.0, 0.020), vec2(0.008, 0.026), 0.002), sd_round_box(q - vec2(0.0, 0.020), vec2(0.026, 0.008), 0.002));
	over(acc, LINEN, cov(crs, f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - HEART;
	add_light(acc, mix(sand_color, vec3(1.0, 0.8, 0.8), 0.4), exp(-dot(q, q) / 0.010) * 0.4);
}

void art_frame(inout vec4 acc, Px f) {
	bandage_post(acc, f, -POST_X);
	bandage_post(acc, f, POST_X);
	draw_collars(acc, f, LAUREL, 0.0);
	herb_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		heart_wreath(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
