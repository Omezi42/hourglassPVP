shader_type canvas_item;
// 夜番の灯り(ワッチャー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 深緑の鉄の柱、天板の上の腕木に灯の入った角灯。板には三日月と星。灯の光が器の後ろへ滲む。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 IRON_GREEN = vec3(0.20, 0.34, 0.30);
const vec3 FLAME = vec3(1.0, 0.86, 0.50);
const float POST_R = 0.046;
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const vec2 LAMP = vec2(0.0, 1.262);

void iron_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, IRON_GREEN, 0.7);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.028), GOLD, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.62), vec2(0.064, 0.014), GOLD, 1.0);
	draw_ball(acc, f, vec2(cx, 0.0), 0.060, IRON_GREEN, 0.7);
	// 柱の頭の小さな火袋の飾り
	draw_ball(acc, f, vec2(cx, 1.205), 0.032, GOLD, 1.0);
}

// 角灯: 屋根・硝子の箱・中の炎・底
void lantern(inout vec4 acc, Px f) {
	vec2 q = f.p - LAMP;
	if (abs(q.x) > 0.14 + f.pad || abs(q.y) > 0.14 + f.pad) {
		return;
	}
	float d_box = sd_round_box(q - vec2(0.0, -0.005), vec2(0.060, 0.062), 0.010);
	// 硝子越しの灯
	float glow_r = length((q - vec2(0.0, -0.01)) / vec2(0.06, 0.07));
	vec3 inside = mix(FLAME, mix(sand_color, FLAME, 0.3) * 0.8, smoothstep(0.0, 1.0, glow_r));
	part(acc, d_box, ink_of(IRON_GREEN), inside, f.ow, f.px);
	float d_flame = sd_ellipse(q - vec2(0.0, -0.015), vec2(0.016, 0.034));
	over(acc, vec3(1.0, 0.98, 0.88), cov(d_flame, f.px));
	// 枠の縦桟
	float bars = step(abs(abs(q.x) - 0.030), 0.006) * step(abs(q.y + 0.005), 0.060);
	over(acc, IRON_GREEN, bars * cov(d_box, f.px));
	// 屋根と底
	vec2 rq = q - vec2(0.0, 0.070);
	float d_roof = max(abs(rq.x) - 0.085 + rq.y * 1.4, max(-rq.y, rq.y - 0.050));
	vec3 rn = normalize(vec3(sign(rq.x) * 0.4, 0.5, 0.75));
	part(acc, d_roof, ink_of(IRON_GREEN), shade_mat(IRON_GREEN, rn, 0.7, 1.0, 1.0), f.ow, f.px);
	draw_ball(acc, f, LAMP + vec2(0.0, 0.128), 0.016, GOLD, 1.0);
	draw_band(acc, f, LAMP + vec2(0.0, -0.075), vec2(0.075, 0.014), IRON_GREEN, 0.7);
}

void night_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, IRON_GREEN, 0.5, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.052) - 0.005);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.76), f);
	float moon = max(length(q) - 0.040, -(length(q - vec2(0.016, 0.010)) - 0.034));
	inlay(acc, d, GOLD, cov(moon, f.px), f);
	for (int k = 0; k < 4; k++) {
		float sx = (float(k) - 1.5) * 0.26;
		if (abs(sx) < 0.1) {
			continue;
		}
		float tw = star4(q - vec2(sx, 0.008 * float(k % 2)), 0.032);
		inlay(acc, d, mix(GOLD, vec3(1.0), 0.4), tw, f);
	}
}

// 灯の光(器の後ろ・上)
void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - LAMP;
	float halo = exp(-dot(d, d) / 0.040);
	add_light(acc, mix(FLAME, sand_color, 0.35), halo * 0.65 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	iron_post(acc, f, -POST_X);
	iron_post(acc, f, POST_X);
	draw_collars(acc, f, IRON_GREEN, 0.7);
	night_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		lantern(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
