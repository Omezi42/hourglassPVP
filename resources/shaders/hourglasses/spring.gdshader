shader_type canvas_item;
// 泉(スプリング)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は細い芯に巻いたばね、板には湧き上がる水の矢印。天板の上に水を噴き上げる小さな泉。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STONE = vec3(0.70, 0.72, 0.70);
const vec3 STEEL = vec3(0.70, 0.74, 0.80);
const vec3 WATER = vec3(0.50, 0.80, 0.92);
const float CORE_R = 0.020;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 FOUNT = vec2(0.0, 1.165);
const float FOUNT_K = 1.3;

// ばねの柱: 芯の棒に斜めの巻き線(手前側だけ明るく)
void spring_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	draw_column(acc, f, cx, CORE_R, -POST_H, POST_H, STEEL * 0.6, 1.0);
	float pitch = 0.075;
	float t = fract(f.p.y / pitch + lx / 0.060 * 0.18);
	float w = 0.060;
	float coil = abs(t - 0.5) - 0.20;
	float d = max(max(coil * pitch, abs(lx) - w), f.ay - POST_H + 0.07);
	vec3 n = lathe_normal(clamp(lx / w, -1.0, 1.0), (t - 0.5) * 1.5);
	vec3 col = mix(STEEL, mix(STEEL, sand_color, 0.5), 0.5 + 0.5 * sin(f.p.y * 2.0));
	part(acc, d, ink_of(STEEL * 0.5), shade_mat(col, n, 1.0, 1.0, f.ao), f.ow * 0.7, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), STONE, 0.0);
}

void well_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, STONE, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 上向きの矢印が並ぶ水路
	inlay(acc, d, WATER * 0.7, step(abs(q.y), 0.040) * step(abs(q.x), 0.76), f);
	for (int k = -4; k <= 4; k++) {
		vec2 aq = q - vec2(float(k) * 0.16, -0.004);
		float d_head = max(abs(aq.x) - (0.026 - (aq.y - 0.004) * 0.9), max(-aq.y - 0.004, aq.y - 0.030));
		float d_stem = max(abs(aq.x) - 0.007, max(-aq.y - 0.030, aq.y));
		vec3 c = k == 0 ? sand_color : mix(WATER, vec3(1.0), 0.5);
		inlay(acc, d, c, cov(min(d_head, d_stem), f.px), f);
	}
}

// 泉: 石の鉢から噴き上がる水と、弧を描いて落ちる滴
void fountain(inout vec4 acc, Px f) {
	vec2 q = (f.p - FOUNT) / FOUNT_K;
	if (abs(q.x) > 0.23 + f.pad || q.y < -0.10 - f.pad || q.y > 0.15 + f.pad) {
		return;
	}
	f.px /= FOUNT_K;
	f.ow /= FOUNT_K;
	// 噴き上がる水柱
	float jet_w = 0.016 * (1.0 - smoothstep(0.04, 0.135, q.y)) + 0.006;
	float d_jet = max(abs(q.x) - jet_w, max(0.04 - q.y, q.y - 0.135));
	part(acc, d_jet, ink_of(WATER), mix(WATER, vec3(1.0), 0.4 + 0.3 * step(abs(q.x), jet_w * 0.4)), f.ow * 0.5, f.px);
	// 左右へ弧を描いて落ちる水
	for (int s = -1; s <= 1; s += 2) {
		vec2 aq = vec2(q.x * float(s), q.y);
		float arc = 0.135 - 4.2 * aq.x * aq.x;
		float d_arc = max(abs(aq.y - arc) - 0.007, max(-aq.x, aq.x - 0.165));
		d_arc = max(d_arc, 0.020 - aq.y);
		part(acc, d_arc, ink_of(WATER), mix(WATER, sand_color, 0.35), f.ow * 0.4, f.px);
		for (int k = 0; k < 2; k++) {
			vec2 dq = aq - vec2(0.180 + 0.018 * float(k), -0.005 - 0.030 * float(k));
			part(acc, sd_ellipse(dq, vec2(0.009, 0.013)), ink_of(WATER), mix(WATER, vec3(1.0), 0.4), f.ow * 0.4, f.px);
		}
	}
	draw_ball(acc, f, FOUNT + vec2(0.0, 0.140) * FOUNT_K, 0.016 * FOUNT_K, mix(sand_color, vec3(1.0), 0.3), 0.0);
	// 石の鉢
	vec2 bq = q - vec2(0.0, 0.030);
	float d_bowl = max(length(bq * vec2(1.0, 1.8)) - 0.120, bq.y - 0.010);
	part(acc, d_bowl, ink_of(STONE), shade_mat(STONE, normalize(vec3(bq.x / 0.12 * 0.6, -0.2, 0.75)), 0.0, 0.6, 1.0), f.ow, f.px);
	part(acc, sd_ellipse(bq - vec2(0.0, 0.010), vec2(0.120, 0.018)), ink_of(STONE), mix(WATER, sand_color, 0.25), f.ow * 0.7, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	spring_post(acc, f, -POST_X);
	spring_post(acc, f, POST_X);
	draw_collars(acc, f, STONE, 0.0);
	well_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		fountain(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
