shader_type canvas_item;
// 金庫(ヴォールト)。GameDesign.md 9章 / Architecture.md 10.19節。
// 鋲を打った分厚い鋼の柱と板。天板の上に丸い金庫の扉、中央に回し輪と目盛りの付いた錠。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEEL = vec3(0.56, 0.58, 0.56);
const vec3 BRASS = vec3(0.84, 0.70, 0.40);
const vec3 INK = vec3(0.12, 0.12, 0.12);
const float POST_HALF = 0.068;
const vec2 SLAB_HALF = vec2(0.84, 0.090);
const vec2 DOOR = vec2(0.0, 1.250);

void riveted_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(STEEL, n, 1.0, 0.8, f.ao);
	// 縦の継ぎ目と2列の鋲
	c = mix(c, c * 0.7, (1.0 - smoothstep(0.0, max(0.006, f.px), abs(lx) - 0.004)) * 0.0);
	vec2 rq = vec2(abs(lx) - POST_HALF * 0.55, fract(f.p.y / 0.12 + 0.5) * 0.12 - 0.06);
	float rivet = length(rq) - 0.012;
	vec3 rn = normalize(vec3(rq / 0.012 * 0.6, 0.8));
	c = mix(c, shade_mat(STEEL * 1.2, rn, 1.0, 1.0, 1.0), cov(rivet, f.px) * step(f.ay, POST_H - 0.06));
	part(acc, d, INK, c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.028), BRASS, 1.0);
}

void vault_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, STEEL, 1.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 横に通した閂と、鍵の座
	float bolt = step(abs(q.y), 0.020) * step(abs(q.x), 0.74);
	inlay(acc, d, BRASS * 0.9, bolt, f);
	for (int k = -3; k <= 3; k++) {
		draw_ball(acc, f, vec2(float(k) * 0.22, cy + 0.056 * sign(q.y + 0.0001)), 0.012, STEEL * 1.2, 1.0);
	}
	inlay(acc, d, sand_color, cov(sd_round_box(q, vec2(0.045, 0.030), 0.008), f.px), f);
}

// 丸い扉: 厚い縁、目盛りの錠、4本の握りの回し輪
void vault_door(inout vec4 acc, Px f) {
	vec2 q = f.p - DOOR;
	if (length(q) > 0.15 + f.pad) {
		return;
	}
	vec3 n = normalize(vec3(q / 0.13 * 0.5, 0.8));
	part(acc, length(q) - 0.128, INK, shade_mat(STEEL, n, 1.0, 1.0, 1.0), f.ow, f.px);
	over(acc, STEEL * 0.72, cov(length(q) - 0.100, f.px) - cov(length(q) - 0.094, f.px));
	// 回し輪
	float a = atan(q.y, q.x);
	float sector = 6.2832 / 4.0;
	float sa = mod(a + 0.4 + sector * 0.5, sector) - sector * 0.5;
	vec2 lq = vec2(cos(sa), sin(sa)) * length(q);
	float d_spoke = max(abs(lq.y) - 0.010, max(lq.x - 0.088, 0.030 - lq.x));
	d_spoke = min(d_spoke, length(lq - vec2(0.088, 0.0)) - 0.016);
	part(acc, d_spoke, INK, shade_mat(BRASS, normalize(vec3(0.2, 0.3, 0.9)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	// 目盛りの錠
	part(acc, length(q) - 0.036, INK, shade_mat(BRASS, n, 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	float tick = step(abs(fract(a / 6.2832 * 12.0 + 0.5) - 0.5), 0.12) * step(abs(length(q) - 0.028), 0.006);
	over(acc, INK, tick);
	over(acc, sand_color, cov(length(q) - 0.012, f.px));
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	riveted_post(acc, f, -POST_X);
	riveted_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	vault_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		vault_door(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
