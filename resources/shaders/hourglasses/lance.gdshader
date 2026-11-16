shader_type canvas_item;
// 騎士の槍(ランス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は青と白の縞の騎槍で、下に円錐の鍔、天板の上へ穂先が抜ける。右の槍に小さな旗。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 ROYAL = vec3(0.24, 0.30, 0.72);
const vec3 IVORY = vec3(0.94, 0.92, 0.86);
const float LANCE_X = 0.68;
const float SHAFT_R = 0.042;
const float GUARD_Y = -0.70;
const float TIP_Y = 1.355;
const vec2 SLAB_HALF = vec2(0.80, 0.080);

void lance(inout vec4 acc, Px f, float cx, bool flag) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.30 + f.pad || f.p.y < -1.03 - f.pad || f.p.y > TIP_Y + f.pad) {
		return;
	}
	// 柄: 鍔から上へ細っていく。斜めの縞
	float t = clamp((f.p.y - GUARD_Y) / (TIP_Y - GUARD_Y), 0.0, 1.0);
	float r = mix(SHAFT_R * 1.25, 0.0, pow(t, 1.6));
	r = f.p.y < GUARD_Y ? SHAFT_R * 0.75 : r;
	float d = max(abs(lx) - r, max(-1.02 - f.p.y, f.p.y - TIP_Y));
	vec3 n = lathe_normal(clamp(lx / max(r, 0.001), -1.0, 1.0), 0.0);
	float stripe = step(0.5, fract((f.p.y - lx * 0.9) * 3.2));
	vec3 base = f.p.y < GUARD_Y ? vec3(0.42, 0.28, 0.16) : mix(ROYAL, IVORY, stripe);
	part(acc, d, ink_of(ROYAL), shade_mat(base, n, 0.0, 1.0, f.ao), f.ow, f.px);
	// 円錐の鍔
	vec2 gq = vec2(lx, f.p.y - GUARD_Y);
	float gt = clamp(gq.y / 0.22, 0.0, 1.0);
	float d_guard = max(abs(gq.x) - mix(0.115, SHAFT_R * 1.1, gt), max(-gq.y, gq.y - 0.22));
	vec3 gn = normalize(vec3(gq.x / 0.115, -0.35, 0.8));
	part(acc, d_guard, ink_of(SILVER), shade_mat(SILVER, gn, 1.0, 1.0, f.ao), f.ow, f.px);
	draw_band(acc, f, vec2(cx, GUARD_Y - 0.01), vec2(0.12, 0.016), GOLD, 1.0);
	draw_ball(acc, f, vec2(cx, -1.0), 0.040, GOLD, 1.0);
	// 旗: 穂先の下に砂の色の三角旗
	if (flag) {
		vec2 fq = vec2(lx * sign(cx), f.p.y - 1.13);
		float wave = 0.012 * sin(fq.x * 30.0);
		float h = 0.06 * (1.0 - clamp(fq.x / 0.24, 0.0, 1.0));
		float d_flag = max(abs(fq.y - wave) - h, max(-fq.x + 0.01, fq.x - 0.24));
		part(acc, d_flag, ink_of(ROYAL), mix(sand_color, vec3(1.0), 0.25 * step(fq.y - wave, 0.0)), f.ow * 0.8, f.px);
	}
}

void royal_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, ROYAL, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.050) - 0.005);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.74), f);
	// 盾形の紋に斜めの帯
	vec2 sq = q - vec2(0.0, 0.008);
	float d_shield = max(abs(sq.x) - 0.05 + max(-sq.y, 0.0) * 0.6, abs(sq.y) - 0.046);
	inlay(acc, d, GOLD, cov(d_shield, f.px), f);
	float bend = step(abs(sq.x + sq.y), 0.016);
	inlay(acc, d, IVORY, cov(d_shield + 0.010, f.px), f);
	inlay(acc, d, ROYAL, cov(d_shield + 0.010, f.px) * bend, f);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	draw_collars(acc, f, GOLD, 1.0);
	royal_slab(acc, f, f.side * PLATE_Y);
	lance(acc, f, -LANCE_X, false);
	lance(acc, f, LANCE_X, true);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
