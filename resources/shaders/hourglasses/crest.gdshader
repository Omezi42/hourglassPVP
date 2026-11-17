shader_type canvas_item;
// 兜飾り(クレスト)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱から市松の紋章旗を下げ、板には紋章の帯。天板の上に羽根飾りを立てた騎士の兜。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 AZURE = vec3(0.18, 0.28, 0.62);
const vec3 ARGENT = vec3(0.86, 0.88, 0.92);
const vec3 HELM = vec3(0.62, 0.64, 0.70);
const vec3 PLUME = vec3(0.86, 0.20, 0.24);
const float POST_R = 0.040;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 HELMET = vec2(0.0, 1.195);
const float HELMET_K = 1.2;

// 紋章旗: 柱の前に垂らした市松の旗、裾は燕尾
void banner_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, GOLD * 0.85, 1.0);
	vec2 q = vec2(f.p.x - cx, f.p.y - 0.30);
	if (abs(q.x) < 0.07 + f.pad && q.y < 0.40 + f.pad && q.y > -0.60 - f.pad) {
		float hw = 0.060;
		float tail = -0.50 + 0.06 * (abs(q.x) / hw);
		float d = max(abs(q.x) - hw, max(q.y - 0.36, tail - q.y));
		vec2 g = floor(vec2(q.x / 0.040 + 0.5, q.y / 0.060));
		float chk = mod(g.x + g.y, 2.0);
		vec3 c = mix(AZURE, mix(ARGENT, sand_color, 0.3), chk);
		vec3 n = normalize(vec3(sin(q.x * 40.0) * 0.3, 0.0, 0.9));
		part(acc, d, ink_of(AZURE), shade_mat(c, n, 0.0, 0.6, f.ao), f.ow * 0.7, f.px);
		draw_band(acc, f, vec2(cx, 0.68), vec2(0.075, 0.014), GOLD, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), AZURE, 0.3);
}

void heraldic_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, AZURE, 0.3, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 山形の帯(シェブロン)と百合の小紋
	float chev = abs(q.y + abs(q.x) * 0.08) - 0.014;
	inlay(acc, d, GOLD, cov(chev, f.px) * step(abs(q.x), 0.76) * step(0.08, abs(q.x)), f);
	for (int k = -3; k <= 3; k++) {
		if (k == 0) {
			continue;
		}
		vec2 lq = q - vec2(float(k) * 0.21, 0.038);
		float d_lily = min(sd_ellipse(lq - vec2(0.0, 0.004), vec2(0.006, 0.014)), sd_ellipse(abs(lq) - vec2(0.010, 0.0), vec2(0.008, 0.005)));
		inlay(acc, d, ARGENT, cov(d_lily, f.px), f);
	}
	inlay(acc, d, GOLD, cov(sd_round_box(q, vec2(0.040, 0.044), 0.016), f.px), f);
	inlay(acc, d, sand_color, cov(sd_round_box(q, vec2(0.028, 0.032), 0.012), f.px), f);
}

// 騎士の兜: 丸い鉢、目庇の細い覗き穴、頂きから流れる羽根飾り
void knight_helm(inout vec4 acc, Px f) {
	vec2 q = (f.p - HELMET) / HELMET_K;
	if (abs(q.x) > 0.20 + f.pad || abs(q.y) > 0.17 + f.pad) {
		return;
	}
	f.px /= HELMET_K;
	f.ow /= HELMET_K;
	// 羽根飾り: 後ろへ流れる3枚
	for (int k = 0; k < 3; k++) {
		vec2 pq = rot(q - vec2(0.040 + 0.020 * float(k), 0.090 - 0.012 * float(k)), -0.9 - 0.25 * float(k));
		float d_plume = sd_ellipse(pq, vec2(0.020, 0.058 - 0.008 * float(k)));
		vec3 pc = k == 1 ? sand_color : PLUME;
		part(acc, d_plume, ink_of(pc), mix(pc, pc * 1.3, step(0.0, pq.x)), f.ow * 0.6, f.px);
	}
	vec2 hq = q - vec2(0.0, 0.010);
	float d_bowl = sd_ellipse(hq, vec2(0.075, 0.085));
	d_bowl = max(d_bowl, -hq.y - 0.070);
	vec3 n = normalize(vec3(hq / 0.08 * 0.7, 0.7));
	vec3 c = shade_mat(HELM, n, 1.0, 1.0, 1.0);
	// 鉢の中央の稜線と覗き穴
	c = mix(c, HELM * 1.3, step(abs(hq.x), 0.006) * step(0.020, hq.y));
	float slit = step(abs(hq.y - 0.005), 0.007) * step(abs(hq.x), 0.058);
	c = mix(c, vec3(0.04), slit);
	float holes = step(length(vec2(fract(hq.x / 0.020) - 0.5, (hq.y + 0.035) / 0.020)), 0.25) * step(abs(hq.x), 0.040) * step(abs(hq.y + 0.035), 0.010);
	c = mix(c, vec3(0.06), holes);
	part(acc, d_bowl, ink_of(HELM), c, f.ow, f.px);
	part(acc, sd_round_box(q - vec2(0.0, -0.068), vec2(0.085, 0.012), 0.006), ink_of(GOLD), GOLD, f.ow * 0.7, f.px);
	draw_ball(acc, f, HELMET + vec2(0.0, 0.092) * HELMET_K, 0.016 * HELMET_K, GOLD, 1.0);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	banner_post(acc, f, -POST_X);
	banner_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	heraldic_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		knight_helm(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
