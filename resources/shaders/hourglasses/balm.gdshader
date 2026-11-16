shader_type canvas_item;
// 軟膏(バーム)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は白い包帯を巻いた木、板は薬草の葉を押した蜜蝋色の木。天板の上に蓋をずらした軟膏の壺。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 LINEN = vec3(0.96, 0.94, 0.88);
const vec3 LINEN_SHADE = vec3(0.78, 0.74, 0.66);
const vec3 WOOD = vec3(0.78, 0.64, 0.42);
const vec3 HERB = vec3(0.46, 0.66, 0.36);
const vec3 TIN = vec3(0.76, 0.78, 0.80);
const float POST_R = 0.054;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 JAR = vec2(0.0, 1.228);

void bandaged_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	// 斜めに巻いた包帯の重なり
	float turn = fract((f.p.y - lx * 0.6) * 7.0);
	vec3 c = mix(LINEN_SHADE, LINEN, smoothstep(0.0, 0.25, turn));
	c *= 0.72 + 0.32 * clamp(dot(n, LIGHT_DIR) + 0.3, 0.0, 1.0);
	float weave = step(0.5, fract(lx * 90.0)) * smoothstep(0.03, 0.012, f.px);
	c = mix(c, c * 0.94, weave);
	part(acc, d, ink_of(LINEN_SHADE), c * f.ao, f.ow, f.px);
	// 巻き終わりの留め布
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.070, 0.020), mix(HERB, sand_color, 0.3), 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), WOOD, 0.0);
}

void herb_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.035, WOOD, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 押し葉を左右に、中央に砂の色の蜜の滴
	for (int k = -2; k <= 2; k++) {
		if (k == 0) {
			continue;
		}
		vec2 lq = rot(q - vec2(float(k) * 0.30, 0.0), float(k) * 0.4 + 1.5708);
		float t = clamp(lq.y / 0.12 + 0.5, 0.0, 1.0);
		float d_leaf = max(abs(lq.x) - 0.030 * sin(3.1416 * t), abs(lq.y) - 0.06);
		inlay(acc, d, mix(HERB, HERB * 1.3, step(0.0, lq.x)), cov(d_leaf, f.px), f);
	}
	vec3 gn = normalize(vec3(q / 0.04 * 0.6, 0.8));
	part(acc, length(q) - 0.036, ink_of(WOOD), shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
}

// 軟膏の壺: 低い円筒、少しずらした蓋、縁からのぞく軟膏
void jar(inout vec4 acc, Px f) {
	vec2 q = f.p - JAR;
	if (abs(q.x) > 0.16 + f.pad || abs(q.y) > 0.15 + f.pad) {
		return;
	}
	float d_body = sd_round_box(q - vec2(0.0, -0.02), vec2(0.12, 0.050), 0.018);
	vec3 n = normalize(vec3(q.x / 0.12 * 0.8, 0.0, 0.6));
	vec3 c = shade_mat(TIN, n, 1.0, 1.0, 1.0);
	float label = step(abs(q.y + 0.02), 0.022);
	c = mix(c, LINEN * 0.95, label);
	part(acc, d_body, ink_of(TIN), c, f.ow, f.px);
	over(acc, HERB, cov(sd_rhombus(q - vec2(0.0, -0.02), vec2(0.022, 0.016)), f.px) * label);
	// のぞく軟膏
	float d_salve = sd_ellipse(q - vec2(0.0, 0.035), vec2(0.105, 0.020));
	part(acc, d_salve, ink_of(sand_color), mix(sand_color, vec3(1.0), 0.35), f.ow * 0.7, f.px);
	// ずらした蓋
	vec2 lq = rot(q - vec2(0.05, 0.075), -0.25);
	float d_lid = sd_round_box(lq, vec2(0.115, 0.018), 0.012);
	part(acc, d_lid, ink_of(TIN), shade_mat(TIN, normalize(vec3(lq.x / 0.12 * 0.5, 0.4, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	bandaged_post(acc, f, -POST_X);
	bandaged_post(acc, f, POST_X);
	draw_collars(acc, f, WOOD, 0.0);
	herb_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		jar(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
