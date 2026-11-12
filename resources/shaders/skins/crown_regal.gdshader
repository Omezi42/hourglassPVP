shader_type canvas_item;
// スキン「戴冠」(クラウン)。GameDesign.md 31章 / Architecture.md 10.19節。

#define SKIN_SAND_COLOR vec3(1.0, 0.80, 0.26)
#define SKIN_SAND_KIND KIND_GRAIN
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_parts.gdshaderinc"

const vec3 VELVET = vec3(0.52, 0.07, 0.14);
const vec3 RUBY = vec3(0.92, 0.16, 0.24);
const vec3 SAPPHIRE = vec3(0.24, 0.42, 0.96);
const vec3 PEARL = vec3(0.98, 0.95, 0.88);
const float ROPE_POST_X = 0.68;
const float ROPE_POST_R = 0.056;
const float CROWN_Y = 1.120;
// 王冠は天板の上の空きに収まる最大の大きさで描く(縮めても形が読めるように)
const float CROWN_SCALE = 1.35;
const int CROWN_POINTS = 5;

// 宝石 k の瞬き(順に光が渡る)
float jewel_twinkle(float k, float count) {
	float t = fract(clock * 0.32 - k / count);
	return exp(-pow((t - 0.5) / 0.05, 2.0));
}

// ねじり柱: 斜めの溝が巻く金の柱。砂が落ちている間だけ、ねじれが回って見える。
void draw_rope_column(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > ROPE_POST_R + f.pad || f.ay > 1.02 + f.pad) {
		return;
	}
	float d = max(abs(lx) - ROPE_POST_R, f.ay - 1.02);
	float u = clamp(lx / ROPE_POST_R, -1.0, 1.0);
	float ang = asin(u);
	float g = fract(f.p.y * 7.5 + ang * 0.55 - clock * 0.45 * flow);
	float bulge = sin(g * 3.1416);
	float fine = smoothstep(0.028, 0.012, f.px);
	vec3 n = lathe_normal(u, (0.5 - g) * 1.2 * fine);
	vec3 c = shade_mat(GOLD, n, 1.0, 1.0, f.ao);
	c *= mix(1.0, mix(0.55, 1.0, smoothstep(0.0, 0.35, bulge)), fine);
	part(acc, d, ink_of(GOLD), c, f.ow, f.px);
}

void jewel(inout vec4 acc, Px f, vec2 c, vec2 r, vec3 col, float sparkle) {
	vec2 q = f.p - c;
	if (abs(q.x) > r.x + f.pad || abs(q.y) > r.y + f.pad) {
		return;
	}
	float d = sd_ellipse(q, r);
	vec2 s = q / r;
	vec3 face = mix(col * 0.55, mix(col, vec3(1.0), 0.45), smoothstep(0.4, -0.6, s.x + s.y));
	face = mix(face, vec3(1.0), cov(length(s - vec2(-0.35, 0.35)) - 0.28, f.px / r.x) * 0.8);
	part(acc, d, ink_of(GOLD), face, f.ow * 0.8, f.px);
	add_light(acc, vec3(1.0, 0.96, 0.86), star4(q, max(r.x, r.y) * 3.2) * sparkle);
}

void draw_crown(inout vec4 acc, Px fs) {
	Px f = fs;
	f.p = (fs.p - vec2(0.0, CROWN_Y)) / CROWN_SCALE + vec2(0.0, CROWN_Y);
	f.px = fs.px / CROWN_SCALE;
	f.ow = fs.ow / CROWN_SCALE;
	f.pad = fs.pad / CROWN_SCALE;
	vec2 q = f.p - vec2(0.0, CROWN_Y);
	if (abs(q.x) > 0.34 || q.y < -0.08 || q.y > 0.24) {
		return;
	}
	// 中の赤い帽子
	float d_cap = sd_ellipse(q - vec2(0.0, 0.060), vec2(0.19, 0.095));
	vec3 cap_n = normalize(vec3(q.x / 0.19 * 0.6, (q.y - 0.06) / 0.095 * 0.6, 0.8));
	part(acc, d_cap, ink_of(VELVET), shade_mat(VELVET * 1.25, cap_n, 0.0, 0.4, 1.0), f.ow, f.px);
	// 5本の爪(中央が最も高い)。先に真珠
	for (int k = 0; k < CROWN_POINTS; k++) {
		float i = float(k) - 2.0;
		float h = 0.090 + 0.022 * (2.0 - abs(i));
		float lean = i * 0.07;
		vec2 pc = vec2(i * 0.098, 0.030);
		vec2 lq = q - pc;
		lq.x -= lean * lq.y;
		// 根元が広く先の尖った爪
		float tt = clamp(lq.y / h, 0.0, 1.0);
		float hw = mix(0.054, 0.008, pow(tt, 0.75));
		float d_pt = max(abs(lq.x) - hw, max(-lq.y, lq.y - h));
		if (d_pt < f.ow + f.px) {
			vec3 n = normalize(vec3(sign(lq.x) * 0.45 * smoothstep(0.0, hw, abs(lq.x)), 0.25, 0.85));
			part(acc, d_pt, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
		}
		vec2 tip = vec2(0.0, CROWN_Y) + pc + vec2(lean * (h + 0.012), h + 0.012);
		draw_ball(acc, f, tip, 0.018, PEARL, 0.25);
		add_light(acc, vec3(1.0, 0.97, 0.88), star4(f.p - tip, 0.085) * jewel_twinkle(float(k), 5.0));
	}
	// 帯: 金の輪。赤と青の宝石
	float d_band = sd_round_box(q, vec2(0.215, 0.040), 0.014);
	vec3 band_n = normalize(vec3(q.x / 0.215 * 0.35, q.y / 0.040 * 0.5, 0.8));
	part(acc, d_band, ink_of(GOLD), shade_mat(GOLD, band_n, 1.0, 1.0, 1.0), f.ow, f.px);
	jewel(acc, f, vec2(0.0, CROWN_Y), vec2(0.034, 0.025), RUBY, 0.0);
	jewel(acc, f, vec2(-0.125, CROWN_Y), vec2(0.022, 0.018), SAPPHIRE, 0.0);
	jewel(acc, f, vec2(0.125, CROWN_Y), vec2(0.022, 0.018), SAPPHIRE, 0.0);
}

// 板の金の縁を照りが滑る
float rim_glint(float x) {
	float g = fract(clock * 0.12) * 2.6 - 1.3;
	return exp(-pow((x - g) / 0.08, 2.0));
}

void skin_back(inout vec4 acc, Px f) {
}

void skin_frame(inout vec4 acc, Px f) {
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -ROPE_POST_X : ROPE_POST_X;
		draw_rope_column(acc, f, cx);
		draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.034), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.890), vec2(0.072, 0.014), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, 0.0), vec2(0.074, 0.024), GOLD, 1.0);
		jewel(acc, f, vec2(cx, 0.0), vec2(0.020, 0.016), RUBY, 0.0);
	}
	draw_collars(acc, f, GOLD, 1.0);
	float d = draw_slab(acc, f, f.side * 1.098, vec2(0.82, 0.082), 0.03, VELVET, 0.0, 0.35);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	// 上下の縁の太い金の帯
	float rim_band = smoothstep(0.050, 0.056, abs(q.y));
	vec3 gold_rim = shade_mat(GOLD, normalize(vec3(0.0, sign(q.y) * 0.5, 0.8)), 1.0, 1.0, 1.0);
	gold_rim = mix(gold_rim, vec3(1.0, 0.98, 0.9), rim_glint(q.x) * 0.7);
	inlay(acc, d, gold_rim, rim_band, f);
	// 金の鋲と宝石の列
	for (int k = 0; k < 4; k++) {
		float x = (float(k) - 1.5) * 0.40;
		if (abs(x) < 0.25) {
			continue;
		}
		vec3 col = k % 3 == 0 ? SAPPHIRE : RUBY;
		jewel(acc, f, vec2(x, f.side * 1.098), vec2(0.022, 0.018), col, jewel_twinkle(float(k) + 1.5, 5.0) * 0.7);
	}
	for (int k = 0; k < 2; k++) {
		float x = (k == 0 ? -1.0 : 1.0) * 0.40;
		draw_ball(acc, f, vec2(x, f.side * 1.098), 0.018, GOLD, 1.0);
	}
	if (f.p.y > 0.0) {
		draw_crown(acc, f);
	} else {
		// 底板の中央: 金の楯形の飾りに大粒の紅玉
		vec2 mq = f.p - vec2(0.0, -1.098);
		float d_m = sd_ellipse(mq, vec2(0.10, 0.072));
		vec3 n = normalize(vec3(mq / vec2(0.10, 0.072) * 0.6, 0.8));
		part(acc, d_m, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
		jewel(acc, f, vec2(0.0, -1.098), vec2(0.050, 0.036), RUBY, jewel_twinkle(3.0, 5.0));
	}
}

#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_main.gdshaderinc"
