shader_type canvas_item;
// スキン「裁きの槌」(ハンマー)。GameDesign.md 31章 / Architecture.md 10.19節。

#define SKIN_SAND_COLOR vec3(0.88, 0.25, 0.25)
#define SKIN_SAND_KIND 0
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_parts.gdshaderinc"

const vec3 WALNUT = vec3(0.44, 0.26, 0.15);
const vec3 WALNUT_DARK = vec3(0.30, 0.17, 0.10);
const vec3 BRASS = vec3(0.86, 0.66, 0.32);
const float TURNED_POST_X = 0.68;
// 天秤
const vec2 SCALE_PIVOT = vec2(0.0, 1.322);
const float BEAM_HALF = 0.30;
const float PAN_DROP = 0.112;
// 槌(右の柱の根元の手前に頭を置き、柄は柱に沿って立つ)
const vec2 GAVEL_HEAD = vec2(0.785, -0.918);
const vec2 GAVEL_HEAD_HALF = vec2(0.188, 0.100);
const vec2 GAVEL_GRIP = vec2(0.900, 0.20);
const vec2 STRIKE_C = vec2(0.785, -1.02);
// 槌を打つ間隔の速さ(1秒あたりの回数)
const float STRIKE_RATE = 0.42;
const float STRIKE_AT = 0.68;

// 槌の持ち上がり(0〜1)。ゆっくり上げて、速く打ち下ろす。砂が落ちていないときは台に置いたまま。
float gavel_lift() {
	float ph = fract(clock * STRIKE_RATE);
	float up = smoothstep(0.05, 0.58, ph) * (1.0 - smoothstep(0.60, STRIKE_AT, ph));
	return up * flow;
}

// 最後に打ってからの秒数
float since_strike() {
	float ph = fract(clock * STRIKE_RATE - STRIKE_AT);
	return ph / STRIKE_RATE;
}

// 天秤の傾き(左の皿が下がる向きが正)。上の砂が多いほど左、下の砂が多いほど右へ傾く。打った直後は揺れる。
float beam_tilt() {
	float bal = clamp((sand_top - sand_bottom) / 0.85, -1.0, 1.0) * 0.20;
	float s = since_strike();
	float wobble = 0.07 * flow * exp(-s * 2.2) * sin(s * 13.0);
	return bal + 0.012 * sin(clock * 1.1) + wobble;
}

vec3 wood_shade(vec3 base, vec3 n, vec2 grain_p, float px) {
	float g = vnoise(grain_p);
	float fine = smoothstep(0.03, 0.012, px);
	vec3 c = shade_mat(base * mix(1.0, 0.82 + 0.30 * g, fine), n, 0.0, 0.55, 1.0);
	return c;
}

// ろくろで挽いた木の柱(中ほどと上下に膨らみ)
void draw_turned_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > 1.02 + f.pad) {
		return;
	}
	float ay = f.ay;
	float r = 0.040 + 0.030 * exp(-pow(ay / 0.10, 2.0)) + 0.024 * exp(-pow((ay - 0.62) / 0.09, 2.0))
			+ 0.016 * exp(-pow((ay - 0.86) / 0.035, 2.0));
	float dr = (0.040 + 0.030 * exp(-pow((ay + 0.004) / 0.10, 2.0)) + 0.024 * exp(-pow((ay + 0.004 - 0.62) / 0.09, 2.0))
			+ 0.016 * exp(-pow((ay + 0.004 - 0.86) / 0.035, 2.0)) - r) / 0.004;
	float d = max((abs(lx) - r) / sqrt(1.0 + dr * dr), ay - 1.02);
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), dr * f.side);
	vec3 c = wood_shade(WALNUT, n, vec2(lx * 60.0, f.p.y * 5.0), f.px) * f.ao;
	part(acc, d, ink_of(WALNUT_DARK), c, f.ow, f.px);
}

void draw_scales(inout vec4 acc, Px f) {
	vec2 q = f.p - SCALE_PIVOT;
	if (abs(q.x) > 0.44 || q.y < -0.20 || q.y > 0.09) {
		return;
	}
	vec3 brass_ink = ink_of(BRASS);
	float rod_w = max(0.014, f.px * 0.6);
	// 支柱と頭の玉
	float d_post = sd_round_box(q - vec2(0.0, -0.075), vec2(rod_w, 0.085), 0.006);
	part(acc, d_post, brass_ink, shade_mat(BRASS, lathe_normal(clamp(q.x / rod_w, -1.0, 1.0), 0.0), 1.0, 1.0, 1.0), f.ow, f.px);
	float d_foot = sd_round_box(q - vec2(0.0, -0.140), vec2(0.060, 0.018), 0.010);
	part(acc, d_foot, brass_ink, shade_mat(BRASS, normalize(vec3(q.x * 4.0, 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	float tilt = beam_tilt();
	// 竿
	vec2 bq = rot(q, -tilt);
	float d_beam = sd_round_box(bq, vec2(BEAM_HALF, rod_w), 0.008);
	part(acc, d_beam, brass_ink, shade_mat(BRASS, normalize(vec3(0.0, bq.y / rod_w * 0.6, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	draw_ball(acc, f, SCALE_PIVOT + vec2(0.0, 0.038), 0.026, BRASS, 1.0);
	// 皿は竿の両端から真下へ吊る
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		vec2 end = rot(vec2(sx * BEAM_HALF, 0.0), tilt);
		vec2 pq = q - end;
		float d_str = min(sd_segment(pq, vec2(0.0), vec2(-0.080, -PAN_DROP)), sd_segment(pq, vec2(0.0), vec2(0.080, -PAN_DROP)));
		over(acc, brass_ink, cov(d_str - max(0.004, f.px * 0.35), f.px));
		vec2 dq = pq - vec2(0.0, -PAN_DROP);
		float d_pan = max(sd_ellipse(dq, vec2(0.105, 0.048)), dq.y - 0.004);
		vec3 n = normalize(vec3(dq.x / 0.105 * 0.6, -0.4, 0.75));
		part(acc, d_pan, brass_ink, shade_mat(BRASS, n, 1.0, 1.0, 1.0), f.ow, f.px);
		draw_ball(acc, f, SCALE_PIVOT + end, 0.014, BRASS, 1.0);
	}
}

void draw_gavel(inout vec4 acc, Px f) {
	float lift = gavel_lift();
	// 持ち上げると柄の先を軸に起き上がる
	vec2 off = vec2(0.0, 0.10 * lift);
	vec2 q = rot(f.p - GAVEL_GRIP - off, 0.16 * lift) + GAVEL_GRIP;
	if (q.x < 0.54 || q.y < -1.06 || q.y > 0.29) {
		return;
	}
	// 柄
	float d_handle = sd_segment(q, GAVEL_HEAD, GAVEL_GRIP) - 0.034;
	vec2 hd = normalize(GAVEL_GRIP - GAVEL_HEAD);
	float hu = clamp((hd.x * (q.y - GAVEL_HEAD.y) - hd.y * (q.x - GAVEL_HEAD.x)) / 0.034, -1.0, 1.0);
	float along = dot(q - GAVEL_HEAD, hd);
	vec3 handle = wood_shade(WALNUT, lathe_normal(-hu, 0.0), vec2(hu * 3.0, along * 20.0), f.px);
	float ring = step(abs(along - 0.86), 0.016);
	handle = mix(handle, shade_mat(BRASS, lathe_normal(-hu, 0.0), 1.0, 1.0, 1.0), ring);
	part(acc, d_handle, ink_of(WALNUT_DARK), handle, f.ow, f.px);
	// 柄頭
	vec2 kq = q - GAVEL_GRIP - hd * 0.022;
	float d_knob = length(kq) - 0.048;
	part(acc, d_knob, ink_of(WALNUT_DARK), wood_shade(WALNUT, normalize(vec3(kq / 0.04 * 0.8, 0.6)), kq * 30.0, f.px), f.ow, f.px);
	// 頭: 両端が太い樽。真鍮の帯を2本ずつ巻く
	vec2 g = q - GAVEL_HEAD;
	float bulge = 1.0 - 0.16 * pow(1.0 - abs(g.x) / GAVEL_HEAD_HALF.x, 2.0);
	float d_head = sd_round_box(g, vec2(GAVEL_HEAD_HALF.x, GAVEL_HEAD_HALF.y * bulge), 0.020);
	if (d_head < f.ow + f.px) {
		float v = clamp(g.y / (GAVEL_HEAD_HALF.y * bulge), -1.0, 1.0);
		float end_round = smoothstep(GAVEL_HEAD_HALF.x - 0.03, GAVEL_HEAD_HALF.x, abs(g.x)) * sign(g.x);
		vec3 n = normalize(vec3(end_round * 0.8, v * 0.9, sqrt(max(1.0 - v * v, 0.0)) * 0.9 + 0.1));
		vec3 c = wood_shade(WALNUT, n, vec2(g.x * 6.0, g.y * 70.0), f.px);
		float ax = abs(g.x);
		float band = step(0.114, ax) * step(ax, 0.132) + step(0.146, ax) * step(ax, 0.160);
		c = mix(c, shade_mat(BRASS, n, 1.0, 1.0, 1.0), band);
		part(acc, d_head, ink_of(WALNUT_DARK), c, f.ow, f.px);
	}
}

// 打った瞬間に台から光の輪が広がる
void strike_flash(inout vec4 acc, Px f) {
	float s = since_strike();
	if (flow <= 0.0 || s > 0.6) {
		return;
	}
	vec2 q = (f.p - STRIKE_C) * vec2(1.0, 2.0);
	float r = 0.06 + s * 0.55;
	float ring = 1.0 - smoothstep(0.0, max(0.014, f.px), abs(length(q) - r) - 0.006);
	float fade = (1.0 - s / 0.6) * step(-0.01, f.p.y - STRIKE_C.y);
	add_light(acc, vec3(1.0, 0.86, 0.55), ring * fade * 0.8 * flow * canvas_window(f.p));
}

void skin_back(inout vec4 acc, Px f) {
}

void skin_frame(inout vec4 acc, Px f) {
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -TURNED_POST_X : TURNED_POST_X;
		draw_turned_post(acc, f, cx);
		draw_band(acc, f, vec2(cx, f.side * 0.960), vec2(0.084, 0.034), WALNUT, 0.0);
		draw_band(acc, f, vec2(cx, 0.0), vec2(0.080, 0.016), BRASS, 1.0);
	}
	draw_collars(acc, f, BRASS, 1.0);
	float half_w = 0.84;
	float d = draw_slab(acc, f, f.side * 1.098, vec2(half_w, 0.082), 0.03, WALNUT, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	// 板の彫り: 二重の細い溝と、真鍮の縁
	// 板の彫り: 唐草の溝(中央の飾りの左右)
	float vine = 0.022 * sin(abs(q.x) * 34.0) * smoothstep(0.10, 0.16, abs(q.x));
	float groove = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(q.y - vine) - 0.005);
	float curl = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(length(vec2(mod(abs(q.x) + 0.046, 0.185) - 0.092, q.y + sign(sin(abs(q.x) * 34.0)) * 0.012)) - 0.020) - 0.004);
	float carve = max(groove, curl * 0.8) * step(abs(q.x), half_w - 0.07) * step(0.12, abs(q.x));
	inlay(acc, d, WALNUT_DARK * 0.62, carve, f);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.064) - 0.004);
	inlay(acc, d, BRASS, rim * step(abs(q.x), half_w - 0.04), f);
	if (f.p.y > 0.0) {
		draw_scales(acc, f);
	} else {
		// 底板の中央: 真鍮の月桂冠
		vec2 wq = f.p - vec2(0.0, -1.098);
		float ang = atan(wq.x, wq.y);
		float leaves = 0.0;
		if (abs(ang) > 0.55 && abs(ang) < 2.75) {
			float a0 = (floor(ang / 0.42) + 0.5) * 0.42;
			vec2 lc = vec2(sin(a0), cos(a0)) * 0.060;
			vec2 lq = rot(wq - lc, a0 + 0.45 * sign(ang));
			leaves = cov(sd_ellipse(lq, vec2(0.026, 0.012)), f.px);
		}
		inlay(acc, d, BRASS, leaves, f);
		inlay(acc, d, BRASS * 0.9, cov(length(wq) - 0.016, f.px), f);
		strike_flash(acc, f);
	}
	draw_gavel(acc, f);
}

#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_main.gdshaderinc"
