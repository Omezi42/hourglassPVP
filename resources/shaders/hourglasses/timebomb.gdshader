shader_type canvas_item;
// 時限爆弾(タイムボム)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は鉄の帯で締めた松の角材、板は松の木箱の板に黒色火薬の煤の溝と、そこを這う導火線の火の点。
// 天板の上には黒い帯で束ねた三本の赤い発破筒が立ち、正面の真鍮の時計の針が十二時の手前を指す。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 POWDER = vec3(0.11, 0.10, 0.10);
const vec3 HEMP = vec3(0.86, 0.68, 0.40);
const vec3 ASH = vec3(0.40, 0.38, 0.37);
const vec3 SPARK = vec3(1.0, 0.70, 0.24);
const vec3 SPARK_HOT = vec3(1.0, 0.97, 0.80);
const vec3 BRASS = vec3(0.90, 0.70, 0.36);
const vec3 PINE = vec3(0.86, 0.68, 0.44);
const vec3 IRON = vec3(0.24, 0.24, 0.27);
const vec3 DYNAMITE = vec3(0.86, 0.20, 0.16);
const vec3 PAPER_END = vec3(0.94, 0.84, 0.66);
const vec3 STRAP = vec3(0.12, 0.11, 0.12);
const vec3 DIAL = vec3(0.97, 0.95, 0.88);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_HALF = 0.054;
const float LIT_X = 0.24;
// 発破筒の間隔・半幅・下端と上端、時計の中心と半径、長針の角度(十二時から時計回り)
const float STICK_GAP = 0.086;
const float STICK_HALF = 0.041;
const float STICK_BOTTOM = 1.196;
const float STICK_TOP = 1.356;
const vec2 DIAL_C = vec2(0.0, 1.268);
const float DIAL_R = 0.058;
const float HAND = -0.42;

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

// 鉄の帯で締めた松の角材
void pine_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float u = clamp(lx / POST_HALF, -1.0, 1.0);
	vec3 n = normalize(vec3(smoothstep(0.6, 1.0, abs(u)) * sign(u) * 0.8, 0.0, 0.75));
	float fine = smoothstep(0.03, 0.012, f.px);
	vec3 c = shade_mat(PINE, n, 0.0, 0.4, f.ao);
	c *= 0.90 + 0.16 * vnoise(vec2(lx * 90.0, f.p.y * 6.0)) * fine;
	part(acc, d, ink_of(PINE), c, f.ow, f.px);
	for (int k = 0; k < 3; k++) {
		float y = 0.26 + 0.28 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(POST_HALF + 0.006, 0.016), IRON, 1.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.030), IRON, 1.0);
}

void crate_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, PINE * 0.92, 0.0, 0.4);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	for (int k = 0; k < 2; k++) {
		float x = k == 0 ? -0.71 : 0.71;
		inlay(acc, d, ink_of(PINE), cov(abs(q.x - x) - 0.004, f.px), f);
	}
	fuse_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.765 : 0.765, cy), 0.022, IRON, 1.0);
	}
}

// 三本の発破筒と、束ねる黒い帯
void sticks(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > STICK_GAP + STICK_HALF + 0.03 || q.y < STICK_BOTTOM - 0.02 || q.y > STICK_TOP + 0.05) {
		return;
	}
	float mid = (STICK_BOTTOM + STICK_TOP) * 0.5;
	float half_h = (STICK_TOP - STICK_BOTTOM) * 0.5;
	for (int k = 0; k < 3; k++) {
		float cx = STICK_GAP * float(k - 1);
		float lift = k == 1 ? 0.0 : -0.010;
		vec2 sq = q - vec2(cx, mid + lift);
		float d = sd_round_box(sq, vec2(STICK_HALF, half_h), 0.010);
		float u = clamp(sq.x / STICK_HALF, -1.0, 1.0);
		vec3 n = lathe_normal(u, 0.0);
		vec3 c = shade_mat(DYNAMITE, n, 0.0, 0.7, 1.0);
		c = mix(c, shade_mat(PAPER_END, n, 0.0, 0.5, 1.0), step(half_h - 0.014, sq.y));
		part(acc, d, ink_of(DYNAMITE), c, f.ow, f.px);
		// 上の端から伸びる短い導火線
		vec2 top = vec2(cx, mid + lift + half_h);
		float d_fuse = sd_segment(q, top, top + vec2(0.012 * float(k - 1), 0.030)) - 0.006;
		part(acc, d_fuse, ink_of(HEMP), HEMP, f.ow * 0.6, f.px);
	}
	for (int k = 0; k < 2; k++) {
		float y = mid + (k == 0 ? -0.046 : 0.050);
		vec2 bq = q - vec2(0.0, y);
		float d_strap = sd_round_box(bq, vec2(STICK_GAP + STICK_HALF + 0.006, 0.011), 0.008);
		vec3 n = normalize(vec3(clamp(bq.x / 0.12, -1.0, 1.0) * 0.4, clamp(bq.y / 0.011, -1.0, 1.0) * 0.5, 0.75));
		part(acc, d_strap, vec3(0.02), shade_mat(STRAP, n, 0.0, 1.0, 1.0), f.ow * 0.8, f.px);
	}
}

// 正面の真鍮の時計
void timer(inout vec4 acc, Px f) {
	vec2 q = f.p - DIAL_C;
	if (length(q) > DIAL_R + 0.03) {
		return;
	}
	vec3 bn = normalize(vec3(q / DIAL_R * 0.7, 0.7));
	part(acc, length(q) - DIAL_R, ink_of(BRASS), shade_mat(BRASS, bn, 1.0, 1.0, 1.0), f.ow, f.px);
	float r_face = DIAL_R - 0.011;
	over(acc, DIAL * (0.92 + 0.08 * clamp(q.y / r_face + 0.5, 0.0, 1.0)), cov(length(q) - r_face, f.px));
	float a = atan(q.x, q.y);
	float tick = abs(fract(a / 6.2832 * 12.0 + 0.5) - 0.5);
	float ring = abs(length(q) - r_face + 0.009) - 0.005;
	over(acc, STRAP, cov(max(ring, tick * 0.06 - 0.0035), f.px));
	vec2 hand_dir = vec2(sin(HAND), cos(HAND));
	float d_hand = sd_segment(q, vec2(0.0), hand_dir * r_face * 0.82) - 0.0045;
	over(acc, DYNAMITE * 0.9, cov(d_hand, f.px));
	float d_short = sd_segment(q, vec2(0.0), vec2(sin(HAND * 0.1), cos(HAND * 0.1)) * r_face * 0.5) - 0.005;
	over(acc, STRAP, cov(d_short, f.px));
	over(acc, STRAP, cov(length(q) - 0.007, f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.6, f.p.y - 1.27);
	add_light(acc, DYNAMITE, exp(-dot(d, d) / 0.012) * 0.35 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	pine_post(acc, f, -POST_X);
	pine_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	crate_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		sticks(acc, f);
		timer(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
