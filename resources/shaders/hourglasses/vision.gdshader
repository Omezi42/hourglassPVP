shader_type canvas_item;
// 幻視(ヴィジョン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は銀の線を嵌めた黒曜石に星の粒、板は黒曜石に深い藍の帯と銀の星図の線。
// 天板の上に銀の瞼の大きな目が開き、瞳は星を散らした夜空で、芯に白い星が灯る。上の瞼から銀の光芒が扇に開く。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 LAPIS = vec3(0.07, 0.09, 0.27);
const vec3 CHART = vec3(0.86, 0.90, 1.0);
const vec3 NEXT_STAR = vec3(0.74, 0.84, 1.0);

// 星図の星の位置(帯の中の座標)。右端の5番が「まだ来ない」星
vec2 chart_star(int k) {
	return vec2(-0.60 + 0.228 * float(k), 0.017 * sin(float(k) * 2.3 + 0.4));
}
// 先触の刻の印: 板に嵌めた深い藍の帯を銀の星図の線がつなぎ、点線の先の右端の星だけが明るく瞬く
void star_chart(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.075) {
		return;
	}
	float strip = sd_round_box(q, vec2(0.68, 0.040), 0.036);
	inlay(acc, d, ink_of(SILVER), cov(strip - 0.013, f.px), f);
	inlay(acc, d, SILVER * 0.9, cov(strip - 0.007, f.px), f);
	float fleck = step(0.95, hash21(floor(q * 160.0)));
	vec3 lapis = mix(LAPIS, LAPIS * 1.7, vnoise(q * 22.0) * 0.7);
	inlay(acc, d, mix(lapis, CHART, fleck * 0.45), cov(strip, f.px), f);
	float inside = cov(strip + 0.004, f.px);
	for (int k = 0; k < 4; k++) {
		float dl = sd_segment(q, chart_star(k), chart_star(k + 1)) - 0.0035;
		inlay(acc, d, CHART * 0.82, cov(dl, f.px) * inside, f);
	}
	vec2 a = chart_star(4);
	vec2 b = chart_star(5);
	float dash = step(0.45, fract(dot(q - a, normalize(b - a)) * 30.0));
	inlay(acc, d, CHART * 0.7, cov(sd_segment(q, a, b) - 0.003, f.px) * dash * inside, f);
	for (int k = 0; k < 5; k++) {
		float r = k % 2 == 0 ? 0.012 : 0.009;
		inlay(acc, d, CHART, cov(length(q - chart_star(k)) - r, f.px), f);
	}
	vec2 s = q - b;
	add_light(acc, NEXT_STAR, exp(-dot(s, s) / 0.0014) * 0.95);
	add_light(acc, vec3(1.0), star4(s, 0.075));
}
const vec3 OBSIDIAN = vec3(0.11, 0.10, 0.15);
const vec3 IRIS = vec3(0.14, 0.18, 0.56);
const vec3 EYE_WHITE = vec3(0.86, 0.89, 0.97);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.056;
// 目の中心・半幅・半分の高さ、瞳の半径、光芒の数と長さ
const vec2 EYE = vec2(0.0, 1.270);
const vec2 EYE_HALF = vec2(0.180, 0.060);
const float IRIS_R = 0.050;
const int RAYS = 7;
const float RAY_LEN = 0.034;

void obsidian_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, OBSIDIAN, 0.5);
	float lx = f.p.x - cx;
	if (abs(lx) < POST_R - 0.004 && f.ay < POST_H) {
		over(acc, SILVER, cov(abs(lx + 0.012) - 0.0045, f.px) * 0.85);
		vec2 cell = floor(vec2(lx, f.p.y) * 70.0);
		vec2 s = vec2(lx, f.p.y) * 70.0 - cell - 0.5;
		float star = step(0.90, hash21(cell + cx)) * smoothstep(0.30, 0.05, length(s));
		over(acc, CHART, star * 0.9);
	}
	for (int k = 0; k < 2; k++) {
		draw_band(acc, f, vec2(cx, f.side * (0.34 + 0.34 * float(k))), vec2(POST_R + 0.006, 0.010), SILVER, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), SILVER, 1.0);
}

void obsidian_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, OBSIDIAN, 0.5, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	star_chart(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.022, SILVER, 1.0);
	}
}

// アーモンド形の目(二つの円の重なり)
float almond(vec2 q) {
	float r = (EYE_HALF.x * EYE_HALF.x + EYE_HALF.y * EYE_HALF.y) / (2.0 * EYE_HALF.y);
	float c = r - EYE_HALF.y;
	return max(length(q - vec2(0.0, -c)) - r, length(q - vec2(0.0, c)) - r);
}

void seeing_eye(inout vec4 acc, Px f) {
	vec2 q = f.p - EYE;
	if (abs(q.x) > 0.24 || q.y < -0.09 || q.y > 0.12) {
		return;
	}
	for (int k = 0; k < RAYS; k++) {
		float a = mix(0.42, 3.14159 - 0.42, float(k) / float(RAYS - 1));
		vec2 dir = vec2(cos(a), sin(a));
		vec2 root = vec2(dir.x * EYE_HALF.x * 0.82, EYE_HALF.y * 0.62 + abs(dir.x) * -0.010) + dir * 0.012;
		float len = RAY_LEN * (k % 2 == 0 ? 1.0 : 0.7);
		float d_ray = sd_segment(q, root, root + dir * len) - 0.0045;
		part(acc, d_ray, ink_of(SILVER), SILVER, f.ow * 0.6, f.px);
	}
	float d_eye = almond(q);
	part(acc, abs(d_eye) - 0.006, ink_of(SILVER), shade_mat(SILVER, normalize(vec3(0.2, 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	float inside = cov(d_eye + 0.006, f.px);
	vec3 white = mix(EYE_WHITE, EYE_WHITE * 0.72, smoothstep(0.0, EYE_HALF.y, q.y + 0.01) * 0.6);
	over(acc, white, inside);
	float d_iris = length(q) - IRIS_R;
	vec2 cell = floor(q * 260.0);
	float speck = step(0.88, hash21(cell)) * smoothstep(0.5, 0.1, length(q * 260.0 - cell - 0.5));
	vec3 iris = mix(IRIS * 0.7, IRIS * 1.5, smoothstep(IRIS_R, 0.0, length(q)));
	iris = mix(iris, CHART, speck);
	over(acc, ink_of(IRIS), cov(d_iris + 0.0, f.px) * inside);
	over(acc, iris, cov(d_iris + 0.005, f.px) * inside);
	add_light(acc, vec3(1.0), star4(q, 0.050) * inside);
	over(acc, vec3(1.0), cov(length(q - vec2(-0.018, 0.020)) - 0.009, f.px) * inside * 0.8);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2((f.p.x - EYE.x) * 0.7, f.p.y - EYE.y);
	add_light(acc, IRIS * 1.6, exp(-dot(d, d) / 0.008) * 0.55 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	obsidian_post(acc, f, -POST_X);
	obsidian_post(acc, f, POST_X);
	draw_collars(acc, f, SILVER, 1.0);
	obsidian_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		seeing_eye(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
