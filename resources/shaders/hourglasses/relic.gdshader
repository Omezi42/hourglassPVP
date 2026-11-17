shader_type canvas_item;
// 聖遺物(レリック)。GameDesign.md 9章 / Architecture.md 10.19節。
// 古びた大理石の柱に金の透かし細工、板には古い碑文。天板の上に後光を負った聖遺物箱。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 MARBLE = vec3(0.86, 0.84, 0.80);
const vec3 VEIN = vec3(0.56, 0.54, 0.58);
const vec3 VELVET = vec3(0.36, 0.14, 0.24);
const float POST_R = 0.050;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 CASKET = vec2(0.0, 1.210);
const float CASKET_K = 1.15;

void marble_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(MARBLE, n, 0.0, 0.9, f.ao);
	// 大理石の筋
	float vein = abs(sin((f.p.y * 3.0 + lx * 9.0) + vnoise(f.p * vec2(10.0, 3.0)) * 4.0));
	c = mix(c, VEIN, (1.0 - smoothstep(0.0, 0.10, vein)) * 0.6 * smoothstep(0.03, 0.012, f.px));
	// 古びた欠け
	c *= 1.0 - 0.18 * step(0.82, vnoise(f.p * 14.0 + cx));
	part(acc, d, ink_of(MARBLE * 0.6), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), GOLD, 1.0);
	// 金の透かし細工の帯と、砂の色の石
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.064, 0.050), GOLD, 1.0);
	vec2 q = vec2(lx, f.p.y);
	float lattice = step(0.30, abs(fract((q.x + q.y) * 30.0) - 0.5)) * step(0.30, abs(fract((q.x - q.y) * 30.0) - 0.5));
	over(acc, GOLD * 0.45, (1.0 - lattice) * step(abs(q.x), 0.058) * step(abs(q.y), 0.044) * smoothstep(0.03, 0.012, f.px));
	draw_ball(acc, f, vec2(cx, 0.0), 0.022, sand_color, 1.0);
}

void inscription_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, MARBLE, 0.0, 0.9);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 碑文: 古い字の行と金の縁
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.056) - 0.005);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.76), f);
	vec2 g = vec2(q.x / 0.040, q.y / 0.034 + 0.5);
	float glyph = step(abs(fract(g.x) - 0.5), 0.26) * step(abs(fract(g.y) - 0.5), 0.30) * step(abs(q.y), 0.036);
	glyph *= step(0.35, hash21(floor(g)));
	inlay(acc, d, VEIN * 0.7, glyph * step(0.10, abs(q.x)) * step(abs(q.x), 0.72), f);
	inlay(acc, d, GOLD, cov(length(q) - 0.036, f.px), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.024, f.px), f);
}

// 聖遺物箱: 丸い屋根の金の箱、ビロードの台、正面に砂の色の宝石
void reliquary(inout vec4 acc, Px f) {
	vec2 q = (f.p - CASKET) / CASKET_K;
	if (abs(q.x) > 0.20 + f.pad || abs(q.y) > 0.17 + f.pad) {
		return;
	}
	f.px /= CASKET_K;
	f.ow /= CASKET_K;
	part(acc, sd_round_box(q - vec2(0.0, -0.080), vec2(0.140, 0.018), 0.008), ink_of(VELVET), VELVET, f.ow * 0.8, f.px);
	float d_box = sd_round_box(q - vec2(0.0, -0.025), vec2(0.105, 0.040), 0.008);
	vec3 n = normalize(vec3(q.x / 0.105 * 0.5, 0.2, 0.85));
	part(acc, d_box, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
	// 屋根: 半円の蓋と頂きの十字
	vec2 lq = q - vec2(0.0, 0.015);
	float d_lid = max(length(lq * vec2(1.0, 1.6)) - 0.105, -lq.y);
	part(acc, d_lid, ink_of(GOLD), shade_mat(GOLD * 0.9, normalize(vec3(lq / 0.1 * 0.6, 0.7)), 1.0, 1.0, 1.0), f.ow, f.px);
	vec2 cq = q - vec2(0.0, 0.100);
	float d_cross = min(sd_round_box(cq, vec2(0.008, 0.030), 0.003), sd_round_box(cq - vec2(0.0, 0.006), vec2(0.022, 0.008), 0.003));
	part(acc, d_cross, ink_of(GOLD), GOLD, f.ow * 0.6, f.px);
	// 箱の縁飾りと宝石
	float trim = step(abs(abs(q.y + 0.025) - 0.030), 0.004) * step(abs(q.x), 0.10);
	over(acc, GOLD * 0.55, trim * cov(d_box, f.px));
	draw_ball(acc, f, CASKET + vec2(0.0, -0.025) * CASKET_K, 0.024 * CASKET_K, sand_color, 1.0);
	for (int s = -1; s <= 1; s += 2) {
		draw_ball(acc, f, CASKET + vec2(float(s) * 0.065, -0.025) * CASKET_K, 0.012 * CASKET_K, mix(VELVET, vec3(1.0), 0.3), 1.0);
	}
}

// 後光
void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - (CASKET + vec2(0.0, 0.03));
	float r = length(q);
	float a = atan(q.y, q.x);
	float rays = smoothstep(0.55, 1.0, cos(a * 12.0)) * smoothstep(0.30, 0.12, r) * step(0.0, q.y + 0.02);
	add_light(acc, mix(GOLD, sand_color, 0.4), rays * 0.6 + exp(-r * r / 0.006) * 0.35);
}

void art_frame(inout vec4 acc, Px f) {
	marble_post(acc, f, -POST_X);
	marble_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	inscription_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		reliquary(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
