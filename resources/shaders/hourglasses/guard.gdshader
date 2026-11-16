shader_type canvas_item;
// 名もない衛兵(ガード)。GameDesign.md 9章 / Architecture.md 10.19節。
// 黄の布を巻いた鋼の柱、天板の上に面頬を下ろした兜、底板の前に大きな凧形の盾。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEEL = vec3(0.64, 0.68, 0.74);
const vec3 CLOTH = vec3(0.92, 0.78, 0.22);
const vec3 LEATHER = vec3(0.46, 0.30, 0.18);
const float POST_R = 0.050;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 HELM = vec2(0.0, 1.245);
const float HELM_K = 1.25;

void sentry_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, STEEL, 1.0);
	// 斜めに巻いた黄の布
	float lx = f.p.x - cx;
	if (abs(lx) < POST_R + f.pad && f.ay < 0.40) {
		float wrap = step(0.5, fract((f.p.y + lx * 0.8) * 4.0));
		float d = max(abs(lx) - POST_R - 0.004, f.ay - 0.40);
		vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
		vec3 c = shade_mat(mix(CLOTH, CLOTH * 0.78, wrap), n, 0.0, 0.4, f.ao);
		part(acc, d, ink_of(CLOTH), c, f.ow, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), LEATHER, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.42), vec2(0.070, 0.018), STEEL, 1.0);
}

// 兜: 丸い鉢、面頬の覗き穴、頂の房
void helm(inout vec4 acc, Px f) {
	vec2 q = (f.p - HELM) / HELM_K;
	if (abs(q.x) > 0.14 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	f.px /= HELM_K;
	f.ow /= HELM_K;
	float d_bowl = max(length(q * vec2(1.0, 0.95)) - 0.100, -q.y - 0.090);
	vec3 n = normalize(vec3(q / 0.10 * 0.7, 0.7));
	vec3 c = shade_mat(STEEL, n, 1.0, 1.0, 1.0);
	float slit = step(abs(q.y + 0.005), 0.010) * step(abs(q.x), 0.075);
	float holes = step(length(vec2(fract(q.x / 0.03 + 0.5) - 0.5, (q.y + 0.045) / 0.03)), 0.28) * step(abs(q.x), 0.05) * step(abs(q.y + 0.045), 0.01);
	c = mix(c, vec3(0.06), max(slit, holes));
	float ridge = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(q.x) - 0.008);
	c = mix(c, vec3(1.0), ridge * 0.4 * step(0.0, q.y));
	part(acc, d_bowl, ink_of(STEEL), c, f.ow, f.px);
	// 頂の黄の房
	vec2 pq = q - vec2(0.0, 0.098);
	float d_plume = sd_ellipse(rot(pq, 0.3), vec2(0.020, 0.026));
	part(acc, d_plume, ink_of(CLOTH), CLOTH, f.ow * 0.8, f.px);
}

// 凧形の盾: 鋼の縁、黄の地に砂の色の十字
void kite_shield(inout vec4 acc, Px f, vec2 c) {
	vec2 q = f.p - c;
	if (abs(q.x) > 0.13 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	float w = 0.105 * (1.0 - smoothstep(-0.02, 0.14, -q.y) * 0.85);
	float d = max(abs(q.x) - w, max(q.y - 0.090, -q.y - 0.140));
	vec3 n = normalize(vec3(q.x / 0.10 * 0.5, 0.15, 0.85));
	part(acc, d, ink_of(STEEL), shade_mat(STEEL, n, 1.0, 1.0, 1.0), f.ow, f.px);
	float d_in = d + 0.016;
	over(acc, shade_mat(CLOTH, n, 0.0, 0.6, 1.0), cov(d_in, f.px));
	float cross_d = min(abs(q.x) - 0.014, abs(q.y - 0.020) - 0.014);
	over(acc, mix(sand_color, LEATHER, 0.45), cov(max(cross_d, d_in), f.px));
}

void sentry_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.025, STEEL, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float band = step(abs(q.y), 0.036) * step(abs(q.x), 0.76);
	inlay(acc, d, CLOTH * 0.92, band, f);
	for (int k = -3; k <= 3; k++) {
		draw_ball(acc, f, vec2(float(k) * 0.24, cy + 0.058 * sign(q.y + 0.0001)), 0.012, STEEL * 1.1, 1.0);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	sentry_post(acc, f, -POST_X);
	sentry_post(acc, f, POST_X);
	draw_collars(acc, f, LEATHER, 0.0);
	sentry_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		helm(acc, f);
	}
	if (f.p.y < -0.9) {
		kite_shield(acc, f, vec2(0.0, -1.075));
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
