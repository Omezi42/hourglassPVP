shader_type canvas_item;
// 芽吹いた種(シード)。GameDesign.md 9章 / Architecture.md 10.19節。
// 白木の枠。底板は割れ、その割れ目から小さな芽が伸びる。天板の上に殻の割れかけた種がひとつ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PALE_WOOD = vec3(0.84, 0.72, 0.54);
const vec3 WOOD_INK = vec3(0.42, 0.30, 0.18);
const vec3 HULL = vec3(0.56, 0.38, 0.22);
const vec3 SHOOT = vec3(0.46, 0.74, 0.30);
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const vec2 SEED = vec2(0.0, 1.255);

float crack_d(vec2 q) {
	vec2 a = vec2(-0.30, 0.080);
	vec2 b = vec2(-0.26, 0.020);
	vec2 c = vec2(-0.31, -0.030);
	vec2 e = vec2(-0.27, -0.080);
	return min(min(sd_segment(q, a, b), sd_segment(q, b, c)), sd_segment(q, c, e));
}

void pale_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float r = 0.046 + 0.008 * cos(f.p.y * 5.0);
	float d = max(abs(lx) - r, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(PALE_WOOD, n, 0.0, 0.5, f.ao);
	float grain = abs(fract(lx * 30.0 + vnoise(vec2(lx * 8.0, f.p.y * 2.0)) * 0.8) - 0.5);
	c = mix(c, c * 0.86, (1.0 - smoothstep(0.05, 0.2, grain)) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, WOOD_INK, c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), HULL, 0.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.066, 0.018), HULL, 0.0);
}

void pale_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.035, PALE_WOOD, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + 0.25 + f.pad) {
		return;
	}
	float grain = abs(fract(q.y * 22.0 + vnoise(q * vec2(2.0, 8.0)) * 1.2) - 0.5);
	inlay(acc, d, PALE_WOOD * 0.82, (1.0 - smoothstep(0.05, 0.15, grain)) * 0.5 * smoothstep(0.03, 0.012, f.px), f);
	if (cy < 0.0) {
		// 割れ目と、そこから伸びる芽
		over(acc, WOOD_INK, cov(crack_d(q) - max(0.006, f.px * 0.6), f.px) * cov(d, f.px));
		vec2 root = vec2(-0.30, SLAB_HALF.y);
		float d_stem = sd_segment(q, root, root + vec2(0.02, 0.12)) - 0.012;
		part(acc, d_stem, ink_of(SHOOT), SHOOT, f.ow * 0.8, f.px);
		for (int i = 0; i < 2; i++) {
			float sx = i == 0 ? -1.0 : 1.0;
			vec2 lq = rot(q - root - vec2(0.02, 0.12), sx * 1.0);
			float d_leaf = sd_ellipse(lq - vec2(0.0, 0.040), vec2(0.020, 0.045));
			part(acc, d_leaf, ink_of(SHOOT), mix(SHOOT, SHOOT * 1.25, step(0.0, lq.x)), f.ow * 0.8, f.px);
		}
	} else {
		vec3 gn = normalize(vec3(q / 0.04 * 0.6, 0.8));
		part(acc, sd_ellipse(q, vec2(0.050, 0.030)), WOOD_INK, shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
}

// 殻の割れかけた種(すきまから芽の色がのぞく)
void seed_top(inout vec4 acc, Px f) {
	vec2 q = f.p - SEED;
	if (abs(q.x) > 0.14 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	vec2 sq = rot(q, 0.35);
	float d = sd_ellipse(sq, vec2(0.075, 0.105));
	vec3 n = normalize(vec3(sq / vec2(0.075, 0.105) * 0.6, 0.75));
	vec3 c = shade_mat(HULL, n, 0.0, 0.8, 1.0);
	float seam = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(sq.x - 0.01 * sin(sq.y * 40.0)) - 0.006);
	c = mix(c, mix(SHOOT, sand_color, 0.35), seam * step(0.02, sq.y));
	part(acc, d, WOOD_INK, c, f.ow, f.px);
	draw_band(acc, f, vec2(0.0, 1.17), vec2(0.070, 0.016), HULL, 0.0);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	pale_post(acc, f, -POST_X);
	pale_post(acc, f, POST_X);
	draw_collars(acc, f, HULL, 0.0);
	pale_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		seed_top(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
