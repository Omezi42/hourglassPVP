shader_type canvas_item;
// 夜明け(ドーン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は朝焼けの色の帯が螺旋に巻く金の柱、板は金に朝空の七宝と真鍮の音の輪。天板の上の風見の矢に金の雄鶏が胸を張り、背の後光が一度に開く。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.94, 0.74, 0.36);
const vec3 SKY = vec3(0.62, 0.82, 0.98);
const vec3 SKY_DEEP = vec3(0.30, 0.48, 0.82);
const vec3 DAYBREAK = vec3(1.0, 0.76, 0.52);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec3 GILT = vec3(0.98, 0.80, 0.40);
const vec3 ROSE = vec3(0.98, 0.52, 0.56);
const vec3 COMB = vec3(0.88, 0.16, 0.14);
const float POST_R = 0.058;
const float ARROW_Y = 1.228;
const vec2 BODY_C = vec2(-0.01, 1.280);

// 早鐘の刻の印: 板に嵌めた朝空の七宝。中央の鐘の口から左右へ、真鍮の音の輪が広がる
void toll_band(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.07) {
		return;
	}
	float strip = sd_round_box(q, vec2(0.68, 0.044), 0.038);
	vec3 sky = mix(SKY_DEEP, SKY, smoothstep(-0.05, 0.05, q.y));
	sky = mix(sky, DAYBREAK, exp(-q.x * q.x / 0.03) * smoothstep(0.05, -0.04, q.y) * 0.9);
	inlay(acc, d, ink_of(BRASS), cov(strip - 0.013, f.px), f);
	inlay(acc, d, BRASS, cov(strip - 0.008, f.px), f);
	inlay(acc, d, sky, cov(strip, f.px), f);
	float inside = cov(strip + 0.003, f.px);
	for (int k = 0; k < 4; k++) {
		float j = float(k) / 3.0;
		float dr = abs(length(vec2(q.x, q.y * 4.0)) - 0.17 - 0.14 * float(k)) - mix(0.015, 0.010, j);
		inlay(acc, d, mix(BRASS * 1.15, BRASS, j), cov(dr, f.px) * inside, f);
	}
	vec2 b = q - vec2(0.0, -0.040);
	float d_dome = max(length(b) - 0.066, -b.y);
	inlay(acc, d, ink_of(BRASS), cov(d_dome - 0.010, f.px), f);
	vec3 n = normalize(vec3(b / 0.066 * 0.6, 0.75));
	inlay(acc, d, shade_mat(BRASS, n, 1.0, 1.0, 1.0), cov(d_dome, f.px), f);
}

void dawn_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	part(acc, d, ink_of(GILT), shade_mat(GILT, n, 1.0, 1.0, f.ao), f.ow, f.px);
	float s = fract((f.p.y - asin(u) * POST_R * 1.2) * 3.6);
	float band = smoothstep(0.0, 0.04, s) * smoothstep(0.42, 0.38, s) * cov(d, f.px);
	vec3 c = mix(ROSE, DAYBREAK, smoothstep(0.05, 0.22, s));
	c = mix(c, SKY, smoothstep(0.24, 0.38, s));
	over(acc, shade_mat(c, n, 0.0, 1.0, f.ao), band);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.032), GILT, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.076, 0.022), GILT, 1.0);
}

void gilt_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, GILT, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	toll_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.026, ROSE, 0.3);
	}
}

// 風見の矢: 右へ鏃、左へ矢羽。中央の支柱
void vane_arrow(inout vec4 acc, Px f) {
	vec3 c = shade_mat(GILT, normalize(vec3(0.0, 0.4, 0.8)), 1.0, 1.0, 1.0);
	float d_post = max(abs(f.p.x) - 0.012, max(PLATE_Y - f.p.y, f.p.y - ARROW_Y));
	part(acc, d_post, ink_of(GILT), c, f.ow, f.px);
	vec2 q = f.p - vec2(0.0, ARROW_Y);
	float d = sd_round_box(q, vec2(0.30, 0.008), 0.006);
	vec2 h = q - vec2(0.30, 0.0);
	d = min(d, max(abs(h.y) - (0.040 - h.x) * 0.75, max(-h.x - 0.004, h.x - 0.040)) );
	vec2 t = q - vec2(-0.30, 0.0);
	float fletch = max(abs(t.y - t.x * 0.6 * sign(t.y)) - 0.008, max(-t.x, t.x - 0.07)) ;
	fletch = max(min(fletch, max(abs(abs(t.y) - 0.022 - (t.x - 0.035) * 0.5) - 0.008, abs(t.x - 0.035) - 0.035)), abs(t.y) - 0.040);
	d = min(d, fletch);
	part(acc, d, ink_of(GILT), c, f.ow, f.px);
}

// 金の雄鶏: 胸を張った胴、反った3枚の尾羽、首と頭、赤いとさか
void rooster(inout vec4 acc, Px f) {
	vec2 q = f.p - BODY_C;
	if (abs(q.x + 0.04) > 0.22 || q.y < -0.07 || q.y > 0.11) {
		return;
	}
	for (int k = -1; k <= 1; k += 2) {
		vec2 a = BODY_C + vec2(float(k) * 0.020 - 0.005, -0.040);
		part(acc, sd_segment(f.p, a, vec2(a.x, ARROW_Y + 0.004)) - 0.007, ink_of(GILT), GILT * 0.8, f.ow * 0.7, f.px);
	}
	float d_tail = 1.0;
	for (int k = 0; k < 3; k++) {
		float j = float(k);
		vec2 base = vec2(-0.060, 0.012);
		vec2 tip = vec2(-0.150 - 0.020 * j, 0.078 - 0.040 * j);
		vec2 ba = tip - base;
		float t = clamp(dot(q - base, ba) / dot(ba, ba), 0.0, 1.0);
		vec2 bend = vec2(0.010, 0.022) * sin(t * 3.1416);
		d_tail = min(d_tail, length(q - base - ba * t - bend) - mix(0.026, 0.006, t));
	}
	part(acc, d_tail, ink_of(GILT), mix(GILT, ROSE, 0.35), f.ow, f.px);
	vec2 bq = rot(q, -0.25);
	float d_body = length(bq / vec2(0.080, 0.050)) - 1.0;
	d_body *= 0.050;
	vec2 hq = q - vec2(0.070, 0.050);
	float d_neck = sd_segment(q, vec2(0.040, 0.010), vec2(0.066, 0.044)) - 0.026;
	float d_head = length(hq) - 0.026;
	float d = min(min(d_body, d_neck), d_head);
	vec3 n = normalize(vec3(clamp(q.x / 0.09, -1.0, 1.0) * 0.4, q.y / 0.06 * 0.5, 0.75));
	vec3 c = shade_mat(GILT, n, 1.0, 1.0, 1.0);
	float wing = cov(length((rot(q, -0.25) - vec2(-0.012, -0.004)) / vec2(0.046, 0.026)) - 1.0, 0.02);
	c = mix(c, mix(c, ROSE, 0.45), wing);
	part(acc, d, ink_of(GILT), c, f.ow, f.px);
	float d_comb = 1.0;
	for (int k = 0; k < 3; k++) {
		d_comb = min(d_comb, length(hq - vec2(-0.016 + 0.015 * float(k), 0.026 - 0.003 * float(k))) - 0.012);
	}
	part(acc, d_comb, ink_of(COMB), COMB, f.ow * 0.8, f.px);
	part(acc, length(hq - vec2(0.010, -0.030)) - 0.010, ink_of(COMB), COMB, f.ow * 0.8, f.px);
	vec2 bk = hq - vec2(0.026, -0.004);
	float d_beak = max(abs(bk.y) - (0.026 - bk.x) * 0.45, max(-bk.x, bk.x - 0.026));
	part(acc, d_beak, ink_of(GILT), DAYBREAK, f.ow * 0.8, f.px);
	over(acc, vec3(0.1), cov(length(hq - vec2(0.008, 0.006)) - 0.005, f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - vec2(0.0, 1.28);
	float ang = atan(d.x, d.y);
	float rays = 0.55 + 0.45 * smoothstep(0.3, 0.7, abs(fract(ang * 2.8648) - 0.5) * 2.0);
	float fall = exp(-dot(d * vec2(0.55, 1.0), d * vec2(0.55, 1.0)) / 0.03);
	add_light(acc, mix(DAYBREAK, ROSE, 0.25), fall * rays * 0.9 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	dawn_post(acc, f, -POST_X);
	dawn_post(acc, f, POST_X);
	draw_collars(acc, f, GILT, 1.0);
	gilt_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y && abs(f.p.x) < 0.40) {
		vane_arrow(acc, f);
		rooster(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
