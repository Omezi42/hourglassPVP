shader_type canvas_item;
// 詠唱(チャント)。GameDesign.md 9章 / Architecture.md 10.19節。
// 朱塗りの柱に房を下げ、板には経文の行を刻む。天板の上に座布団に据えたおりんと撞木。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 LACQUER = vec3(0.62, 0.18, 0.28);
const vec3 BLACK = vec3(0.14, 0.10, 0.12);
const vec3 BRASS = vec3(0.86, 0.68, 0.32);
const vec3 CUSHION = vec3(0.86, 0.46, 0.64);
const float POST_R = 0.046;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 BOWL = vec2(0.0, 1.225);

void tassel_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, LACQUER, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), BRASS, 1.0);
	draw_band(acc, f, vec2(cx, 0.40), vec2(0.064, 0.016), BRASS, 1.0);
	// 柱から外へ下がる房
	float out_dir = sign(cx);
	vec2 q = vec2((f.p.x - cx) * out_dir - POST_R - 0.012, f.p.y - 0.40);
	if (abs(q.x) < 0.05 + f.pad && q.y < 0.02 && q.y > -0.30) {
		float d_cord = max(abs(q.x) - 0.006, max(q.y, -q.y - 0.10));
		part(acc, d_cord, ink_of(CUSHION), CUSHION, f.ow * 0.5, f.px);
		vec2 tq = q - vec2(0.0, -0.10);
		float w = 0.012 + 0.025 * clamp(-tq.y / 0.16, 0.0, 1.0);
		float d_tassel = max(abs(tq.x) - w, max(tq.y, -tq.y - 0.16));
		float strand = abs(fract(tq.x / max(w, 0.001) * 3.0) - 0.5);
		part(acc, d_tassel, ink_of(CUSHION), mix(CUSHION * 0.8, mix(CUSHION, sand_color, 0.4), smoothstep(0.1, 0.4, strand)), f.ow * 0.6, f.px);
		draw_ball(acc, f, vec2(cx + out_dir * (POST_R + 0.012), 0.30), 0.016, BRASS, 1.0);
	}
}

void sutra_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, BLACK, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 経文: 縦に短い字の行が並ぶ
	float col_x = fract(q.x / 0.055);
	float glyph = step(abs(col_x - 0.5), 0.18) * step(abs(fract(q.y / 0.022) - 0.5), 0.30) * step(abs(q.y), 0.046);
	glyph *= step(0.25, hash21(floor(vec2(q.x / 0.055, q.y / 0.022))));
	inlay(acc, d, BRASS * 0.9, glyph * step(0.10, abs(q.x)) * step(abs(q.x), 0.74), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.032, f.px), f);
}

// おりん: 座布団の上の鉢と、立てかけた撞木
void singing_bowl(inout vec4 acc, Px f) {
	vec2 q = f.p - BOWL;
	if (abs(q.x) > 0.22 + f.pad || abs(q.y) > 0.15 + f.pad) {
		return;
	}
	float d_cushion = sd_round_box(q - vec2(0.0, -0.045), vec2(0.13, 0.028), 0.024);
	part(acc, d_cushion, ink_of(CUSHION), shade_mat(CUSHION, normalize(vec3(q.x / 0.13 * 0.4, 0.5, 0.75)), 0.0, 0.5, 1.0), f.ow * 0.8, f.px);
	vec2 bq = q - vec2(0.0, 0.040);
	float d_bowl = max(length(bq * vec2(1.0, 1.25)) - 0.090, bq.y);
	vec3 n = normalize(vec3(bq.x / 0.09 * 0.8, -0.2, 0.6));
	part(acc, d_bowl, ink_of(BRASS), shade_mat(BRASS, n, 1.0, 1.0, 1.0), f.ow, f.px);
	part(acc, sd_ellipse(bq, vec2(0.090, 0.014)), ink_of(BRASS), BRASS * 0.6, f.ow * 0.7, f.px);
	// 撞木
	float d_stick = sd_segment(q, vec2(0.11, -0.03), vec2(0.20, 0.06)) - 0.012;
	part(acc, d_stick, ink_of(LACQUER), LACQUER, f.ow * 0.7, f.px);
	draw_ball(acc, f, BOWL + vec2(0.20, 0.06), 0.024, mix(CUSHION, sand_color, 0.3), 0.0);
}

// おりんの響き(小さな弧)
void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - (BOWL + vec2(0.0, 0.05));
	float r = length(q);
	float a = 0.0;
	for (int k = 1; k <= 2; k++) {
		a = max(a, 1.0 - smoothstep(0.0, max(0.006, f.px), abs(r - 0.06 - 0.030 * float(k)) - 0.005));
	}
	a *= step(0.02, q.y) * step(abs(q.x), 0.08);
	add_light(acc, mix(sand_color, vec3(1.0), 0.4), a * 0.8);
}

void art_frame(inout vec4 acc, Px f) {
	tassel_post(acc, f, -POST_X);
	tassel_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	sutra_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		singing_bowl(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
