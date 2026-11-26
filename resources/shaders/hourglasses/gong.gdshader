shader_type canvas_item;
// 銅鑼(ゴング)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は黒漆の帯を巻いた朱漆の柱、板は黒漆に朝空の七宝と真鍮の音の輪。天板の上の朱の架に青銅の銅鑼が吊られ、綿の撥が打ち当たる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.94, 0.74, 0.36);
const vec3 SKY = vec3(0.62, 0.82, 0.98);
const vec3 SKY_DEEP = vec3(0.30, 0.48, 0.82);
const vec3 DAYBREAK = vec3(1.0, 0.76, 0.52);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec3 LACQUER = vec3(0.74, 0.16, 0.12);
const vec3 BLACK_LACQUER = vec3(0.17, 0.14, 0.15);
const vec3 BRONZE = vec3(0.88, 0.58, 0.26);
const vec3 COTTON = vec3(0.95, 0.92, 0.84);
const float POST_R = 0.056;
const vec2 GONG_C = vec2(-0.04, 1.268);
const float GONG_R = 0.090;
const float STAND_HALF = 0.21;
const float BEAM_Y = 1.350;

// 早鐘の刻の印: 板に嵌めた朝空の七宝。中央の鐘の口から左右へ、真鍮の音の輪が広がる
void toll_band(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.07) {
		return;
	}
	float strip = sd_round_box(q, vec2(0.68, 0.044), 0.038);
	vec3 sky = mix(SKY_DEEP, SKY, smoothstep(-0.05, 0.05, q.y));
	sky = mix(sky, DAYBREAK, exp(-q.x * q.x / 0.03) * smoothstep(0.05, -0.04, q.y) * 0.9);
	inlay(acc, d, ink_of(BRASS), cov(strip - 0.013, f.px), f);
	inlay(acc, d, BRASS, cov(strip - 0.008, f.px), f);
	inlay(acc, d, sky, cov(strip, f.px), f);
	float inside = cov(strip + 0.003, f.px);
	for (int k = 0; k < 4; k++) {
		float j = float(k) / 3.0;
		float dr = abs(length(vec2(q.x, q.y * 4.0)) - 0.17 - 0.14 * float(k)) - mix(0.015, 0.010, j);
		inlay(acc, d, mix(BRASS * 1.15, BRASS, j), cov(dr, f.px) * inside, f);
	}
	vec2 b = q - vec2(0.0, -0.040);
	float d_dome = max(length(b) - 0.066, -b.y);
	inlay(acc, d, ink_of(BRASS), cov(d_dome - 0.010, f.px), f);
	vec3 n = normalize(vec3(b / 0.066 * 0.6, 0.75));
	inlay(acc, d, shade_mat(BRASS, n, 1.0, 1.0, 1.0), cov(d_dome, f.px), f);
}

void lacquer_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, LACQUER, 0.0);
	for (int k = 0; k < 2; k++) {
		draw_band(acc, f, vec2(cx, f.side * (0.36 + 0.30 * float(k))), vec2(0.064, 0.024), BLACK_LACQUER, 0.0);
	}
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.070, 0.022), BRASS, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), BRASS, 1.0);
}

void black_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, BLACK_LACQUER, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	toll_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, BRASS, 1.0);
	}
}

// 朱の架: 2本の脚と、両端の反った梁。銅鑼を吊る紐
void stand(inout vec4 acc, Px f) {
	for (int k = -1; k <= 1; k += 2) {
		float x = float(k) * STAND_HALF;
		float d_leg = max(abs(f.p.x - x) - 0.020, max(PLATE_Y - f.p.y, f.p.y - BEAM_Y));
		vec3 n = normalize(vec3(clamp((f.p.x - x) / 0.020, -1.0, 1.0) * 0.7, 0.0, 0.7));
		part(acc, d_leg, ink_of(LACQUER), shade_mat(LACQUER, n, 0.0, 1.0, 1.0), f.ow, f.px);
	}
	vec2 tq = f.p - vec2(0.0, BEAM_Y);
	float lift = 0.016 * smoothstep(STAND_HALF - 0.02, STAND_HALF + 0.07, abs(tq.x));
	float d_beam = sd_round_box(vec2(tq.x, tq.y - lift), vec2(STAND_HALF + 0.07, 0.015), 0.012);
	part(acc, d_beam, ink_of(BLACK_LACQUER), shade_mat(BLACK_LACQUER * 1.4, normalize(vec3(0.0, 0.4, 0.8)), 0.0, 1.0, 1.0), f.ow, f.px);
	for (int k = -1; k <= 1; k += 2) {
		vec2 top = vec2(GONG_C.x + float(k) * 0.040, BEAM_Y - 0.012);
		vec2 low = GONG_C + vec2(float(k) * 0.052, GONG_R * 0.75);
		over(acc, vec3(0.30, 0.20, 0.14), cov(sd_segment(f.p, top, low) - 0.006, f.px));
	}
}

// 青銅の銅鑼: 縁の厚い皿に同心の筋と、中央の打ち面
void gong_disc(inout vec4 acc, Px f) {
	vec2 q = f.p - GONG_C;
	float r = length(q);
	if (r > GONG_R + f.pad) {
		return;
	}
	float k = r / GONG_R;
	vec3 n = normalize(vec3(q / GONG_R * (k > 0.86 ? 0.75 : 0.25), 0.75));
	vec3 c = shade_mat(BRONZE, n, 1.0, 1.0, 1.0);
	float rings = cov(abs(k - 0.62) - 0.025, f.px / GONG_R) + cov(abs(k - 0.80) - 0.018, f.px / GONG_R);
	c = mix(c, c * 0.62, clamp(rings, 0.0, 1.0));
	part(acc, r - GONG_R, ink_of(BRONZE), c, f.ow, f.px);
	vec3 bn = normalize(vec3(q / 0.034 * 0.6, 0.75));
	part(acc, r - 0.034, ink_of(BRONZE), shade_mat(BRONZE * 1.12, bn, 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
}

// 綿を巻いた撥が、銅鑼の縁へ打ち当たる
void mallet(inout vec4 acc, Px f) {
	vec2 a = vec2(0.36, 1.196);
	vec2 b = GONG_C + vec2(GONG_R + 0.030, 0.006);
	float d = sd_segment(f.p, a, b) - 0.011;
	part(acc, d, ink_of(LACQUER), shade_mat(vec3(0.55, 0.36, 0.22), normalize(vec3(0.0, 0.5, 0.8)), 0.0, 0.8, 1.0), f.ow, f.px);
	vec2 h = f.p - b;
	float d_head = length(h * vec2(1.0, 1.2)) - 0.030;
	part(acc, d_head, ink_of(COTTON), shade_mat(COTTON, normalize(vec3(h / 0.03 * 0.6, 0.7)), 0.0, 0.6, 1.0), f.ow, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - GONG_C;
	add_light(acc, mix(BRONZE, DAYBREAK, 0.5), exp(-dot(d, d) / 0.025) * 0.55 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	lacquer_post(acc, f, -POST_X);
	lacquer_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	black_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y && abs(f.p.x) < 0.42) {
		stand(acc, f);
		gong_disc(acc, f);
		mallet(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
