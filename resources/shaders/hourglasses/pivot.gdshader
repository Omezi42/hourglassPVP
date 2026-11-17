shader_type canvas_item;
// 軸(ピボット)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱の中ほどに軸受け、天板の上に向きの違う2つの輪を組んだ回り台(ジンバル)。輪の中心に砂の色の玉。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEEL = vec3(0.68, 0.70, 0.76);
const vec3 PLUM = vec3(0.50, 0.18, 0.36);
const float POST_R = 0.044;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 GIMBAL = vec2(0.0, 1.245);
const float GIMBAL_K = 1.35;

// 横から見た輪(楕円の帯)。tilt で傾け、squash で潰す
float ring_d(vec2 q, float r, float squash, float tilt, float w) {
	vec2 rq = rot(q, tilt);
	return abs(length(rq / vec2(1.0, squash)) - r) * squash - w;
}

void pivot_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, PLUM, 0.2);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), STEEL, 1.0);
	// 中ほどの軸受け: 丸い座金と軸の頭
	vec2 q = f.p - vec2(cx, 0.0);
	if (length(q) < 0.10 + f.pad) {
		vec3 n = normalize(vec3(q / 0.09 * 0.5, 0.8));
		part(acc, length(q) - 0.085, ink_of(STEEL), shade_mat(STEEL, n, 1.0, 1.0, 1.0), f.ow, f.px);
		float d_slot = sd_round_box(rot(q, 0.6), vec2(0.040, 0.008), 0.004);
		over(acc, ink_of(STEEL), cov(d_slot, f.px));
	}
}

void plum_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, PLUM, 0.2, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.054) - 0.005);
	inlay(acc, d, STEEL, rim * step(abs(q.x), 0.76), f);
	// 回る向きを示す2つの弧の矢印
	float r = length(q);
	float ang = atan(q.y, q.x);
	float arc = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.7), abs(r - 0.040) - 0.006);
	inlay(acc, d, STEEL, arc * step(0.35, abs(sin(ang))), f);
	inlay(acc, d, sand_color, cov(r - 0.016, f.px), f);
}

// ジンバル: 外の輪は縦、内の輪は横に寝かせ、台座から立ち上がる
void gimbal(inout vec4 acc, Px f) {
	draw_column(acc, f, 0.0, 0.018, PLATE_Y + 0.07, GIMBAL.y - 0.08, STEEL, 1.0);
	vec2 q = (f.p - GIMBAL) / GIMBAL_K;
	if (abs(q.x) > 0.16 + f.pad || abs(q.y) > 0.14 + f.pad) {
		return;
	}
	f.px /= GIMBAL_K;
	f.ow /= GIMBAL_K;
	// 奥側の半分を先に、手前の半分を後に
	float d_outer = ring_d(q, 0.105, 0.35, 0.0, 0.010);
	float d_inner = ring_d(q, 0.078, 1.0, 0.0, 0.010);
	float d_tilted = ring_d(q, 0.090, 0.45, 0.9, 0.009);
	vec3 n = normalize(vec3(q / 0.1 * 0.5, 0.8));
	part(acc, d_inner, ink_of(STEEL), shade_mat(STEEL, n, 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	part(acc, d_tilted, ink_of(PLUM), shade_mat(mix(PLUM, STEEL, 0.4), n, 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	if (q.y < 0.0) {
		part(acc, d_outer, ink_of(STEEL), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
	vec3 gn = normalize(vec3(q / 0.035 * 0.6, 0.75));
	part(acc, length(q) - 0.032, ink_of(sand_color), shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
	if (q.y >= 0.0) {
		part(acc, d_outer, ink_of(STEEL), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	pivot_post(acc, f, -POST_X);
	pivot_post(acc, f, POST_X);
	draw_collars(acc, f, STEEL, 1.0);
	plum_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		gimbal(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
