shader_type canvas_item;
// 芽吹き(スプラウト)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は葉を付けた若い茎、底板は土を盛った素焼きの鉢の縁、天板の上に双葉が開く。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEM = vec3(0.40, 0.64, 0.28);
const vec3 LEAF = vec3(0.42, 0.74, 0.30);
const vec3 TERRACOTTA = vec3(0.78, 0.46, 0.30);
const vec3 SOIL = vec3(0.34, 0.24, 0.16);
const float STEM_R = 0.034;
const vec2 SLAB_HALF = vec2(0.80, 0.082);

// 葉1枚。根元 base から角度 ang へ、長さ len
void leaf(inout vec4 acc, Px f, vec2 base, float ang, float len, float w) {
	vec2 q = rot(f.p - base, ang);
	if (q.y < -f.pad || q.y > len + f.pad || abs(q.x) > w + f.pad) {
		return;
	}
	float t = clamp(q.y / len, 0.0, 1.0);
	float hw = w * sin(3.1416 * pow(t, 0.8));
	float d = max(abs(q.x) - hw, max(-q.y, q.y - len));
	vec3 c = mix(LEAF * 0.72, LEAF * 1.12, step(0.0, q.x));
	float vein = 1.0 - smoothstep(0.0, max(0.005, f.px * 0.7), abs(q.x) - 0.003);
	c = mix(c, LEAF * 1.35, vein * 0.6);
	part(acc, d, ink_of(STEM), c, f.ow * 0.8, f.px);
}

void stem_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.26 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float bend = 0.012 * sin(f.p.y * 3.0 + cx);
	float d = max(abs(lx - bend) - STEM_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp((lx - bend) / STEM_R, -1.0, 1.0), 0.0);
	part(acc, d, ink_of(STEM), shade_mat(STEM, n, 0.0, 0.6, f.ao), f.ow, f.px);
	// 外へ向けて交互に付く葉
	float out_dir = sign(cx);
	for (int k = 0; k < 3; k++) {
		float y = -0.55 + float(k) * 0.55;
		float side = (k % 2 == 0) ? out_dir : -out_dir * 0.0 + out_dir;
		leaf(acc, f, vec2(cx + side * STEM_R * 0.8, y), -side * 0.9, 0.20, 0.050);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.070, 0.022), STEM * 0.8, 0.0);
}

// 底板: 素焼きの鉢の縁と、上に盛った土
void pot_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.04, TERRACOTTA, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = step(abs(q.y), 0.050) * step(abs(q.x), 0.76);
	float stamp = step(abs(fract(q.x * 6.0) - 0.5), 0.12) * step(abs(q.y), 0.020);
	inlay(acc, d, TERRACOTTA * 0.80, rim, f);
	inlay(acc, d, TERRACOTTA * 1.12, stamp * rim, f);
	if (cy < 0.0) {
		// 鉢の上の土と、こぼれた種
		vec2 sq = q - vec2(0.0, SLAB_HALF.y + 0.005);
		float d_soil = max(sd_ellipse(sq, vec2(0.62, 0.030)), -sq.y);
		part(acc, d_soil, ink_of(SOIL), mix(SOIL, SOIL * 1.4, vnoise(sq * 40.0)), f.ow * 0.8, f.px);
		for (int k = 0; k < 3; k++) {
			vec2 seed_q = sq - vec2(-0.40 + float(k) * 0.38, 0.012);
			over(acc, mix(sand_color, SOIL, 0.25), cov(sd_ellipse(seed_q, vec2(0.016, 0.010)), f.px));
		}
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	stem_post(acc, f, -POST_X);
	stem_post(acc, f, POST_X);
	draw_collars(acc, f, TERRACOTTA, 0.0);
	pot_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		vec2 root = vec2(0.0, PLATE_Y + SLAB_HALF.y - 0.01);
		float d_stalk = sd_segment(f.p, root, root + vec2(0.0, 0.08)) - 0.016;
		part(acc, d_stalk, ink_of(STEM), STEM, f.ow * 0.8, f.px);
		leaf(acc, f, root + vec2(0.0, 0.07), 1.25, 0.22, 0.070);
		leaf(acc, f, root + vec2(0.0, 0.07), -1.25, 0.22, 0.070);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
