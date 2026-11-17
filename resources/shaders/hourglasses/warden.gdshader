shader_type canvas_item;
// 砦の番人(ウォーデン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 灰青の石柱に光るルーンを刻み、天板の上に輪を巡らせた護りの宝珠。宝珠の光が後ろへ滲む。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STONE = vec3(0.46, 0.52, 0.56);
const vec3 STONE_INK = vec3(0.14, 0.18, 0.20);
const float PILLAR_HALF = 0.064;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec2 ORB = vec2(0.0, 1.27);

vec3 rune_glow() {
	return mix(sand_color, vec3(1.0), 0.25);
}

// ルーン: 縦棒に斜めの枝を足した簡単な字形を、セルごとに変える
float rune(vec2 q, float k) {
	float h = hash21(vec2(k, 9.0));
	float d = sd_segment(q, vec2(0.0, -0.045), vec2(0.0, 0.045));
	vec2 a = vec2(0.0, h < 0.5 ? 0.02 : -0.01);
	d = min(d, sd_segment(q, a, a + vec2(h < 0.33 ? 0.03 : -0.03, 0.025)));
	if (h > 0.6) {
		d = min(d, sd_segment(q, vec2(0.0, -0.02), vec2(0.03, -0.045)));
	}
	return d;
}

void rune_pillar(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > PILLAR_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - PILLAR_HALF, f.ay - POST_H);
	float face = lx / PILLAR_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(STONE, n, 0.0, 0.3, f.ao);
	float k = floor(f.p.y / 0.15 + 0.5);
	vec2 rq = vec2(lx, f.p.y - k * 0.15);
	float glyph = 1.0 - smoothstep(0.0, max(0.006, f.px), rune(rq, k + cx * 7.0) - 0.006);
	c = mix(c, rune_glow(), glyph * step(f.ay, POST_H - 0.07));
	part(acc, d, STONE_INK, c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.028), STONE * 0.8, 0.3);
}

void rune_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, STONE, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float k = floor(q.x / 0.12 + 0.5);
	vec2 rq = vec2(q.x - k * 0.12, q.y) * vec2(1.0, 1.4);
	float glyph = 1.0 - smoothstep(0.0, max(0.006, f.px), rune(rq, k + cy * 3.0) - 0.006);
	inlay(acc, d, rune_glow(), glyph * step(abs(q.x), 0.72), f);
}

// 護りの宝珠: 硝子の珠と、斜めに巡る2本の輪、台座
void ward_orb(inout vec4 acc, Px f) {
	draw_band(acc, f, vec2(0.0, PLATE_Y + SLAB_HALF.y + 0.012), vec2(0.080, 0.018), STONE * 0.8, 0.3);
	vec2 q = (f.p - ORB) / 1.3;
	if (abs(q.x) > 0.16 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	f.px /= 1.3;
	f.ow /= 1.3;
	vec3 n = normalize(vec3(q / 0.07 * 0.7, 0.7));
	vec3 orb = mix(rune_glow(), sand_color * 0.7, smoothstep(0.0, 0.07, length(q - vec2(-0.02, 0.02))));
	part(acc, length(q) - 0.068, STONE_INK, orb, f.ow, f.px);
	over(acc, vec3(1.0), cov(sd_ellipse(q - vec2(-0.025, 0.028), vec2(0.016, 0.010)), f.px) * 0.8);
	for (int k = 0; k < 2; k++) {
		vec2 rq = rot(q, k == 0 ? 0.45 : -0.45);
		float d_ring = abs(length(rq / vec2(1.0, 0.32)) - 0.13) * 0.32 - 0.006;
		float front = step(0.0, -rq.y);
		over(acc, STONE_INK, cov(d_ring - f.ow * 0.6, f.px) * (front > 0.5 ? 1.0 : step(0.068, length(q))));
		over(acc, rune_glow(), cov(d_ring, f.px) * (front > 0.5 ? 1.0 : step(0.068, length(q))));
	}
}

// 宝珠の光
void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - ORB;
	add_light(acc, rune_glow(), exp(-dot(d, d) / 0.030) * 0.7 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	rune_pillar(acc, f, -POST_X);
	rune_pillar(acc, f, POST_X);
	draw_collars(acc, f, STONE * 0.8, 0.3);
	rune_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		ward_orb(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
