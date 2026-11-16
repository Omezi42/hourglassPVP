shader_type canvas_item;
// 物見の塔(タワー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は丸い石積みの小塔で矢狭間が開き、天板の上へ緑の円錐の屋根が突き出す。板は太い木の梁。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STONE = vec3(0.70, 0.68, 0.62);
const vec3 ROOF = vec3(0.26, 0.56, 0.36);
const vec3 BEAM = vec3(0.50, 0.34, 0.20);
const float TOWER_X = 0.70;
const float TOWER_R = 0.088;
const float ROOF_BASE = 1.16;
const float ROOF_TOP = 1.385;
const vec2 SLAB_HALF = vec2(0.80, 0.078);

void turret(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.15 + f.pad || f.ay > ROOF_TOP + f.pad) {
		return;
	}
	float d = max(abs(lx) - TOWER_R, f.ay - POST_H);
	float u = clamp(lx / TOWER_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	vec3 c = shade_mat(STONE, n, 0.0, 0.15, f.ao);
	// 丸く回り込む石積み(段ごとに目地をずらす)
	float row = floor(f.p.y / 0.11);
	float ang = asin(u) / 3.1416 * 3.0 + mod(row, 2.0) * 0.5;
	float joint_v = 1.0 - smoothstep(0.0, 0.10, abs(fract(ang) - 0.5) * 2.0 - 0.88);
	float joint_h = 1.0 - smoothstep(0.0, 0.10, min(fract(f.p.y / 0.11), 1.0 - fract(f.p.y / 0.11)) * 2.0);
	float fine = smoothstep(0.03, 0.012, f.px);
	c = mix(c, c * 0.62, max(joint_h, joint_v * 0.0 + (1.0 - smoothstep(0.85, 0.95, abs(fract(ang) - 0.5) * 2.0)) * 0.0) * fine);
	c = mix(c, c * 0.70, step(0.92, abs(fract(ang) - 0.5) * 2.0) * fine);
	// 矢狭間(上下2つ)
	for (int j = 0; j < 2; j++) {
		float y = j == 0 ? 0.40 : -0.40;
		vec2 sq = vec2(lx, f.p.y - y);
		float d_slit = max(abs(sq.x) - 0.012, abs(sq.y) - 0.07);
		d_slit = min(d_slit, max(abs(sq.y) - 0.012, abs(sq.x) - 0.034));
		c = mix(c, vec3(0.08, 0.07, 0.10), cov(d_slit, f.px));
	}
	part(acc, d, ink_of(STONE), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.104, 0.024), STONE * 0.85, 0.0);
	// 円錐の屋根と旗竿の玉
	vec2 rq = vec2(lx, f.p.y - ROOF_BASE);
	float rt = clamp(rq.y / (ROOF_TOP - ROOF_BASE), 0.0, 1.0);
	float d_roof = max(abs(rq.x) - 0.125 * (1.0 - rt), max(-rq.y, rq.y - (ROOF_TOP - ROOF_BASE)));
	vec3 rn = normalize(vec3(rq.x / 0.12, 0.5, 0.8));
	vec3 rc = shade_mat(ROOF, rn, 0.0, 0.6, 1.0);
	float tile = step(0.5, fract(rq.y * 22.0));
	rc = mix(rc, rc * 0.82, tile * smoothstep(0.03, 0.012, f.px));
	part(acc, d_roof, ink_of(ROOF), rc, f.ow, f.px);
}

void beam_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, BEAM, 0.0, 0.4);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float grain = abs(fract(q.y * 20.0 + vnoise(q * vec2(2.0, 8.0))) - 0.5);
	inlay(acc, d, BEAM * 0.7, (1.0 - smoothstep(0.05, 0.15, grain)) * 0.5 * smoothstep(0.03, 0.012, f.px), f);
	// 中央に緑の小旗の紋
	vec2 bq = q - vec2(-0.02, 0.0);
	float d_pole = max(abs(bq.x) - 0.006, abs(bq.y) - 0.050);
	inlay(acc, d, vec3(0.2), cov(d_pole, f.px), f);
	float d_flag = max(abs(bq.y - 0.022) - 0.026 * (1.0 - clamp((bq.x - 0.006) / 0.08, 0.0, 1.0)), max(-(bq.x - 0.006), bq.x - 0.086));
	inlay(acc, d, mix(ROOF, sand_color, 0.4), cov(d_flag, f.px), f);
	for (int i = 0; i < 2; i++) {
		draw_ball(acc, f, vec2((i == 0 ? -1.0 : 1.0) * 0.40, cy), 0.020, vec3(0.3), 1.0);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	draw_collars(acc, f, BEAM, 0.0);
	beam_slab(acc, f, f.side * PLATE_Y);
	turret(acc, f, -TOWER_X);
	turret(acc, f, TOWER_X);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
