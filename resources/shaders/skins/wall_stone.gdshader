shader_type canvas_item;
// スキン「石積み」(ウォール)。GameDesign.md 31章 / Architecture.md 10.19節。

#define SKIN_SAND_COLOR vec3(0.82, 0.58, 0.34)
#define SKIN_SAND_KIND KIND_GRAIN
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_parts.gdshaderinc"

const vec3 STONE = vec3(0.72, 0.69, 0.62);
const vec3 MORTAR = vec3(0.30, 0.29, 0.27);
const vec3 MOSS = vec3(0.42, 0.58, 0.24);
const vec3 IVY = vec3(0.30, 0.56, 0.22);
const vec3 TORCH = vec3(1.0, 0.70, 0.30);
const vec3 BANNER = vec3(0.74, 0.17, 0.17);
const float TOWER_X = 0.70;
const float TOWER_HALF = 0.088;
const vec2 TOWER_STONE = vec2(0.088, 0.072);
const vec2 WALL_STONE = vec2(0.150, 0.054);
const float MERLON_Y0 = 1.170;
const float MERLON_Y1 = 1.268;
const float MERLON_STEP = 0.24;
const float MERLON_HALF = 0.072;

// 石積みの模様。x=目地までの距離、y=石ごとの乱数、zw=石の中の位置
vec4 masonry(vec2 p, vec2 cell) {
	float row = floor(p.y / cell.y);
	float off = mod(row, 2.0) * 0.5;
	float col = floor(p.x / cell.x + off);
	vec2 l = vec2(fract(p.x / cell.x + off) - 0.5, fract(p.y / cell.y) - 0.5) * cell;
	float d = min(cell.x * 0.5 - abs(l.x), cell.y * 0.5 - abs(l.y));
	return vec4(d, hash21(vec2(col, row) + 3.0), l);
}

// 石の面。目地は暗く、石の上の縁は明るく、ところどころ苔むす。
vec3 stone_face(vec2 p, vec2 cell, float shade, float moss_k, float px) {
	vec4 m = masonry(p, cell);
	float fine = smoothstep(0.03, 0.012, px);
	vec3 c = STONE * (0.82 + 0.30 * m.y) * shade;
	c *= 0.92 + 0.16 * vnoise(p * 38.0) * fine;
	float top_edge = smoothstep(cell.y * 0.5 - 0.016, cell.y * 0.5 - 0.004, m.w) * step(0.010, m.x);
	c = mix(c, c * 1.22 + 0.04, top_edge * 0.6 * fine);
	float moss = smoothstep(0.58, 0.74, vnoise(p * 6.5 + 2.0)) * moss_k;
	c = mix(c, MOSS * (0.8 + 0.3 * vnoise(p * 30.0)), moss * 0.85);
	float joint = 1.0 - smoothstep(0.004, 0.004 + max(0.006, px * 0.8), m.x);
	return mix(c, MORTAR, joint * mix(0.45, 1.0, fine));
}

// 狭間の灯の揺らぎ
float torch_flicker(float s) {
	return 0.55 + 0.45 * vnoise(vec2(clock * 7.0, s * 13.0)) * (0.7 + 0.3 * sin(clock * 11.0 + s));
}

void draw_tower(inout vec4 acc, Px f, float cx) {
	vec2 q = vec2(f.p.x - cx, f.p.y);
	if (abs(q.x) > TOWER_HALF + f.pad || f.ay > 1.02 + f.pad) {
		return;
	}
	float d = max(abs(q.x) - TOWER_HALF, f.ay - 1.02);
	// 正面は平ら、右の端だけ陰の側面
	float side = smoothstep(TOWER_HALF * 0.55, TOWER_HALF * 0.62, q.x);
	vec3 c = stone_face(vec2(q.x, q.y) + vec2(cx * 3.0, 0.0), TOWER_STONE, mix(1.0, 0.68, side) * f.ao, 0.6 * smoothstep(-0.2, -1.0, q.y) + 0.25, f.px);
	// 狭間(縦の細い窓)と、中の灯
	for (int k = 0; k < 2; k++) {
		float sy = k == 0 ? 0.50 : -0.42;
		vec2 sq = q - vec2(-0.008, sy);
		float d_slit = sd_round_box(sq, vec2(0.018, 0.080), 0.014);
		float flick = torch_flicker(cx + float(k));
		vec3 inner = mix(vec3(0.10, 0.06, 0.04), TORCH, flick * smoothstep(0.07, -0.05, sq.y));
		c = mix(c, inner, cov(d_slit, f.px));
		c = mix(c, c * 0.55, (1.0 - cov(d_slit, f.px)) * cov(d_slit - 0.012, f.px) * step(0.0, sq.x));
		c += TORCH * 0.35 * flick * exp(-max(d_slit, 0.0) / 0.035) * (1.0 - cov(d_slit, f.px));
	}
	part(acc, d, ink_of(STONE) * 0.9, min(c, vec3(1.0)), f.ow, f.px);
}

// 塔を垂れる蔦。ゆっくり揺れる。
void draw_ivy(inout vec4 acc, Px f, float cx, float y0, float y1, float phase) {
	vec2 q = f.p - vec2(cx, 0.0);
	if (abs(q.x) > 0.10 || f.p.y > y0 + 0.02 || f.p.y < y1 - 0.04) {
		return;
	}
	float hang = clamp((y0 - f.p.y) / (y0 - y1), 0.0, 1.0);
	float sway = 0.012 * sin(clock * 1.3 + phase) * hang;
	float vx = 0.018 * sin(f.p.y * 18.0 + phase) + sway;
	float d_vine = abs(q.x - vx) - max(0.006, f.px * 0.5);
	d_vine = max(d_vine, max(f.p.y - y0, y1 - f.p.y));
	over(acc, IVY * 0.55, cov(d_vine, f.px));
	// 葉: 左右交互
	float stepy = 0.075;
	float k = floor((y0 - f.p.y) / stepy);
	for (int j = 0; j < 2; j++) {
		float kk = k + float(j);
		float ly = y0 - (kk + 0.5) * stepy;
		if (ly < y1) {
			continue;
		}
		float side = mod(kk, 2.0) * 2.0 - 1.0;
		float lx = 0.018 * sin(ly * 18.0 + phase) + 0.012 * sin(clock * 1.3 + phase) * clamp((y0 - ly) / (y0 - y1), 0.0, 1.0);
		vec2 lq = rot(q - vec2(lx + side * 0.026, ly), side * 0.7);
		float d_leaf = sd_ellipse(lq, vec2(0.024, 0.016));
		vec3 n = normalize(vec3(lq / vec2(0.024, 0.016) * 0.5, 0.8));
		part(acc, d_leaf, IVY * 0.35, shade_mat(IVY * (0.85 + 0.3 * hash21(vec2(kk, phase))), n, 0.0, 0.5, 1.0), f.ow * 0.6, f.px);
	}
}

void draw_merlons(inout vec4 acc, Px f) {
	if (f.p.y < MERLON_Y0 - f.pad || f.p.y > MERLON_Y1 + f.pad) {
		return;
	}
	float k = floor(f.p.x / MERLON_STEP + 0.5);
	if (abs(k) > 3.0) {
		return;
	}
	vec2 q = vec2(f.p.x - k * MERLON_STEP, f.p.y - (MERLON_Y0 + MERLON_Y1) * 0.5);
	float d = sd_round_box(q, vec2(MERLON_HALF, (MERLON_Y1 - MERLON_Y0) * 0.5), 0.010);
	float side = smoothstep(MERLON_HALF * 0.55, MERLON_HALF * 0.65, q.x);
	vec3 c = stone_face(f.p + vec2(0.0, 0.03), vec2(0.072, 0.050), mix(1.0, 0.70, side), 0.15, f.px);
	part(acc, d, ink_of(STONE) * 0.9, c, f.ow, f.px);
}

// 中央の旗。砂が落ちている間は強くはためく。
void draw_banner(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(-0.004, MERLON_Y1);
	if (q.x < -0.03 || q.x > 0.27 || q.y < -0.02 || q.y > 0.13) {
		return;
	}
	float d_pole = sd_round_box(q - vec2(0.0, 0.060), vec2(0.010, 0.064), 0.006);
	part(acc, d_pole, ink_of(GOLD), shade_mat(GOLD, lathe_normal(clamp(q.x / 0.01, -1.0, 1.0), 0.0), 1.0, 1.0, 1.0), f.ow, f.px);
	float len = 0.22;
	float t = clamp(q.x / len, 0.0, 1.0);
	float amp = (0.010 + 0.020 * flow) * t;
	float wave = sin(q.x * 26.0 - clock * (3.0 + 5.0 * flow)) * amp;
	float yc = 0.090 - 0.010 * t + wave;
	float hh = 0.034 * (1.0 - 0.35 * t);
	// 先は燕尾に切れる
	float notch = max(0.0, (q.x - len + 0.05) / 0.05) * hh * 0.9;
	float dy = abs(q.y - yc);
	float d_flag = max(dy - hh, max(0.012 - q.x, q.x - len));
	d_flag = max(d_flag, notch - dy);
	float shade = 0.80 + 0.30 * cos(q.x * 26.0 - clock * (3.0 + 5.0 * flow));
	part(acc, d_flag, ink_of(BANNER), BANNER * shade, f.ow * 0.8, f.px);
}

// 底板の中央の門。奥に灯
void draw_gate(inout vec4 acc, Px f, float slab_d) {
	vec2 q = f.p - vec2(0.0, -1.120);
	if (abs(q.x) > 0.09 || abs(q.y) > 0.09) {
		return;
	}
	float d_arch = min(sd_round_box(q - vec2(0.0, -0.020), vec2(0.052, 0.040), 0.002), length(q - vec2(0.0, 0.020)) - 0.052);
	d_arch = max(d_arch, -0.060 - q.y);
	float flick = torch_flicker(5.0);
	vec3 inner = mix(vec3(0.10, 0.06, 0.04), TORCH * 0.9, flick * smoothstep(0.05, -0.06, q.y));
	float grid = max(1.0 - smoothstep(0.0, max(0.006, f.px * 0.7), abs(mod(q.x + 0.013, 0.026) - 0.013) - 0.003),
			1.0 - smoothstep(0.0, max(0.006, f.px * 0.7), abs(mod(q.y + 0.013, 0.026) - 0.013) - 0.003));
	inner = mix(inner, vec3(0.16, 0.13, 0.12), grid * smoothstep(0.03, 0.012, f.px));
	inlay(acc, slab_d, vec3(0.42, 0.40, 0.37), cov(d_arch - 0.016, f.px), f);
	inlay(acc, slab_d, inner, cov(d_arch, f.px), f);
}

void skin_back(inout vec4 acc, Px f) {
}

void skin_frame(inout vec4 acc, Px f) {
	draw_tower(acc, f, -TOWER_X);
	draw_tower(acc, f, TOWER_X);
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -TOWER_X : TOWER_X;
		draw_band(acc, f, vec2(cx, f.side * 0.958), vec2(0.108, 0.036), STONE * 0.92, 0.0);
		draw_band(acc, f, vec2(cx, 0.0), vec2(0.104, 0.026), STONE * 0.92, 0.0);
	}
	draw_ivy(acc, f, -TOWER_X - 0.040, 0.92, 0.14, 0.0);
	draw_ivy(acc, f, TOWER_X + 0.040, -0.06, -0.90, 2.1);
	draw_collars(acc, f, vec3(0.50, 0.48, 0.45), 0.0);
	float d = draw_slab(acc, f, f.side * 1.098, vec2(0.84, 0.080), 0.02, STONE, 0.0, 0.0);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	if (d < 0.0) {
		vec3 c = stone_face(f.p + vec2(0.07, 0.027), WALL_STONE, 1.0 - 0.18 * step(q.y, -0.04), f.side < 0.0 ? 0.55 : 0.30, f.px);
		inlay(acc, d, c, 1.0, f);
	}
	if (f.p.y > 0.0) {
		draw_merlons(acc, f);
		draw_banner(acc, f);
	} else {
		draw_gate(acc, f, d);
	}
}

#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_main.gdshaderinc"
