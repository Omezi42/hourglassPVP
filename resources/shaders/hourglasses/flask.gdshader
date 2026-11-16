shader_type canvas_item;
// 薬の瓶(フラスコ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は赤い薬を満たした試験管を真鍮の留め具で支えたもの。天板の上にひびの入った丸底の瓶。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.86, 0.66, 0.34);
const vec3 GLASSY = vec3(0.86, 0.92, 0.96);
const vec3 GLASS_INK = vec3(0.26, 0.32, 0.40);
const vec3 CORK = vec3(0.70, 0.52, 0.34);
const vec3 OAK = vec3(0.52, 0.36, 0.22);
const float TUBE_R = 0.050;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 FLASK_C = vec2(0.0, 1.232);

// 試験管: 硝子の中に砂の色の薬。上は栓、下は丸い底
void test_tube(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - TUBE_R, f.ay - POST_H);
	float u = clamp(lx / TUBE_R, -1.0, 1.0);
	float level = 0.55;
	vec3 inside = f.p.y < level ? mix(sand_color * 0.75, sand_color, smoothstep(0.6, -0.4, u)) : GLASSY * 0.82;
	part(acc, d, GLASS_INK, inside, f.ow, f.px);
	// 液面の明るい線と硝子の照り
	over(acc, mix(sand_color, vec3(1.0), 0.55), (1.0 - smoothstep(0.0, max(0.006, f.px), abs(f.p.y - level) - 0.006)) * cov(d, f.px));
	float shine = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(u + 0.5) * TUBE_R - 0.008);
	over(acc, vec3(1.0), shine * 0.7 * cov(d, f.px));
	// 気泡
	vec2 bq = vec2(lx - 0.012, fract(f.p.y * 3.0) / 3.0 - 0.15);
	over(acc, mix(sand_color, vec3(1.0), 0.6), cov(length(bq) - 0.010, f.px) * step(f.p.y, level - 0.05) * step(-0.95, f.p.y));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), CORK, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.62), vec2(0.072, 0.018), BRASS, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.072, 0.018), BRASS, 1.0);
}

void oak_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, OAK, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 薬の札: 生成りの紙に砂の色の十字
	float d_label = sd_round_box(q, vec2(0.15, 0.050), 0.008);
	inlay(acc, d, vec3(0.94, 0.88, 0.74), cov(d_label, f.px), f);
	float cross_d = min(max(abs(q.x) - 0.010, abs(q.y) - 0.032), max(abs(q.x) - 0.032, abs(q.y) - 0.010));
	inlay(acc, d, sand_color, cov(cross_d, f.px), f);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.058) - 0.005);
	inlay(acc, d, BRASS, rim * step(0.17, abs(q.x)) * step(abs(q.x), 0.76), f);
}

// 丸底の瓶: 首と栓、中に薬、ひびの線
void round_flask(inout vec4 acc, Px f) {
	vec2 q = f.p - FLASK_C;
	if (abs(q.x) > 0.12 + f.pad || abs(q.y) > 0.17 + f.pad) {
		return;
	}
	float d_body = length(q + vec2(0.0, 0.02)) - 0.085;
	float d_neck = sd_round_box(q - vec2(0.0, 0.080), vec2(0.026, 0.050), 0.006);
	float d = min(d_body, d_neck);
	vec3 c = q.y < -0.010 + 0.006 * sin(q.x * 60.0) ? mix(sand_color * 0.8, sand_color, smoothstep(0.05, -0.05, q.x)) : GLASSY * 0.85;
	part(acc, d, GLASS_INK, c, f.ow, f.px);
	over(acc, vec3(1.0), cov(sd_ellipse(q - vec2(-0.040, 0.010), vec2(0.012, 0.028)), f.px) * 0.85);
	float crack = min(sd_segment(q, vec2(0.050, 0.040), vec2(0.030, 0.000)), sd_segment(q, vec2(0.030, 0.000), vec2(0.055, -0.030)));
	over(acc, vec3(1.0), cov(crack - max(0.004, f.px * 0.5), f.px) * cov(d_body, f.px));
	vec2 cq = q - vec2(0.0, 0.135);
	part(acc, sd_round_box(cq, vec2(0.032, 0.022), 0.008), ink_of(CORK), shade_mat(CORK, normalize(vec3(cq.x / 0.03 * 0.6, 0.2, 0.8)), 0.0, 0.5, 1.0), f.ow * 0.8, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	test_tube(acc, f, -POST_X);
	test_tube(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	oak_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		round_flask(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
