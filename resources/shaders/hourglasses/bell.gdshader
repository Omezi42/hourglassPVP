shader_type canvas_item;
// 早鐘(ベル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は朝空の七宝の輪を嵌めた細い真鍮の棒、板は胡桃の木に朝空の七宝と真鍮の音の輪。天板の上で、木の柄の手振りの鈴が振れて鳴る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRASS = vec3(0.94, 0.74, 0.36);
const vec3 SKY = vec3(0.62, 0.82, 0.98);
const vec3 SKY_DEEP = vec3(0.30, 0.48, 0.82);
const vec3 DAYBREAK = vec3(1.0, 0.76, 0.52);
const vec3 WALNUT = vec3(0.50, 0.32, 0.20);
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float POST_R = 0.046;
// 鈴の冠の位置・傾き・高さ・口の半幅
const vec2 CROWN = vec2(-0.01, 1.336);
const float SWING = 0.30;
const float BELL_H = 0.136;
const float BELL_MOUTH = 0.106;

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

// 鐘の形。q は冠の上からの位置(下が負)。t は冠(0)から口(1)まで
float bell_sd(vec2 q, float h, float m, out float t) {
	t = clamp(-q.y / h, 0.0, 1.0);
	float hw = mix(m * 0.40, m * 0.68, smoothstep(0.0, 0.35, t));
	hw = mix(hw, m, smoothstep(0.62, 1.0, t));
	float d_body = max(abs(q.x) - hw, max(q.y + h * 0.12, -h - q.y));
	float d_crown = max(length(q - vec2(0.0, -h * 0.17)) - m * 0.42, -h * 0.17 - q.y);
	return min(d_body, d_crown);
}

void enamel_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, BRASS, 1.0);
	for (int k = 0; k < 3; k++) {
		float y = 0.26 + 0.24 * float(k);
		draw_band(acc, f, vec2(cx, f.side * y), vec2(0.062, 0.020), SKY, 0.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.030), BRASS, 1.0);
}

void walnut_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, WALNUT, 0.0, 0.7);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	toll_band(acc, f, d, q);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.024, BRASS, 1.0);
	}
}

// 手振りの鈴: 胴に朝空の帯、木の柄と握りの玉。傾いて鳴る
void hand_bell(inout vec4 acc, Px f) {
	vec2 q = rot(f.p - CROWN, -SWING);
	if (abs(q.x) > BELL_MOUTH + 0.04 || q.y > 0.09 || q.y < -BELL_H - 0.04) {
		return;
	}
	// 柄と握り
	float d_handle = sd_segment(q, vec2(0.0, -0.005), vec2(0.0, 0.024)) - 0.016;
	vec3 hn = normalize(vec3(clamp(q.x / 0.015, -1.0, 1.0) * 0.8, 0.0, 0.6));
	part(acc, d_handle, ink_of(WALNUT), shade_mat(WALNUT * 1.2, hn, 0.0, 0.8, 1.0), f.ow, f.px);
	vec2 kq = q - vec2(0.0, 0.032);
	vec3 kn = normalize(vec3(kq / 0.022 * 0.7, 0.7));
	part(acc, length(kq) - 0.022, ink_of(WALNUT), shade_mat(WALNUT * 1.25, kn, 0.0, 1.0, 1.0), f.ow, f.px);
	float t;
	float d = bell_sd(q, BELL_H, BELL_MOUTH, t);
	vec3 n = normalize(vec3(clamp(q.x / (BELL_MOUTH * 0.8), -1.0, 1.0) * 0.75, 0.15, 0.65));
	vec3 c = shade_mat(BRASS, n, 1.0, 1.0, 1.0);
	float band = cov(abs(t - 0.56) - 0.07, f.px / BELL_H);
	c = mix(c, shade_mat(SKY, n, 0.0, 1.0, 1.0), band);
	part(acc, d, ink_of(BRASS), c, f.ow, f.px);
	vec2 mq = q - vec2(0.0, -BELL_H);
	float d_lip = sd_round_box(mq, vec2(BELL_MOUTH + 0.006, 0.011), 0.009);
	vec3 ln = normalize(vec3(mq.x / BELL_MOUTH * 0.6, 0.2, 0.75));
	part(acc, d_lip, ink_of(BRASS), shade_mat(BRASS * 1.1, ln, 1.0, 1.0, 1.0), f.ow, f.px);
	// 口の奥で振れる舌
	vec2 cq = q - vec2(0.030, -BELL_H - 0.012);
	part(acc, length(cq) - 0.016, ink_of(BRASS), shade_mat(BRASS * 0.8, normalize(vec3(cq / 0.016 * 0.6, 0.7)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
}

// 鈴の左右へ広がる音の弧
void ring_arcs(inout vec4 acc, Px f) {
	vec2 c = vec2(-0.01, 1.272);
	vec2 q = f.p - c;
	float ang = abs(atan(q.y, abs(q.x)));
	float mask = smoothstep(0.46, 0.30, ang);
	for (int k = 0; k < 3; k++) {
		float r = 0.150 + 0.050 * float(k);
		float dr = abs(length(q) - r) - (0.013 - 0.003 * float(k));
		over(acc, ink_of(BRASS), cov(dr - 0.008, f.px) * mask);
		over(acc, mix(BRASS * 1.15, SKY, 0.3 * float(k)), cov(dr, f.px) * mask);
	}
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.6, f.p.y - 1.27);
	add_light(acc, DAYBREAK, exp(-dot(d, d) / 0.02) * 0.45 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	enamel_post(acc, f, -POST_X);
	enamel_post(acc, f, POST_X);
	draw_collars(acc, f, BRASS, 1.0);
	walnut_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		ring_arcs(acc, f);
		hand_bell(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
