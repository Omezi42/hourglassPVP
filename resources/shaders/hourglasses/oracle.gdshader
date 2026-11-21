shader_type canvas_item;
// 託宣者(オラクル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は薄絹のヴェールを垂らした溝彫りの大理石、板には閉じた目と開いた目が交互に並ぶ。天板の上に三脚の香炉と、その上に浮かぶ水晶玉。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 MARBLE = vec3(0.90, 0.89, 0.92);
const vec3 VEIL = vec3(0.55, 0.42, 0.78);
const vec3 BRONZE = vec3(0.70, 0.48, 0.24);
const vec3 NIGHT = vec3(0.16, 0.14, 0.30);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float COL_R = 0.048;
const vec2 TRIPOD = vec2(0.0, 1.212);
const float TRIPOD_K = 1.55;

// 溝彫りの大理石の柱に、上から薄絹が垂れて裾が揺れる
void veiled_column(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.13 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - COL_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / COL_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(MARBLE, n, 0.0, 0.7, f.ao);
	float flute = abs(fract(lx / COL_R * 2.5 + 0.5) - 0.5);
	c *= mix(0.86, 1.0, smoothstep(0.05, 0.2, flute));
	float vein = smoothstep(0.92, 1.0, sin(f.p.y * 14.0 + lx * 40.0 + vnoise(f.p * 9.0) * 4.0));
	c = mix(c, vec3(0.70, 0.68, 0.76), vein * 0.4);
	part(acc, d, ink_of(MARBLE) * 0.8, c, f.ow, f.px);
	// ヴェール: 上の端(f.p.y が正の側)から柱の外側へ垂れ、裾が波打つ
	float hang = 0.95 - f.p.y;
	float side_out = sign(cx);
	float width = 0.030 + hang * 0.070 + 0.012 * sin(hang * 18.0);
	float vx = lx * side_out - COL_R * 0.4;
	float d_veil = max(abs(vx - width * 0.5) - width * 0.5, max(-hang, hang - 0.78 - 0.03 * sin(lx * 60.0)));
	vec3 vc = mix(VEIL, vec3(1.0), 0.15 + 0.2 * sin(vx * 120.0));
	part(acc, d_veil, ink_of(VEIL), vc, f.ow * 0.6, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), BRONZE, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.50), vec2(0.060, 0.014), BRONZE, 1.0);
}

// 目の紋: 開いた目(瞳に砂の色)と閉じた目(弧のまつげ)
float eye_open(vec2 q) {
	return sd_ellipse(q, vec2(0.040, 0.020));
}

void eye_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, NIGHT, 0.2, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	for (int k = -3; k <= 3; k++) {
		vec2 eq = q - vec2(float(k) * 0.20, 0.0);
		if ((k & 1) == 0) {
			float d_eye = eye_open(eq);
			inlay(acc, d, vec3(0.95, 0.92, 0.84), cov(d_eye, f.px), f);
			inlay(acc, d, sand_color, cov(length(eq) - 0.013, f.px), f);
			inlay(acc, d, NIGHT, cov(length(eq) - 0.006, f.px), f);
			inlay(acc, d, BRONZE, cov(abs(d_eye) - 0.003, f.px), f);
		} else {
			float arc = abs(length(eq - vec2(0.0, 0.035)) - 0.040) - 0.003;
			inlay(acc, d, BRONZE, cov(max(arc, eq.y - 0.0), f.px), f);
		}
	}
}

// 三脚の香炉と、その上に浮かぶ水晶玉
void tripod(inout vec4 acc, Px f) {
	vec2 q = (f.p - TRIPOD) / TRIPOD_K;
	if (abs(q.x) > 0.16 + f.pad || q.y < -0.04 - f.pad || q.y > 0.11 + f.pad) {
		return;
	}
	f.px /= TRIPOD_K;
	f.ow /= TRIPOD_K;
	for (int s = -1; s <= 1; s++) {
		float d_leg = sd_segment(q, vec2(float(s) * 0.020, 0.020), vec2(float(s) * 0.070, -0.035)) - 0.008;
		part(acc, d_leg, ink_of(BRONZE), shade_mat(BRONZE, vec3(0.0, 0.3, 0.95), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	}
	vec2 bq = q - vec2(0.0, 0.025);
	float d_bowl = max(sd_ellipse(bq, vec2(0.080, 0.032)), bq.y - 0.004);
	part(acc, d_bowl, ink_of(BRONZE), shade_mat(BRONZE, normalize(vec3(bq.x * 8.0, -0.4, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	part(acc, sd_round_box(bq - vec2(0.0, 0.004), vec2(0.084, 0.006), 0.004), ink_of(BRONZE), BRONZE * 1.1, f.ow * 0.6, f.px);
	// 水晶玉
	vec2 oq = q - vec2(0.0, 0.066);
	float r = 0.040;
	vec3 on = normalize(vec3(oq / r, sqrt(max(1.0 - dot(oq / r, oq / r), 0.0))));
	vec3 oc = mix(NIGHT * 1.5, sand_color, 0.35 + 0.65 * on.z * on.z);
	oc += vec3(1.0) * pow(max(dot(on, normalize(vec3(-0.5, 0.6, 0.6))), 0.0), 24.0);
	part(acc, length(oq) - r, ink_of(sand_color) * 0.6, oc, f.ow * 0.7, f.px);
	add_light(acc, sand_color, star4(oq - vec2(0.018, 0.016), 0.050) * 0.9);
	add_light(acc, sand_color, cov(length(oq) - r - 0.03, f.px) * 0.12);
}

// 背後に立ちのぼる薄い香煙
void art_back(inout vec4 acc, Px f) {
	float y = f.p.y;
	float sway = sin(y * 3.2 + 1.3) * 0.12 + sin(y * 7.0) * 0.04;
	float smoke = exp(-pow((f.p.x - sway) / (0.22 + 0.10 * (1.3 - y)), 2.0));
	float n = vnoise(vec2(f.p.x * 3.0, y * 2.0 + 4.0));
	add_light(acc, mix(sand_color, vec3(1.0), 0.4), smoke * (0.12 + 0.10 * n) * canvas_window(f.p) * smoothstep(-0.8, 0.6, y) * (1.0 - acc.a));
}

void art_frame(inout vec4 acc, Px f) {
	veiled_column(acc, f, -POST_X);
	veiled_column(acc, f, POST_X);
	draw_collars(acc, f, BRONZE, 1.0);
	eye_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		tripod(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
