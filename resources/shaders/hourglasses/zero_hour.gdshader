shader_type canvas_item;
// 零時(ゼロアワー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は星を散らした夜の色の柱で、中ほどに止まった振り子、板には時計の目盛り。天板の上に、両方の針が12時で重なった文字盤と、背後の新月。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 MIDNIGHT = vec3(0.16, 0.18, 0.38);
const vec3 DIAL = vec3(0.95, 0.93, 0.86);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float COL_HALF = 0.054;
const vec2 CLOCK = vec2(0.0, 1.262);
const float CLOCK_R = 0.100;
const float TICKS = 12.0;

void night_column(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = sd_round_box(vec2(lx, f.ay - POST_H * 0.5), vec2(COL_HALF, POST_H * 0.5), 0.01);
	vec3 n = normalize(vec3(lx / COL_HALF * 0.6, 0.0, 0.8));
	vec3 c = shade_mat(MIDNIGHT, n, 0.3, 1.0, f.ao);
	vec2 cell = floor(f.p / 0.03);
	vec2 sp = f.p - (cell + 0.5) * 0.03;
	float star = step(0.82, hash21(cell + cx)) * (1.0 - smoothstep(0.002, 0.006, length(sp)));
	c = mix(c, DIAL, star * step(abs(lx), COL_HALF - 0.01));
	c = mix(c, SILVER, smoothstep(COL_HALF - 0.016, COL_HALF - 0.008, abs(lx)));
	part(acc, d, ink_of(SILVER), c, f.ow, f.px);
	// 止まった振り子(柱の前に下がる銀の竿と、砂の色の錘)
	vec2 pq = vec2(lx, f.p.y);
	float d_rod = max(abs(pq.x) - 0.006, abs(pq.y - 0.12) - 0.26);
	part(acc, d_rod, ink_of(SILVER), SILVER, f.ow * 0.5, f.px);
	float d_bob = length(pq - vec2(0.0, -0.16)) - 0.050;
	vec3 bn = normalize(vec3((pq - vec2(0.0, -0.16)) / 0.05 * 0.7, 0.7));
	part(acc, d_bob, ink_of(sand_color), shade_mat(sand_color, bn, 0.8, 1.0, 1.0), f.ow * 0.7, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), SILVER, 1.0);
	draw_band(acc, f, vec2(cx, 0.38), vec2(0.060, 0.014), SILVER, 1.0);
}

void tick_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, MIDNIGHT, 0.3, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float k = floor(q.x / 0.06 + 0.5);
	float major = step(0.5, 1.0 - abs(mod(k, 5.0)));
	float tick = max(abs(q.x - k * 0.06) - (0.004 + major * 0.003), abs(q.y) - (0.022 + major * 0.020));
	inlay(acc, d, mix(SILVER, sand_color, major), cov(max(tick, abs(q.x) - 0.70), f.px), f);
}

// 文字盤(両方の針が12時で重なる)と、その後ろの新月
void midnight_clock(inout vec4 acc, Px f) {
	vec2 q = f.p - CLOCK;
	if (length(q) > CLOCK_R * 1.9 + f.pad) {
		return;
	}
	vec2 mq = q - vec2(-0.110, 0.010);
	float d_moon = max(length(mq) - CLOCK_R * 0.62, -(length(mq - vec2(0.040, 0.016)) - CLOCK_R * 0.55));
	part(acc, d_moon, ink_of(sand_color), mix(sand_color, vec3(1.0), 0.3), f.ow * 0.6, f.px);
	float d_face = length(q) - CLOCK_R;
	vec3 fn = normalize(vec3(q / CLOCK_R * 0.4, 0.9));
	part(acc, d_face, ink_of(SILVER), shade_mat(DIAL, fn, 0.0, 0.8, 1.0), f.ow, f.px);
	part(acc, abs(d_face + 0.010) - 0.008, ink_of(SILVER), SILVER, f.ow * 0.4, f.px);
	float a = atan(q.x, q.y);
	float seg = abs(fract(a / 6.2832 * TICKS + 0.5) - 0.5);
	float ticks = step(seg, 0.06) * step(CLOCK_R * 0.70, length(q)) * step(length(q), CLOCK_R * 0.86);
	over(acc, MIDNIGHT, ticks);
	float d_long = max(abs(q.x) - 0.007, max(-q.y - 0.010, q.y - CLOCK_R * 0.78));
	float d_short = max(abs(q.x) - 0.012, max(-q.y - 0.010, q.y - CLOCK_R * 0.52));
	over(acc, MIDNIGHT, cov(min(d_long, d_short), f.px));
	over(acc, sand_color, cov(length(q) - 0.014, f.px));
	add_light(acc, sand_color, star4(q - vec2(0.0, CLOCK_R * 0.80), 0.05) * 0.8);
}

void art_back(inout vec4 acc, Px f) {
	float r = length(f.p - vec2(0.0, 0.0));
	add_light(acc, MIDNIGHT * 1.8, smoothstep(1.3, 0.2, r) * 0.25 * canvas_window(f.p) * (1.0 - acc.a));
}

void art_frame(inout vec4 acc, Px f) {
	night_column(acc, f, -POST_X);
	night_column(acc, f, POST_X);
	draw_collars(acc, f, SILVER, 1.0);
	tick_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		midnight_clock(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
