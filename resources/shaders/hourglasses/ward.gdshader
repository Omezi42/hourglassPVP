shader_type canvas_item;
// 護り(ウォード)。GameDesign.md 9章 / Architecture.md 10.19節。
// 白木の柱にお札を貼り、天板の前に注連縄を渡して紙垂を垂らす。天板の上に小さな鈴。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 HINOKI = vec3(0.90, 0.80, 0.62);
const vec3 WOOD_INK = vec3(0.40, 0.28, 0.18);
const vec3 ROPE = vec3(0.86, 0.76, 0.52);
const vec3 PAPER = vec3(0.98, 0.97, 0.94);
const vec3 VERMILION = vec3(0.80, 0.26, 0.24);
const float POST_R = 0.050;
const vec2 SLAB_HALF = vec2(0.80, 0.080);

void hinoki_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(HINOKI, n, 0.0, 0.5, f.ao);
	part(acc, d, WOOD_INK, c, f.ow, f.px);
	// お札: 白い紙に朱の線と、砂の色の印
	vec2 tq = vec2(lx, f.p.y + 0.30);
	float d_tag = sd_round_box(tq, vec2(0.040, 0.15), 0.004);
	part(acc, d_tag, WOOD_INK, PAPER, f.ow * 0.6, f.px);
	float line = step(abs(tq.x), 0.006) * step(abs(tq.y), 0.11);
	over(acc, VERMILION, line * 0.85);
	over(acc, sand_color, cov(length(tq - vec2(0.0, 0.10)) - 0.018, f.px));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), VERMILION, 0.0);
}

void hinoki_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, HINOKI, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float grain = abs(fract(q.y * 26.0 + vnoise(q * vec2(2.0, 8.0)) * 0.8) - 0.5);
	inlay(acc, d, HINOKI * 0.86, (1.0 - smoothstep(0.05, 0.15, grain)) * 0.5 * smoothstep(0.03, 0.012, f.px), f);
}

// 注連縄: 撚った太い縄が天板の前でゆるく垂れ、紙垂を3か所に
void shimenawa(inout vec4 acc, Px f) {
	vec2 q = vec2(f.p.x, f.p.y - (PLATE_Y - 0.01));
	if (abs(q.x) > 0.80 + f.pad || q.y > 0.06 + f.pad || q.y < -0.24 - f.pad) {
		return;
	}
	float sag = -0.040 * (1.0 - pow(q.x / 0.78, 2.0));
	float d_rope = abs(q.y - sag) - 0.026 * (1.0 - 0.3 * pow(abs(q.x) / 0.78, 2.0));
	d_rope = max(d_rope, abs(q.x) - 0.78);
	float twist = fract((q.x + (q.y - sag) * 1.5) * 12.0);
	vec3 rc = mix(ROPE * 0.72, ROPE * 1.08, smoothstep(0.0, 0.4, twist) * (1.0 - smoothstep(0.6, 1.0, twist)));
	part(acc, d_rope, WOOD_INK, rc, f.ow, f.px);
	// 紙垂(稲妻形の白い紙)
	for (int k = -1; k <= 1; k++) {
		float x0 = float(k) * 0.42;
		vec2 sq = q - vec2(x0, -0.040 * (1.0 - pow(x0 / 0.78, 2.0)) - 0.02);
		float step_y = floor(-sq.y / 0.045);
		float off = mod(step_y, 2.0) * 0.022;
		float d_shide = max(abs(sq.x - off) - 0.020, max(sq.y, -sq.y - 0.18));
		part(acc, d_shide, WOOD_INK, mix(PAPER, PAPER * 0.88, step(0.0, sq.x - off)), f.ow * 0.6, f.px);
	}
}

// 天板の上の鈴と朱の紐
void bell(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, 1.245);
	if (abs(q.x) > 0.10 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	float d_cord = sd_segment(q, vec2(0.0, -0.07), vec2(0.0, 0.0)) - 0.010;
	part(acc, d_cord, ink_of(VERMILION), VERMILION, f.ow * 0.6, f.px);
	vec2 bq = q - vec2(0.0, 0.040);
	vec3 n = normalize(vec3(bq / 0.06 * 0.6, 0.75));
	part(acc, length(bq) - 0.058, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
	// 鈴の口(下半分の横の切れ目と、両端の丸)
	float slit = max(abs(bq.y + 0.018) - 0.006, abs(bq.x) - 0.042);
	slit = min(slit, length(vec2(abs(bq.x) - 0.042, bq.y + 0.018)) - 0.010);
	over(acc, ink_of(GOLD), cov(slit, f.px));
	over(acc, ink_of(GOLD) * 1.4, cov(abs(bq.y - 0.006) - 0.003, f.px) * cov(length(bq) - 0.052, f.px));
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	hinoki_post(acc, f, -POST_X);
	hinoki_post(acc, f, POST_X);
	draw_collars(acc, f, VERMILION, 0.0);
	hinoki_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > 0.7) {
		shimenawa(acc, f);
	}
	if (f.p.y > PLATE_Y) {
		bell(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
