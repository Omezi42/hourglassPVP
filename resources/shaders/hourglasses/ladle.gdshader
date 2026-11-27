shader_type canvas_item;
// 柄杓(ラドル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は節を重ねた青竹、板は杉の板に素焼きの樋。
// 天板の上に水を湛えた石の手水鉢が据わり、竹の柄杓が斜めに渡されて、合から滴が鉢へ落ちる。

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
const vec3 BAMBOO = vec3(0.50, 0.70, 0.34);
const vec3 CEDAR = vec3(0.70, 0.50, 0.32);
const vec3 STONE = vec3(0.56, 0.57, 0.56);
const vec3 TWINE = vec3(0.30, 0.20, 0.14);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.054;
const float NODE_PITCH = 0.26;
// 手水鉢の中心と半幅・高さ、水面、柄杓の柄の両端と合(水を汲む筒)の中心
const vec2 BASIN = vec2(-0.03, 1.238);
const vec2 BASIN_HALF = vec2(0.190, 0.050);
const float POOL_Y = 1.276;
const vec2 HANDLE_A = vec2(-0.29, 1.292);
const vec2 HANDLE_B = vec2(0.060, 1.328);
const vec2 CUP = vec2(0.100, 1.330);

// 節を重ねた青竹。節ごとに少し膨らみ、節の上下で色が変わる
void bamboo_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + 0.012 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	float seg = fract(f.ay / NODE_PITCH);
	vec3 culm = BAMBOO * mix(1.08, 0.82, seg);
	part(acc, d, ink_of(BAMBOO), shade_mat(culm, n, 0.0, 0.8, f.ao), f.ow, f.px);
	over(acc, BAMBOO * 1.3, cov(abs(lx + POST_R * 0.35) - 0.006, f.px) * step(f.ay, POST_H) * 0.5);
	float node_y = floor(f.ay / NODE_PITCH + 0.5) * NODE_PITCH;
	if (node_y > 0.04 && node_y < POST_H - 0.04) {
		draw_band(acc, f, vec2(cx, f.side * node_y), vec2(POST_R + 0.008, 0.010), BAMBOO * 0.9, 0.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.028), TWINE, 0.0);
}

void cedar_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, CEDAR, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float grain = abs(fract(q.y * 26.0 + sin(q.x * 4.0 + cy) * 0.6) - 0.5);
	inlay(acc, d, CEDAR * 0.72, smoothstep(0.06, 0.0, grain) * 0.5, f);
	pour_trough(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		float x = k == 0 ? -0.74 : 0.74;
		inlay(acc, d, TWINE, cov(abs(q.x - x) - 0.014, f.px), f);
	}
}

// 石の手水鉢と、斜めに渡した竹の柄杓、合から落ちる滴
void basin(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.36 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	vec2 b = q - BASIN;
	float d_bowl = sd_round_box(b, BASIN_HALF, 0.030);
	float speck = hash21(floor(q * 220.0));
	vec3 n = normalize(vec3(b.x / BASIN_HALF.x * 0.5, b.y / BASIN_HALF.y * 0.4, 0.8));
	vec3 stone = shade_mat(STONE * mix(0.86, 1.06, speck), n, 0.0, 0.1, 1.0);
	part(acc, d_bowl, ink_of(STONE), stone, f.ow, f.px);
	float d_pool = sd_ellipse(q - vec2(BASIN.x, POOL_Y), vec2(BASIN_HALF.x - 0.022, 0.016));
	part(acc, d_pool, ink_of(STONE), mix(sand_color * 0.6, sand_color, smoothstep(POOL_Y - 0.014, POOL_Y + 0.012, q.y)), f.ow * 0.6, f.px);
	over(acc, vec3(1.0), cov(abs(sd_ellipse(q - vec2(BASIN.x + 0.04, POOL_Y), vec2(0.030, 0.006))) - 0.002, f.px) * 0.7);
	float d_handle = sd_segment(q, HANDLE_A, HANDLE_B) - 0.011;
	part(acc, d_handle, ink_of(BAMBOO), shade_mat(BAMBOO * 1.05, vec3(0.0, 0.6, 0.8), 0.0, 0.6, 1.0), f.ow * 0.6, f.px);
	vec2 c = q - CUP;
	float d_cup = sd_round_box(c, vec2(0.038, 0.030), 0.010);
	vec3 cn = lathe_normal(clamp(c.x / 0.038, -1.0, 1.0), 0.0);
	part(acc, d_cup, ink_of(BAMBOO), shade_mat(BAMBOO * 0.95, cn, 0.0, 0.6, 1.0), f.ow * 0.8, f.px);
	draw_band(acc, f, CUP + vec2(0.0, 0.022), vec2(0.040, 0.007), BAMBOO * 0.8, 0.0);
	for (int k = 0; k < 2; k++) {
		vec2 dq = q - vec2(CUP.x + 0.004, CUP.y - 0.044 - 0.016 * float(k));
		float d_drop = length(dq * vec2(1.0, 0.75)) - (0.008 - 0.002 * float(k));
		part(acc, d_drop, ink_of(sand_color), mix(sand_color, vec3(1.0), 0.45), f.ow * 0.5, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2((f.p.x - 0.04) * 1.4, f.p.y - 1.27);
	add_light(acc, sand_color, exp(-dot(d, d) / 0.009) * 0.28 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	bamboo_post(acc, f, -POST_X);
	bamboo_post(acc, f, POST_X);
	draw_collars(acc, f, TWINE, 0.0);
	cedar_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		basin(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
