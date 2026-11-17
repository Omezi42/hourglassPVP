shader_type canvas_item;
// 焼き戻し(テンパー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は焼き戻しの色(藁色・銅色・紫・青)が帯になった鋼の角材。天板の上に砥石と、その上に寝かせた短い刃。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEEL = vec3(0.72, 0.74, 0.78);
const vec3 STONE = vec3(0.50, 0.46, 0.42);
const vec3 HILT = vec3(0.36, 0.24, 0.16);
const float BAR_HALF = 0.050;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 WHET = vec2(0.0, 1.225);

// 焼き戻しの色: 上から鋼・藁色・銅色・紫・青
vec3 temper_tint(float t) {
	vec3 c = STEEL;
	c = mix(c, vec3(0.92, 0.80, 0.50), smoothstep(0.10, 0.25, t));
	c = mix(c, vec3(0.80, 0.50, 0.30), smoothstep(0.30, 0.45, t));
	c = mix(c, vec3(0.50, 0.30, 0.56), smoothstep(0.50, 0.65, t));
	c = mix(c, vec3(0.30, 0.44, 0.78), smoothstep(0.70, 0.85, t));
	return c;
}

void tempered_bar(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > BAR_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - BAR_HALF, f.ay - POST_H);
	float face = lx / BAR_HALF;
	vec3 n = normalize(vec3(face > 0.6 ? 0.6 : (face < -0.6 ? -0.6 : 0.0), 0.0, 0.8));
	float t = clamp((POST_H - f.p.y) / (2.0 * POST_H), 0.0, 1.0);
	vec3 base = temper_tint(t);
	vec3 c = shade_mat(base, n, 1.0, 1.0, f.ao);
	// 研ぎ目の細い横筋
	float grind = abs(fract(f.p.y * 60.0 + lx * 3.0) - 0.5);
	c = mix(c, c * 0.9, (1.0 - smoothstep(0.1, 0.3, grind)) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(STEEL), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), HILT, 0.0);
}

void temper_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, STEEL * 0.8, 1.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 横に流れる焼き戻しの帯
	float t = clamp(q.x / 1.5 + 0.5, 0.0, 1.0);
	inlay(acc, d, temper_tint(t), step(abs(q.y), 0.030) * step(abs(q.x), 0.76), f);
	inlay(acc, d, sand_color, cov(sd_rhombus(q, vec2(0.040, 0.030)), f.px), f);
}

// 砥石と短い刃
void whetstone(inout vec4 acc, Px f) {
	vec2 q = (f.p - WHET) / 1.35;
	if (abs(q.x) > 0.24 + f.pad || abs(q.y) > 0.15 + f.pad) {
		return;
	}
	f.px /= 1.35;
	f.ow /= 1.35;
	float d_stone = sd_round_box(q - vec2(0.0, -0.01), vec2(0.15, 0.035), 0.010);
	vec3 sn = normalize(vec3(0.0, q.y > 0.0 ? 0.5 : -0.3, 0.8));
	vec3 sc = shade_mat(STONE, sn, 0.0, 0.2, 1.0);
	sc = mix(sc, sc * 0.85, step(0.7, vnoise(q * 60.0)));
	part(acc, d_stone, ink_of(STONE), sc, f.ow, f.px);
	// 刃: 斜めに寝かせ、根元から刃先へ焼き戻しの色
	vec2 bq = rot(q - vec2(-0.02, 0.060), -0.20);
	float t = clamp((bq.x + 0.17) / 0.30, 0.0, 1.0);
	float w = 0.022 * (1.0 - smoothstep(0.80, 1.0, t));
	float d_blade = max(abs(bq.y) - w - 0.002, max(-0.06 - bq.x, bq.x - 0.14));
	part(acc, d_blade, ink_of(STEEL), mix(temper_tint(1.0 - t), vec3(1.0), step(bq.y, -0.004) * 0.3), f.ow * 0.8, f.px);
	float d_hilt = sd_round_box(bq - vec2(-0.11, 0.0), vec2(0.050, 0.016), 0.008);
	part(acc, d_hilt, ink_of(HILT), HILT, f.ow * 0.8, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	tempered_bar(acc, f, -POST_X);
	tempered_bar(acc, f, POST_X);
	draw_collars(acc, f, HILT, 0.0);
	temper_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		whetstone(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
