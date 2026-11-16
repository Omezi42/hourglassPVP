shader_type canvas_item;
// 双子の器(ツイン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は2本の細い柱を撚り合わせたもの。天板の上に同じ形の小さな砂時計がふたつ並び、板には組み合う2つの輪。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 ROSE = vec3(0.78, 0.40, 0.58);
const float TWIST_X = 0.68;
const float STRAND_R = 0.026;
const float TWIST_AMP = 0.030;
const float TWIST_FREQ = 5.0;
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const float MINI_Y = 1.268;
const float MINI_X = 0.11;

// 撚り合わせた2本。前後は位相で入れ替わる
void twisted_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > TWIST_AMP + STRAND_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float ph = f.p.y * TWIST_FREQ * 6.2832 / 2.0;
	for (int pass = 0; pass < 2; pass++) {
		for (int k = 0; k < 2; k++) {
			float s = k == 0 ? 1.0 : -1.0;
			float front = s * cos(ph);
			if ((pass == 0) == (front > 0.0)) {
				continue;
			}
			float sx = lx - s * TWIST_AMP * sin(ph);
			float d = max(abs(sx) - STRAND_R, f.ay - POST_H);
			vec3 n = lathe_normal(clamp(sx / STRAND_R, -1.0, 1.0), 0.0);
			vec3 col = k == 0 ? ROSE : SILVER;
			part(acc, d, ink_of(ROSE), shade_mat(col, n, float(k), 1.0, f.ao * (0.82 + 0.18 * step(0.0, front))), f.ow * 0.8, f.px);
		}
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.078, 0.028), SILVER, 1.0);
	draw_ball(acc, f, vec2(cx, 0.0), 0.058, SILVER, 1.0);
}

// 天板の上の小さな砂時計(同じ形の器がふたつ)
void mini_hourglass(inout vec4 acc, Px f, float cx) {
	vec2 q = (f.p - vec2(cx, MINI_Y)) / 0.78;
	if (abs(q.x) > 0.09 + f.pad / 0.78 || abs(q.y) > 0.12 + f.pad / 0.78) {
		return;
	}
	float k = 0.085;
	float bulb = abs(q.x) - (0.012 + 0.045 * smoothstep(0.0, 0.07, abs(q.y)));
	float d_glass = max(bulb, abs(q.y) - k);
	part(acc, d_glass, ink_of(ROSE), mix(vec3(0.86, 0.90, 0.96), vec3(1.0), step(q.x, -0.012) * 0.6), f.ow * 0.7, f.px);
	float sand = step(-k, q.y) * step(q.y, -0.035) * cov(d_glass + f.ow * 0.3, f.px);
	over(acc, sand_color, sand);
	for (int j = 0; j < 2; j++) {
		float y = j == 0 ? 0.093 : -0.093;
		vec2 pq = q - vec2(0.0, y);
		part(acc, sd_round_box(pq, vec2(0.068, 0.014), 0.008), ink_of(ROSE), shade_mat(ROSE, normalize(vec3(0.0, pq.y / 0.014 * 0.6, 0.8)), 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
}

void rose_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.035, ROSE, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.052) - 0.005);
	inlay(acc, d, SILVER, rim * step(abs(q.x), 0.76), f);
	// 組み合う2つの銀の輪
	float r1 = abs(length(q - vec2(-0.030, 0.0)) - 0.040) - 0.009;
	float r2 = abs(length(q - vec2(0.030, 0.0)) - 0.040) - 0.009;
	inlay(acc, d, SILVER, cov(min(r1, r2), f.px), f);
	inlay(acc, d, mix(sand_color, vec3(1.0), 0.3), cov(r2, f.px) * step(0.0, q.y) * step(q.x, 0.03), f);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	twisted_post(acc, f, -TWIST_X);
	twisted_post(acc, f, TWIST_X);
	draw_collars(acc, f, SILVER, 1.0);
	rose_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		mini_hourglass(acc, f, -MINI_X);
		mini_hourglass(acc, f, MINI_X);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
