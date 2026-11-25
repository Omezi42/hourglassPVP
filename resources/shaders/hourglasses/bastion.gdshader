shader_type canvas_item;
// 最後の城壁(バスティオン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 裾の広がった黒い玄武岩の控え壁を柱にし、ひびを鉄のかすがいで留める。天板の上には狭間を開けた稜堡の胸壁が立つ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BASALT = vec3(0.40, 0.40, 0.44);
const vec3 MORTAR = vec3(0.13, 0.13, 0.15);
const vec3 IRON = vec3(0.36, 0.37, 0.40);
const vec3 EMBER = vec3(1.0, 0.44, 0.14);
const vec3 EMBER_HOT = vec3(1.0, 0.88, 0.56);
// 控え壁の上端・下端の半幅
const float BUTT_TOP = 0.066;
const float BUTT_BOTTOM = 0.098;
const vec2 SLAB_HALF = vec2(0.85, 0.090);
// 胸壁: 下端・上端の高さと半幅、狭間の数
const float PARAPET_Y0 = 1.120;
const float PARAPET_Y1 = 1.295;
const float PARAPET_BOTTOM = 0.400;
const float PARAPET_TOP = 0.330;

void ember_seam(inout vec4 acc, Px f, float d, vec2 q, float half_x) {
	float line = cov(abs(q.y) - 0.008, f.px) * step(abs(q.x), half_x);
	inlay(acc, d, mix(EMBER, EMBER_HOT, cov(abs(q.y) - 0.003, f.px)), line, f);
}

// 石積み: x=目地までの距離、y=石ごとの乱数
vec2 masonry(vec2 p, vec2 cell) {
	float row = floor(p.y / cell.y);
	float off = mod(row, 2.0) * 0.5;
	float col = floor(p.x / cell.x + off);
	vec2 l = vec2(fract(p.x / cell.x + off) - 0.5, fract(p.y / cell.y) - 0.5) * cell;
	return vec2(min(cell.x * 0.5 - abs(l.x), cell.y * 0.5 - abs(l.y)), hash21(vec2(col, row) + 3.0));
}

vec3 basalt_face(vec2 p, vec2 cell, float shade, float px) {
	vec2 m = masonry(p, cell);
	float fine = smoothstep(0.03, 0.012, px);
	vec3 c = BASALT * (0.80 + 0.32 * m.y) * shade;
	c *= 0.92 + 0.16 * vnoise(p * 40.0) * fine;
	float joint = 1.0 - smoothstep(0.004, 0.004 + max(0.006, px * 0.8), m.x);
	return mix(c, MORTAR, joint * mix(0.5, 1.0, fine));
}

// 鉄のかすがい(コの字の留め金)
float cramp(vec2 q) {
	float d_bar = sd_round_box(q, vec2(0.040, 0.008), 0.006);
	float d_leg = sd_round_box(vec2(abs(q.x) - 0.034, q.y + 0.010), vec2(0.008, 0.016), 0.005);
	return min(d_bar, d_leg);
}

void buttress(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	float k = clamp((POST_H - f.p.y) / (2.0 * POST_H), 0.0, 1.0);
	float hw = mix(BUTT_TOP, BUTT_BOTTOM, k);
	if (abs(lx) > BUTT_BOTTOM + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - hw, f.ay - POST_H);
	float side = smoothstep(hw * 0.5, hw * 0.6, lx * sign(-cx));
	vec3 c = basalt_face(vec2(lx + cx * 2.0, f.p.y), vec2(0.10, 0.068), mix(1.0, 0.68, side) * f.ao, f.px);
	// 斜めに走るひびが内側から赤く灯る
	float crack_y = 0.32 * sign(cx);
	float cr = abs(f.p.y - crack_y - lx * 0.9 - 0.02 * sin(lx * 90.0));
	c = mix(c, EMBER, cov(cr - 0.011, f.px));
	c = mix(c, EMBER_HOT, cov(cr - 0.004, f.px));
	part(acc, d, MORTAR, c, f.ow, f.px);
	vec2 cq = vec2(lx, f.p.y - crack_y);
	part(acc, cramp(cq), vec3(0.06), shade_mat(IRON * 1.4, normalize(vec3(0.0, 0.4, 0.85)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.112, 0.032), BASALT * 0.9, 0.0);
}

void stone_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, BASALT * 0.62, 0.0, 0.2);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	ember_seam(acc, f, d, q, 0.76);
}

// 稜堡の胸壁: 裾の広い台形、上に低い歯、正面に狭間。中央を縦に割るひびを鉄で留める
void parapet(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, PARAPET_Y0);
	float h = PARAPET_Y1 - PARAPET_Y0;
	if (abs(q.x) > PARAPET_BOTTOM + 0.03 || q.y < -0.02 || q.y > h + 0.09) {
		return;
	}
	float hw = mix(PARAPET_BOTTOM, PARAPET_TOP, clamp(q.y / h, 0.0, 1.0));
	float d_body = max(abs(q.x) - hw, max(-q.y, q.y - h));
	// 歯: 中央と両端に3つ
	float tk = clamp(floor(q.x / 0.255 + 0.5), -1.0, 1.0);
	vec2 tq = vec2(q.x - tk * 0.255, q.y - h - 0.034);
	float d_teeth = sd_round_box(tq, vec2(0.072, 0.036), 0.008);
	float d = min(d_body, d_teeth);
	float side = smoothstep(0.0, 0.02, abs(q.x) - hw + 0.045) * step(q.y, h);
	vec3 c = basalt_face(f.p * vec2(1.0, 1.0) + vec2(0.05, 0.0), vec2(0.115, 0.055), mix(1.08, 0.72, side), f.px);
	part(acc, d, MORTAR, c, f.ow, f.px);
	// 狭間(暗い縦長の窓)を2つ
	vec2 sq = vec2(abs(q.x) - 0.190, q.y - h * 0.52);
	float d_slit = max(sd_round_box(sq, vec2(0.020, 0.048), 0.016), d_body);
	over(acc, vec3(0.05, 0.04, 0.05), cov(d_slit, f.px));
	over(acc, EMBER, cov(d_slit + 0.008, f.px) * smoothstep(0.03, -0.04, sq.y) * 0.8);
	// 中央のひびと鉄のかすがい
	float cr = abs(q.x - 0.012 * sin(q.y * 70.0)) - 0.006;
	cr = max(cr, max(-q.y, q.y - h + 0.01));
	over(acc, EMBER, cov(cr, f.px));
	over(acc, EMBER_HOT, cov(cr + 0.004, f.px));
	for (int k = 0; k < 2; k++) {
		vec2 cq = q - vec2(0.0, h * (k == 0 ? 0.30 : 0.72));
		part(acc, cramp(cq), vec3(0.06), shade_mat(IRON * 1.4, normalize(vec3(0.0, 0.4, 0.85)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - vec2(0.0, (PARAPET_Y0 + PARAPET_Y1) * 0.5);
	add_light(acc, EMBER, exp(-dot(d, d) / 0.035) * 0.45 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	buttress(acc, f, -POST_X);
	buttress(acc, f, POST_X);
	draw_collars(acc, f, BASALT * 0.8, 0.0);
	stone_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		parapet(acc, f);
	} else if (f.p.y < 0.0) {
		vec2 cq = f.p - vec2(0.0, -PLATE_Y);
		part(acc, cramp(cq * 0.8), vec3(0.06), shade_mat(IRON * 1.4, normalize(vec3(0.0, 0.4, 0.85)), 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
