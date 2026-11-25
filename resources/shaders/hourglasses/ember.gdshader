shader_type canvas_item;
// 燠火(エンバー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 焼けて炭になった丸太の柱は、割れ目の奥が赤く灯る。天板の上の鉄の火鉢には燠が盛られ、短い炎が立つ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 CHAR = vec3(0.17, 0.15, 0.15);
const vec3 ASH = vec3(0.40, 0.38, 0.37);
const vec3 IRON = vec3(0.30, 0.31, 0.34);
const vec3 EMBER = vec3(1.0, 0.40, 0.12);
const vec3 EMBER_DEEP = vec3(0.78, 0.12, 0.06);
const vec3 EMBER_HOT = vec3(1.0, 0.88, 0.52);
const float POST_R = 0.064;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec2 BOWL = vec2(0.0, 1.205);
const vec2 BOWL_HALF = vec2(0.255, 0.085);

void ember_seam(inout vec4 acc, Px f, float d, vec2 q, float half_x) {
	float line = cov(abs(q.y) - 0.008, f.px) * step(abs(q.x), half_x);
	inlay(acc, d, mix(EMBER, EMBER_HOT, cov(abs(q.y) - 0.003, f.px)), line, f);
}

// 炭の割れ目: 鱗状のひびの境目までの距離(x)と、ひびごとの燃え方(y)
vec2 char_cells(vec2 p) {
	vec2 g = p / vec2(0.055, 0.075);
	vec2 gi = floor(g);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 nearest = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = gi + vec2(float(x), float(y));
			float d = length(g - (o + hash22(o)));
			if (d < d1) {
				d2 = d1;
				d1 = d;
				nearest = o;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2((d2 - d1) * 0.055, hash21(nearest + 4.0));
}

void char_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	vec3 c = shade_mat(CHAR, n, 0.0, 0.5, f.ao);
	vec2 cell = char_cells(vec2(asin(u) * POST_R * 1.2 + cx, f.p.y));
	float fine = smoothstep(0.03, 0.012, f.px);
	// 下ほど、割れ目の奥が赤く灯る
	float heat = mix(0.35, 1.0, smoothstep(0.6, -0.9, f.p.y)) * step(0.35, cell.y);
	float seam = 1.0 - smoothstep(0.0, 0.006 + f.px, cell.x);
	c = mix(c, mix(EMBER_DEEP, EMBER, heat), seam * mix(0.5, 1.0, fine) * heat);
	c = mix(c, c * 1.35 + vec3(0.04), smoothstep(0.012, 0.03, cell.x) * smoothstep(0.5, 0.9, n.x * 0.5 + 0.5) * 0.4);
	part(acc, d, vec3(0.04), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.094, 0.030), IRON, 1.0);
}

void ash_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, ASH * 0.72, 0.0, 0.2);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	ember_seam(acc, f, d, q, 0.72);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.74 : 0.74, cy), 0.022, IRON * 1.3, 1.0);
	}
	if (cy < 0.0) {
		// 底板の中央: 灰の中で赤く灯る燠
		vec2 mq = q - vec2(0.0, 0.004);
		float d_m = sd_ellipse(mq, vec2(0.085, 0.040));
		inlay(acc, d, mix(EMBER_DEEP, EMBER_HOT, smoothstep(0.04, -0.01, length(mq))), cov(d_m, f.px), f);
	}
}

// 鉄の火鉢: 三本脚、浅い椀、縁の輪
void brazier(inout vec4 acc, Px f) {
	vec2 q = f.p - BOWL;
	if (abs(q.x) > 0.32 || q.y < -0.16 || q.y > 0.18) {
		return;
	}
	for (int k = -1; k <= 1; k++) {
		float x = float(k) * 0.15;
		float d_leg = sd_segment(q, vec2(x * 0.9, -0.05), vec2(x * 1.4, -0.105)) - 0.016;
		part(acc, d_leg, vec3(0.05), shade_mat(IRON, normalize(vec3(0.0, 0.0, 1.0)), 1.0, 0.7, 1.0), f.ow * 0.8, f.px);
	}
	// 燠の山(椀の縁より上へ盛り上がる)
	float d_coal = 9.0;
	float coal_k = 0.0;
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		vec2 cc = vec2((fi - 4.0) * 0.054, 0.012 + 0.046 * (1.0 - pow((fi - 4.0) / 4.4, 2.0)) + 0.010 * hash21(vec2(fi, 2.0)));
		float r = 0.042 + 0.010 * hash21(vec2(fi, 5.0));
		float dc = length(q - cc) - r;
		if (dc < d_coal) {
			d_coal = dc;
			coal_k = hash21(vec2(fi, 7.0));
		}
	}
	vec3 coal = mix(EMBER_DEEP, EMBER, coal_k);
	coal = mix(coal, EMBER_HOT, smoothstep(-0.006, -0.03, d_coal) * 0.7);
	part(acc, d_coal, vec3(0.12, 0.03, 0.02), coal, f.ow * 0.6, f.px);
	// 椀
	float d_bowl = max(sd_ellipse(q - vec2(0.0, 0.010), BOWL_HALF), q.y - 0.012);
	vec3 bn = normalize(vec3(q.x / BOWL_HALF.x * 0.6, (q.y + 0.03) / BOWL_HALF.y * 0.3, 0.75));
	part(acc, d_bowl, vec3(0.05), shade_mat(IRON, bn, 1.0, 0.8, 1.0), f.ow, f.px);
	float d_rim = sd_round_box(q - vec2(0.0, 0.008), vec2(BOWL_HALF.x + 0.014, 0.017), 0.014);
	part(acc, d_rim, vec3(0.05), shade_mat(IRON * 1.4, normalize(vec3(0.0, 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	// 椀の正面の透かし(中の火が透ける)
	float d_slot = sd_round_box(vec2(mod(q.x + 0.045, 0.09) - 0.045, q.y + 0.030), vec2(0.013, 0.022), 0.010);
	d_slot = max(d_slot, abs(q.x) - 0.19);
	over(acc, mix(EMBER, EMBER_HOT, 0.3), cov(max(d_slot, d_bowl), f.px));
}

// 燠の上に立つ短い炎(3枚の舌)
void flames(inout vec4 acc, Px f) {
	vec2 q = f.p - BOWL - vec2(0.0, 0.050);
	if (abs(q.x) > 0.20 || q.y < -0.02 || q.y > 0.15) {
		return;
	}
	for (int k = -1; k <= 1; k++) {
		float x = float(k) * 0.095;
		float h = k == 0 ? 0.135 : 0.100;
		vec2 fq = q - vec2(x, 0.0);
		// 丸い根元から先へ細る舌。先は外へ少し流れる
		vec2 root = vec2(0.0, 0.018);
		vec2 tip = vec2(float(k) * 0.022 + 0.008, h);
		vec2 ba = tip - root;
		float t = clamp(dot(fq - root, ba) / dot(ba, ba), 0.0, 1.0);
		float d = length(fq - root - ba * t) - mix(0.040, 0.003, pow(t, 0.8));
		over(acc, EMBER_DEEP, cov(d - 0.004, f.px) * 0.9);
		over(acc, EMBER, cov(d, f.px));
		over(acc, EMBER_HOT, cov(d + 0.014, f.px) * smoothstep(0.85, 0.1, t));
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - BOWL - vec2(0.0, 0.07);
	add_light(acc, EMBER, exp(-dot(d, d) / 0.030) * 0.75 * canvas_window(f.p));
	vec2 d2 = vec2(abs(f.p.x) - POST_X, max(f.p.y + 0.9, 0.0));
	add_light(acc, EMBER_DEEP, exp(-dot(d2, d2) / 0.06) * 0.25 * step(f.p.y, -0.2) * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	char_post(acc, f, -POST_X);
	char_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	ash_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y - 0.03) {
		brazier(acc, f);
		flames(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
