shader_type canvas_item;
// 積み木(ブロック)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は色を交互にした四角い積み木を積んだもの、板は太い角材。天板の上に斜めから見た立方体の積み木。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 LILAC = vec3(0.62, 0.48, 0.78);
const vec3 CREAM = vec3(0.94, 0.88, 0.74);
const vec3 INK = vec3(0.22, 0.16, 0.28);
const float STACK_X = 0.68;
const float CUBE_HALF = 0.072;
const int CUBES = 7;
const vec2 SLAB_HALF = vec2(0.82, 0.084);
const vec2 TOP_CUBE = vec2(0.0, 1.262);

// 積み木1個: 面取りした正面と、中の彫り込み
void block_face(inout vec4 acc, Px f, vec2 c, float hs, vec3 col, int mark) {
	vec2 q = f.p - c;
	if (abs(q.x) > hs + f.pad || abs(q.y) > hs + f.pad) {
		return;
	}
	float d = sd_round_box(q, vec2(hs), 0.012);
	vec2 u = q / hs;
	vec3 n = normalize(vec3(smoothstep(0.75, 1.0, abs(u.x)) * sign(u.x) * 0.7, smoothstep(0.75, 1.0, abs(u.y)) * sign(u.y) * 0.7, 0.75));
	vec3 fill = shade_mat(col, n, 0.0, 0.7, f.ao);
	part(acc, d, INK, fill, f.ow, f.px);
	// 彫り込み: 丸・三角・菱を順に
	float dm = mark == 0 ? length(q) - hs * 0.40 : (mark == 1 ? max(abs(q.x) * 0.866 + q.y * 0.5, -q.y) - hs * 0.28 : sd_rhombus(q, vec2(hs * 0.42)));
	float rim = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(dm) - 0.006);
	over(acc, fill * 0.72, rim * cov(d, f.px));
}

void block_stack(inout vec4 acc, Px f, float cx) {
	if (abs(f.p.x - cx) > CUBE_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float span = 2.0 * POST_H / float(CUBES);
	int k = int(clamp(floor((f.p.y + POST_H) / span), 0.0, float(CUBES - 1)));
	for (int j = max(k - 1, 0); j <= min(k + 1, CUBES - 1); j++) {
		float y = -POST_H + span * (float(j) + 0.5);
		vec3 col = (j % 2 == 0) == (cx < 0.0) ? LILAC : CREAM;
		block_face(acc, f, vec2(cx, y), span * 0.5 - 0.004, col, j % 3);
	}
}

void beam_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, CREAM, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 薄紫の帯に並ぶ四角の窓
	inlay(acc, d, LILAC, step(abs(q.y), 0.042) * step(abs(q.x), 0.78), f);
	float cell = abs(fract(q.x / 0.13) - 0.5) * 0.13;
	inlay(acc, d, CREAM * 0.9, step(cell, 0.030) * step(abs(q.y), 0.022) * step(abs(q.x), 0.72), f);
	inlay(acc, d, mix(sand_color, CREAM, 0.2), step(abs(q.x), 0.030) * step(abs(q.y), 0.022), f);
}

// 斜めから見た立方体: 上・左・右の3面
void iso_cube(inout vec4 acc, Px f) {
	vec2 q = f.p - TOP_CUBE;
	float s = 0.112;
	if (abs(q.x) > s * 1.2 + f.pad || abs(q.y) > s * 1.3 + f.pad) {
		return;
	}
	vec2 a = vec2(0.866, 0.5) * s;
	vec2 b = vec2(-0.866, 0.5) * s;
	// 六角の外形
	vec2 h = abs(q);
	float d = max(h.x - 0.866 * s, h.x * 0.577 + h.y - s);
	float top = step(0.0, q.y - abs(q.x) * 0.577);
	vec3 col = top > 0.5 ? CREAM * 1.04 : (q.x < 0.0 ? LILAC : LILAC * 0.72);
	part(acc, d, INK, col, f.ow, f.px);
	float edges = min(min(sd_segment(q, vec2(0.0), vec2(0.0, -s)), sd_segment(q, vec2(0.0), a * vec2(1.0, 1.0) - vec2(0.0, 0.0))), sd_segment(q, vec2(0.0), b));
	over(acc, INK, cov(edges - max(0.005, f.px * 0.6), f.px) * cov(d, f.px));
	over(acc, mix(sand_color, CREAM, 0.15), cov(sd_ellipse((q - vec2(0.0, s * 0.5)) * vec2(1.0, 1.7), vec2(s * 0.30)), f.px));
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	block_stack(acc, f, -STACK_X);
	block_stack(acc, f, STACK_X);
	draw_collars(acc, f, LILAC * 0.8, 0.0);
	beam_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		iso_cube(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
