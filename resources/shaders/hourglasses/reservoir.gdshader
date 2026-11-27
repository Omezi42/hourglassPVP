shader_type canvas_item;
// 貯水槽(リザーバー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱はフランジで継いだ緑青の鉄管に赤い弁の輪、板は鋲を打った鉄板に素焼きの樋。
// 天板の上に脚の付いた鋲打ちの円い貯水槽が立ち、胴の硝子の窓に溜まった水の高さが見える。円錐の屋根の頂に赤い小旗。

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
const vec3 VERDIGRIS = vec3(0.34, 0.56, 0.50);
const vec3 IRON = vec3(0.34, 0.36, 0.40);
const vec3 VALVE = vec3(0.80, 0.20, 0.16);
const vec3 BRASS = vec3(0.92, 0.70, 0.34);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.050;
// 弁の輪の高さと半径、槽の中心・半幅・半高、脚の足元、水位、屋根の頂
const float WHEEL_Y = 0.52;
const float WHEEL_R = 0.054;
const vec2 TANK = vec2(0.0, 1.284);
const vec2 TANK_HALF = vec2(0.118, 0.050);
const float LEG_FOOT = 1.190;
const float LEVEL_Y = 1.290;
const float ROOF_TOP = 1.376;

// フランジで継いだ緑青の鉄管。中ほどに赤い弁の輪
void pipe_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, VERDIGRIS, 0.5);
	for (int k = 0; k < 4; k++) {
		float y = 0.12 + 0.26 * float(k);
		if (abs(y - WHEEL_Y) < 0.08) {
			continue;
		}
		draw_band(acc, f, vec2(cx, f.side * y), vec2(POST_R + 0.016, 0.012), IRON, 1.0);
		draw_ball(acc, f, vec2(cx - 0.044, f.side * y), 0.006, BRASS, 1.0);
		draw_ball(acc, f, vec2(cx + 0.044, f.side * y), 0.006, BRASS, 1.0);
	}
	vec2 w = vec2(f.p.x - cx, f.p.y - f.side * WHEEL_Y);
	if (length(w) < WHEEL_R + f.pad) {
		float r = length(w);
		float a = atan(w.y, w.x);
		float d_rim = abs(r - WHEEL_R + 0.010) - 0.010;
		float spoke = abs(fract(a / 6.2832 * 4.0 + 0.125) - 0.5) * 6.2832 / 4.0 * r;
		float d_spoke = max(spoke - 0.007, r - WHEEL_R + 0.012);
		vec3 n = normalize(vec3(w / WHEEL_R * 0.5, 0.8));
		part(acc, min(min(d_rim, d_spoke), r - 0.016), ink_of(VALVE), shade_mat(VALVE, n, 0.6, 1.0, 1.0), f.ow * 0.8, f.px);
		draw_ball(acc, f, vec2(cx, f.side * WHEEL_Y), 0.010, BRASS, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), IRON, 1.0);
}

void plate_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, IRON, 0.8, 0.7);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	for (int k = 0; k < 9; k++) {
		float x = -0.76 + 0.19 * float(k);
		inlay(acc, d, BRASS * 0.9, cov(length(q - vec2(x, 0.064)) - 0.007, f.px), f);
		inlay(acc, d, BRASS * 0.9, cov(length(q - vec2(x, -0.064)) - 0.007, f.px), f);
	}
	pour_trough(acc, f, d, q);
}

// 脚の付いた鋲打ちの貯水槽、脇の水位計、円錐の屋根と小旗
void tank(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.26 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	vec3 iron = shade_mat(IRON, normalize(vec3(0.2, 0.3, 0.9)), 0.8, 0.6, 1.0);
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		float d_leg = sd_segment(q, vec2(TANK.x + sx * 0.112, LEG_FOOT), vec2(TANK.x + sx * 0.084, TANK.y - TANK_HALF.y)) - 0.011;
		part(acc, d_leg, ink_of(IRON), iron, f.ow * 0.8, f.px);
	}
	float d_brace = min(sd_segment(q, TANK + vec2(-0.104, -0.090), TANK + vec2(0.092, -0.054)), sd_segment(q, TANK + vec2(0.104, -0.090), TANK + vec2(-0.092, -0.054))) - 0.005;
	part(acc, d_brace, ink_of(IRON), iron * 0.85, f.ow * 0.5, f.px);
	vec2 t = q - TANK;
	float d_tank = sd_round_box(t, TANK_HALF, 0.012);
	vec3 n = lathe_normal(clamp(t.x / TANK_HALF.x, -1.0, 1.0), 0.0);
	vec3 shell = shade_mat(VERDIGRIS, n, 0.5, 0.8, 1.0);
	part(acc, d_tank, ink_of(VERDIGRIS), shell, f.ow, f.px);
	for (int k = 0; k < 2; k++) {
		float y = k == 0 ? -0.026 : 0.026;
		over(acc, ink_of(VERDIGRIS), cov(abs(t.y - y) - 0.003, f.px) * cov(d_tank + 0.004, f.px) * 0.7);
		for (int j = 0; j < 6; j++) {
			float x = -0.090 + 0.036 * float(j);
			over(acc, BRASS * 0.9, cov(length(t - vec2(x, y + 0.010)) - 0.004, f.px));
		}
	}
	float d_window = sd_round_box(t, vec2(0.022, 0.040), 0.012);
	part(acc, d_window, ink_of(IRON), vec3(0.16, 0.20, 0.24), f.ow * 0.8, f.px);
	over(acc, sand_color, cov(max(d_window + 0.006, q.y - LEVEL_Y), f.px));
	over(acc, mix(sand_color, vec3(1.0), 0.6), cov(abs(q.y - LEVEL_Y) - 0.0035, f.px) * cov(d_window + 0.006, f.px));
	over(acc, vec3(1.0), cov(abs(t.x + 0.010) - 0.003, f.px) * cov(d_window + 0.008, f.px) * 0.4);
	vec2 r = q - vec2(TANK.x, TANK.y + TANK_HALF.y);
	float slope = abs(r.x) * 0.32 + r.y - 0.046;
	float d_roof = max(slope, max(-r.y, abs(r.x) - TANK_HALF.x - 0.014));
	part(acc, d_roof, ink_of(IRON), shade_mat(IRON, normalize(vec3(sign(r.x) * 0.4, 0.6, 0.7)), 0.8, 0.8, 1.0), f.ow, f.px);
	float d_pole = max(abs(r.x) - 0.004, max(-r.y + 0.04, r.y - (ROOF_TOP - TANK.y - TANK_HALF.y)));
	part(acc, d_pole, ink_of(IRON), iron, f.ow * 0.4, f.px);
	vec2 fl = q - vec2(TANK.x + 0.004, ROOF_TOP - 0.016);
	float d_flag = max(max(-fl.x, fl.x - 0.050), abs(fl.y + 0.004 * sin(fl.x * 80.0)) - 0.014 * (1.0 - fl.x / 0.062));
	part(acc, d_flag, ink_of(VALVE), VALVE, f.ow * 0.5, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.4, f.p.y - 1.29);
	add_light(acc, POOL_LIT, exp(-dot(d, d) / 0.010) * 0.28 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	pipe_post(acc, f, -POST_X);
	pipe_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	plate_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		tank(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
