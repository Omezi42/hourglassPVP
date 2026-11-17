shader_type canvas_item;
// 棘(スパイク)。GameDesign.md 9章 / Architecture.md 10.19節。
// 黒鉄の柱の外側へ鋭い棘が並び、板の縁にも棘。天板の上に棘を生やした鉄球。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 IRON = vec3(0.30, 0.30, 0.34);
const vec3 SPIKE_STEEL = vec3(0.80, 0.82, 0.86);
const float POST_R = 0.046;
const float SPIKE_LEN = 0.120;
const float SPIKE_STEP = 0.16;
const vec2 SLAB_HALF = vec2(0.78, 0.080);
const vec2 BALL = vec2(0.0, 1.250);

// 円錐の棘1本: 根元 base から dir へ
void spike_cone(inout vec4 acc, Px f, vec2 base, vec2 dir, float len, float w) {
	vec2 q = f.p - base;
	vec2 side = vec2(-dir.y, dir.x);
	float t = dot(q, dir);
	float s = dot(q, side);
	if (t < -f.pad || t > len + f.pad || abs(s) > w + f.pad) {
		return;
	}
	float d = max(abs(s) - w * (1.0 - clamp(t / len, 0.0, 1.0)), -t);
	vec3 c = mix(SPIKE_STEEL * 0.62, SPIKE_STEEL, step(s * sign(dir.x + 0.001), 0.0));
	part(acc, d, ink_of(IRON), c, f.ow * 0.7, f.px);
}

void spiked_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + SPIKE_LEN + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float out_dir = sign(cx);
	float k = floor(f.p.y / SPIKE_STEP + 0.5);
	for (int j = -1; j <= 1; j++) {
		float y = (k + float(j)) * SPIKE_STEP;
		if (abs(y) > POST_H - 0.10) {
			continue;
		}
		spike_cone(acc, f, vec2(cx + out_dir * POST_R * 0.8, y), vec2(out_dir, 0.0), SPIKE_LEN, 0.034);
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	part(acc, d, vec3(0.05), shade_mat(IRON, n, 1.0, 0.7, f.ao), f.ow, f.px);
	// 棘の根元の鋲
	vec2 rq = vec2(lx, fract(f.p.y / SPIKE_STEP + 0.5) * SPIKE_STEP - SPIKE_STEP * 0.5);
	over(acc, SPIKE_STEEL * 0.8, cov(length(rq) - 0.014, f.px) * step(f.ay, POST_H - 0.10));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), IRON * 1.4, 1.0);
}

void spiked_slab(inout vec4 acc, Px f, float cy) {
	// 板の外の縁に下(上)向きの棘
	float s = sign(cy);
	float k = floor(f.p.x / 0.20 + 0.5);
	for (int j = -1; j <= 1; j++) {
		float x = (k + float(j)) * 0.20;
		if (abs(x) > 0.70) {
			continue;
		}
		spike_cone(acc, f, vec2(x, cy + s * (SLAB_HALF.y - 0.01)), vec2(0.0, s), 0.060, 0.022);
	}
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, IRON, 1.0, 0.7);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	inlay(acc, d, mix(sand_color, IRON, 0.25), step(abs(q.y), 0.012) * step(abs(q.x), 0.74), f);
	inlay(acc, d, sand_color, cov(sd_rhombus(q, vec2(0.050, 0.040)), f.px), f);
}

// 棘の鉄球: 球と8方向の棘
void spiked_ball(inout vec4 acc, Px f) {
	vec2 q = f.p - BALL;
	if (length(q) > 0.15 + f.pad) {
		return;
	}
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.7854 + 0.39;
		vec2 dir = vec2(cos(a), sin(a));
		spike_cone(acc, f, BALL + dir * 0.060, dir, 0.065, 0.026);
	}
	vec3 n = normalize(vec3(q / 0.07 * 0.7, 0.7));
	part(acc, length(q) - 0.075, vec3(0.05), shade_mat(IRON, n, 1.0, 0.9, 1.0), f.ow, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	spiked_post(acc, f, -POST_X);
	spiked_post(acc, f, POST_X);
	draw_collars(acc, f, IRON * 1.4, 1.0);
	spiked_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		spiked_ball(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
