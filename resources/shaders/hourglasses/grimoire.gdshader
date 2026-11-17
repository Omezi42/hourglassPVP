shader_type canvas_item;
// 魔導書(グリモア)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は鎖を巻いた黒革の柱、板には光る魔法陣。天板の上に錠前と宝石で閉じた分厚い魔導書。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 LEATHER = vec3(0.24, 0.12, 0.16);
const vec3 BRASS = vec3(0.80, 0.62, 0.30);
const vec3 IRON = vec3(0.36, 0.36, 0.40);
const vec3 PAGE_EDGE = vec3(0.90, 0.84, 0.70);
const float POST_HALF = 0.056;
const vec2 SLAB_HALF = vec2(0.82, 0.084);
const vec2 TOME = vec2(0.0, 1.210);
const float TOME_K = 1.25;

void chained_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + 0.02 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(LEATHER, n, 0.0, 0.7, f.ao);
	// 縁の縫い目
	float stitch = step(abs(abs(lx) - POST_HALF * 0.78), 0.004) * step(0.5, fract(f.p.y / 0.030));
	c = mix(c, BRASS * 0.8, stitch);
	part(acc, d, ink_of(LEATHER), c, f.ow, f.px);
	// 斜めの鎖: 楕円の輪を交互に向きを変えて連ねる
	float t = f.p.y / 0.050 + lx / POST_HALF * 0.9;
	float k = floor(t);
	vec2 lq = vec2(lx, (fract(t) - 0.5) * 0.050);
	vec2 rad = mod(k, 2.0) < 0.5 ? vec2(0.032, 0.020) : vec2(0.010, 0.022);
	float d_link = abs(sd_ellipse(lq, rad)) - 0.005;
	if (abs(f.p.y) < 0.55) {
		part(acc, d_link, vec3(0.05), shade_mat(IRON * 1.4, normalize(vec3(lq * 10.0, 0.8)), 1.0, 1.0, f.ao), f.ow * 0.4, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), BRASS, 1.0);
}

void circle_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, LEATHER, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	vec3 rune_col = mix(sand_color, vec3(1.0), 0.3);
	// 中央の魔法陣: 二重円と内接する星
	vec2 cq = q / vec2(1.0, 0.95);
	float r = length(cq);
	float rings = (1.0 - smoothstep(0.0, max(0.004, f.px), abs(r - 0.058) - 0.003)) + (1.0 - smoothstep(0.0, max(0.004, f.px), abs(r - 0.044) - 0.002));
	float a = atan(cq.y, cq.x);
	float star = 1.0 - smoothstep(0.0, max(0.004, f.px), abs(r * cos(mod(a, 1.2566) - 0.6283) - 0.036) - 0.002);
	inlay(acc, d, rune_col, min(rings + star * step(r, 0.046), 1.0), f);
	// 左右へ伸びる文字の帯
	float runes = step(abs(fract(q.x / 0.040) - 0.5), 0.22) * step(abs(q.y), 0.012) * step(0.4, hash21(vec2(floor(q.x / 0.040), 9.0)));
	inlay(acc, d, BRASS, runes * step(0.10, abs(q.x)) * step(abs(q.x), 0.76), f);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.062) - 0.004);
	inlay(acc, d, BRASS, rim * step(abs(q.x), 0.78), f);
}

// 魔導書: 厚い表紙、頁の小口、角金具、留め帯と錠前、中央の宝石
void tome(inout vec4 acc, Px f) {
	vec2 q = (f.p - TOME) / TOME_K;
	if (abs(q.x) > 0.22 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= TOME_K;
	f.ow /= TOME_K;
	vec2 bq = q - vec2(0.0, -0.005);
	float d_pages = sd_round_box(bq - vec2(0.006, -0.004), vec2(0.150, 0.075), 0.006);
	float stripe = step(0.5, fract(bq.y / 0.008));
	part(acc, d_pages, ink_of(PAGE_EDGE), mix(PAGE_EDGE, PAGE_EDGE * 0.85, stripe), f.ow * 0.6, f.px);
	float d_cover = sd_round_box(bq - vec2(-0.008, 0.008), vec2(0.145, 0.078), 0.010);
	vec3 n = normalize(vec3(bq.x / 0.15 * 0.3, bq.y / 0.08 * 0.3, 0.9));
	vec3 c = shade_mat(LEATHER * 1.3, n, 0.0, 0.8, 1.0);
	// 浮き彫りの枠
	float frame_line = step(abs(sd_round_box(bq - vec2(-0.008, 0.008), vec2(0.120, 0.055), 0.010)), 0.005);
	c = mix(c, BRASS * 0.75, frame_line);
	part(acc, d_cover, ink_of(LEATHER), c, f.ow, f.px);
	// 角金具
	for (int sx = -1; sx <= 1; sx += 2) {
		for (int sy = -1; sy <= 1; sy += 2) {
			vec2 cq = bq - vec2(-0.008 + float(sx) * 0.130, 0.008 + float(sy) * 0.063);
			float d_corner = max(sd_round_box(cq, vec2(0.022, 0.022), 0.004), -(cq.x * float(sx) + cq.y * float(sy)) - 0.008);
			part(acc, d_corner, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(float(sx) * 0.3, float(sy) * 0.3, 0.9)), 1.0, 1.0, 1.0), f.ow * 0.5, f.px);
		}
	}
	// 留め帯と錠前
	part(acc, sd_round_box(bq - vec2(0.130, 0.008), vec2(0.035, 0.016), 0.004), ink_of(LEATHER), LEATHER * 0.8, f.ow * 0.6, f.px);
	vec2 lq = bq - vec2(0.160, 0.008);
	part(acc, sd_round_box(lq, vec2(0.018, 0.024), 0.005), ink_of(BRASS), shade_mat(BRASS, normalize(vec3(lq / 0.02 * 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	over(acc, vec3(0.06), cov(min(length(lq - vec2(0.0, 0.004)) - 0.005, sd_round_box(lq - vec2(0.0, -0.006), vec2(0.002, 0.008), 0.001)), f.px));
	// 宝石
	vec2 gq = bq - vec2(-0.008, 0.008);
	part(acc, sd_rhombus(gq, vec2(0.030, 0.040)), ink_of(BRASS), BRASS, f.ow * 0.6, f.px);
	part(acc, sd_rhombus(gq, vec2(0.020, 0.028)), ink_of(sand_color), shade_mat(sand_color, normalize(vec3(sign(gq.x) * 0.4, sign(gq.y) * 0.4, 0.8)), 0.4, 1.0, 1.0), f.ow * 0.4, f.px);
}

// 魔導書から漏れる光と、浮かぶ文字の粒
void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - TOME;
	add_light(acc, mix(sand_color, vec3(1.0), 0.2), exp(-dot(q, q) / 0.020) * 0.45);
	for (int k = 0; k < 5; k++) {
		vec2 sp = vec2(-0.24 + 0.12 * float(k), 0.08 + 0.03 * hash21(vec2(float(k), 1.0)));
		add_light(acc, mix(sand_color, vec3(1.0), 0.4), star4(q - sp, 0.024) * 0.7);
	}
}

void art_frame(inout vec4 acc, Px f) {
	chained_post(acc, f, -POST_X);
	chained_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	circle_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		tome(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
