shader_type canvas_item;
// 掘り手(ディガー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は革紐を巻いた白樫の柄に鉄の口金、板は樫の木に深い藍の帯と銀の星図の線。
// 天板の上の掘り返した土の山につるはしが突き立ち、半ば埋まった素焼きの壺が覗いて光る。

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
const vec3 ASH_WOOD = vec3(0.80, 0.62, 0.40);
const vec3 OAK = vec3(0.42, 0.27, 0.16);
const vec3 IRON = vec3(0.40, 0.41, 0.45);
const vec3 THONG = vec3(0.40, 0.22, 0.12);
const vec3 EARTH = vec3(0.44, 0.29, 0.18);
const vec3 CLAY = vec3(0.80, 0.44, 0.26);
const vec3 GLINT = vec3(1.0, 0.92, 0.70);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.054;
// 土の山(中心・半径)、つるはしの柄の下端と頭、頭の半分の長さ、壺の胴の中心と半径
const vec2 MOUND = vec2(0.0, 1.184);
const vec2 MOUND_R = vec2(0.32, 0.070);
const vec2 HANDLE_LOW = vec2(-0.040, 1.214);
const vec2 PICK_HEAD = vec2(-0.185, 1.306);
const float PICK_HALF = 0.086;
const vec2 JAR = vec2(0.140, 1.256);
const vec2 JAR_R = vec2(0.064, 0.056);

void handle_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, ASH_WOOD, 0.0);
	float lx = f.p.x - cx;
	if (abs(lx) < POST_R + f.pad && f.ay < 0.24) {
		float d = max(abs(lx) - POST_R - 0.004, f.ay - 0.24);
		float wrap = step(0.42, fract((f.p.y + lx * 0.7) * 22.0));
		vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
		part(acc, d, ink_of(THONG), shade_mat(THONG * mix(0.75, 1.1, wrap), n, 0.0, 0.5, f.ao), f.ow * 0.7, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.30), vec2(POST_R + 0.008, 0.020), IRON, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.66), vec2(POST_R + 0.006, 0.014), IRON, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), IRON, 1.0);
}

void oak_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, OAK, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float grain = sin(q.y * 150.0 + sin(q.x * 9.0 + 1.0) * 3.0);
	inlay(acc, d, OAK * 1.2, smoothstep(0.6, 1.0, grain) * 0.35, f);
	star_chart(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, IRON, 1.0);
	}
}

// 半ば埋まった素焼きの壺(胴・口・両の取っ手)
void jar(inout vec4 acc, Px f) {
	vec2 q = f.p - JAR;
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		vec2 hq = q - vec2(sx * 0.046, 0.044);
		float d_h = abs(length(hq) - 0.018) - 0.006;
		part(acc, d_h, ink_of(CLAY), CLAY * 0.8, f.ow * 0.7, f.px);
	}
	float d_neck = sd_round_box(q - vec2(0.0, 0.062), vec2(0.024, 0.022), 0.006);
	float d_lip = sd_round_box(q - vec2(0.0, 0.084), vec2(0.034, 0.008), 0.006);
	float d_body = sd_ellipse(q, JAR_R);
	float d = min(min(d_body, d_neck), d_lip);
	vec3 n = normalize(vec3(clamp(q.x / JAR_R.x, -1.0, 1.0) * 0.7, clamp(q.y / JAR_R.y, -1.0, 1.0) * 0.3, 0.7));
	vec3 clay = shade_mat(CLAY, n, 0.0, 0.4, 1.0);
	clay = mix(clay, ink_of(CLAY) * 1.6, cov(abs(q.y - 0.012) - 0.005, f.px) * 0.7);
	part(acc, d, ink_of(CLAY), clay, f.ow, f.px);
	add_light(acc, GLINT, star4(q - vec2(-0.026, 0.030), 0.050));
}

// 土の山に突き立つつるはし(柄と、反った鉄の頭)
void pick(inout vec4 acc, Px f) {
	vec2 axis = normalize(PICK_HEAD - HANDLE_LOW);
	vec2 across = vec2(axis.y, -axis.x);
	float d_handle = sd_segment(f.p, HANDLE_LOW, PICK_HEAD) - 0.014;
	vec3 n_h = normalize(vec3(0.2, 0.3, 0.8));
	part(acc, d_handle, ink_of(ASH_WOOD), shade_mat(ASH_WOOD, n_h, 0.0, 0.6, 1.0), f.ow * 0.8, f.px);
	vec2 hq = f.p - PICK_HEAD;
	float u = dot(hq, across);
	float v = dot(hq, axis) + 5.0 * u * u;
	float thick = 0.005 + 0.015 * (1.0 - abs(u) / PICK_HALF);
	float d_head = max(abs(v) - thick, abs(u) - PICK_HALF);
	float shade = clamp(v / max(thick, 0.001), -1.0, 1.0);
	vec3 iron = mix(IRON * 1.35, IRON * 0.75, shade * 0.5 + 0.5);
	part(acc, d_head, ink_of(IRON), iron, f.ow * 0.8, f.px);
	draw_band(acc, f, PICK_HEAD, vec2(0.018, 0.018), IRON * 0.8, 1.0);
}

void dig_site(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.32 || q.y < 1.16 || q.y > 1.39) {
		return;
	}
	jar(acc, f);
	pick(acc, f);
	vec2 mq = q - MOUND;
	float d_mound = max(sd_ellipse(mq, MOUND_R), -mq.y);
	vec3 n = normalize(vec3(clamp(mq.x / MOUND_R.x, -1.0, 1.0) * 0.5, 0.5, 0.7));
	vec3 earth = EARTH * (0.8 + 0.4 * vnoise(q * 60.0));
	earth = mix(earth, vec3(0.62, 0.58, 0.54), step(0.90, hash21(floor(q * 90.0))));
	part(acc, d_mound, ink_of(EARTH), shade_mat(earth, n, 0.0, 0.1, 1.0), f.ow, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - JAR - vec2(0.0, 0.02);
	add_light(acc, GLINT, exp(-dot(d, d) / 0.005) * 0.4 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	handle_post(acc, f, -POST_X);
	handle_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	oak_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		dig_site(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
