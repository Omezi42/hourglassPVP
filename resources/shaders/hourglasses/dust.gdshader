shader_type canvas_item;
// 塵をかぶった器(ダスト)。GameDesign.md 9章 / Architecture.md 10.19節。
// 色褪せた古い木の枠に塵が積もり、上の隅に蜘蛛の巣。底板は欠けている。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 OLD_WOOD = vec3(0.62, 0.52, 0.56);
const vec3 OLD_INK = vec3(0.26, 0.20, 0.24);
const vec3 DUST = vec3(0.90, 0.86, 0.88);
const vec3 WEB = vec3(0.95, 0.95, 0.98);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float WEB_R = 0.30;

// 上から積もった塵(上を向いた面にだけ)
void dust_cap(inout vec4 acc, float d, vec2 q, float top, Px f) {
	float layer = 0.016 + 0.014 * vnoise(vec2(q.x * 16.0, top * 3.0));
	float a = step(top - layer, q.y) * cov(d, f.px);
	over(acc, DUST, a * 0.85);
}

void old_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.12 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float r = post_body_r(f.ay) * 0.92;
	float slope = (post_body_r(f.ay + 0.01) * 0.92 - r) / 0.01;
	float d = max(abs(lx) - r, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), slope * f.side);
	vec3 c = shade_mat(OLD_WOOD, n, 0.0, 0.1, f.ao);
	// 割れ目と擦れ
	float crack = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(lx - 0.012 * sin(f.p.y * 9.0 + cx * 5.0)) - 0.003);
	crack *= step(0.55, vnoise(vec2(cx * 4.0, f.p.y * 3.0)));
	c = mix(c, OLD_INK, crack * 0.6 * smoothstep(0.03, 0.012, f.px));
	c = mix(c, DUST, smoothstep(0.4, 0.9, vnoise(f.p * 18.0)) * 0.25);
	part(acc, d, OLD_INK, c, f.ow, f.px);
	draw_ball(acc, f, vec2(cx, 0.0), BEAD_R * 0.80, OLD_WOOD, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.028), OLD_WOOD * 0.85, 0.0);
}

void old_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, SLAB_HALF, 0.03);
	// 底板の左の角が欠けている
	if (cy < 0.0) {
		d = max(d, -(length(q - vec2(-0.80, -0.08)) - 0.075 - (vnoise(q * 30.0) - 0.5) * 0.02));
	}
	float v = q.y / SLAB_HALF.y;
	vec3 n = normalize(vec3(q.x / SLAB_HALF.x * 0.2, smoothstep(0.4, 0.6, v) * 0.7 - smoothstep(0.4, 0.6, -v) * 0.7, 0.75));
	vec3 c = shade_mat(OLD_WOOD, n, 0.0, 0.1, 1.0);
	float grain = abs(fract(q.y * 18.0 + vnoise(q * vec2(2.0, 8.0)) * 1.2) - 0.5);
	c = mix(c, c * 0.82, (1.0 - smoothstep(0.05, 0.15, grain)) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, OLD_INK, c, f.ow, f.px);
	dust_cap(acc, d, q, SLAB_HALF.y, f);
	// 中央の錆びた鋲と、色褪せた砂の色の小さな布
	draw_ball(acc, f, vec2(0.0, cy), 0.030, vec3(0.62, 0.42, 0.32), 0.6);
	for (int i = 0; i < 2; i++) {
		draw_ball(acc, f, vec2((i == 0 ? -1.0 : 1.0) * 0.66, cy), 0.022, vec3(0.62, 0.42, 0.32), 0.6);
	}
}

// 柱と天板の隅に張った蜘蛛の巣
void cobweb(inout vec4 acc, Px f, float sx) {
	vec2 corner = vec2(sx * 0.60, PLATE_Y - SLAB_HALF.y);
	vec2 q = (f.p - corner) * vec2(-sx, -1.0);
	if (q.x < -f.pad || q.y < -f.pad || length(q) > WEB_R + f.pad) {
		return;
	}
	float r = length(q);
	float ang = atan(q.y, q.x);
	float line_w = max(0.0035, f.px * 0.55);
	float spokes = 0.0;
	for (int k = 0; k < 4; k++) {
		float a = 0.12 + float(k) * 0.44;
		vec2 dir = vec2(cos(a), sin(a));
		spokes = max(spokes, 1.0 - smoothstep(0.0, line_w + f.px, sd_segment(q, vec2(0.0), dir * WEB_R)));
	}
	// 輪の糸は spokes の間でたるむ
	float seg = fract((ang - 0.12) / 0.44);
	float sag = 1.0 + 0.10 * sin(seg * 3.1416);
	float rr = r * sag;
	float rings = 0.0;
	for (int j = 1; j <= 3; j++) {
		float rk = WEB_R * float(j) / 3.6;
		rings = max(rings, 1.0 - smoothstep(0.0, line_w + f.px, abs(rr - rk)));
	}
	rings *= step(0.12, ang) * step(ang, 0.12 + 0.44 * 3.0);
	over(acc, WEB, max(spokes, rings) * 0.75 * (1.0 - smoothstep(WEB_R * 0.85, WEB_R, r)));
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	old_post(acc, f, -POST_X);
	old_post(acc, f, POST_X);
	draw_collars(acc, f, OLD_WOOD * 0.85, 0.0);
	old_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > 0.5) {
		cobweb(acc, f, -1.0);
		cobweb(acc, f, 1.0);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
