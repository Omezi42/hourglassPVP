shader_type canvas_item;
// 方尖塔(オベリスク)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は象形の刻まれた黒い花崗岩、板には刻文の帯。天板の上に金の頂を戴き、刻文が砂の色に光るオベリスク。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 GRANITE = vec3(0.34, 0.31, 0.40);
const vec3 SANDSTONE = vec3(0.78, 0.66, 0.48);
const float POST_HALF = 0.058;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec2 OBELISK = vec2(0.0, 1.120);
const float SHAFT_H = 0.166;

// 象形の刻文: 格子の升ごとに縦線・横線・丸・目のどれかを彫る
float glyph(vec2 g, float salt) {
	vec2 cell = floor(g);
	vec2 u = fract(g) - 0.5;
	float h = hash21(cell + salt);
	if (h < 0.25) {
		return step(abs(u.x), 0.10) * step(abs(u.y), 0.34);
	}
	if (h < 0.5) {
		return step(abs(abs(u.y) - 0.18), 0.08) * step(abs(u.x), 0.32);
	}
	if (h < 0.75) {
		return step(abs(length(u) - 0.24), 0.08);
	}
	return step(abs(length(u * vec2(1.0, 2.2)) - 0.30), 0.09) + step(length(u), 0.08);
}

void granite_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + 0.02 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	// 上へ行くほど細くなる角柱
	float half_w = POST_HALF * (1.0 - 0.10 * (f.ay / POST_H));
	float d = max(abs(lx) - half_w, f.ay - POST_H);
	float face = lx / half_w;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(GRANITE * (0.92 + 0.12 * vnoise(f.p * 60.0)), n, 0.0, 0.6, f.ao);
	// 柱の正面に縦一列の刻文
	vec2 g = vec2(lx / 0.050 + 0.5, f.p.y / 0.050);
	float carve = glyph(g, cx * 7.0) * step(abs(lx), half_w * 0.62) * step(abs(f.p.y), 0.78);
	c = mix(c, mix(GRANITE * 0.4, sand_color, 0.8), carve * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(GRANITE), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.086, 0.028), SANDSTONE, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.905), vec2(0.070, 0.012), GOLD, 1.0);
}

void inscribed_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, SANDSTONE, 0.0, 0.4);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.062) - 0.004);
	inlay(acc, d, SANDSTONE * 0.55, rim * step(abs(q.x), 0.78), f);
	// 横一列の刻文(中央の円盤の左右)
	float carve = glyph(vec2(q.x / 0.060, q.y / 0.060 + 0.5), cy) * step(abs(q.y), 0.034);
	inlay(acc, d, SANDSTONE * 0.45, carve * step(0.10, abs(q.x)) * step(abs(q.x), 0.74), f);
	// 太陽の円盤
	inlay(acc, d, GOLD, cov(length(q) - 0.040, f.px), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.026, f.px), f);
}

// オベリスク: 段の台座、細る角柱、金の頂(ピラミディオン)、光る刻文
void obelisk_tower(inout vec4 acc, Px f) {
	vec2 q = f.p - OBELISK;
	if (abs(q.x) > 0.14 + f.pad || q.y > SHAFT_H + 0.07 + f.pad || q.y < -0.02 - f.pad) {
		return;
	}
	// 台座の2段
	part(acc, sd_round_box(q - vec2(0.0, 0.012), vec2(0.124, 0.012), 0.003), ink_of(SANDSTONE), shade_mat(SANDSTONE, normalize(vec3(0.0, 0.5, 0.8)), 0.0, 0.4, 1.0), f.ow * 0.7, f.px);
	part(acc, sd_round_box(q - vec2(0.0, 0.034), vec2(0.096, 0.011), 0.003), ink_of(SANDSTONE), shade_mat(SANDSTONE * 0.92, normalize(vec3(0.0, 0.5, 0.8)), 0.0, 0.4, 1.0), f.ow * 0.7, f.px);
	// 角柱: 左面は明るく右面は影
	float sy = q.y - 0.045;
	float t = clamp(sy / SHAFT_H, 0.0, 1.0);
	float half_w = mix(0.066, 0.044, t);
	float d_shaft = max(abs(q.x) - half_w, max(-sy, sy - SHAFT_H));
	vec3 n = normalize(vec3(q.x < 0.0 ? -0.35 : 0.45, 0.0, 0.85));
	vec3 c = shade_mat(GRANITE * 0.85 * (0.95 + 0.10 * vnoise(q * 70.0)), n, 0.0, 0.7, 1.0);
	float ridge = 1.0 - smoothstep(0.0, max(0.003, f.px), abs(q.x) - 0.0015);
	c = mix(c, GRANITE * 1.6, ridge * 0.5);
	// 刻文は砂の色に光る
	vec2 g = vec2(q.x / (half_w * 0.9) * 0.5 + 0.5, sy / 0.030);
	float carve = glyph(g, 3.0) * step(abs(q.x), half_w * 0.62) * step(0.012, sy) * step(sy, SHAFT_H - 0.018);
	c = mix(c, mix(sand_color, vec3(1.0), 0.25), carve);
	part(acc, d_shaft, ink_of(GRANITE), c, f.ow, f.px);
	// 金の頂
	float py = sy - SHAFT_H;
	float d_cap = max(abs(q.x) * 0.95 + py - 0.042, -py);
	part(acc, d_cap, ink_of(GOLD), shade_mat(GOLD, normalize(vec3(q.x < 0.0 ? -0.5 : 0.5, 0.4, 0.75)), 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
}

// 頂の輝きと、落砂で四方へ走る衝撃の輪
void art_back(inout vec4 acc, Px f) {
	vec2 tip = OBELISK + vec2(0.0, 0.045 + SHAFT_H + 0.022);
	vec2 q = f.p - tip;
	float a = atan(q.y, q.x);
	float rays = smoothstep(0.55, 1.0, cos(a * 9.0)) * smoothstep(0.30, 0.04, length(q)) * step(-0.12, q.y);
	add_light(acc, mix(sand_color, vec3(1.0), 0.3), exp(-dot(q, q) / 0.004) * 0.6 + star4(q, 0.10) * 0.6 + rays * 0.45);
	vec2 bq = (f.p - (OBELISK + vec2(0.0, 0.03))) * vec2(1.0, 3.2);
	float r = length(bq);
	float wave = 0.0;
	for (int k = 1; k <= 2; k++) {
		wave += (1.0 - smoothstep(0.0, 0.020, abs(r - 0.13 * float(k)))) * (0.6 / float(k));
	}
	add_light(acc, sand_color, wave * step(0.0, f.p.y - PLATE_Y) * smoothstep(0.36, 0.20, r));
}

void art_frame(inout vec4 acc, Px f) {
	granite_post(acc, f, -POST_X);
	granite_post(acc, f, POST_X);
	draw_collars(acc, f, SANDSTONE, 0.0);
	inscribed_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		obelisk_tower(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
