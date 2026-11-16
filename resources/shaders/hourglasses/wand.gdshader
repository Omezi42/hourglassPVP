shader_type canvas_item;
// 魔法の杖(ワンド)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は銀の線を巻いた黒檀の杖で、天板を突き抜けた先に星の飾り。板は紅紫の漆に銀の三日月。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 EBONY = vec3(0.24, 0.16, 0.22);
const vec3 LACQUER = vec3(0.66, 0.24, 0.48);
const float WAND_X = 0.68;
const float WAND_R = 0.040;
const float WAND_BOTTOM = -1.02;
const float WAND_TOP = 1.20;
const float STAR_Y = 1.262;
const vec2 SLAB_HALF = vec2(0.78, 0.078);

// 5つの角の星の距離
float sd_star5(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809017, -0.587785);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

void draw_wand(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.16 + f.pad || f.p.y < WAND_BOTTOM - 0.06 - f.pad || f.p.y > STAR_Y + 0.12 + f.pad) {
		return;
	}
	// 先へ向けてわずかに細る杖
	float t = clamp((f.p.y - WAND_BOTTOM) / (WAND_TOP - WAND_BOTTOM), 0.0, 1.0);
	float r = WAND_R * mix(1.12, 0.78, t);
	float d = max(abs(lx) - r, max(WAND_BOTTOM - f.p.y, f.p.y - WAND_TOP));
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(EBONY, n, 0.0, 1.0, f.ao);
	// 螺旋に巻いた銀の線
	float spiral = abs(fract((f.p.y + lx * 0.8) * 7.0) - 0.5);
	float wire = (1.0 - smoothstep(0.06, 0.12, spiral)) * smoothstep(0.03, 0.012, f.px);
	c = mix(c, shade_mat(SILVER, n, 1.0, 1.0, 1.0), wire * 0.85);
	part(acc, d, ink_of(EBONY), c, f.ow, f.px);
	// 握りの金の輪と石突き
	draw_band(acc, f, vec2(cx, -0.62), vec2(0.060, 0.016), GOLD, 1.0);
	draw_band(acc, f, vec2(cx, -0.40), vec2(0.056, 0.014), GOLD, 1.0);
	draw_ball(acc, f, vec2(cx, WAND_BOTTOM - 0.02), 0.046, GOLD, 1.0);
	// 星の飾り: 金の縁に砂の色の面
	vec2 sq = f.p - vec2(cx, STAR_Y);
	float d_star = sd_star5(sq, 0.118, 0.45);
	if (d_star < f.ow + f.px) {
		vec3 sn = normalize(vec3(sq / 0.10 * 0.6, 0.75));
		part(acc, d_star, ink_of(GOLD), shade_mat(GOLD, sn, 1.0, 1.0, 1.0), f.ow, f.px);
		float d_core = sd_star5(sq, 0.070, 0.45);
		vec3 core = mix(sand_color * 0.82, mix(sand_color, vec3(1.0), 0.6), step(sq.x - sq.y * 0.4, 0.0));
		over(acc, core, cov(d_core, f.px));
	}
}

void lacquer_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.035, LACQUER, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.050) - 0.005);
	inlay(acc, d, SILVER, rim * step(abs(q.x), 0.74), f);
	// 中央の銀の三日月と、左右の小さな星
	float moon = max(length(q) - 0.044, -(length(q - vec2(0.018, 0.010)) - 0.036));
	inlay(acc, d, SILVER, cov(moon, f.px), f);
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		inlay(acc, d, SILVER, cov(sd_star5(q - vec2(sx * 0.15, 0.0), 0.026, 0.45), f.px), f);
	}
}

// 星の先に灯るきらめき(止めた光)
void art_back(inout vec4 acc, Px f) {
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -WAND_X : WAND_X;
		vec2 d = f.p - vec2(cx, STAR_Y);
		float halo = exp(-dot(d, d) / 0.012);
		add_light(acc, mix(sand_color, vec3(1.0), 0.4), halo * 0.55 * canvas_window(f.p * vec2(0.9, 1.0)));
	}
}

void art_frame(inout vec4 acc, Px f) {
	draw_collars(acc, f, SILVER, 1.0);
	lacquer_slab(acc, f, f.side * PLATE_Y);
	draw_wand(acc, f, -WAND_X);
	draw_wand(acc, f, WAND_X);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
