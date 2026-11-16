shader_type canvas_item;
// 閉ざした門(ゲート)。GameDesign.md 9章 / Architecture.md 10.19節。
// 器の後ろに下ろした鉄の落とし格子。柱は角石の門柱、天板は要石を据えた門の楣。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRONZE = vec3(0.36, 0.52, 0.36);
const vec3 STONE = vec3(0.64, 0.66, 0.58);
const vec3 IRON = vec3(0.30, 0.32, 0.34);
const float PILLAR_X = 0.70;
const float PILLAR_HALF = 0.075;
const vec2 SLAB_HALF = vec2(0.86, 0.088);
const float BAR_GAP = 0.20;

// 落とし格子: 縦の鉄棒と横の帯、下端は尖る
void portcullis(inout vec4 acc, Px f) {
	vec2 p = f.p;
	if (abs(p.x) > 0.62 + f.pad || p.y > 1.02 || p.y < -0.98 - f.pad) {
		return;
	}
	float gx = (fract(p.x / BAR_GAP + 0.5) - 0.5) * BAR_GAP;
	float bar_w = 0.020;
	float tip = smoothstep(-0.98, -0.88, p.y);
	float d_v = abs(gx) - bar_w * tip;
	float gy = (fract(p.y / 0.36 + 0.25) - 0.5) * 0.36;
	float d_h = max(abs(gy) - 0.016, -0.86 - p.y);
	float d = min(d_v, d_h);
	d = max(d, abs(p.x) - 0.62);
	vec3 n = normalize(vec3(d_v < d_h ? gx / bar_w * 0.6 : 0.0, d_v < d_h ? 0.0 : gy / 0.016 * 0.6, 0.8));
	part(acc, d, vec3(0.06), shade_mat(IRON, n, 1.0, 0.8, 1.0), f.ow * 0.8, f.px);
	// 交点の鋲
	float rivet = length(vec2(gx, gy)) - 0.022;
	over(acc, shade_mat(BRONZE * 1.3, normalize(vec3(vec2(gx, gy) / 0.022 * 0.6, 0.8)), 1.0, 1.0, 1.0), cov(rivet, f.px) * step(-0.86, p.y));
}

// 角石を積んだ門柱
void gate_pillar(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > PILLAR_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - PILLAR_HALF, f.ay - POST_H);
	float course = fract(f.p.y / 0.17);
	float face = lx / PILLAR_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(STONE, n, 0.0, 0.15, f.ao);
	float joint = 1.0 - smoothstep(0.0, 0.09, min(course, 1.0 - course));
	c = mix(c, c * 0.62, joint * smoothstep(0.03, 0.012, f.px));
	c = mix(c, c * 0.88, step(0.6, vnoise(f.p * 20.0)) * 0.5);
	part(acc, d, ink_of(STONE), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.096, 0.030), BRONZE, 0.9);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.090, 0.024), BRONZE, 0.9);
}

void lintel(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, STONE, 0.0, 0.2);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + 0.06 + f.pad || abs(q.y) > SLAB_HALF.y + 0.06 + f.pad) {
		return;
	}
	float joint = step(abs(fract(q.x / 0.26 + 0.5) - 0.5) * 0.26, 0.005);
	inlay(acc, d, STONE * 0.6, joint, f);
	inlay(acc, d, BRONZE * 1.1, 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.058) - 0.006), f);
	// 要石: 青銅の縁に砂の色の宝玉
	vec2 kq = q * vec2(1.0, sign(cy));
	float d_key = max(abs(kq.x) - 0.07 - kq.y * 0.25, abs(kq.y - 0.012) - 0.105);
	vec3 kn = normalize(vec3(kq.x / 0.08 * 0.4, 0.2, 0.85));
	part(acc, d_key, ink_of(STONE), shade_mat(STONE * 1.05, kn, 0.0, 0.3, 1.0), f.ow, f.px);
	vec3 gn = normalize(vec3(kq / 0.04 * 0.6, 0.8));
	part(acc, length(kq - vec2(0.0, 0.012)) - 0.036, ink_of(BRONZE), shade_mat(sand_color, gn, 0.2, 1.0, 1.0), f.ow * 0.7, f.px);
}

// 格子は器の後ろ
void art_back(inout vec4 acc, Px f) {
	portcullis(acc, f);
}

void art_frame(inout vec4 acc, Px f) {
	gate_pillar(acc, f, -PILLAR_X);
	gate_pillar(acc, f, PILLAR_X);
	draw_collars(acc, f, BRONZE, 0.9);
	lintel(acc, f, f.side * PLATE_Y);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
