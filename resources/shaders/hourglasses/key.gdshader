shader_type canvas_item;
// 飾り鍵(キー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は大きな飾り鍵そのもの: 天板の上へ輪の頭が抜け、下端に鍵の歯。板の中央に鍵穴。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.84, 0.66, 0.32);
const vec3 VELVET = vec3(0.48, 0.22, 0.52);
const float KEY_X = 0.68;
const float SHAFT_R = 0.036;
const float BOW_Y = 1.255;
const float BOW_R = 0.095;
const vec2 SLAB_HALF = vec2(0.78, 0.082);

void ornate_key(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.16 + f.pad || f.p.y < -1.05 - f.pad || f.p.y > BOW_Y + BOW_R + f.pad) {
		return;
	}
	vec3 ink = ink_of(BRASS);
	// 軸
	float d_shaft = max(abs(lx) - SHAFT_R, max(-0.98 - f.p.y, f.p.y - BOW_Y + BOW_R * 0.7));
	vec3 n = lathe_normal(clamp(lx / SHAFT_R, -1.0, 1.0), 0.0);
	part(acc, d_shaft, ink, shade_mat(BRASS, n, 1.0, 1.0, f.ao), f.ow, f.px);
	// 歯: 下端から外へ
	float out_dir = sign(cx);
	vec2 bq = vec2(lx * out_dir, f.p.y + 0.86);
	float d_bit = sd_round_box(bq - vec2(0.065, 0.0), vec2(0.040, 0.085), 0.006);
	d_bit = max(d_bit, -sd_round_box(bq - vec2(0.09, 0.0), vec2(0.020, 0.018), 0.003));
	d_bit = max(d_bit, -sd_round_box(bq - vec2(0.09, 0.050), vec2(0.020, 0.012), 0.003));
	part(acc, d_bit, ink, shade_mat(BRASS, normalize(vec3(0.0, 0.0, 1.0)), 1.0, 1.0, f.ao), f.ow, f.px);
	// 飾り輪
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.066, 0.020), BRASS, 1.0);
	draw_band(acc, f, vec2(cx, 0.955), vec2(0.072, 0.024), BRASS, 1.0);
	// 頭: 四つ葉の透かし輪と、中央の宝石
	vec2 hq = f.p - vec2(cx, BOW_Y);
	float r = length(hq);
	float a = atan(hq.y, hq.x);
	float lobe = BOW_R * (0.78 + 0.22 * abs(cos(a * 2.0)));
	float d_bow = max(r - lobe, -(r - lobe * 0.55));
	vec3 bn = normalize(vec3(hq / BOW_R * 0.6, 0.75));
	part(acc, d_bow, ink, shade_mat(BRASS, bn, 1.0, 1.0, 1.0), f.ow, f.px);
	vec3 gem = mix(sand_color * 0.75, mix(sand_color, vec3(1.0), 0.6), step(hq.x + hq.y, 0.0));
	part(acc, length(hq) - 0.030, ink, gem, f.ow * 0.7, f.px);
}

void velvet_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, VELVET, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.054) - 0.005);
	inlay(acc, d, BRASS, rim * step(abs(q.x), 0.74), f);
	// 真鍮の鍵穴の座金
	float d_plate = sd_ellipse(q, vec2(0.070, 0.056));
	inlay(acc, d, BRASS, cov(d_plate, f.px), f);
	float d_hole = min(length(q - vec2(0.0, 0.012)) - 0.016, max(abs(q.x) - 0.008 - (0.012 - q.y) * 0.15, max(q.y - 0.012, -q.y - 0.034)));
	inlay(acc, d, vec3(0.06), cov(d_hole, f.px), f);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	draw_collars(acc, f, BRASS, 1.0);
	velvet_slab(acc, f, f.side * PLATE_Y);
	ornate_key(acc, f, -KEY_X);
	ornate_key(acc, f, KEY_X);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
