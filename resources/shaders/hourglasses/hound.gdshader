shader_type canvas_item;
// 猟犬(ハウンド)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は鋲を打った革の首輪を巻いた杭、板には足跡が続く。天板の上に垂れ耳の猟犬の顔。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 OAK = vec3(0.42, 0.28, 0.18);
const vec3 LEATHER = vec3(0.50, 0.22, 0.14);
const vec3 COAT = vec3(0.72, 0.50, 0.30);
const vec3 EAR = vec3(0.40, 0.24, 0.14);
const vec3 MUZZLE = vec3(0.94, 0.88, 0.80);
const float POST_R = 0.048;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 HEAD = vec2(0.0, 1.228);
const float HEAD_K = 1.2;

void collar_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, OAK, 0.0);
	for (int k = -1; k <= 1; k++) {
		float y = float(k) * 0.42;
		vec2 q = vec2(f.p.x - cx, f.p.y - y);
		if (abs(q.x) > 0.08 + f.pad || abs(q.y) > 0.04 + f.pad) {
			continue;
		}
		draw_band(acc, f, vec2(cx, y), vec2(0.064, 0.026), LEATHER, 0.0);
		float stud = step(length(vec2(fract(q.x / 0.032 + 0.5) - 0.5, q.y / 0.032)), 0.22);
		over(acc, mix(SILVER, vec3(1.0), 0.3), stud * step(abs(q.x), 0.055) * step(abs(q.y), 0.02));
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), LEATHER, 0.0);
}

void track_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, OAK, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 左から右へ続く足跡
	float a = 0.0;
	for (int k = -4; k <= 4; k++) {
		if (k == 0) {
			continue;
		}
		vec2 pq = q - vec2(float(k) * 0.16, (k % 2 == 0) ? 0.020 : -0.020);
		float d_pad = sd_ellipse(pq - vec2(0.0, -0.008), vec2(0.020, 0.016));
		float d_toes = 1e3;
		for (int t = -1; t <= 1; t++) {
			d_toes = min(d_toes, length(pq - vec2(float(t) * 0.016, 0.020 - abs(float(t)) * 0.004)) - 0.008);
		}
		a = max(a, cov(min(d_pad, d_toes), f.px));
	}
	inlay(acc, d, LEATHER * 0.7, a, f);
	inlay(acc, d, sand_color, cov(length(q) - 0.030, f.px), f);
}

// 猟犬の顔: 丸い頭、垂れた耳、白い鼻面、首輪の札
void hound_head(inout vec4 acc, Px f) {
	vec2 q = (f.p - HEAD) / HEAD_K;
	if (abs(q.x) > 0.20 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= HEAD_K;
	f.ow /= HEAD_K;
	// 首輪
	part(acc, sd_round_box(q - vec2(0.0, -0.085), vec2(0.075, 0.014), 0.006), ink_of(LEATHER), LEATHER, f.ow * 0.6, f.px);
	vec2 hq = q - vec2(0.0, 0.015);
	vec3 n = normalize(vec3(hq / 0.09 * 0.6, 0.75));
	part(acc, sd_ellipse(hq, vec2(0.090, 0.095)), ink_of(COAT), shade_mat(COAT, n, 0.0, 0.5, 1.0), f.ow, f.px);
	vec2 mq = q - vec2(0.0, -0.040);
	part(acc, sd_ellipse(mq, vec2(0.058, 0.044)), ink_of(COAT), shade_mat(MUZZLE, normalize(vec3(mq / 0.06 * 0.5, 0.8)), 0.0, 0.5, 1.0), f.ow * 0.7, f.px);
	over(acc, MUZZLE, cov(sd_ellipse(q - vec2(0.0, 0.035), vec2(0.014, 0.050)), f.px));
	part(acc, sd_ellipse(q - vec2(0.0, -0.020), vec2(0.024, 0.016)), vec3(0.04), vec3(0.10, 0.08, 0.08), f.ow * 0.5, f.px);
	for (int s = -1; s <= 1; s += 2) {
		vec2 eq = q - vec2(float(s) * 0.040, 0.030);
		over(acc, vec3(0.08, 0.05, 0.04), cov(length(eq) - 0.012, f.px));
		over(acc, vec3(1.0), cov(length(eq - vec2(-0.004, 0.004)) - 0.004, f.px));
	}
	for (int s = -1; s <= 1; s += 2) {
		vec2 eq = rot(q - vec2(float(s) * 0.092, 0.010), float(s) * 0.25);
		vec3 en = normalize(vec3(eq.x / 0.034 * 0.5, 0.0, 0.85));
		part(acc, sd_ellipse(eq, vec2(0.034, 0.075)), ink_of(EAR), shade_mat(EAR, en, 0.0, 0.5, 1.0), f.ow * 0.8, f.px);
	}
	vec2 bq = q - vec2(0.0, -0.105);
	vec3 tag = mix(sand_color, GOLD, 0.3);
	part(acc, length(bq) - 0.020, ink_of(tag), shade_mat(tag, normalize(vec3(bq / 0.02 * 0.6, 0.75)), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	collar_post(acc, f, -POST_X);
	collar_post(acc, f, POST_X);
	draw_collars(acc, f, LEATHER, 0.0);
	track_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		hound_head(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
