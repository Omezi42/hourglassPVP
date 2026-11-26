shader_type canvas_item;
// 張り線(ワイヤー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は白い碍子を重ねた鋼の棒、板は赤褐色のベークライトに黒色火薬の煤の溝と、そこを這う導火線の火の点。
// 天板の上で、二つの碍子のあいだに張った銅の巻き線の上を、青白い火花が跳ねる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 POWDER = vec3(0.11, 0.10, 0.10);
const vec3 HEMP = vec3(0.86, 0.68, 0.40);
const vec3 ASH = vec3(0.40, 0.38, 0.37);
const vec3 SPARK = vec3(1.0, 0.70, 0.24);
const vec3 SPARK_HOT = vec3(1.0, 0.97, 0.80);
const vec3 BRASS = vec3(0.90, 0.70, 0.36);
const vec3 STEEL = vec3(0.70, 0.74, 0.80);
const vec3 PORCELAIN = vec3(0.95, 0.95, 0.93);
const vec3 BAKELITE = vec3(0.46, 0.18, 0.11);
const vec3 COPPER = vec3(0.92, 0.52, 0.30);
const vec3 ZAP = vec3(0.50, 0.85, 1.0);
const vec3 ZAP_HOT = vec3(0.92, 0.98, 1.0);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.040;
const float LIT_X = 0.24;
// 碍子の位置(左右)、巻き線の中心の高さ・半径・両端・巻き数
const float INSULATOR_X = 0.215;
const float COIL_Y = 1.262;
const float COIL_R = 0.036;
const float COIL_END = 0.172;
const float COIL_TURNS = 6.0;
const int COIL_STEPS = 60;

float fuse_y(float x) {
	return 0.016 * sin(x * 15.0 + 0.6);
}
// 導火の刻の印: 板に掘った黒色火薬の煤の溝を麻の導火線が波打って這い、右寄りで火の点が燃える(先は燃え尽きた灰)
void fuse_band(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.075) {
		return;
	}
	float strip = sd_round_box(q, vec2(0.68, 0.040), 0.036);
	inlay(acc, d, POWDER * 0.5, cov(strip - 0.010, f.px), f);
	float grain = step(0.80, hash21(floor(q * 110.0))) * 0.5;
	inlay(acc, d, mix(POWDER, vec3(0.30, 0.28, 0.27), grain), cov(strip, f.px), f);
	float dy = q.y - fuse_y(q.x);
	float inside = cov(strip + 0.004, f.px);
	float d_cord = max(abs(dy) - 0.015, max(q.x - LIT_X, -0.62 - q.x));
	float twist = fract((q.x * 0.9 + dy * 0.7) * 30.0);
	vec3 hemp = mix(HEMP * 0.70, HEMP * 1.08, smoothstep(0.15, 0.45, twist) * smoothstep(0.95, 0.65, twist));
	vec3 n = normalize(vec3(0.0, clamp(dy / 0.015, -1.0, 1.0) * 0.7, 0.7));
	inlay(acc, d, ink_of(HEMP), cov(d_cord - 0.006, f.px) * inside, f);
	inlay(acc, d, shade_mat(hemp, n, 0.0, 0.5, 1.0), cov(d_cord, f.px) * inside, f);
	float d_ash = max(abs(dy) - 0.008, max(LIT_X - q.x, q.x - 0.62));
	float flake = step(0.28, fract(q.x * 26.0));
	inlay(acc, d, ASH, cov(d_ash, f.px) * flake * inside, f);
	vec2 cap = q - vec2(-0.635, fuse_y(-0.635));
	inlay(acc, d, ink_of(BRASS), cov(length(cap) - 0.028, f.px), f);
	inlay(acc, d, shade_mat(BRASS, normalize(vec3(cap / 0.028 * 0.6, 0.75)), 1.0, 1.0, 1.0), cov(length(cap) - 0.020, f.px), f);
	vec2 s = q - vec2(LIT_X, fuse_y(LIT_X));
	add_light(acc, SPARK, exp(-dot(s, s) / 0.0018) * 0.95);
	add_light(acc, SPARK_HOT, star4(s, 0.075));
	for (int k = 0; k < 4; k++) {
		float a = 0.9 + 1.55 * float(k);
		vec2 o = s - vec2(cos(a), sin(a)) * (0.040 + 0.012 * float(k % 2));
		over(acc, SPARK_HOT, cov(length(o) - 0.0065, f.px));
	}
}

// 白い碍子を重ねた鋼の柱
void insulator_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, STEEL, 1.0);
	for (int k = 0; k < 6; k++) {
		float y = 0.24 + 0.12 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(0.076, 0.022), PORCELAIN, 0.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), STEEL, 1.0);
}

void bakelite_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, BAKELITE, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	fuse_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, STEEL, 1.0);
	}
}

// 3段の碍子と、上の鋼の留め玉
void insulator(inout vec4 acc, Px f, float cx) {
	for (int k = 0; k < 3; k++) {
		vec2 c = vec2(cx, 1.212 + 0.036 * float(k));
		vec2 hs = vec2(0.050 - 0.008 * float(k), 0.016);
		vec2 q = f.p - c;
		float d = sd_round_box(q, hs, 0.014);
		vec3 n = normalize(vec3(clamp(q.x / hs.x, -1.0, 1.0) * 0.8, clamp(q.y / hs.y, -1.0, 1.0) * 0.5, 0.6));
		part(acc, d, ink_of(PORCELAIN) + 0.08, shade_mat(PORCELAIN, n, 0.0, 1.0, 1.0), f.ow, f.px);
	}
	draw_ball(acc, f, vec2(cx, 1.312), 0.020, STEEL, 1.0);
}

vec2 coil_point(int i) {
	float t = float(i) / float(COIL_STEPS);
	float a = t * COIL_TURNS * 6.2832;
	return vec2(mix(-COIL_END, COIL_END, t) + 0.010 * sin(a), COIL_Y + COIL_R * cos(a));
}

// 銅の巻き線: 奥の線を暗く先に、手前を明るく後に
void coil(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > COIL_END + 0.06 || abs(q.y - COIL_Y) > COIL_R + 0.03) {
		return;
	}
	for (int pass = 0; pass < 2; pass++) {
		float best = 9.0;
		for (int i = 0; i < COIL_STEPS; i++) {
			float t = (float(i) + 0.5) / float(COIL_STEPS);
			float front = sin(t * COIL_TURNS * 6.2832);
			if ((pass == 0) == (front > 0.0)) {
				continue;
			}
			best = min(best, sd_segment(q, coil_point(i), coil_point(i + 1)));
		}
		float d = best - 0.0085;
		vec3 c = pass == 0 ? COPPER * 0.55 : COPPER;
		part(acc, d, ink_of(COPPER), shade_mat(c, normalize(vec3(0.15, 0.55, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
	// 巻き線の両端を碍子の留め玉へ
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		float d = sd_segment(q, vec2(sx * COIL_END, COIL_Y + COIL_R), vec2(sx * INSULATOR_X, 1.312)) - 0.008;
		part(acc, d, ink_of(COPPER), shade_mat(COPPER, normalize(vec3(0.15, 0.55, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	}
}

// 留め玉から留め玉へ跳ねる青白い火花
void zap(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > INSULATOR_X + 0.06 || q.y < 1.28 || q.y > 1.40) {
		return;
	}
	vec2 pts[8] = vec2[](
		vec2(-INSULATOR_X, 1.318), vec2(-0.140, 1.352), vec2(-0.085, 1.330), vec2(-0.020, 1.364),
		vec2(0.040, 1.336), vec2(0.100, 1.360), vec2(0.150, 1.334), vec2(INSULATOR_X, 1.318)
	);
	float best = 9.0;
	for (int i = 0; i < 7; i++) {
		best = min(best, sd_segment(q, pts[i], pts[i + 1]));
	}
	add_light(acc, ZAP, exp(-best * best / 0.00035) * 0.9);
	over(acc, ZAP, cov(best - 0.009, f.px));
	over(acc, ZAP_HOT, cov(best - 0.0045, f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.45, f.p.y - 1.33);
	add_light(acc, ZAP, exp(-dot(d, d) / 0.006) * 0.55 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	insulator_post(acc, f, -POST_X);
	insulator_post(acc, f, POST_X);
	draw_collars(acc, f, STEEL, 1.0);
	bakelite_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		insulator(acc, f, -INSULATOR_X);
		insulator(acc, f, INSULATOR_X);
		coil(acc, f);
		zap(acc, f);
		for (int k = 0; k < 2; k++) {
			add_light(acc, ZAP_HOT, star4(f.p - vec2(k == 0 ? -INSULATOR_X : INSULATOR_X, 1.318), 0.05) * 0.8);
		}
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
