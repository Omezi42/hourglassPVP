shader_type canvas_item;
// 抜け道(バイパス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 薄紅の砂岩を積んだ枠。底板に小さなアーチの抜け穴が開き、天板の上の道標が回り道を指す。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 SANDSTONE = vec3(0.86, 0.66, 0.62);
const vec3 STONE_INK = vec3(0.36, 0.22, 0.22);
const vec3 SIGN_WOOD = vec3(0.56, 0.40, 0.24);
const float PILLAR_X = 0.69;
const float PILLAR_HALF = 0.066;
const vec2 SLAB_HALF = vec2(0.82, 0.088);

vec3 brick(vec2 p, vec3 base, float px) {
	float row = floor(p.y / 0.085);
	float bx = fract(p.x / 0.16 + mod(row, 2.0) * 0.5);
	float by = fract(p.y / 0.085);
	float joint = max(1.0 - smoothstep(0.0, 0.08, min(by, 1.0 - by)), 1.0 - smoothstep(0.0, 0.05, min(bx, 1.0 - bx)));
	vec3 c = base * (0.92 + 0.12 * hash21(vec2(floor(p.x / 0.16 + mod(row, 2.0) * 0.5), row)));
	return mix(c, base * 0.62, joint * smoothstep(0.03, 0.012, px));
}

void brick_pillar(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > PILLAR_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - PILLAR_HALF, f.ay - POST_H);
	float face = lx / PILLAR_HALF;
	vec3 n = normalize(vec3(face > 0.75 ? 0.6 : (face < -0.75 ? -0.6 : 0.0), 0.0, 0.8));
	part(acc, d, STONE_INK, brick(vec2(lx * 2.0, f.p.y), shade_mat(SANDSTONE, n, 0.0, 0.2, f.ao), f.px), f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.028), SANDSTONE * 0.82, 0.0);
}

void brick_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, SLAB_HALF, 0.02);
	// 底板の中央にアーチの抜け穴
	float d_arch = max(abs(q.x) - 0.075, -q.y - SLAB_HALF.y - 0.01);
	d_arch = max(d_arch, min(q.y - 0.010, length(q - vec2(0.0, 0.010)) - 0.075));
	float v = q.y / SLAB_HALF.y;
	vec3 n = normalize(vec3(0.0, smoothstep(0.5, 0.7, v) * 0.6 - smoothstep(0.5, 0.7, -v) * 0.6, 0.8));
	part(acc, d, STONE_INK, brick(q + vec2(0.0, cy), shade_mat(SANDSTONE, n, 0.0, 0.2, 1.0), f.px), f.ow, f.px);
	if (cy < 0.0) {
		over(acc, STONE_INK, cov(d_arch - f.ow * 0.6, f.px));
		over(acc, mix(vec3(0.10, 0.07, 0.08), sand_color * 0.45, smoothstep(0.06, -0.08, q.y)), cov(d_arch, f.px));
	} else {
		vec3 gn = normalize(vec3(q / 0.04 * 0.6, 0.8));
		part(acc, sd_rhombus(q, vec2(0.050, 0.040)), STONE_INK, shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
}

// 道標: 柱と、弧を描いて回り込む矢印の板
void signpost(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, 1.17);
	if (abs(q.x) > 0.24 + f.pad || q.y > 0.23 + f.pad || q.y < -f.pad) {
		return;
	}
	float d_pole = sd_round_box(q - vec2(0.0, 0.06), vec2(0.018, 0.06), 0.006);
	part(acc, d_pole, ink_of(SIGN_WOOD), shade_mat(SIGN_WOOD, normalize(vec3(q.x / 0.016 * 0.5, 0.0, 0.85)), 0.0, 0.5, 1.0), f.ow * 0.8, f.px);
	// 弧の矢印(左から上を回って右下へ)
	vec2 aq = q - vec2(0.0, 0.075);
	float r = length(aq);
	float ang = atan(aq.y, aq.x);
	float d_arc = max(abs(r - 0.115) - 0.028, -aq.y - 0.01);
	vec2 tip = vec2(0.115, -0.01);
	vec2 tq = aq - tip;
	float d_head = max(abs(tq.x) * 0.9 + tq.y, -tq.y - 0.065);
	float d = min(d_arc, d_head);
	vec3 c = shade_mat(mix(SIGN_WOOD, sand_color, 0.5), normalize(vec3(cos(ang) * 0.3, sin(ang) * 0.3, 0.85)), 0.0, 0.8, 1.0);
	part(acc, d, ink_of(SIGN_WOOD), c, f.ow * 0.9, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	brick_pillar(acc, f, -PILLAR_X);
	brick_pillar(acc, f, PILLAR_X);
	draw_collars(acc, f, SANDSTONE * 0.82, 0.0);
	brick_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		signpost(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
