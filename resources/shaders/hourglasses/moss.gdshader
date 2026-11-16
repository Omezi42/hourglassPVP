shader_type canvas_item;
// 苔むした朽ち木(モス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 灰色に朽ちた木の柱と板を苔が覆い、天板の上の苔の小山に茸が生える。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 DEADWOOD = vec3(0.54, 0.52, 0.46);
const vec3 WOOD_INK = vec3(0.22, 0.21, 0.18);
const vec3 MOSS = vec3(0.34, 0.58, 0.22);
const vec3 CAP = vec3(0.80, 0.52, 0.30);
const vec3 STALK = vec3(0.92, 0.88, 0.76);
const vec2 SLAB_HALF = vec2(0.80, 0.084);

// 苔の斑(ふわふわした縁)
float moss_mask(vec2 p, float k) {
	float n = vnoise(p * 7.0 + k) * 0.7 + vnoise(p * 23.0 + k) * 0.3;
	return smoothstep(0.50, 0.58, n);
}

vec3 moss_color(vec2 p, float px) {
	float tuft = vnoise(p * 60.0);
	vec3 c = mix(MOSS * 0.70, mix(MOSS, sand_color, 0.35) * 1.15, tuft * smoothstep(0.03, 0.012, px) + 0.3);
	return c;
}

void dead_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float r = 0.052 + 0.010 * vnoise(vec2(f.p.y * 4.0, cx));
	float d = max(abs(lx) - r, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(DEADWOOD, n, 0.0, 0.1, f.ao);
	float grain = abs(fract(lx * 26.0 + vnoise(vec2(lx * 6.0, f.p.y * 1.5)) * 1.2) - 0.5);
	c = mix(c, WOOD_INK, (1.0 - smoothstep(0.04, 0.12, grain)) * 0.45 * smoothstep(0.03, 0.012, f.px));
	c = mix(c, moss_color(f.p, f.px), moss_mask(f.p * vec2(2.0, 1.0), cx) * step(lx * sign(cx), 0.02));
	part(acc, d, WOOD_INK, c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), DEADWOOD * 0.8, 0.0);
}

void dead_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + 0.04 + f.pad) {
		return;
	}
	float d = sd_round_box(q, SLAB_HALF, 0.04) + (vnoise(q * 18.0) - 0.5) * 0.012;
	float v = q.y / SLAB_HALF.y;
	vec3 n = normalize(vec3(q.x / SLAB_HALF.x * 0.2, smoothstep(0.4, 0.6, v) * 0.7 - smoothstep(0.4, 0.6, -v) * 0.7, 0.75));
	vec3 c = shade_mat(DEADWOOD, n, 0.0, 0.1, 1.0);
	float grain = abs(fract(q.y * 18.0 + vnoise(q * vec2(2.0, 8.0)) * 1.4) - 0.5);
	c = mix(c, WOOD_INK, (1.0 - smoothstep(0.04, 0.12, grain)) * 0.45 * smoothstep(0.03, 0.012, f.px));
	// 上の縁を厚く覆う苔
	float cover = step(SLAB_HALF.y - 0.035 - 0.02 * vnoise(vec2(q.x * 8.0, cy)), q.y) + moss_mask(q, cy) * 0.8;
	c = mix(c, moss_color(q, f.px), clamp(cover, 0.0, 1.0));
	part(acc, d, WOOD_INK, c, f.ow, f.px);
}

// 茸1本(傘と柄)
void mushroom(inout vec4 acc, Px f, vec2 base, float s) {
	vec2 q = (f.p - base) / s;
	float ps = f.px / s;
	if (abs(q.x) > 1.4 + ps * 3.0 || q.y < -0.2 - ps * 3.0 || q.y > 2.2 + ps * 3.0) {
		return;
	}
	float d_stalk = sd_round_box(q - vec2(0.0, 0.55), vec2(0.28, 0.55), 0.15);
	part(acc, d_stalk * s, WOOD_INK, STALK, f.ow * 0.8, f.px);
	vec2 cq = q - vec2(0.0, 1.20);
	float d_cap = max(sd_ellipse(cq, vec2(1.05, 0.75)), -cq.y - 0.05);
	vec3 n = normalize(vec3(cq / vec2(1.05, 0.75) * 0.6, 0.75));
	vec3 c = shade_mat(CAP, n, 0.0, 0.8, 1.0);
	float spot = step(length(vec2(fract(cq.x * 1.6 + 0.3) - 0.5, (cq.y - 0.35) * 1.6)), 0.22);
	c = mix(c, STALK, spot);
	part(acc, d_cap * s, WOOD_INK, c, f.ow * 0.8, f.px);
}

void moss_mound(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, PLATE_Y + SLAB_HALF.y - 0.01);
	if (abs(q.x) > 0.40 + f.pad || q.y > 0.22 + f.pad) {
		return;
	}
	float mound = max(abs(q.x) - 0.34, q.y - 0.060 * (1.0 - pow(min(abs(q.x) / 0.34, 1.0), 2.0)) - 0.008 * sin(q.x * 70.0));
	mound = max(mound, -q.y - 0.01);
	part(acc, mound, WOOD_INK, moss_color(q, f.px), f.ow * 0.8, f.px);
	mushroom(acc, f, vec2(-0.09, PLATE_Y + SLAB_HALF.y + 0.030), 0.090);
	mushroom(acc, f, vec2(0.12, PLATE_Y + SLAB_HALF.y + 0.025), 0.068);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	dead_post(acc, f, -POST_X);
	dead_post(acc, f, POST_X);
	draw_collars(acc, f, DEADWOOD * 0.8, 0.0);
	dead_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		moss_mound(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
