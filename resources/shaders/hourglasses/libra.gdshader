shader_type canvas_item;
// 天秤(リブラ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 溝を彫った青銅の柱と、燠火の筋が走る胡桃の板。天板の上の天秤は左へ傾き、下がった皿に赤い燠の砂が盛られている。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRONZE = vec3(0.78, 0.55, 0.32);
const vec3 WALNUT = vec3(0.34, 0.22, 0.16);
const vec3 EMBER = vec3(1.0, 0.44, 0.14);
const vec3 EMBER_HOT = vec3(1.0, 0.88, 0.56);
const float POST_R = 0.058;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
// 天秤: 支柱の足元・梁の支点・梁の半長・傾き(左が下がる)・鎖の長さ・皿の半幅
const float STAND_Y = 1.150;
const vec2 PIVOT = vec2(0.0, 1.312);
const float BEAM_HALF = 0.360;
const float BEAM_TILT = 0.12;
const float CHAIN = 0.100;
const vec2 PAN_HALF = vec2(0.112, 0.038);

void ember_seam(inout vec4 acc, Px f, float d, vec2 q, float half_x) {
	float line = cov(abs(q.y) - 0.008, f.px) * step(abs(q.x), half_x);
	inlay(acc, d, mix(EMBER, EMBER_HOT, cov(abs(q.y) - 0.003, f.px)), line, f);
}

// 縦の溝を彫った円柱
void fluted_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	float a = asin(u);
	float fine = smoothstep(0.03, 0.012, f.px);
	float flute = sin(a * 6.0);
	vec3 n = normalize(lathe_normal(u, 0.0) + vec3(cos(a * 6.0) * 0.35 * fine, 0.0, 0.0));
	vec3 c = shade_mat(BRONZE, n, 1.0, 1.0, f.ao);
	c *= mix(1.0, 0.82 + 0.18 * smoothstep(-0.6, 0.6, flute), fine);
	part(acc, d, ink_of(BRONZE), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.094, 0.032), BRONZE * 1.05, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.895), vec2(0.076, 0.014), BRONZE * 1.05, 1.0);
}

void walnut_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, WALNUT, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	ember_seam(acc, f, d, q, 0.72);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.74 : 0.74, cy), 0.022, BRONZE, 1.0);
	}
}

vec2 beam_end(float sx) {
	return PIVOT + vec2(sx * BEAM_HALF * cos(BEAM_TILT), sx * BEAM_HALF * sin(BEAM_TILT));
}

// 吊られた皿: 3本の鎖を三角に張り、浅い椀を下げる。heap が正なら燠の砂を盛る
void pan(inout vec4 acc, Px f, vec2 hook, float heap) {
	vec2 rim = hook - vec2(0.0, CHAIN);
	vec2 q = f.p - rim;
	if (abs(q.x) > PAN_HALF.x + 0.03 || q.y < -0.05 || q.y > CHAIN + 0.03) {
		return;
	}
	vec3 chain = shade_mat(BRONZE, normalize(vec3(0.0, 0.0, 1.0)), 1.0, 1.0, 1.0);
	for (int k = -1; k <= 1; k += 2) {
		float d_c = sd_segment(f.p, hook, rim + vec2(float(k) * PAN_HALF.x * 0.92, 0.0)) - 0.0045;
		part(acc, d_c, ink_of(BRONZE), chain, f.ow * 0.5, f.px);
	}
	if (heap > 0.0) {
		float d_heap = max(sd_ellipse(q - vec2(0.0, 0.002), vec2(PAN_HALF.x * 0.78, 0.034)), -q.y);
		vec3 sand = mix(EMBER, EMBER_HOT, smoothstep(0.0, 0.03, q.y) * 0.6);
		part(acc, d_heap, vec3(0.3, 0.06, 0.02), sand, f.ow * 0.6, f.px);
	}
	float d_bowl = max(sd_ellipse(q, PAN_HALF), q.y - 0.004);
	vec3 n = normalize(vec3(q.x / PAN_HALF.x * 0.5, -0.3, 0.8));
	part(acc, d_bowl, ink_of(BRONZE), shade_mat(BRONZE, n, 1.0, 1.0, 1.0), f.ow, f.px);
	float d_lip = sd_round_box(q - vec2(0.0, 0.002), vec2(PAN_HALF.x + 0.006, 0.008), 0.008);
	part(acc, d_lip, ink_of(BRONZE), shade_mat(BRONZE * 1.1, normalize(vec3(0.0, 0.6, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
}

void balance(inout vec4 acc, Px f) {
	if (abs(f.p.x) > BEAM_HALF + PAN_HALF.x + 0.04 || f.p.y < STAND_Y - 0.03) {
		return;
	}
	// 台と支柱
	vec2 bq = f.p - vec2(0.0, STAND_Y);
	float d_base = sd_round_box(bq - vec2(0.0, 0.010), vec2(0.075, 0.018), 0.012);
	part(acc, d_base, ink_of(BRONZE), shade_mat(BRONZE, normalize(vec3(bq.x / 0.075 * 0.4, 0.4, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	float d_post = max(abs(f.p.x) - 0.016, max(STAND_Y - f.p.y, f.p.y - PIVOT.y));
	part(acc, d_post, ink_of(BRONZE), shade_mat(BRONZE, lathe_normal(clamp(f.p.x / 0.016, -1.0, 1.0), 0.0), 1.0, 1.0, 1.0), f.ow, f.px);
	// 梁
	vec2 l = beam_end(-1.0);
	vec2 r = beam_end(1.0);
	float d_beam = sd_segment(f.p, l, r) - 0.013;
	part(acc, d_beam, ink_of(BRONZE), shade_mat(BRONZE * 1.05, normalize(vec3(0.0, 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	draw_ball(acc, f, l, 0.016, BRONZE, 1.0);
	draw_ball(acc, f, r, 0.016, BRONZE, 1.0);
	pan(acc, f, l, 1.0);
	pan(acc, f, r, 0.0);
	// 支点の飾り: 尖った頂の玉
	draw_ball(acc, f, PIVOT, 0.026, BRONZE, 1.0);
	vec2 tq = f.p - PIVOT - vec2(0.0, 0.026);
	float d_tip = max(abs(tq.x) - 0.016 * (1.0 - tq.y / 0.034), max(-tq.y, tq.y - 0.034));
	part(acc, d_tip, ink_of(BRONZE), shade_mat(BRONZE, normalize(vec3(sign(tq.x) * 0.4, 0.3, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - beam_end(-1.0) + vec2(0.0, CHAIN);
	add_light(acc, EMBER, exp(-dot(d, d) / 0.012) * 0.6 * canvas_window(f.p));
	vec2 d2 = f.p - PIVOT;
	add_light(acc, EMBER, exp(-dot(d2, d2) / 0.035) * 0.25 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	fluted_post(acc, f, -POST_X);
	fluted_post(acc, f, POST_X);
	draw_collars(acc, f, BRONZE, 1.0);
	walnut_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		balance(acc, f);
	} else if (f.p.y < 0.0) {
		vec2 mq = f.p - vec2(0.0, -PLATE_Y);
		float d_m = sd_rhombus(mq, vec2(0.070, 0.048));
		part(acc, d_m, ink_of(BRONZE), shade_mat(BRONZE, normalize(vec3(sign(mq.x) * 0.3, sign(mq.y) * 0.3, 0.85)), 1.0, 1.0, 1.0), f.ow, f.px);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
