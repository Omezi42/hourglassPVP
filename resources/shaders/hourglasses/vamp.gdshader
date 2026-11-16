shader_type canvas_item;
// 夜の吸血者(ヴァンプ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 黒い柱の頭に尖塔、天板の上に翼を広げた蝙蝠。板の中央に砂の色の一滴。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 NIGHT = vec3(0.20, 0.17, 0.26);
const vec3 BLOOD = vec3(0.62, 0.12, 0.20);
const vec3 BAT = vec3(0.30, 0.24, 0.40);
const float SPIRE_X = 0.68;
const float POST_R = 0.048;
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const float BAT_Y = 1.262;

// 尖塔の付いた黒い柱。正面に縦の溝
void gothic_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.p.y < -POST_H - f.pad || f.p.y > 1.38 + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(NIGHT, n, 0.3, 1.0, f.ao);
	float groove = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(abs(lx) - POST_R * 0.45) - 0.004);
	c = mix(c, BLOOD * 0.7, groove * 0.7 * step(f.ay, 0.88) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(NIGHT), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.028), SILVER, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.070, 0.020), BLOOD, 0.4);
	// 天板を突き抜けた尖塔
	vec2 sq = vec2(lx, f.p.y - 1.17);
	float t = clamp(sq.y / 0.17, 0.0, 1.0);
	float d_spire = max(abs(sq.x) - 0.046 * (1.0 - t), max(-sq.y, sq.y - 0.17));
	vec3 sn = normalize(vec3(sign(sq.x) * 0.5, 0.2, 0.8));
	part(acc, d_spire, ink_of(NIGHT), shade_mat(NIGHT * 1.3, sn, 0.5, 1.0, 1.0), f.ow, f.px);
	draw_ball(acc, f, vec2(cx, 1.19), 0.034, SILVER, 1.0);
}

// 蝙蝠: 胴と、下の縁が波打つ広げた翼
void bat(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, BAT_Y);
	if (abs(q.x) > 0.34 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	float ax = abs(q.x);
	float top = 0.04 + 0.05 * smoothstep(0.05, 0.30, ax) - 0.05 * smoothstep(0.24, 0.32, ax);
	float scallop = 0.025 * abs(sin(ax * 3.1416 / 0.095));
	float bottom = -0.035 + 0.06 * smoothstep(0.04, 0.30, ax) + scallop;
	float d_wing = max(max(q.y - top, bottom - q.y), ax - 0.32);
	float d_body = sd_ellipse(q - vec2(0.0, 0.0), vec2(0.045, 0.065));
	float d_head = length(q - vec2(0.0, 0.065)) - 0.034;
	float ear = max(abs(ax - 0.02) - 0.012 * (1.0 - clamp((q.y - 0.07) / 0.05, 0.0, 1.0)), max(0.07 - q.y, q.y - 0.12));
	float d = min(min(d_wing, d_body), min(d_head, ear));
	vec3 c = mix(BAT, min(BAT * 1.7, vec3(1.0)), smoothstep(-0.03, 0.10, q.y) * 0.7);
	// 翼の骨
	float bone = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(q.y - 0.05 * smoothstep(0.0, 0.3, ax) - (ax - 0.05) * 0.2 * step(0.16, ax)) - 0.004);
	c = mix(c, vec3(0.55, 0.48, 0.66), bone * step(0.05, ax) * 0.8);
	part(acc, d, vec3(0.04, 0.03, 0.06), c, f.ow, f.px);
	// 赤い目
	vec2 eq = vec2(ax - 0.013, q.y - 0.070);
	over(acc, mix(BLOOD, vec3(1.0, 0.4, 0.4), 0.4), cov(length(eq) - 0.008, f.px));
}

void night_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, NIGHT, 0.3, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.052) - 0.005);
	inlay(acc, d, BLOOD, rim * step(abs(q.x), 0.76), f);
	// 砂の色の一滴を銀の枠に
	vec2 dq = q - vec2(0.0, -0.008);
	float drop = max(length(dq) - 0.034, -dq.y - 0.034 + abs(dq.x) * 1.4);
	drop = min(length(dq) - 0.034, sd_segment(dq, vec2(0.0), vec2(0.0, 0.058)) - 0.034 * (1.0 - clamp(dq.y / 0.058, 0.0, 1.0)));
	inlay(acc, d, SILVER, cov(drop - 0.010, f.px), f);
	inlay(acc, d, mix(sand_color, vec3(1.0), 0.15 * step(dq.x, -0.01)), cov(drop, f.px), f);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	draw_collars(acc, f, SILVER, 1.0);
	night_slab(acc, f, f.side * PLATE_Y);
	gothic_post(acc, f, -SPIRE_X);
	gothic_post(acc, f, SPIRE_X);
	if (f.p.y > PLATE_Y) {
		bat(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
