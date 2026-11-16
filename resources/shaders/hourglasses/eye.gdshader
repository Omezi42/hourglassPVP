shader_type canvas_item;
// 千里眼(アイ)。GameDesign.md 9章 / Architecture.md 10.19節。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 VIOLET = vec3(0.40, 0.24, 0.62);
const vec3 VIOLET_DEEP = vec3(0.20, 0.11, 0.34);
const vec3 EYE_WHITE = vec3(0.97, 0.95, 0.90);
const float EYE_POST_X = 0.69;
const float EYE_POST_R = 0.058;
const float MEDALLION_R = 0.108;
const vec2 SLAB_HALF = vec2(0.80, 0.080);

// 瞬き。目ごとに時刻をずらす。
float eye_open(float phase) {
	float t = fract(clock * 0.23 + phase);
	return 1.0 - (1.0 - smoothstep(0.0, 0.045, abs(t - 0.5))) * 0.96;
}

vec3 iris_color() {
	return mix(sand_color, vec3(1.0, 0.75, 0.35), 0.35);
}


void base_back(inout vec4 acc, Px f) {
}

void base_frame(inout vec4 acc, Px f) {
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -EYE_POST_X : EYE_POST_X;
		draw_column(acc, f, cx, EYE_POST_R, -1.02, 1.02, VIOLET, 0.0);
		draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.034), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.70), vec2(0.070, 0.016), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.165), vec2(0.070, 0.016), GOLD, 1.0);
		// 柱の中ほどの円盤(目は動きが重ねる)
		vec2 q = f.p - vec2(cx, 0.0);
		if (length(q) <= MEDALLION_R + f.pad) {
			vec3 n = normalize(vec3(q * 0.6, sqrt(max(MEDALLION_R * MEDALLION_R - dot(q, q), 0.0)) + 0.02));
			part(acc, length(q) - MEDALLION_R, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
			over(acc, VIOLET_DEEP, cov(length(q) - MEDALLION_R * 0.80, f.px));
		}
	}
	draw_collars(acc, f, GOLD, 1.0);
	float d = draw_slab(acc, f, f.side * 1.098, SLAB_HALF, 0.03, VIOLET * 0.85, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.056) - 0.005);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.76), f);
	// 底板の中央の目の枠
	if (f.p.y < 0.0) {
		vec2 eq = f.p - vec2(0.0, -1.098);
		float t = clamp(eq.x / 0.13, -1.0, 1.0);
		float d_frame = max(abs(eq.y) - 0.066 * (1.0 - t * t), abs(eq.x) - 0.13);
		part(acc, d_frame, ink_of(GOLD), shade_mat(GOLD, vec3(0.0, 0.0, 1.0), 1.0, 1.0, 1.0), f.ow, f.px);
	}
	// 天板の上の三日月
	vec2 mq = f.p - vec2(0.0, 1.272);
	float d_moon = max(length(mq) - 0.112, -(length(mq - vec2(0.050, 0.040)) - 0.100));
	if (d_moon < f.ow + f.px) {
		vec3 n = normalize(vec3(mq * 0.8, 0.07));
		part(acc, d_moon, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
	}
}

// 目。open は開き具合(0〜1)。
void draw_eye(inout vec4 acc, Px f, vec2 c, float hw, float hh, float open, vec3 iris_col) {
	vec2 q = f.p - c;
	if (abs(q.x) > hw + f.pad || abs(q.y) > hh + f.pad) {
		return;
	}
	float t = clamp(q.x / hw, -1.0, 1.0);
	float lid = hh * max(open, 0.04) * (1.0 - t * t);
	float d_eye = max(abs(q.y) - lid, abs(q.x) - hw);
	vec2 gaze = vec2(0.0);
	if (length(gaze) > 1.0) {
		gaze = normalize(gaze);
	}
	vec2 ic = vec2(gaze.x * hw * 0.42, gaze.y * hh * 0.30);
	float ir = hh * 0.82;
	float di = length(q - ic);
	// 白目は上瞼の影で上が沈む
	vec3 white = mix(EYE_WHITE, EYE_WHITE * vec3(0.72, 0.70, 0.80), smoothstep(-0.2, 1.0, q.y / max(lid, 0.001)));
	float iris = cov(di - ir, f.px);
	float ang = atan(q.y - ic.y, q.x - ic.x);
	float fiber = 0.85 + 0.15 * sin(ang * 14.0 + seed);
	vec3 iris_rgb = mix(iris_col * 0.45, iris_col * 1.15, smoothstep(ir, ir * 0.35, di)) * fiber;
	float pupil = cov(di - ir * 0.42, f.px);
	vec3 rgb = mix(white, iris_rgb, iris);
	rgb = mix(rgb, vec3(0.04, 0.02, 0.08), pupil);
	float hl = cov(length(q - ic - vec2(-ir * 0.35, ir * 0.35)) - ir * 0.22, f.px);
	rgb = mix(rgb, vec3(1.0), hl * 0.9);
	over(acc, vec3(0.08, 0.04, 0.12), cov(d_eye - f.ow * 0.9, f.px));
	over(acc, rgb, cov(d_eye, f.px));
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

void over_back(inout vec4 acc, Px f) {
}

// 文字の列・目・星(動くもの)
void over_front(inout vec4 acc, Px f) {
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	runes(acc, f, sd_round_box(q, SLAB_HALF, 0.03), q);
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -EYE_POST_X : EYE_POST_X;
		draw_eye(acc, f, vec2(cx, 0.0), MEDALLION_R * 0.68, MEDALLION_R * 0.40, eye_open(i == 0 ? 0.0 : 0.37), iris_color());
	}
	if (f.p.y < 0.0) {
		draw_eye(acc, f, vec2(0.0, -1.098), 0.10, 0.046, eye_open(0.18), iris_color());
	}
	// 天板の上の三日月の目。まわりで星が1つずつ瞬く
	draw_eye(acc, f, vec2(0.040, 1.300), 0.046, 0.026, eye_open(0.71), iris_color());
	for (int k = 0; k < 3; k++) {
		vec2 sc = vec2(-0.20 + 0.20 * float(k), 1.33 - 0.04 * float(k % 2));
		sc.x += k == 1 ? 0.33 : 0.0;
		float tw = pow(0.5 + 0.5 * sin(clock * 2.1 + float(k) * 2.3), 3.0);
		add_light(acc, vec3(1.0, 0.92, 0.70), star4(f.p - sc, 0.045) * tw);
	}
}

void art_back(inout vec4 acc, Px f) {
	base_back(acc, f);
	over_back(acc, f);
}

void art_frame(inout vec4 acc, Px f) {
	base_frame(acc, f);
	over_front(acc, f);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
