shader_type canvas_item;
// 流星(ミーティア)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は網目の結晶模様が浮かぶ隕鉄、板は夜空の紺に星を散らし、黒色火薬の煤の溝と、そこを這う導火線の火の点。
// 天板の上を、燃える岩が右上の空から火の尾を引いて斜めに落ちてくる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 POWDER = vec3(0.11, 0.10, 0.10);
const vec3 HEMP = vec3(0.86, 0.68, 0.40);
const vec3 ASH = vec3(0.40, 0.38, 0.37);
const vec3 SPARK = vec3(1.0, 0.70, 0.24);
const vec3 SPARK_HOT = vec3(1.0, 0.97, 0.80);
const vec3 BRASS = vec3(0.90, 0.70, 0.36);
const vec3 METEORIC = vec3(0.66, 0.68, 0.72);
const vec3 NIGHT = vec3(0.17, 0.19, 0.33);
const vec3 ROCK = vec3(0.36, 0.30, 0.28);
const vec3 FIRE = vec3(1.0, 0.52, 0.16);
const vec3 FIRE_RED = vec3(0.90, 0.22, 0.10);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.050;
const float LIT_X = 0.24;
// 岩の中心と半径、尾の先
const vec2 HEAD = vec2(-0.10, 1.270);
const float ROCK_R = 0.068;
const vec2 TAIL = vec2(0.34, 1.382);

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

// 隕鉄の柱: 三方向の帯が交わる網目の結晶模様
void meteoric_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, METEORIC, 1.0);
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R - 0.004 && f.ay < POST_H) {
		vec2 p = vec2(lx, f.p.y) * 22.0;
		float w = 0.0;
		for (int k = 0; k < 3; k++) {
			float a = 0.35 + 2.094 * float(k);
			w += smoothstep(0.30, 0.42, abs(fract(dot(p, vec2(cos(a), sin(a)))) - 0.5));
		}
		float fine = smoothstep(0.03, 0.012, f.px);
		over(acc, METEORIC * 0.55, clamp(w - 1.2, 0.0, 1.0) * 0.45 * fine);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.030), METEORIC, 1.0);
}

void night_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, NIGHT, 0.0, 0.9);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	vec2 cell = floor(q * vec2(40.0, 40.0));
	vec2 jit = hash22(cell) - 0.5;
	float star = step(0.86, hash21(cell + 7.0));
	float d_star = length(fract(q * 40.0) - 0.5 - jit * 0.5) / 40.0 - 0.0035;
	inlay(acc, d, vec3(0.92, 0.92, 1.0), cov(d_star, f.px) * star, f);
	fuse_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, METEORIC, 1.0);
	}
}

// 火の尾: 岩から尾の先へ細りながら、白から橙・赤へ冷める
void fire_tail(inout vec4 acc, Px f) {
	vec2 axis = TAIL - HEAD;
	float len = length(axis);
	vec2 dir = axis / len;
	vec2 q = f.p - HEAD;
	float t = dot(q, dir) / len;
	if (t < -0.2 || t > 1.05) {
		return;
	}
	float side = dot(q, vec2(-dir.y, dir.x));
	float wave = 0.006 * sin(t * 26.0);
	float w = ROCK_R * 1.05 * pow(clamp(1.0 - t, 0.0, 1.0), 0.75);
	float d = abs(side - wave) - w;
	d = max(d, -t * len);
	float a = cov(d, f.px) * smoothstep(1.0, 0.75, t);
	vec3 c = mix(SPARK_HOT, FIRE, smoothstep(0.05, 0.40, t));
	c = mix(c, FIRE_RED, smoothstep(0.45, 0.95, t));
	over(acc, FIRE_RED * 0.8, cov(d - 0.008, f.px) * smoothstep(1.0, 0.7, t) * 0.9);
	over(acc, c, a);
	float core = cov(abs(side - wave) - w * 0.42, f.px) * smoothstep(0.55, 0.0, t) * step(0.0, t);
	over(acc, SPARK_HOT, core);
}

// 燃える岩: 窪みを持つ焦げ茶の岩。落ちていく向き(左下)の縁が白く灼ける
void rock(inout vec4 acc, Px f) {
	vec2 q = f.p - HEAD;
	if (length(q) > ROCK_R + 0.03) {
		return;
	}
	float ang = atan(q.y, q.x);
	float r = ROCK_R * (1.0 + 0.07 * sin(ang * 5.0 + 1.3) + 0.04 * sin(ang * 9.0));
	float d = length(q) - r;
	vec3 n = normalize(vec3(q / ROCK_R * 0.75, 0.6));
	vec3 c = shade_mat(ROCK, n, 0.0, 0.3, 1.0);
	for (int k = 0; k < 3; k++) {
		vec2 cc = vec2(cos(float(k) * 2.3 + 0.6), sin(float(k) * 2.3 + 0.6)) * ROCK_R * 0.45;
		float cr = ROCK_R * (0.20 - 0.04 * float(k));
		c = mix(c, ROCK * 0.45, cov(length(q - cc) - cr, f.px) * 0.8);
	}
	vec2 lead = normalize(HEAD - TAIL);
	float hot = smoothstep(0.1, 0.9, dot(normalize(q + 0.0001), lead)) * smoothstep(-0.35, 0.0, d / ROCK_R);
	c = mix(c, mix(FIRE, SPARK_HOT, 0.5), hot * 0.85);
	part(acc, d, ink_of(ROCK), c, f.ow, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - mix(HEAD, TAIL, 0.25);
	add_light(acc, FIRE, exp(-dot(d, d) / 0.018) * 0.55 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	meteoric_post(acc, f, -POST_X);
	meteoric_post(acc, f, POST_X);
	draw_collars(acc, f, METEORIC, 1.0);
	night_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		fire_tail(acc, f);
		rock(acc, f);
		add_light(acc, SPARK_HOT, star4(f.p - HEAD - normalize(HEAD - TAIL) * ROCK_R, 0.06) * 0.7);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
