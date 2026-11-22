shader_type canvas_item;
// 永劫(アイオーン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は細い軸に天球の輪と小さな惑星を通したもの、板には日と月が交互に並ぶ黄道。天板の上に尾をくわえた蛇の円環。後ろに大きな軌道の輪。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 COSMOS = vec3(0.14, 0.10, 0.26);
const vec3 SERPENT = vec3(0.30, 0.62, 0.48);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float AXIS_R = 0.016;
const float RING_PITCH = 0.24;
const vec2 OURO = vec2(0.0, 1.272);
const float OURO_R = 0.072;
const float OURO_W = 0.020;

// 細い金の軸に、斜めに傾いた輪(楕円)と小さな惑星をいくつも通す
void orbit_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d_axis = max(abs(lx) - AXIS_R, f.ay - POST_H);
	part(acc, d_axis, ink_of(GOLD), shade_mat(GOLD, lathe_normal(clamp(lx / AXIS_R, -1.0, 1.0), 0.0), 1.0, 1.0, f.ao), f.ow * 0.6, f.px);
	float k = floor(f.ay / RING_PITCH + 0.5);
	vec2 rq = vec2(lx, f.ay - k * RING_PITCH);
	if (k * RING_PITCH < POST_H - 0.08) {
		vec2 tq = rot(rq, 0.35);
		float d_ring = abs(sd_ellipse(tq, vec2(0.070, 0.020))) - 0.006;
		part(acc, d_ring, ink_of(SILVER), mix(SILVER, sand_color, 0.4), f.ow * 0.5, f.px);
		float d_planet = length(rq) - 0.024;
		vec3 pn = normalize(vec3(rq / 0.024 * 0.7, 0.7));
		vec3 pc = shade_mat(mod(k, 2.0) < 0.5 ? sand_color : SERPENT, pn, 0.2, 1.0, 1.0);
		part(acc, d_planet, ink_of(COSMOS), pc, f.ow * 0.6, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), COSMOS * 2.0, 0.4);
}

void zodiac_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, COSMOS, 0.3, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	inlay(acc, d, GOLD * 0.8, cov(abs(abs(q.y) - 0.050) - 0.003, f.px) * step(abs(q.x), 0.72), f);
	for (int k = -3; k <= 3; k++) {
		vec2 sq = q - vec2(float(k) * 0.20, 0.0);
		if ((k & 1) == 0) {
			float d_sun = length(sq) - 0.018;
			float rays = abs(fract(atan(sq.y, sq.x) / 6.2832 * 8.0) - 0.5);
			float d_rays = max(length(sq) - 0.032, rays * 0.06 - 0.008);
			inlay(acc, d, GOLD, cov(min(d_sun, d_rays), f.px), f);
		} else {
			float d_moon = max(length(sq) - 0.026, -(length(sq - vec2(0.012, 0.006)) - 0.022));
			inlay(acc, d, SILVER, cov(d_moon, f.px), f);
		}
	}
}

// 尾をくわえた蛇の円環: 鱗の帯の輪、上で頭が尾を噛む。中心に砂の色の星
void ouroboros(inout vec4 acc, Px f) {
	vec2 q = f.p - OURO;
	if (length(q) > OURO_R + OURO_W + 0.03 + f.pad) {
		return;
	}
	float a = atan(q.x, q.y);
	float taper = mix(0.45, 1.0, smoothstep(0.0, 1.2, abs(a)));
	float d_body = abs(length(q) - OURO_R) - OURO_W * taper;
	float scale = abs(fract(a / 6.2832 * 28.0) - 0.5);
	vec3 n = normalize(vec3(q / OURO_R * 0.3, 0.9));
	vec3 c = shade_mat(SERPENT, n, 0.3, 1.0, 1.0) * mix(0.75, 1.0, smoothstep(0.1, 0.3, scale));
	part(acc, d_body, ink_of(SERPENT), c, f.ow * 0.7, f.px);
	vec2 hq = q - vec2(0.020, OURO_R);
	float d_head = sd_ellipse(rot(hq, -0.3), vec2(0.034, 0.022));
	part(acc, d_head, ink_of(SERPENT), shade_mat(SERPENT, normalize(vec3(hq * 10.0, 0.8)), 0.3, 1.0, 1.0), f.ow * 0.7, f.px);
	over(acc, vec3(1.0, 0.9, 0.4), cov(length(hq - vec2(0.010, 0.006)) - 0.005, f.px));
	add_light(acc, sand_color, star4(q, 0.070));
	over(acc, mix(sand_color, vec3(1.0), 0.4), cov(length(q) - 0.010, f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, 0.05);
	float orbit = abs(sd_ellipse(q, vec2(0.95, 1.18))) - 0.006;
	float dots = step(0.97, fract(atan(q.y, q.x) / 6.2832 * 36.0));
	add_light(acc, mix(sand_color, vec3(1.0), 0.3), (cov(orbit, f.px) * 0.35 + cov(orbit - 0.012, f.px) * dots * 0.5) * canvas_window(f.p) * (1.0 - acc.a));
}

void art_frame(inout vec4 acc, Px f) {
	orbit_post(acc, f, -POST_X);
	orbit_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	zodiac_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		ouroboros(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
