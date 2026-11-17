shader_type canvas_item;
// 不寝番(ヴィジル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は見張りの槍、板には夜番の星。天板の上に一晩じゅう灯る角灯。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 NIGHT_WOOD = vec3(0.34, 0.30, 0.36);
const vec3 IRON = vec3(0.30, 0.31, 0.34);
const vec3 FLAME = vec3(1.0, 0.82, 0.46);
const float POST_R = 0.040;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 LANTERN = vec2(0.0, 1.196);
const float LANTERN_K = 1.25;

// 見張りの槍: 黒い柄に巻いた革、上端の槍の穂
void spear_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, NIGHT_WOOD, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), IRON, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.056, 0.060), mix(NIGHT_WOOD, sand_color, 0.35), 0.0);
	// 柄の巻き革の筋
	vec2 q = vec2(f.p.x - cx, f.p.y);
	float wrap = step(abs(fract(q.y / 0.024 + q.x * 8.0) - 0.5), 0.12) * step(abs(q.y), 0.058) * step(abs(q.x), 0.054);
	over(acc, NIGHT_WOOD * 0.6, wrap * 0.8);
	draw_band(acc, f, vec2(cx, 0.40), vec2(0.056, 0.014), IRON, 1.0);
	draw_band(acc, f, vec2(cx, -0.40), vec2(0.056, 0.014), IRON, 1.0);
}

void star_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, NIGHT_WOOD, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.054) - 0.005);
	inlay(acc, d, IRON * 1.6, rim * step(abs(q.x), 0.76), f);
	for (int k = -3; k <= 3; k++) {
		if (k == 0) {
			continue;
		}
		vec2 sq = q - vec2(float(k) * 0.20, 0.010 * float(k % 2));
		inlay(acc, d, mix(FLAME, vec3(1.0), 0.4), star4(sq, 0.040), f);
	}
	inlay(acc, d, sand_color, cov(length(q) - 0.032, f.px), f);
}

// 角灯: 鉄の枠、四面のガラス越しの炎、上の吊り輪
void lantern(inout vec4 acc, Px f) {
	vec2 q = (f.p - LANTERN) / LANTERN_K;
	if (abs(q.x) > 0.14 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= LANTERN_K;
	f.ow /= LANTERN_K;
	float d_base = sd_round_box(q - vec2(0.0, -0.085), vec2(0.085, 0.018), 0.006);
	float d_roof = sd_rhombus(q - vec2(0.0, 0.075), vec2(0.090, 0.040));
	d_roof = max(d_roof, -(q.y - 0.075));
	float d_glass = sd_round_box(q - vec2(0.0, -0.005), vec2(0.064, 0.066), 0.006);
	// 炎の明るいガラス
	vec2 fq = q - vec2(0.0, -0.020);
	float flame = cov(sd_ellipse(fq * vec2(1.0, 0.7) - vec2(0.0, 0.010), vec2(0.022, 0.030)), f.px);
	vec3 gc = mix(mix(FLAME, sand_color, 0.35) * 0.8, FLAME, exp(-dot(fq, fq) / 0.004));
	part(acc, d_glass, ink_of(IRON), gc, f.ow * 0.6, f.px);
	over(acc, vec3(1.0, 0.98, 0.90), flame);
	// 枠の縦桟
	float bars = step(abs(abs(q.x) - 0.064), 0.008) + step(abs(q.x), 0.006);
	over(acc, IRON, min(bars, 1.0) * step(abs(q.y + 0.005), 0.068));
	part(acc, d_base, vec3(0.05), shade_mat(IRON, normalize(vec3(0.0, 0.5, 0.8)), 1.0, 0.8, 1.0), f.ow * 0.8, f.px);
	part(acc, d_roof, vec3(0.05), shade_mat(IRON, normalize(vec3(q.x / 0.09 * 0.5, 0.5, 0.7)), 1.0, 0.8, 1.0), f.ow * 0.8, f.px);
	float d_ring = abs(length(q - vec2(0.0, 0.122)) - 0.018) - 0.006;
	part(acc, d_ring, vec3(0.05), IRON * 1.4, f.ow * 0.5, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - (LANTERN + vec2(0.0, -0.01));
	float halo = exp(-dot(q, q) / 0.018);
	add_light(acc, mix(FLAME, sand_color, 0.4), halo * 0.60);
}

void art_frame(inout vec4 acc, Px f) {
	spear_post(acc, f, -POST_X);
	spear_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	star_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		lantern(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
