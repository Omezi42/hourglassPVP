shader_type canvas_item;
// 麦の束(グレイン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 麦わらを束ねた柱を緑の紐で縛り、天板の上に麦の穂を3本挿す。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STRAW = vec3(0.90, 0.74, 0.40);
const vec3 STRAW_DARK = vec3(0.62, 0.45, 0.20);
const vec3 TWINE = vec3(0.24, 0.62, 0.32);
const vec3 WOOD = vec3(0.56, 0.40, 0.22);
const float STALK_R = 0.028;
const float BUNDLE_HALF = 0.078;
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const int KERNELS = 7;

// 束ねた麦わら3本(中央が手前)
void straw_bundle(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > BUNDLE_HALF + 0.03 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	for (int k = 0; k < 3; k++) {
		float ox = (float(k == 2 ? 1 : k) - 0.5) * 2.0 * (BUNDLE_HALF - STALK_R);
		if (k == 2) {
			ox = 0.0;
		}
		float sx = lx - ox;
		float d = max(abs(sx) - STALK_R, f.ay - POST_H);
		vec3 n = lathe_normal(clamp(sx / STALK_R, -1.0, 1.0), 0.0);
		vec3 c = shade_mat(k == 2 ? STRAW : STRAW * 0.92, n, 0.0, 0.7, f.ao);
		// 麦わらの節
		float node = 1.0 - smoothstep(0.0, max(0.008, f.px), abs(fract(f.ay * 2.6 + float(k) * 0.37) - 0.5) * 0.38 - 0.006);
		c = mix(c, STRAW_DARK, node * 0.55);
		part(acc, d, ink_of(STRAW_DARK), c, f.ow * 0.8, f.px);
	}
	// 緑の紐で3か所を縛る
	for (int j = 0; j < 3; j++) {
		float y = j == 0 ? 0.0 : (j == 1 ? 0.62 : -0.62);
		vec2 q = vec2(lx, f.p.y - y);
		float d = sd_round_box(q, vec2(BUNDLE_HALF + 0.012, 0.030), 0.018);
		float twist = abs(fract((q.x * 0.6 - q.y) * 22.0) - 0.5);
		vec3 n = normalize(vec3(q.x / BUNDLE_HALF * 0.8, q.y / 0.03 * 0.5, 0.7));
		vec3 c = shade_mat(TWINE, n, 0.0, 0.4, 1.0);
		c = mix(c * 0.72, c, smoothstep(0.1, 0.3, twist) * smoothstep(0.03, 0.012, f.px) + (1.0 - smoothstep(0.03, 0.012, f.px)));
		part(acc, d, ink_of(TWINE), c, f.ow, f.px);
	}
}

// 麦の穂1本。根元 base から角度 ang(右回りが正)へ伸びる。
void wheat_ear(inout vec4 acc, Px f, vec2 base, float ang, float len) {
	vec2 q = rot(f.p - base, ang);
	if (abs(q.x) > 0.10 + f.pad || q.y < -f.pad || q.y > len + 0.08 + f.pad) {
		return;
	}
	float d_stem = sd_segment(q, vec2(0.0), vec2(0.0, len)) - 0.010;
	part(acc, d_stem, ink_of(STRAW_DARK), STRAW_DARK * 1.15, f.ow * 0.7, f.px);
	// 粒は穂先へ向けて小さく、左右交互に
	for (int k = 0; k < KERNELS; k++) {
		float t = float(k) / float(KERNELS - 1);
		float y = mix(len * 0.40, len, t);
		float sx = (k % 2 == 0) ? -1.0 : 1.0;
		vec2 c = vec2(sx * 0.024 * (1.0 - t * 0.5), y);
		vec2 kq = rot(q - c, sx * 0.35);
		vec2 kr = vec2(0.022, 0.038) * (1.0 - t * 0.35);
		float d = sd_ellipse(kq, kr);
		vec3 n = normalize(vec3(kq / kr * 0.7, 0.7));
		part(acc, d, ink_of(STRAW_DARK), shade_mat(STRAW, n, 0.0, 0.8, 1.0), f.ow * 0.7, f.px);
	}
	// 芒(のぎ)
	float awn = sd_segment(q, vec2(0.0, len), vec2(0.0, len + 0.06)) - 0.004;
	over(acc, STRAW_DARK, cov(awn, f.px));
}

void straw_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.04, WOOD, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 板に巻いた麦わらの帯と、緑の紐の結び目
	float band = step(abs(q.y), 0.040);
	float weave = abs(fract((q.x + abs(q.y) * 1.6) * 11.0) - 0.5);
	vec3 straw = mix(STRAW_DARK, STRAW, smoothstep(0.05, 0.35, weave));
	inlay(acc, d, straw, band, f);
	float knot = cov(sd_ellipse(q, vec2(0.060, 0.050)), f.px);
	inlay(acc, d, TWINE, knot, f);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	straw_bundle(acc, f, -POST_X);
	straw_bundle(acc, f, POST_X);
	draw_collars(acc, f, WOOD, 0.0);
	straw_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		vec2 root = vec2(0.0, PLATE_Y + SLAB_HALF.y - 0.01);
		wheat_ear(acc, f, root + vec2(0.05, 0.0), 1.22, 0.38);
		wheat_ear(acc, f, root - vec2(0.05, 0.0), -1.22, 0.38);
		wheat_ear(acc, f, root + vec2(0.02, 0.0), 0.62, 0.20);
		wheat_ear(acc, f, root - vec2(0.02, 0.0), -0.62, 0.20);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
