shader_type canvas_item;
// 触れてはならない光(グリム)。GameDesign.md 9章 / Architecture.md 10.19節。
// 黒い鉄の枠に棘の蔦が巻きつき、器の後ろから薄緑の光が滲む。板の中央に光る目玉石。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BLACK_IRON = vec3(0.24, 0.26, 0.28);
const vec3 VINE = vec3(0.20, 0.34, 0.20);
const float POST_R = 0.046;
const float VINE_AMP = 0.050;
const float VINE_FREQ = 2.4;
const vec2 SLAB_HALF = vec2(0.80, 0.080);

float vine_x(float y, float cx) {
	return VINE_AMP * sin(y * VINE_FREQ * 6.2832 + cx * 4.0);
}

// 鉄の柱に巻きつく棘の蔦
void thorn_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.15 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d_post = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	part(acc, d_post, vec3(0.05), shade_mat(BLACK_IRON, n, 1.0, 0.7, f.ao), f.ow, f.px);
	float vx = vine_x(f.p.y, cx);
	float front = cos(f.p.y * VINE_FREQ * 6.2832 + cx * 4.0);
	float d_vine = abs(lx - vx) - 0.016;
	d_vine = max(d_vine, f.ay - POST_H);
	float shade = 0.7 + 0.3 * step(0.0, front);
	part(acc, d_vine, vec3(0.04, 0.08, 0.04), VINE * shade * 1.3, f.ow * 0.8, f.px);
	// 棘: 蔦の外側の山ごとに1本
	float period = 1.0 / VINE_FREQ;
	float yk = (floor((f.p.y) / (period * 0.5)) + 0.5) * period * 0.5;
	float tx = vine_x(yk, cx);
	float out_dir = sign(tx);
	vec2 tq = vec2((lx - tx) * out_dir, f.p.y - yk);
	float t = clamp(tq.x / 0.07, 0.0, 1.0);
	float d_thorn = max(abs(tq.y - tq.x * 0.5) - 0.018 * (1.0 - t), max(-tq.x, tq.x - 0.07));
	part(acc, d_thorn, vec3(0.04, 0.08, 0.04), mix(VINE * 1.3, vec3(0.80, 0.85, 0.70), t), f.ow * 0.6, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.028), BLACK_IRON * 1.3, 1.0);
}

void iron_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, BLACK_IRON, 1.0, 0.7);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 板を這う棘の線
	float wave = 0.022 * sin(q.x * 18.0);
	float line = 1.0 - smoothstep(0.0, max(0.008, f.px), abs(q.y - wave) - 0.008);
	inlay(acc, d, VINE * 1.4, line * step(0.10, abs(q.x)) * step(abs(q.x), 0.74), f);
	// 光る目玉石
	vec2 eq = q / vec2(0.075, 0.048);
	float d_eye = (length(eq) - 1.0) * 0.048;
	part(acc, d_eye, vec3(0.05), mix(sand_color * 0.5, sand_color, smoothstep(0.9, 0.2, length(eq))), f.ow * 0.7, f.px);
	over(acc, vec3(0.04, 0.10, 0.04), cov(sd_ellipse(q, vec2(0.012, 0.036)), f.px));
}

// 器の後ろから滲む光
void art_back(inout vec4 acc, Px f) {
	float r = length(f.p * vec2(1.0, 0.72));
	float a = exp(-max(r - 0.50, 0.0) / 0.30) * smoothstep(0.25, 0.60, r);
	add_light(acc, mix(sand_color, vec3(1.0), 0.15), a * 0.85 * (0.55 + 0.45 * sand_top / 0.85) * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	thorn_post(acc, f, -POST_X);
	thorn_post(acc, f, POST_X);
	draw_collars(acc, f, BLACK_IRON * 1.3, 1.0);
	iron_slab(acc, f, f.side * PLATE_Y);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
