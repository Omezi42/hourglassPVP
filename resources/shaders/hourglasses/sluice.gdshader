shader_type canvas_item;
// 水門(スルース)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は門の溝を切った切石積みの橋脚、板は切石に素焼きの樋。
// 天板の上の二本の石の橋脚のあいだに板張りの門扉が閉じ、扉の上の縁まで水が溜まって隙間から滴り、
// 渡した梁の上で鉄の巻き上げ車が明日を待つ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 TROUGH_CLAY = vec3(0.84, 0.44, 0.22);
const vec3 POOL_DEEP = vec3(0.03, 0.28, 0.34);
const vec3 POOL_LIT = vec3(0.30, 0.82, 0.78);
const vec3 SPILL = vec3(0.88, 1.0, 0.97);
// 樋の切り欠き(水が溢れ落ちる所)の位置
const float SPILL_X = 0.44;
// 注砂の刻の印: 板に嵌めた舟形の素焼きの樋に青緑の水が縁まで満ち、右寄りで縁を越えて板の下の縁まで溢れ落ちる
void pour_trough(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.09) {
		return;
	}
	float w = mix(0.56, 0.64, clamp((q.y + 0.040) / 0.080, 0.0, 1.0));
	float trough = sd_round_box(vec2(q.x * 0.64 / w, q.y), vec2(0.64, 0.040), 0.030);
	inlay(acc, d, ink_of(TROUGH_CLAY), cov(trough - 0.022, f.px), f);
	vec3 clay = TROUGH_CLAY * mix(0.74, 1.14, smoothstep(-0.06, 0.06, q.y));
	inlay(acc, d, clay, cov(trough - 0.015, f.px), f);
	inlay(acc, d, ink_of(TROUGH_CLAY), cov(trough - 0.002, f.px), f);
	float depth = clamp((0.026 - q.y) / 0.064, 0.0, 1.0);
	float swell = 0.5 + 0.5 * sin(q.x * 38.0 + sin(q.x * 7.0) * 2.0 + q.y * 60.0);
	vec3 water = mix(POOL_LIT, POOL_DEEP, depth) * mix(0.9, 1.08, swell);
	inlay(acc, d, water, cov(trough + 0.002, f.px), f);
	float inside = cov(trough + 0.004, f.px);
	float surface = abs(q.y - 0.020 - 0.004 * sin(q.x * 30.0 + 0.6)) - 0.006;
	inlay(acc, d, SPILL, cov(surface, f.px) * inside, f);
	vec2 s = q - vec2(SPILL_X, 0.0);
	float wob = 0.003 * sin(q.y * 120.0);
	float spread = mix(0.030, 0.014, clamp((0.0 - q.y) / 0.05, 0.0, 1.0));
	float fall = max(abs(s.x + wob) - spread, max(q.y - 0.018, -0.084 - q.y));
	inlay(acc, d, ink_of(POOL_DEEP), cov(fall - 0.007, f.px), f);
	inlay(acc, d, mix(POOL_LIT, SPILL, 0.45 + 0.3 * sin(q.y * 80.0)), cov(fall, f.px), f);
	inlay(acc, d, SPILL, cov(abs(s.x + wob + 0.005) - 0.004, f.px) * cov(fall, f.px), f);
	for (int k = 0; k < 2; k++) {
		vec2 c = vec2(k == 0 ? -0.040 : 0.042, k == 0 ? -0.060 : -0.072);
		float drop = length((s - c) * vec2(1.0, 0.8)) - 0.008;
		inlay(acc, d, ink_of(POOL_DEEP), cov(drop - 0.005, f.px), f);
		inlay(acc, d, SPILL, cov(drop, f.px), f);
	}
}
const vec3 ASHLAR = vec3(0.66, 0.62, 0.56);
const vec3 PLANK = vec3(0.54, 0.36, 0.22);
const vec3 IRON = vec3(0.30, 0.31, 0.34);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.064;
const vec2 BLOCK = vec2(0.064, 0.090);
// 橋脚の中心x・半幅と頂、門扉の半幅と上端、溜まった水の面、梁の高さ、巻き上げ車の中心と半径
const float PIER_X = 0.200;
const float PIER_W = 0.034;
const float PIER_TOP = 1.330;
const float GATE_W = 0.170;
const float GATE_TOP = 1.258;
const float POOL_Y = 1.304;
const float BEAM_Y = 1.336;
const vec2 WINCH = vec2(0.0, 1.352);
const float WINCH_R = 0.032;

// 切石を積んだ橋脚。正面に門の溝
void ashlar_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		float row = floor(f.p.y / BLOCK.y);
		float off = mod(row, 2.0) * BLOCK.x * 0.5;
		vec2 cell = vec2(mod(lx + off, BLOCK.x), mod(f.p.y, BLOCK.y));
		float joint = min(min(cell.x, BLOCK.x - cell.x), min(cell.y, BLOCK.y - cell.y));
		vec3 stone = ASHLAR * mix(0.86, 1.06, hash21(vec2(floor((lx + off) / BLOCK.x), row)));
		vec3 n = normalize(vec3(smoothstep(POST_R * 0.6, POST_R, abs(lx)) * sign(lx) * 0.8, 0.0, 0.7));
		part(acc, d, ink_of(ASHLAR), shade_mat(stone, n, 0.0, 0.1, f.ao), f.ow, f.px);
		over(acc, ink_of(ASHLAR), cov(joint - 0.003, f.px) * 0.6 * step(abs(lx), POST_R - 0.003) * step(f.ay, POST_H));
		over(acc, ink_of(ASHLAR) * 1.5, cov(abs(lx) - 0.010, f.px) * 0.7 * step(f.ay, POST_H - 0.04));
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.032), ASHLAR * 0.85, 0.0);
}

void ashlar_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.016, ASHLAR, 0.0, 0.2);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float joint = abs(fract(q.x / 0.22 + 0.5) - 0.5) * 0.22;
	inlay(acc, d, ink_of(ASHLAR) * 1.4, cov(joint - 0.003, f.px) * step(0.055, abs(q.y)), f);
	pour_trough(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.022, IRON, 1.0);
	}
}

// 二本の石の橋脚、閉じた板張りの門扉と溜まった水、梁の上の巻き上げ車
void gate(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.28 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	float d_pool = max(abs(q.x) - PIER_X + PIER_W * 0.6, max(GATE_TOP - 0.010 - q.y, q.y - POOL_Y - 0.003 * sin(q.x * 60.0)));
	part(acc, d_pool, ink_of(POOL_DEEP), mix(sand_color * 0.7, sand_color, smoothstep(GATE_TOP, POOL_Y, q.y)), f.ow * 0.6, f.px);
	over(acc, SPILL, cov(abs(q.y - POOL_Y + 0.004 - 0.003 * sin(q.x * 60.0)) - 0.005, f.px) * step(abs(q.x), PIER_X - PIER_W));
	over(acc, POOL_LIT, cov(abs(q.y - POOL_Y + 0.022 - 0.004 * sin(q.x * 45.0 + 1.0)) - 0.003, f.px) * step(abs(q.x), PIER_X - PIER_W) * 0.8);
	vec2 g = vec2(q.x, q.y - (1.19 + GATE_TOP) * 0.5);
	float d_gate = sd_round_box(g, vec2(GATE_W, (GATE_TOP - 1.19) * 0.5), 0.006);
	float plank = abs(fract(q.y / 0.022) - 0.5) * 0.022;
	vec3 wood = shade_mat(PLANK * mix(0.88, 1.06, hash21(vec2(floor(q.y / 0.024), 2.0))), vec3(0.0, 0.2, 0.95), 0.0, 0.3, 1.0);
	part(acc, d_gate, ink_of(PLANK), wood, f.ow, f.px);
	over(acc, ink_of(PLANK), cov(plank - 0.002, f.px) * cov(d_gate + 0.004, f.px) * 0.7);
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		float d_strap = max(abs(q.x - sx * 0.110) - 0.010, abs(g.y) - (GATE_TOP - 1.19) * 0.5);
		part(acc, d_strap, ink_of(IRON), shade_mat(IRON, vec3(0.0, 0.3, 0.9), 1.0, 0.8, 1.0), f.ow * 0.5, f.px);
		vec2 dq = q - vec2(sx * 0.050, 1.218 - 0.012 * float(k));
		float d_drip = length(dq * vec2(1.0, 0.75)) - 0.009;
		part(acc, d_drip, ink_of(POOL_DEEP), SPILL, f.ow * 0.4, f.px);
		float px_c = sx * PIER_X;
		float d_pier = sd_round_box(q - vec2(px_c, (1.19 + PIER_TOP) * 0.5), vec2(PIER_W, (PIER_TOP - 1.19) * 0.5), 0.006);
		float course = abs(fract(q.y / 0.036) - 0.5) * 0.036;
		vec3 stone = shade_mat(ASHLAR * mix(0.72, 0.88, hash21(vec2(floor(q.y / 0.036), sx))), normalize(vec3(sx * 0.2, 0.2, 0.9)), 0.0, 0.1, 1.0);
		part(acc, d_pier, ink_of(ASHLAR), stone, f.ow, f.px);
		over(acc, ink_of(ASHLAR), cov(course - 0.002, f.px) * cov(d_pier + 0.004, f.px) * 0.6);
		draw_ball(acc, f, vec2(px_c, PIER_TOP + 0.012), 0.016, ASHLAR * 0.8, 0.0);
	}
	float d_beam = sd_round_box(q - vec2(0.0, BEAM_Y), vec2(PIER_X + 0.014, 0.011), 0.004);
	part(acc, d_beam, ink_of(PLANK), shade_mat(PLANK, vec3(0.0, 0.4, 0.9), 0.0, 0.3, 1.0), f.ow * 0.8, f.px);
	float d_rod = max(abs(q.x) - 0.008, max(GATE_TOP - q.y, q.y - BEAM_Y));
	part(acc, d_rod, ink_of(IRON), shade_mat(IRON, vec3(0.3, 0.3, 0.9), 1.0, 1.0, 1.0), f.ow * 0.5, f.px);
	vec2 w = q - WINCH;
	float r = length(w);
	float a2 = mod(atan(w.y, w.x) + 0.3927, 0.7854) - 0.3927;
	float d_wheel = min(abs(r - WINCH_R + 0.006) - 0.006, max(abs(sin(a2) * r) - 0.004, r - WINCH_R));
	d_wheel = min(d_wheel, r - 0.009);
	part(acc, d_wheel, ink_of(IRON), shade_mat(IRON, normalize(vec3(w / WINCH_R * 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	draw_ball(acc, f, WINCH, 0.010, IRON, 1.0);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.3, f.p.y - 1.29);
	add_light(acc, POOL_LIT, exp(-dot(d, d) / 0.010) * 0.30 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	ashlar_post(acc, f, -POST_X);
	ashlar_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	ashlar_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		gate(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
