shader_type canvas_item;
// 最後の一刻(ラストアワー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 刻み目を打った黒鉄の柱と、燠火の筋が走る板。天板の上の鉄の鐘架に大きな青銅の鐘が吊られ、口の奥が赤く灯る。
// 底板の中央の文字盤は、針が12時の一歩手前を指す。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 IRON = vec3(0.26, 0.26, 0.30);
const vec3 BRONZE = vec3(0.80, 0.56, 0.30);
const vec3 DIAL = vec3(0.95, 0.90, 0.78);
const vec3 EMBER = vec3(1.0, 0.44, 0.14);
const vec3 EMBER_HOT = vec3(1.0, 0.88, 0.56);
const float POST_HALF = 0.058;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
// 鐘架の脚の足元・頂、鐘の吊り点・高さ・口の半幅
const float YOKE_Y0 = 1.100;
const float YOKE_TOP = 1.358;
const float YOKE_HALF = 0.255;
const vec2 HANG = vec2(0.0, 1.338);
const float BELL_H = 0.215;
const float BELL_MOUTH = 0.165;

void ember_seam(inout vec4 acc, Px f, float d, vec2 q, float half_x) {
	float line = cov(abs(q.y) - 0.008, f.px) * step(abs(q.x), half_x);
	inlay(acc, d, mix(EMBER, EMBER_HOT, cov(abs(q.y) - 0.003, f.px)), line, f);
}

// 時の刻み目を打った角柱
void notched_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.65 ? 0.6 : (face < -0.65 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(IRON, n, 1.0, 0.7, f.ao);
	float k = floor(f.p.y / 0.085 + 0.5);
	float major = mod(k, 3.0) < 0.5 ? 1.0 : 0.0;
	float ty = f.p.y - k * 0.085;
	float tick_w = mix(0.018, 0.034, major);
	float d_tick = max(abs(ty) - 0.006, abs(lx) - tick_w);
	c = mix(c, BRONZE * 1.1, cov(d_tick, f.px) * step(f.ay, POST_H - 0.07));
	part(acc, d, vec3(0.05), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.030), BRONZE, 1.0);
}

void iron_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, IRON, 1.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	ember_seam(acc, f, d, q, 0.72);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.74 : 0.74, cy), 0.022, BRONZE, 1.0);
	}
}

// 鐘架: 2本の脚と、上の梁
void yoke(inout vec4 acc, Px f) {
	vec3 col = shade_mat(IRON * 1.3, normalize(vec3(0.0, 0.3, 0.9)), 1.0, 0.8, 1.0);
	for (int k = -1; k <= 1; k += 2) {
		float x = float(k) * YOKE_HALF;
		float d_leg = sd_segment(f.p, vec2(x * 1.08, YOKE_Y0), vec2(x * 0.92, YOKE_TOP - 0.01)) - 0.017;
		part(acc, d_leg, vec3(0.05), col, f.ow, f.px);
	}
	vec2 tq = f.p - vec2(0.0, YOKE_TOP);
	float d_top = sd_round_box(tq, vec2(YOKE_HALF + 0.040, 0.016), 0.012);
	// 梁の両端を少し反らせる
	d_top = min(d_top, sd_round_box(vec2(abs(tq.x) - YOKE_HALF - 0.040, tq.y - 0.010), vec2(0.016, 0.012), 0.008));
	part(acc, d_top, vec3(0.05), col, f.ow, f.px);
}

// 吊られた鐘: 肩の丸い胴、広がる裾、厚い口の縁。口の奥が赤く灯る
void bell(inout vec4 acc, Px f) {
	vec2 q = f.p - HANG;
	if (abs(q.x) > BELL_MOUTH + 0.03 || q.y > 0.03 || q.y < -BELL_H - 0.04) {
		return;
	}
	float t = clamp(-q.y / BELL_H, 0.0, 1.0);
	float hw = mix(0.062, BELL_MOUTH * 0.70, smoothstep(0.0, 0.35, t));
	hw = mix(hw, BELL_MOUTH, smoothstep(0.62, 1.0, t));
	float d_body = max(abs(q.x) - hw, max(q.y + 0.018, -BELL_H - q.y));
	float d_crown = length(q - vec2(0.0, -0.030)) - 0.068;
	d_crown = max(d_crown, -0.030 - q.y);
	float d = min(d_body, d_crown);
	vec3 n = normalize(vec3(clamp(q.x / max(hw, 0.01), -1.0, 1.0) * 0.75, 0.15, 0.65));
	vec3 c = shade_mat(BRONZE, n, 1.0, 1.0, 1.0);
	// 胴の帯(2本の細い筋)
	float band = cov(abs(t - 0.52) - 0.018, f.px / BELL_H) + cov(abs(t - 0.62) - 0.010, f.px / BELL_H);
	c = mix(c, c * 0.6, clamp(band, 0.0, 1.0) * 0.7);
	part(acc, d, ink_of(BRONZE), c, f.ow, f.px);
	// 口の縁と、その奥の赤い光
	vec2 mq = q - vec2(0.0, -BELL_H);
	float d_lip = sd_round_box(mq, vec2(BELL_MOUTH + 0.008, 0.014), 0.012);
	part(acc, d_lip, ink_of(BRONZE), shade_mat(BRONZE * 1.1, normalize(vec3(mq.x / BELL_MOUTH * 0.6, 0.2, 0.75)), 1.0, 1.0, 1.0), f.ow, f.px);
	float d_mouth = sd_ellipse(mq - vec2(0.0, 0.004), vec2(BELL_MOUTH * 0.82, 0.008));
	over(acc, mix(EMBER, EMBER_HOT, 0.4), cov(d_mouth, f.px));
	// 吊り金具
	float d_hook = abs(length(q - vec2(0.0, 0.006)) - 0.016) - 0.006;
	part(acc, d_hook, vec3(0.05), IRON * 1.6, f.ow * 0.6, f.px);
}

// 底板の文字盤(針は12時の一歩手前)
void last_dial(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, -PLATE_Y);
	if (length(q) > 0.08) {
		return;
	}
	part(acc, length(q) - 0.066, ink_of(BRONZE), shade_mat(BRONZE, normalize(vec3(q / 0.066 * 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	over(acc, DIAL, cov(length(q) - 0.050, f.px));
	for (int k = 0; k < 4; k++) {
		vec2 dir = vec2(sin(float(k) * 1.5708), cos(float(k) * 1.5708));
		over(acc, vec3(0.2), cov(sd_segment(q, dir * 0.036, dir * 0.046) - 0.004, f.px));
	}
	vec2 minute = vec2(sin(-0.10), cos(-0.10)) * 0.042;
	vec2 hour = vec2(sin(-0.04), cos(-0.04)) * 0.028;
	over(acc, vec3(0.12), cov(sd_segment(q, vec2(0.0), minute) - 0.004, f.px));
	over(acc, vec3(0.12), cov(sd_segment(q, vec2(0.0), hour) - 0.006, f.px));
	over(acc, EMBER, cov(length(q) - 0.008, f.px));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - HANG - vec2(0.0, -BELL_H);
	add_light(acc, EMBER, exp(-dot(d, d) / 0.020) * 0.7 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	notched_post(acc, f, -POST_X);
	notched_post(acc, f, POST_X);
	draw_collars(acc, f, IRON * 1.3, 1.0);
	iron_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > YOKE_Y0 - 0.03) {
		if (abs(f.p.x) < YOKE_HALF + 0.08) {
			yoke(acc, f);
			bell(acc, f);
		}
	} else if (f.p.y < 0.0) {
		last_dial(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
