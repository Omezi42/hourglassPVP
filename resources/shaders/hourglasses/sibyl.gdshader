shader_type canvas_item;
// 巫女(シビル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は溝を刻んだ白大理石に金の月桂の帯、板は白大理石に金の縁と深い藍の帯・銀の星図の線。
// 天板の上の青銅の三脚の鉢から、銀の霊気が細くうねって立ちのぼり、先で星が一つ瞬く。

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
const vec3 MARBLE = vec3(0.93, 0.91, 0.87);
const vec3 GILT = vec3(0.96, 0.78, 0.38);
const vec3 BRONZE = vec3(0.74, 0.48, 0.26);
const vec3 LAUREL = vec3(0.46, 0.66, 0.34);
const vec3 VAPOR = vec3(0.84, 0.86, 1.0);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.060;
const float FLUTES = 3.0;
// 鉢の中心・半径、三脚の足元の開き、霊気の根元と先
const vec2 BOWL = vec2(0.0, 1.268);
const vec2 BOWL_R = vec2(0.118, 0.046);
const float LEG_X = 0.108;
const float FOOT_Y = 1.192;
const float VAPOR_TOP = 1.372;

void marble_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, MARBLE, 0.0);
	float lx = f.p.x - cx;
	if (abs(lx) < POST_R - 0.006 && f.ay < POST_H) {
		float u = lx / POST_R;
		float flute = abs(fract(asin(clamp(u, -1.0, 1.0)) / 3.14159 * FLUTES + 0.5) - 0.5);
		over(acc, MARBLE * 0.70, smoothstep(0.30, 0.48, flute) * 0.45 * (1.0 - u * u));
	}
	draw_band(acc, f, vec2(cx, 0.0), vec2(POST_R + 0.008, 0.030), LAUREL, 0.0);
	if (abs(lx) < POST_R + 0.008 && abs(f.p.y) < 0.03) {
		float leaf = abs(fract((f.p.y * 0.6 + abs(lx)) * 30.0) - 0.5);
		over(acc, LAUREL * 1.35, smoothstep(0.30, 0.10, leaf) * 0.7);
	}
	draw_band(acc, f, vec2(cx, 0.042), vec2(POST_R + 0.010, 0.006), GILT, 1.0);
	draw_band(acc, f, vec2(cx, -0.042), vec2(POST_R + 0.010, 0.006), GILT, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.032), MARBLE, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.918), vec2(0.072, 0.008), GILT, 1.0);
}

void marble_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, MARBLE, 0.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float vein = abs(vnoise(q * vec2(7.0, 14.0) + vec2(cy * 3.0, 0.0)) - 0.5);
	inlay(acc, d, MARBLE * 0.72, smoothstep(0.035, 0.0, vein) * 0.5, f);
	float rim = sd_round_box(q, SLAB_HALF - vec2(0.020, 0.016), 0.02);
	inlay(acc, d, GILT, cov(abs(rim) - 0.004, f.px), f);
	star_chart(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, GILT, 1.0);
	}
}

// 青銅の三脚と鉢、鉢から立ちのぼる銀の霊気
void tripod(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.24 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	vec3 bronze = shade_mat(BRONZE, normalize(vec3(0.2, 0.4, 0.8)), 1.0, 1.0, 1.0);
	for (int k = 0; k < 3; k++) {
		float x = (float(k) - 1.0) * LEG_X;
		float d_leg = sd_segment(q, vec2(x * 0.45, BOWL.y - 0.01), vec2(x, FOOT_Y + 0.008)) - (k == 1 ? 0.006 : 0.008);
		part(acc, d_leg, ink_of(BRONZE), k == 1 ? bronze * 0.7 : bronze, f.ow * 0.8, f.px);
		draw_ball(acc, f, vec2(x, FOOT_Y + 0.006), 0.012, BRONZE, 1.0);
	}
	vec2 bq = q - BOWL;
	float d_bowl = max(sd_ellipse(bq, BOWL_R), bq.y - 0.004);
	vec3 n = normalize(vec3(clamp(bq.x / BOWL_R.x, -1.0, 1.0) * 0.7, -0.2, 0.7));
	part(acc, d_bowl, ink_of(BRONZE), shade_mat(BRONZE, n, 1.0, 1.0, 1.0), f.ow, f.px);
	float d_rim = sd_ellipse(bq - vec2(0.0, 0.004), vec2(BOWL_R.x + 0.006, 0.012));
	part(acc, d_rim, ink_of(BRONZE), mix(bronze, GILT, 0.5), f.ow * 0.8, f.px);
	float t = clamp((q.y - BOWL.y) / (VAPOR_TOP - BOWL.y), 0.0, 1.0);
	float x0 = 0.034 * sin(t * 8.5) * (0.4 + t);
	float w = mix(0.026, 0.006, t);
	float d_vapor = max(abs(q.x - x0) - w, max(BOWL.y + 0.010 - q.y, q.y - VAPOR_TOP));
	over(acc, VAPOR, cov(d_vapor, f.px) * mix(1.0, 0.65, t));
	add_light(acc, VAPOR, exp(-pow((q.x - x0) / (w * 3.0 + 0.01), 2.0)) * step(BOWL.y, q.y) * step(q.y, VAPOR_TOP) * 0.5);
	vec2 s = q - vec2(0.034 * sin(8.5) * 1.4, VAPOR_TOP);
	add_light(acc, vec3(1.0), star4(s, 0.050));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.6, f.p.y - 1.30);
	add_light(acc, VAPOR, exp(-dot(d, d) / 0.010) * 0.45 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	marble_post(acc, f, -POST_X);
	marble_post(acc, f, POST_X);
	draw_collars(acc, f, GILT, 1.0);
	marble_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		tripod(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
