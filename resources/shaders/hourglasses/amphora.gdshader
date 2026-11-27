shader_type canvas_item;
// 両取っ手の壺(アンフォラ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は黒釉の雷文の帯を巻いた素焼きの柱、板は黒釉に赤い雷文の縁と素焼きの樋。
// 天板の上に黒絵の帯を巻いた両取っ手の壺が立ち、胴に入ったひびから砂の色の油が一筋にじむ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 TROUGH_CLAY = vec3(0.84, 0.44, 0.22);
const vec3 POOL_DEEP = vec3(0.03, 0.28, 0.34);
const vec3 POOL_LIT = vec3(0.30, 0.82, 0.78);
const vec3 SPILL = vec3(0.88, 1.0, 0.97);
// 樋の切り欠き(水が溢れ落ちる所)の位置
const float SPILL_X = 0.44;
// 注砂の刻の印: 板に嵌めた舟形の素焼きの樋に青緑の水が縁まで満ち、右寄りで縁を越えて板の下の縁まで溢れ落ちる
void pour_trough(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.09) {
		return;
	}
	float w = mix(0.56, 0.64, clamp((q.y + 0.040) / 0.080, 0.0, 1.0));
	float trough = sd_round_box(vec2(q.x * 0.64 / w, q.y), vec2(0.64, 0.040), 0.030);
	inlay(acc, d, ink_of(TROUGH_CLAY), cov(trough - 0.022, f.px), f);
	vec3 clay = TROUGH_CLAY * mix(0.74, 1.14, smoothstep(-0.06, 0.06, q.y));
	inlay(acc, d, clay, cov(trough - 0.015, f.px), f);
	inlay(acc, d, ink_of(TROUGH_CLAY), cov(trough - 0.002, f.px), f);
	float depth = clamp((0.026 - q.y) / 0.064, 0.0, 1.0);
	float swell = 0.5 + 0.5 * sin(q.x * 38.0 + sin(q.x * 7.0) * 2.0 + q.y * 60.0);
	vec3 water = mix(POOL_LIT, POOL_DEEP, depth) * mix(0.9, 1.08, swell);
	inlay(acc, d, water, cov(trough + 0.002, f.px), f);
	float inside = cov(trough + 0.004, f.px);
	float surface = abs(q.y - 0.020 - 0.004 * sin(q.x * 30.0 + 0.6)) - 0.006;
	inlay(acc, d, SPILL, cov(surface, f.px) * inside, f);
	vec2 s = q - vec2(SPILL_X, 0.0);
	float wob = 0.003 * sin(q.y * 120.0);
	float spread = mix(0.030, 0.014, clamp((0.0 - q.y) / 0.05, 0.0, 1.0));
	float fall = max(abs(s.x + wob) - spread, max(q.y - 0.018, -0.084 - q.y));
	inlay(acc, d, ink_of(POOL_DEEP), cov(fall - 0.007, f.px), f);
	inlay(acc, d, mix(POOL_LIT, SPILL, 0.45 + 0.3 * sin(q.y * 80.0)), cov(fall, f.px), f);
	inlay(acc, d, SPILL, cov(abs(s.x + wob + 0.005) - 0.004, f.px) * cov(fall, f.px), f);
	for (int k = 0; k < 2; k++) {
		vec2 c = vec2(k == 0 ? -0.040 : 0.042, k == 0 ? -0.060 : -0.072);
		float drop = length((s - c) * vec2(1.0, 0.8)) - 0.008;
		inlay(acc, d, ink_of(POOL_DEEP), cov(drop - 0.005, f.px), f);
		inlay(acc, d, SPILL, cov(drop, f.px), f);
	}
}
const vec3 TERRA = vec3(0.86, 0.48, 0.26);
const vec3 GLAZE = vec3(0.12, 0.10, 0.10);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.060;
const float KEY = 0.040;
// 壺の胴の中心と半径、首の半幅と口の高さ、足の高さ、取っ手の輪
const vec2 BELLY = vec2(0.0, 1.268);
const vec2 BELLY_R = vec2(0.124, 0.070);
const float NECK_W = 0.042;
const float LIP_Y = 1.368;
const float FOOT_Y = 1.192;
const vec2 HANDLE = vec2(0.086, 1.322);

// 雷文(ギリシャの鍵の模様)の1周期: 1なら黒釉
float meander(vec2 p, float cell) {
	vec2 c = fract(p / cell) * 4.0;
	float hook = step(c.y, 1.0) + step(3.0, c.y) * step(c.x, 3.0) + step(c.x, 1.0) * step(1.0, c.y) * step(c.y, 3.0);
	hook += step(2.0, c.x) * step(c.x, 3.0) * step(2.0, c.y) * step(c.y, 3.0);
	return clamp(hook, 0.0, 1.0);
}

// 素焼きの柱に黒釉の雷文の帯
void terra_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, TERRA, 0.0);
	float lx = f.p.x - cx;
	for (int k = 0; k < 3; k++) {
		float y = 0.16 + 0.34 * float(k);
		float by = f.ay - y;
		if (abs(lx) < POST_R - 0.003 && abs(by) < KEY * 0.5) {
			float m = meander(vec2(lx + 0.2, by + KEY * 0.5), KEY);
			over(acc, GLAZE, m * 0.92 * (1.0 - pow(lx / POST_R, 4.0)));
		}
		draw_band(acc, f, vec2(cx, f.side * (y + KEY * 0.5 + 0.008)), vec2(POST_R + 0.006, 0.006), GLAZE, 0.3);
		draw_band(acc, f, vec2(cx, f.side * (y - KEY * 0.5 - 0.008)), vec2(POST_R + 0.006, 0.006), GLAZE, 0.3);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.030), GLAZE, 0.3);
}

void glaze_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, GLAZE, 0.2, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	if (abs(q.x) > 0.68) {
		float m = meander(vec2(q.x, q.y + 0.04), 0.040);
		inlay(acc, d, TERRA, m * step(abs(q.y), 0.060), f);
	}
	inlay(acc, d, TERRA, cov(abs(abs(q.y) - 0.070) - 0.004, f.px) * step(abs(q.x), 0.76), f);
	pour_trough(acc, f, d, q);
}

// 胴の半幅(高さごと)。肩で張り、足へ向けてすぼまる
float amphora_half(float y) {
	float u = (y - BELLY.y) / BELLY_R.y;
	if (u < -1.0) {
		return mix(0.056, 0.036, clamp((BELLY.y - BELLY_R.y - y) / (BELLY.y - BELLY_R.y - FOOT_Y), 0.0, 1.0));
	}
	if (u > 0.6) {
		return mix(BELLY_R.x * 0.8, NECK_W, smoothstep(0.6, 1.3, u));
	}
	return BELLY_R.x * sqrt(max(1.0 - u * u * 0.55, 0.0)) * mix(0.6, 1.0, smoothstep(-1.0, -0.2, u));
}

// 黒絵の帯を巻いた両取っ手の壺と、ひびからにじむ油
void amphora(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.24 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		vec2 h = q - vec2(sx * HANDLE.x, HANDLE.y);
		float d_handle = max(abs(sd_ellipse(h, vec2(0.052, 0.034))) - 0.010, -sx * h.x - 0.012);
		part(acc, d_handle, ink_of(TERRA), shade_mat(TERRA, normalize(vec3(sx * 0.5, 0.3, 0.8)), 0.0, 0.4, 1.0), f.ow * 0.8, f.px);
	}
	float half_w = amphora_half(q.y);
	float d_body = max(abs(q.x) - half_w, max(FOOT_Y - q.y, q.y - LIP_Y));
	vec3 n = lathe_normal(clamp(q.x / max(half_w, 0.01), -1.0, 1.0), 0.0);
	vec3 clay = shade_mat(TERRA, n, 0.0, 0.5, 1.0);
	float band = step(abs(q.y - BELLY.y - 0.004), 0.028);
	vec3 figure = mix(clay, GLAZE, band * (0.85 + 0.15 * step(0.5, fract(q.x * 30.0))));
	float zig = abs(fract(q.x * 14.0) - 0.5) * 0.07 - 0.012;
	figure = mix(figure, clay * 0.95, band * cov(abs(q.y - BELLY.y - 0.004 - zig) - 0.006, f.px));
	figure = mix(figure, GLAZE, step(LIP_Y - 0.016, q.y) + step(q.y, FOOT_Y + 0.012));
	part(acc, d_body, ink_of(TERRA), figure, f.ow, f.px);
	draw_band(acc, f, vec2(0.0, LIP_Y), vec2(NECK_W + 0.016, 0.008), TERRA, 0.0);
	vec2 c = q - vec2(0.044, BELLY.y - 0.030);
	float crack = abs(c.x - 0.010 * sin(c.y * 120.0) + c.y * 0.2) - 0.0028;
	over(acc, GLAZE, cov(crack, f.px) * step(-0.030, c.y) * step(c.y, 0.040) * cov(d_body + 0.004, f.px));
	float d_oil = max(abs(q.x - 0.050 - 0.002 * sin(q.y * 200.0)) - 0.008, max(FOOT_Y - q.y, q.y - BELLY.y + 0.050));
	part(acc, d_oil, ink_of(sand_color), mix(sand_color, vec3(1.0), 0.25), f.ow * 0.5, f.px);
	float d_pool = sd_ellipse(q - vec2(0.064, 1.193), vec2(0.046, 0.008));
	part(acc, d_pool, ink_of(sand_color), sand_color, f.ow * 0.4, f.px);
	over(acc, vec3(1.0), cov(sd_segment(q, vec2(-0.084, 1.250), vec2(-0.070, 1.296)) - 0.006, f.px) * 0.45);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.6, f.p.y - 1.28);
	add_light(acc, sand_color, exp(-dot(d, d) / 0.010) * 0.30 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	terra_post(acc, f, -POST_X);
	terra_post(acc, f, POST_X);
	draw_collars(acc, f, GLAZE, 0.3);
	glaze_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		amphora(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
