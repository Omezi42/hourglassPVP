shader_type canvas_item;
// 均す者(イコライザー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は光の目盛りが積み上がる音量計、板には並んだつまみ。天板の上に高さのそろった光の棒が5本。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEEL = vec3(0.30, 0.33, 0.38);
const vec3 PANEL = vec3(0.12, 0.13, 0.17);
const vec3 KNOB = vec3(0.78, 0.80, 0.84);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float RAIL_HALF = 0.058;
const float SEG_PITCH = 0.072;
const float SEG_GAP = 0.018;
const vec2 METER = vec2(0.0, 1.262);
const float METER_K = 1.3;

// 音量計の柱: 暗い鋼の筐体に、中央から端へ向けて灯る目盛り。左右で灯る高さが違う
void meter_post(inout vec4 acc, Px f, float cx, float lit_to) {
	float lx = f.p.x - cx;
	if (abs(lx) > RAIL_HALF + 0.04 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = sd_round_box(vec2(lx, f.ay - POST_H * 0.5), vec2(RAIL_HALF, POST_H * 0.5), 0.012);
	vec3 n = normalize(vec3(lx / RAIL_HALF * 0.5, 0.0, 0.85));
	vec3 c = shade_mat(PANEL, n, 0.4, 0.8, f.ao);
	// 目盛り(1段ずつの光る板)
	float k = floor(f.ay / SEG_PITCH);
	float in_seg = step(SEG_GAP, f.ay - k * SEG_PITCH) * step(abs(lx), RAIL_HALF - 0.016);
	float lit = step(k * SEG_PITCH, lit_to) * step(f.ay, POST_H - 0.06);
	vec3 hot = mix(sand_color, vec3(1.0), 0.25 * step(lit_to - SEG_PITCH, k * SEG_PITCH));
	c = mix(c, mix(PANEL * 1.6, hot, lit), in_seg * step(f.ay, POST_H - 0.06));
	part(acc, d, ink_of(STEEL), c, f.ow, f.px);
	add_light(acc, sand_color, lit * in_seg * 0.25 * (1.0 - smoothstep(0.0, 0.05, abs(lx) - RAIL_HALF + 0.016)));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), STEEL, 0.8);
}

void knob_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, STEEL, 0.7, 0.9);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	inlay(acc, d, PANEL, cov(sd_round_box(q, vec2(0.70, 0.050), 0.02), f.px), f);
	for (int k = -3; k <= 3; k++) {
		vec2 kq = q - vec2(float(k) * 0.19, 0.0);
		float d_knob = length(kq) - 0.030;
		vec3 kn = normalize(vec3(kq / 0.03 * 0.6, 0.8));
		inlay(acc, d, shade_mat(KNOB, kn, 0.8, 1.0, 1.0), cov(d_knob, f.px), f);
		// つまみの向き(すべて同じ向きにそろう)
		float tick = max(abs(kq.x) - 0.004, abs(kq.y - 0.016) - 0.012);
		inlay(acc, d, sand_color, cov(tick, f.px), f);
	}
}

// 高さのそろった光の棒5本を収めた小さな表示器
void level_meter(inout vec4 acc, Px f) {
	vec2 q = (f.p - METER) / METER_K;
	if (abs(q.x) > 0.17 + f.pad || abs(q.y) > 0.09 + f.pad) {
		return;
	}
	f.px /= METER_K;
	f.ow /= METER_K;
	float d_box = sd_round_box(q, vec2(0.150, 0.070), 0.016);
	part(acc, d_box, ink_of(STEEL), shade_mat(PANEL, normalize(vec3(q.x * 2.0, q.y * 3.0, 0.9)), 0.4, 0.8, 1.0), f.ow, f.px);
	for (int k = -2; k <= 2; k++) {
		vec2 bq = q - vec2(float(k) * 0.052, -0.014);
		float seg = step(0.006, fract((bq.y + 0.06) / 0.022) * 0.022);
		float d_bar = sd_round_box(bq, vec2(0.016, 0.040), 0.003);
		over(acc, mix(sand_color, vec3(1.0), 0.3), cov(d_bar, f.px) * seg);
		add_light(acc, sand_color, cov(d_bar - 0.02, f.px) * 0.18);
	}
	// 棒の頭をそろえる1本の線
	float d_line = max(abs(q.y - 0.034) - 0.0025, abs(q.x) - 0.135);
	over(acc, vec3(1.0, 0.98, 0.92), cov(d_line, f.px));
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	meter_post(acc, f, -POST_X, 0.62);
	meter_post(acc, f, POST_X, 0.62);
	draw_collars(acc, f, STEEL * 1.4, 0.9);
	knob_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		level_meter(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
