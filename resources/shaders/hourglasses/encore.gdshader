shader_type canvas_item;
// 喝采(アンコール)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は房紐で絞った舞台の緞帳、板は脚光の並ぶ舞台の縁。天板の上に投げ込まれたリボンの花束。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 VELVET = vec3(0.62, 0.10, 0.16);
const vec3 STAGE = vec3(0.30, 0.20, 0.14);
const vec3 LAMP = vec3(1.0, 0.90, 0.62);
const vec3 STEM = vec3(0.30, 0.56, 0.28);
const float CURTAIN_HALF = 0.064;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 BOUQUET = vec2(0.0, 1.225);
const float BOUQUET_K = 1.3;

// 緞帳: 縦のひだ、真ん中を金の房紐で絞る
void curtain_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > CURTAIN_HALF + 0.03 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float pinch = 1.0 - 0.45 * exp(-f.p.y * f.p.y / 0.02);
	float hw = CURTAIN_HALF * pinch;
	float d = max(abs(lx) - hw, f.ay - POST_H);
	float u = lx / hw;
	float fold = sin(u * 3.1416 * 2.0);
	vec3 n = normalize(vec3(fold * 0.6, 0.0, 0.8));
	part(acc, d, ink_of(VELVET), shade_mat(VELVET, n, 0.0, 0.6, f.ao), f.ow, f.px);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.044, 0.020), GOLD, 1.0);
	// 房
	vec2 tq = vec2(f.p.x - cx - sign(cx) * 0.040, f.p.y + 0.06);
	float tw = 0.008 + 0.018 * clamp(-tq.y / 0.10, 0.0, 1.0);
	float d_tassel = max(abs(tq.x) - tw, max(tq.y - 0.04, -tq.y - 0.10));
	part(acc, d_tassel, ink_of(GOLD), mix(GOLD * 0.8, mix(GOLD, sand_color, 0.4), step(0.5, fract(tq.x * 60.0))), f.ow * 0.5, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), GOLD, 1.0);
}

void footlight_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, STAGE, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float plank = step(abs(fract(q.x / 0.20) - 0.5), 0.47);
	inlay(acc, d, STAGE * 0.7, (1.0 - plank) * 0.8, f);
	for (int k = -3; k <= 3; k++) {
		vec2 lq = q - vec2(float(k) * 0.20 + 0.10 * sign(float(k)), 0.0);
		if (k == 0) {
			lq = q;
		}
		vec3 c = k == 0 ? sand_color : LAMP;
		inlay(acc, d, GOLD * 0.6, cov(sd_round_box(lq, vec2(0.034, 0.026), 0.010), f.px), f);
		inlay(acc, d, c, cov(sd_ellipse(lq, vec2(0.024, 0.016)), f.px), f);
	}
}

// 花束: 3輪の花、葉、結んだリボン
void bouquet(inout vec4 acc, Px f) {
	vec2 q = (f.p - BOUQUET) / BOUQUET_K;
	if (abs(q.x) > 0.22 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= BOUQUET_K;
	f.ow /= BOUQUET_K;
	for (int k = -1; k <= 1; k++) {
		float d_stem = sd_segment(q, vec2(0.0, -0.090), vec2(float(k) * 0.075, 0.020)) - 0.007;
		part(acc, d_stem, ink_of(STEM), STEM, f.ow * 0.5, f.px);
	}
	for (int s = -1; s <= 1; s += 2) {
		vec2 lq = rot(q - vec2(float(s) * 0.075, -0.030), float(s) * 0.9);
		part(acc, sd_ellipse(lq, vec2(0.018, 0.045)), ink_of(STEM), STEM * 1.2, f.ow * 0.5, f.px);
	}
	vec2 centers[3] = vec2[3](vec2(-0.080, 0.035), vec2(0.0, 0.070), vec2(0.080, 0.035));
	for (int k = 0; k < 3; k++) {
		vec2 fq = q - centers[k];
		float a = atan(fq.y, fq.x);
		float r = length(fq);
		float petals = 0.050 + 0.012 * cos(a * 5.0 + float(k));
		vec3 pc = k == 1 ? sand_color : mix(vec3(0.98, 0.86, 0.90), VELVET, 0.25 * float(k));
		vec3 n = normalize(vec3(fq / 0.05 * 0.5, 0.8));
		part(acc, r - petals, ink_of(pc), shade_mat(pc, n, 0.0, 0.6, 1.0), f.ow * 0.7, f.px);
		draw_ball(acc, f, BOUQUET + centers[k] * BOUQUET_K, 0.016 * BOUQUET_K, LAMP, 0.0);
	}
	// リボン
	vec2 rq = q - vec2(0.0, -0.075);
	float d_bow = min(sd_ellipse(rot(rq - vec2(-0.030, 0.0), 0.4), vec2(0.032, 0.016)), sd_ellipse(rot(rq - vec2(0.030, 0.0), -0.4), vec2(0.032, 0.016)));
	part(acc, d_bow, ink_of(VELVET), VELVET * 1.2, f.ow * 0.6, f.px);
	part(acc, length(rq) - 0.012, ink_of(VELVET), GOLD, f.ow * 0.5, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - (BOUQUET + vec2(0.0, 0.03));
	add_light(acc, LAMP, exp(-dot(q, q) / 0.012) * 0.35);
}

void art_frame(inout vec4 acc, Px f) {
	curtain_post(acc, f, -POST_X);
	curtain_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	footlight_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		bouquet(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
