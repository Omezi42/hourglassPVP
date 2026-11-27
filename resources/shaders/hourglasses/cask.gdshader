shader_type canvas_item;
// 樽(キャスク)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は鉄の箍で締めた樽板の束、板は樫の厚板に素焼きの樋。
// 天板の上の木の台に樽が横に寝て、鏡板の真鍮の呑み口から砂の色の酒が細く注がれる。

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
const vec3 OAK = vec3(0.60, 0.38, 0.20);
const vec3 HOOP = vec3(0.34, 0.33, 0.34);
const vec3 BRASS = vec3(0.92, 0.70, 0.34);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.066;
const float STAVE = 0.022;
// 寝た樽の中心・胴の半長・胴の中ほどと鏡板の半高、呑み口の先
const vec2 CASK = vec2(-0.04, 1.276);
const float CASK_LEN = 0.200;
const float CASK_MID = 0.080;
const float CASK_END = 0.062;
const vec2 TAP = vec2(0.236, 1.250);

// 縦の樽板を束ねて鉄の箍で締めた柱
void stave_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
		float k = floor(lx / STAVE + 0.5);
		vec3 wood = OAK * mix(0.84, 1.08, hash21(vec2(k, cx * 5.0)));
		wood *= mix(0.9, 1.05, sin(f.p.y * 60.0 + k * 3.0) * 0.5 + 0.5);
		part(acc, d, ink_of(OAK), shade_mat(wood, n, 0.0, 0.3, f.ao), f.ow, f.px);
		float seam = abs(fract(lx / STAVE + 0.5) - 0.5) * STAVE;
		over(acc, ink_of(OAK), cov(seam - 0.0018, f.px) * 0.7 * step(abs(lx), POST_R - 0.004) * step(f.ay, POST_H));
	}
	for (int k = 0; k < 3; k++) {
		float y = 0.18 + 0.34 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(POST_R + 0.008, 0.016), HOOP, 1.0);
		draw_ball(acc, f, vec2(cx - 0.036, f.side * y), 0.007, BRASS, 1.0);
		draw_ball(acc, f, vec2(cx + 0.036, f.side * y), 0.007, BRASS, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.030), HOOP, 1.0);
}

void oak_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, OAK, 0.0, 0.4);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float grain = sin(q.y * 220.0 + sin(q.x * 11.0 + cy) * 3.0);
	inlay(acc, d, OAK * 0.78, smoothstep(0.6, 1.0, grain) * 0.4, f);
	for (int k = 0; k < 2; k++) {
		float x = k == 0 ? -0.74 : 0.74;
		inlay(acc, d, HOOP, cov(abs(q.x - x) - 0.022, f.px), f);
		inlay(acc, d, BRASS, cov(length(q - vec2(x, 0.042)) - 0.008, f.px), f);
		inlay(acc, d, BRASS, cov(length(q - vec2(x, -0.042)) - 0.008, f.px), f);
	}
	pour_trough(acc, f, d, q);
}

// 胴の半高(中ほどで膨らみ、鏡板へ向けて細る)
float cask_half(float x) {
	float u = clamp(x / CASK_LEN, -1.0, 1.0);
	return mix(CASK_MID, CASK_END, u * u);
}

// 木の台に横に寝た樽と、鏡板の呑み口から落ちる酒の筋
void lying_cask(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.34 || q.y < 1.16 || q.y > 1.38) {
		return;
	}
	for (int k = 0; k < 2; k++) {
		float x = CASK.x + (k == 0 ? -0.110 : 0.110);
		float d_leg = sd_round_box(q - vec2(x, 1.214), vec2(0.034, 0.026), 0.006);
		part(acc, d_leg, ink_of(OAK), shade_mat(OAK * 0.8, vec3(0.0, 0.3, 0.95), 0.0, 0.2, 1.0), f.ow * 0.8, f.px);
	}
	vec2 c = q - CASK;
	float h = cask_half(c.x);
	float d_body = max(abs(c.y) - h, abs(c.x) - CASK_LEN);
	vec3 n = normalize(vec3(0.0, clamp(c.y / h, -1.0, 1.0) * 0.8, 0.6));
	float k = floor(c.y / h * 3.0 + 0.5);
	vec3 wood = OAK * mix(0.86, 1.08, hash21(vec2(k, 3.0)));
	part(acc, d_body, ink_of(OAK), shade_mat(wood, n, 0.0, 0.4, 1.0), f.ow, f.px);
	float seam = abs(fract(c.y / h * 3.0 + 0.5) - 0.5) * h / 3.0;
	over(acc, ink_of(OAK), cov(seam - 0.0018, f.px) * cov(d_body + 0.004, f.px) * 0.6);
	for (int j = 0; j < 4; j++) {
		float x = (j < 2 ? -1.0 : 1.0) * (j % 2 == 0 ? 0.138 : 0.174);
		float d_hoop = max(abs(c.x - x) - 0.012, abs(c.y) - cask_half(x) - 0.004);
		part(acc, d_hoop, ink_of(HOOP), shade_mat(HOOP, n, 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	}
	vec2 e = c - vec2(CASK_LEN, 0.0);
	float d_head = sd_ellipse(e, vec2(0.020, CASK_END));
	part(acc, d_head, ink_of(OAK), shade_mat(OAK * 0.9, vec3(0.7, 0.2, 0.7), 0.0, 0.3, 1.0), f.ow * 0.7, f.px);
	float d_stream = max(abs(q.x - TAP.x - 0.004 - 0.002 * sin(q.y * 160.0)) - 0.008, max(q.y - TAP.y + 0.006, 1.190 - q.y));
	part(acc, d_stream, ink_of(sand_color), mix(sand_color, vec3(1.0), 0.25), f.ow * 0.5, f.px);
	float d_spout = sd_segment(q, CASK + vec2(CASK_LEN + 0.008, -0.030), TAP) - 0.011;
	part(acc, d_spout, ink_of(BRASS), shade_mat(BRASS, vec3(0.2, 0.5, 0.8), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	draw_ball(acc, f, CASK + vec2(CASK_LEN + 0.018, -0.012), 0.016, BRASS, 1.0);
	float d_pool = sd_ellipse(q - vec2(TAP.x + 0.004, 1.193), vec2(0.040, 0.009));
	part(acc, d_pool, ink_of(sand_color), mix(sand_color, vec3(1.0), 0.15), f.ow * 0.4, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2((f.p.x - 0.10) * 1.4, f.p.y - 1.26);
	add_light(acc, sand_color, exp(-dot(d, d) / 0.010) * 0.30 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	stave_post(acc, f, -POST_X);
	stave_post(acc, f, POST_X);
	draw_collars(acc, f, HOOP, 1.0);
	oak_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		lying_cask(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
