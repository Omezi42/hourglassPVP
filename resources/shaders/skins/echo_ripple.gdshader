shader_type canvas_item;
// スキン「波紋」(エコー)。GameDesign.md 31章 / Architecture.md 10.19節。

#define SKIN_SAND_COLOR vec3(0.32, 0.86, 0.74)
#define SKIN_SAND_KIND KIND_LIQUID
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_parts.gdshaderinc"

const vec3 JADE = vec3(0.30, 0.66, 0.54);
const vec3 JADE_GLOW = vec3(0.55, 1.0, 0.85);
const float RIPPLE_POST_X = 0.68;
const float RIPPLE_POST_R = 0.05;
const float BELL_X = 0.86;

void ripple_rings(inout vec4 acc, Px f) {
	float r = length(f.p * vec2(1.0, 0.86));
	float a = 0.0;
	for (int k = 0; k < 3; k++) {
		float age = fract(clock * 0.30 + float(k) / 3.0);
		float rk = 0.48 + age * 0.50;
		float ring = 1.0 - smoothstep(0.0, max(0.016, f.px * 1.2), abs(r - rk) - 0.008);
		a = max(a, ring * (1.0 - age) * smoothstep(0.0, 0.12, age));
	}
	float behind_glass = step(abs(f.p.x), glass_r(f.p.y) + 0.04) * step(f.ay, GLASS_H + 0.05);
	a *= 1.0 - behind_glass;
	add_light(acc, JADE_GLOW, a * (0.45 + 0.50 * flow) * canvas_window(f.p));
}

void draw_bell(inout vec4 acc, Px f, float cx, float phase) {
	vec2 pivot = vec2(cx, 1.020);
	vec2 q = f.p - pivot;
	if (abs(q.x) > 0.15 + f.pad || q.y > f.pad || q.y < -0.30 - f.pad) {
		return;
	}
	float swing = 0.22 * sin(clock * 2.4 + phase) * (0.35 + 0.65 * flow);
	q = rot(q, -swing);
	float d_cord = sd_segment(q, vec2(0.0, 0.0), vec2(0.0, -0.05)) - 0.008;
	over(acc, ink_of(GOLD), cov(d_cord, f.px));
	// 鈴: 上は丸い肩、下へ広がって縁で終わる
	float yy = clamp((-q.y - 0.05) / 0.17, 0.0, 1.0);
	float shoulder = yy < 0.18 ? sqrt(max(yy / 0.18, 0.0)) * 0.6 + 0.4 : 1.0;
	float half_w = mix(0.045, 0.072, yy * yy) * shoulder;
	float d_bell = max(abs(q.x) - half_w, max(q.y + 0.05, -q.y - 0.22));
	d_bell = min(d_bell, sd_round_box(q - vec2(0.0, -0.215), vec2(0.080, 0.014), 0.012));
	vec3 n = normalize(vec3(q.x / 0.08, 0.15 - yy * 0.3, 0.75));
	part(acc, d_bell, ink_of(SILVER), shade_mat(SILVER, n, 1.0, 1.0, 1.0), f.ow, f.px);
	draw_ball(acc, f, pivot + rot(vec2(0.0, -0.245), swing), 0.022, GOLD, 1.0);
}

void skin_back(inout vec4 acc, Px f) {
	ripple_rings(acc, f);
}

void skin_frame(inout vec4 acc, Px f) {
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -RIPPLE_POST_X : RIPPLE_POST_X;
		draw_column(acc, f, cx, RIPPLE_POST_R, -1.02, 1.02, JADE, 0.0);
		draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.030), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.905), vec2(0.064, 0.018), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.075), vec2(0.064, 0.014), GOLD, 1.0);
		draw_ball(acc, f, vec2(cx, 0.0), 0.062, GOLD, 1.0);
	}
	draw_collars(acc, f, GOLD, 1.0);
	float d = draw_slab(acc, f, f.side * 1.098, vec2(0.86, 0.078), 0.03, JADE * 0.92, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.054) - 0.006);
	inlay(acc, d, SILVER, rim * step(abs(q.x), 0.82), f);
	// 板の金の波線は流れ続ける
	float yl = 0.020 * sin(q.x * 26.0 - clock * 2.5);
	float wave = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(q.y - yl) - 0.006);
	inlay(acc, d, GOLD * 1.05, wave * step(abs(q.x), 0.80) * step(0.09, abs(q.x)), f);
	if (abs(q.x) < 0.09 + f.pad && f.p.y < 0.0) {
		vec3 n = normalize(vec3(q / 0.07 * 0.6, 0.8));
		part(acc, length(q) - 0.066, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
		float rings = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.6), abs(fract(length(q) / 0.022 - clock * 0.8) - 0.5) * 0.022 - 0.003);
		over(acc, JADE * 0.6, rings * cov(length(q) - 0.050, f.px) * smoothstep(0.03, 0.014, f.px));
	}
	if (f.p.y > 0.0) {
		draw_bell(acc, f, -BELL_X, 0.0);
		draw_bell(acc, f, BELL_X, 1.3);
	}
}

#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_main.gdshaderinc"
