shader_type canvas_item;
// 炸裂(バースト)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は導火線を巻いた筒花火、板には火花の模様。天板の上で四方へ弾ける花火玉。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PAPER = vec3(0.70, 0.20, 0.22);
const vec3 CHAR = vec3(0.16, 0.14, 0.16);
const vec3 SPARK = vec3(1.0, 0.86, 0.50);
const float POST_R = 0.048;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 SHELL = vec2(0.0, 1.205);
const float SHELL_K = 1.2;

// 筒花火: 赤い紙筒に白い帯、斜めに巻いた導火線
void rocket_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	float stripe = step(0.5, fract(f.p.y * 3.0));
	vec3 base = mix(PAPER, mix(vec3(0.94, 0.90, 0.84), sand_color, 0.3), stripe * step(abs(f.p.y), 0.82));
	vec3 c = shade_mat(base, n, 0.0, 0.7, f.ao);
	float fuse = abs(fract(f.p.y * 4.0 + lx / POST_R * 0.25) - 0.5);
	c = mix(c, CHAR, (1.0 - smoothstep(0.03, 0.07, fuse)) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(PAPER), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), GOLD, 1.0);
}

void spark_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, CHAR, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	for (int k = -3; k <= 3; k++) {
		vec2 sq = q - vec2(float(k) * 0.21, 0.0);
		float r = length(sq);
		float a = atan(sq.y, sq.x);
		float ray = smoothstep(0.6, 1.0, cos(a * 8.0)) * step(r, 0.050) * step(0.012, r);
		vec3 c = k == 0 ? sand_color : SPARK;
		inlay(acc, d, c, max(ray, cov(r - 0.012, f.px)), f);
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.058) - 0.004);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.76), f);
}

// 弾ける花火玉: 割れた玉と飛び散る火の粉の線
void bursting_shell(inout vec4 acc, Px f) {
	vec2 q = (f.p - SHELL) / SHELL_K;
	if (length(q) > 0.17 + f.pad) {
		return;
	}
	f.px /= SHELL_K;
	f.ow /= SHELL_K;
	float r = length(q);
	float a = atan(q.y, q.x);
	float k = floor(a / 6.2832 * 16.0 + 0.5);
	float ac = k / 16.0 * 6.2832;
	vec2 dir = vec2(cos(ac), sin(ac));
	vec2 side_dir = vec2(-dir.y, dir.x);
	float along = dot(q, dir);
	float across = dot(q, side_dir);
	float len = mod(k, 2.0) < 0.5 ? 0.135 : 0.105;
	float d_ray = max(abs(across) - 0.010 * (1.0 - along / len), max(0.060 - along, along - len));
	vec3 rc = mod(k, 2.0) < 0.5 ? mix(sand_color, vec3(1.0), 0.2) : SPARK;
	if (dir.y > -0.45) {
		part(acc, d_ray, ink_of(rc), rc, f.ow * 0.4, f.px);
	}
	// 割れた玉
	float crack = smoothstep(0.75, 1.0, cos(a * 5.0 + 0.4));
	vec3 n = normalize(vec3(q / 0.05 * 0.6, 0.7));
	vec3 sc = mix(shade_mat(CHAR * 1.8, n, 0.0, 0.8, 1.0), SPARK, crack);
	part(acc, r - 0.048, ink_of(CHAR), sc, f.ow, f.px);
	draw_ball(acc, f, SHELL, 0.018 * SHELL_K, mix(SPARK, vec3(1.0), 0.6), 0.0);
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = (f.p - SHELL) / SHELL_K;
	float halo = exp(-dot(q, q) / 0.010);
	add_light(acc, mix(SPARK, sand_color, 0.5), halo * 0.65);
}

void art_frame(inout vec4 acc, Px f) {
	rocket_post(acc, f, -POST_X);
	rocket_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	spark_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		bursting_shell(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
