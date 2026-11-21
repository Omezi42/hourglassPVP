shader_type canvas_item;
// 五重奏(クインテット)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は5本の細い金の棒を編んだ組紐、板には五角形の宝石が5つ。天板の上に、金の弧に並んだ宝石5つ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 SLATE = vec3(0.20, 0.17, 0.24);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const int STRANDS = 5;
const float BRAID_W = 0.040;
const float STRAND_R = 0.013;
const float BRAID_FREQ = 5.0;
const vec2 ARCH = vec2(0.0, 1.205);
const float ARCH_HALF = 0.21;
const float ARCH_RISE = 0.085;

float sd_pentagon(vec2 p, float r) {
	const vec3 k = vec3(0.809016994, 0.587785252, 0.726542528);
	p.x = abs(p.x);
	p -= 2.0 * min(dot(vec2(-k.x, k.y), p), 0.0) * vec2(-k.x, k.y);
	p -= 2.0 * min(dot(vec2(k.x, k.y), p), 0.0) * vec2(k.x, k.y);
	p -= vec2(clamp(p.x, -r * k.z, r * k.z), r);
	return length(p) * sign(p.y);
}

// 5本の棒の組紐。手前にある棒(位相の余弦が大きい)ほど後から重ねる
void braid_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > BRAID_W + STRAND_R + 0.03 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	for (int pass = 0; pass < 2; pass++) {
		for (int k = 0; k < STRANDS; k++) {
			float ph = f.p.y * BRAID_FREQ + float(k) * 6.2832 / float(STRANDS);
			float front = cos(ph);
			if ((pass == 0) == (front > 0.0)) {
				continue;
			}
			float x = BRAID_W * sin(ph);
			float d = max(abs(lx - x) - STRAND_R, f.ay - POST_H);
			vec3 base = k == 0 ? mix(GOLD, sand_color, 0.6) : GOLD;
			vec3 n = lathe_normal(clamp((lx - x) / STRAND_R, -1.0, 1.0), 0.0);
			vec3 c = shade_mat(base, n, 1.0, 1.0, f.ao) * mix(0.55, 1.0, front * 0.5 + 0.5);
			part(acc, d, ink_of(GOLD), c, f.ow * 0.6, f.px);
		}
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), SLATE, 0.3);
	draw_band(acc, f, vec2(cx, f.side * 0.935), vec2(0.070, 0.010), GOLD, 1.0);
}

void gem(inout vec4 acc, Px f, vec2 q, float r, float slab_d) {
	float d = sd_pentagon(q, r);
	vec3 n = normalize(vec3(q / r * 0.8, 0.7));
	vec3 c = shade_mat(sand_color, n, 0.3, 1.0, 1.0) + vec3(0.25) * step(0.6, n.y + n.x * -0.5);
	if (slab_d > -9.0) {
		inlay(acc, slab_d, ink_of(sand_color), cov(d - f.ow * 0.6, f.px), f);
		inlay(acc, slab_d, c, cov(d, f.px), f);
	} else {
		part(acc, d, ink_of(sand_color), c, f.ow * 0.7, f.px);
	}
}

void pentagon_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, SLATE, 0.2, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float wire = cov(max(abs(q.y) - 0.004, abs(q.x) - 0.66), f.px);
	inlay(acc, d, GOLD * 0.8, wire, f);
	for (int k = -2; k <= 2; k++) {
		gem(acc, f, q - vec2(float(k) * 0.30, 0.0), 0.050, d);
	}
}

// 金の弧に並んだ宝石5つ(5人が並んだ姿)
void gem_arch(inout vec4 acc, Px f) {
	vec2 q = f.p - ARCH;
	if (abs(q.x) > ARCH_HALF + 0.06 + f.pad || q.y < -0.03 - f.pad || q.y > ARCH_RISE + 0.06 + f.pad) {
		return;
	}
	float t = clamp(q.x / ARCH_HALF, -1.0, 1.0);
	float arch_y = ARCH_RISE * cos(t * 1.5708);
	float d_wire = max(abs(q.y - arch_y) - 0.010, abs(q.x) - ARCH_HALF);
	part(acc, d_wire, ink_of(GOLD), shade_mat(GOLD, vec3(0.0, 0.5, 0.85), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	for (int s = -1; s <= 1; s += 2) {
		vec2 fq = q - vec2(float(s) * ARCH_HALF, 0.0);
		part(acc, sd_round_box(fq, vec2(0.016, 0.020), 0.006), ink_of(GOLD), GOLD, f.ow * 0.6, f.px);
	}
	for (int k = -2; k <= 2; k++) {
		float x = float(k) * ARCH_HALF * 0.5;
		float y = ARCH_RISE * cos(x / ARCH_HALF * 1.5708);
		gem(acc, f, q - vec2(x, y), k == 0 ? 0.040 : 0.032, -10.0);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	braid_post(acc, f, -POST_X);
	braid_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	pentagon_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		gem_arch(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
