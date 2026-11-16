shader_type canvas_item;
// 動かない岩(ロック)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は荒い岩を積んだもの、板は苔むした厚い石。天板の上に丸い大岩がひとつ座る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 ROCK = vec3(0.56, 0.56, 0.52);
const vec3 ROCK_DARK = vec3(0.34, 0.34, 0.32);
const vec3 MOSS = vec3(0.42, 0.58, 0.30);
const float STACK_X = 0.68;
const int STONES = 5;
const vec2 SLAB_HALF = vec2(0.84, 0.092);

// 荒い石の距離(縁を雑音で崩す)
float rough_d(vec2 q, vec2 hs, float r, float seed_k) {
	float d = sd_round_box(q, hs, r);
	return d + (vnoise(q * 14.0 + seed_k * 7.3) - 0.5) * 0.022;
}

vec3 rock_color(vec2 q, vec2 hs, float seed_k, float px) {
	vec3 n = normalize(vec3(q.x / hs.x * 0.55, q.y / hs.y * 0.45, 0.8));
	vec3 c = shade_mat(mix(ROCK, ROCK_DARK, hash21(vec2(seed_k, 3.0)) * 0.35), n, 0.0, 0.15, 1.0);
	float speck = step(0.80, vnoise(q * 40.0 + seed_k)) * smoothstep(0.03, 0.012, px);
	return mix(c, c * 0.75, speck * 0.6);
}

// 岩を積んだ柱。上の岩ほど少し小さい
void stone_stack(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.16 + f.pad || f.ay > POST_H + 0.02 + f.pad) {
		return;
	}
	float span = 2.0 * POST_H / float(STONES);
	for (int k = 0; k < STONES; k++) {
		float y = -POST_H + span * (float(k) + 0.5);
		float sk = float(k) + cx * 3.0;
		float ox = (hash21(vec2(sk, 1.0)) - 0.5) * 0.03;
		vec2 hs = vec2(0.105 + hash21(vec2(sk, 2.0)) * 0.025, span * 0.5 - 0.004);
		vec2 q = vec2(lx - ox, f.p.y - y);
		float d = rough_d(q, hs, 0.05, sk);
		if (d < f.ow + f.px) {
			part(acc, d, ink_of(ROCK_DARK), rock_color(q, hs, sk, f.px) * f.ao, f.ow, f.px);
		}
	}
}

void stone_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + 0.03 + f.pad || abs(q.y) > SLAB_HALF.y + 0.03 + f.pad) {
		return;
	}
	float d = rough_d(q, SLAB_HALF, 0.04, cy);
	part(acc, d, ink_of(ROCK_DARK), rock_color(q * vec2(0.3, 1.0), SLAB_HALF * vec2(0.3, 1.0), cy, f.px), f.ow, f.px);
	// 板の上の縁に垂れる苔
	float hang = 0.030 + 0.030 * vnoise(vec2(q.x * 9.0, cy));
	float moss = step(SLAB_HALF.y - hang, q.y) * cov(d + f.ow * 0.5, f.px);
	moss *= smoothstep(0.35, 0.55, vnoise(vec2(q.x * 3.0, cy * 2.0)));
	vec3 mc = mix(MOSS * 0.75, mix(MOSS, sand_color, 0.35), vnoise(q * 30.0));
	over(acc, mc, moss);
	// 中央に打ち込んだ鉄の輪
	vec2 rq = q - vec2(0.0, -0.005);
	float ring = abs(length(rq * vec2(1.0, 1.2)) - 0.050) - 0.012;
	vec3 rn = normalize(vec3(rq / 0.06 * 0.6, 0.8));
	part(acc, ring, vec3(0.08), shade_mat(vec3(0.42, 0.42, 0.46), rn, 1.0, 0.8, 1.0), f.ow * 0.7, f.px);
	draw_ball(acc, f, vec2(0.0, cy + 0.052), 0.022, vec3(0.42, 0.42, 0.46), 1.0);
}

// 天板の上の大岩
void boulder(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.02, 1.262);
	if (abs(q.x) > 0.22 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	vec2 hs = vec2(0.19, 0.080);
	float d = sd_ellipse(q, hs) + (vnoise(q * 12.0 + 4.0) - 0.5) * 0.03;
	part(acc, d, ink_of(ROCK_DARK), rock_color(q, hs, 9.0, f.px), f.ow, f.px);
	float moss = step(0.04, q.y + vnoise(vec2(q.x * 10.0, 1.0)) * 0.04) * cov(d + f.ow * 0.5, f.px);
	over(acc, mix(MOSS, sand_color, 0.3), moss * 0.85);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	stone_stack(acc, f, -STACK_X);
	stone_stack(acc, f, STACK_X);
	draw_collars(acc, f, ROCK_DARK * 1.2, 0.0);
	stone_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		boulder(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
