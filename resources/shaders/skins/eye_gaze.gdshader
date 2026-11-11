shader_type canvas_item;
// スキン「千里眼」(アイ)。GameDesign.md 31章 / Architecture.md 10.19節。

#define SKIN_SAND_COLOR vec3(0.60, 0.44, 1.0)
#define SKIN_SAND_KIND KIND_STARDUST
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_parts.gdshaderinc"

const vec3 VIOLET = vec3(0.40, 0.24, 0.62);
const vec3 VIOLET_DEEP = vec3(0.20, 0.11, 0.34);
const float EYE_POST_X = 0.69;
const float EYE_POST_R = 0.058;

// 瞬き。目ごとに時刻をずらす。
float eye_open(float phase) {
	float t = fract(clock * 0.23 + phase);
	return 1.0 - (1.0 - smoothstep(0.0, 0.045, abs(t - 0.5))) * 0.96;
}

vec3 iris_color() {
	return mix(sand_color, vec3(1.0, 0.75, 0.35), 0.35);
}

void eye_medallion(inout vec4 acc, Px f, vec2 c, float r, float phase) {
	vec2 q = f.p - c;
	if (length(q) > r + f.pad) {
		return;
	}
	vec3 n = normalize(vec3(q * 0.6, sqrt(max(r * r - dot(q, q), 0.0)) + 0.02));
	part(acc, length(q) - r, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
	over(acc, VIOLET_DEEP, cov(length(q) - r * 0.80, f.px));
	draw_eye(acc, f, c, r * 0.68, r * 0.40, eye_open(phase), iris_color());
}

// 板の文字の列。光の波が端から端へ渡る。
void runes(inout vec4 acc, Px f, float slab_d, vec2 q) {
	float cell_w = 0.075;
	if (abs(q.y) > 0.040 || abs(q.x) < 0.17 || abs(q.x) > 0.74) {
		return;
	}
	float ci = floor(q.x / cell_w);
	vec2 l = vec2(q.x - (ci + 0.5) * cell_w, q.y);
	float h = hash21(vec2(ci, f.side + seed));
	float d = sd_segment(l, vec2(-0.012 + 0.024 * step(0.5, h), -0.028), vec2(-0.012 + 0.024 * step(0.5, h), 0.028));
	d = min(d, sd_segment(l, vec2(-0.018, 0.028 - 0.056 * step(0.3, fract(h * 7.0))), vec2(0.018, 0.0)));
	if (fract(h * 13.0) > 0.45) {
		d = min(d, sd_segment(l, vec2(-0.016, -0.010), vec2(0.016, -0.010)));
	}
	float stroke = cov(d - max(0.006, f.px * 0.55), f.px);
	float wave = (fract(clock * 0.18) * 2.0 - 1.0) * 1.3;
	float lit = exp(-pow((q.x - wave * f.side) / 0.16, 2.0));
	vec3 col = mix(GOLD * 0.62, mix(iris_color(), vec3(1.0), 0.5), lit);
	inlay(acc, slab_d, col, stroke, f);
	inlay(acc, slab_d, iris_color(), lit * 0.25 * exp(-d / 0.02), f);
}

void skin_back(inout vec4 acc, Px f) {
}

void skin_frame(inout vec4 acc, Px f) {
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -EYE_POST_X : EYE_POST_X;
		draw_column(acc, f, cx, EYE_POST_R, -1.02, 1.02, VIOLET, 0.0);
		draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.034), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.70), vec2(0.070, 0.016), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.165), vec2(0.070, 0.016), GOLD, 1.0);
		eye_medallion(acc, f, vec2(cx, 0.0), 0.108, i == 0 ? 0.0 : 0.37);
	}
	draw_collars(acc, f, GOLD, 1.0);
	float d = draw_slab(acc, f, f.side * 1.098, vec2(0.80, 0.080), 0.03, VIOLET * 0.85, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.056) - 0.005);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.76), f);
	runes(acc, f, d, q);
	// 底板の中央の目
	if (f.p.y < 0.0) {
		vec2 eq = f.p - vec2(0.0, -1.098);
		float t = clamp(eq.x / 0.13, -1.0, 1.0);
		float d_frame = max(abs(eq.y) - 0.066 * (1.0 - t * t), abs(eq.x) - 0.13);
		part(acc, d_frame, ink_of(GOLD), shade_mat(GOLD, vec3(0.0, 0.0, 1.0), 1.0, 1.0, 1.0), f.ow, f.px);
		draw_eye(acc, f, vec2(0.0, -1.098), 0.10, 0.046, eye_open(0.18), iris_color());
	}
	// 天板の上の三日月と目。まわりで星が1つずつ瞬く
	vec2 mq = f.p - vec2(0.0, 1.272);
	float d_moon = max(length(mq) - 0.112, -(length(mq - vec2(0.050, 0.040)) - 0.100));
	if (d_moon < f.ow + f.px) {
		vec3 n = normalize(vec3(mq * 0.8, 0.07));
		part(acc, d_moon, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
	}
	draw_eye(acc, f, vec2(0.040, 1.300), 0.046, 0.026, eye_open(0.71), iris_color());
	for (int k = 0; k < 3; k++) {
		vec2 sc = vec2(-0.20 + 0.20 * float(k), 1.33 - 0.04 * float(k % 2));
		sc.x += k == 1 ? 0.33 : 0.0;
		float tw = pow(0.5 + 0.5 * sin(clock * 2.1 + float(k) * 2.3), 3.0);
		add_light(acc, vec3(1.0, 0.92, 0.70), star4(f.p - sc, 0.045) * tw);
	}
}

#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_main.gdshaderinc"
