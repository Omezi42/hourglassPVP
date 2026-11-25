shader_type canvas_item;
// 踏みとどまる構え(ホールド)。GameDesign.md 9章 / Architecture.md 10.19節。
// 縄で縛った丸太の柱と、燠火の筋が走る板。天板の上には丸盾が3枚重なって並び、後ろから槍の穂先がのぞく(盾の壁)。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 LOG = vec3(0.50, 0.36, 0.24);
const vec3 ROPE = vec3(0.80, 0.68, 0.46);
const vec3 IRON = vec3(0.42, 0.44, 0.48);
const vec3 PAINT = vec3(0.30, 0.56, 0.32);
const vec3 BRASS = vec3(0.86, 0.64, 0.30);
const vec3 BONE = vec3(0.90, 0.84, 0.70);
const vec3 EMBER = vec3(1.0, 0.44, 0.14);
const vec3 EMBER_HOT = vec3(1.0, 0.88, 0.56);
const float POST_R = 0.064;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const float SHIELD_Y = 1.205;
const float SHIELD_R = 0.128;
const float SIDE_R = 0.108;
const float SIDE_X = 0.200;

void ember_seam(inout vec4 acc, Px f, float d, vec2 q, float half_x) {
	float line = cov(abs(q.y) - 0.008, f.px) * step(abs(q.x), half_x);
	inlay(acc, d, mix(EMBER, EMBER_HOT, cov(abs(q.y) - 0.003, f.px)), line, f);
}

// 皮を剥いだ丸太。木目の縦筋と、縄の巻き
void log_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	float fine = smoothstep(0.03, 0.012, f.px);
	vec3 n = lathe_normal(u, 0.0);
	vec3 c = shade_mat(LOG, n, 0.0, 0.25, f.ao);
	float grain = vnoise(vec2(asin(u) * 9.0 + cx * 4.0, f.p.y * 3.0));
	c *= mix(1.0, 0.82 + 0.3 * grain, fine);
	part(acc, d, ink_of(LOG), c, f.ow, f.px);
	for (int k = 0; k < 3; k++) {
		float y = (float(k) - 1.0) * 0.62;
		vec2 q = vec2(lx, f.p.y - y);
		if (abs(q.y) > 0.06 + f.pad) {
			continue;
		}
		float d_rope = max(abs(lx) - POST_R - 0.008, abs(q.y) - 0.048);
		float twist = smoothstep(0.0, 0.35, sin(fract((q.y + asin(u) * 0.02) * 34.0) * 3.1416));
		vec3 rc = shade_mat(ROPE, lathe_normal(clamp(lx / (POST_R + 0.008), -1.0, 1.0), 0.0), 0.0, 0.3, f.ao);
		part(acc, d_rope, ink_of(ROPE), rc * mix(0.62, 1.05, twist), f.ow * 0.8, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.094, 0.030), IRON, 1.0);
}

void timber_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, LOG * 0.72, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	ember_seam(acc, f, d, q, 0.72);
	for (int k = 0; k < 2; k++) {
		float x = k == 0 ? -0.74 : 0.74;
		draw_ball(acc, f, vec2(x, cy), 0.022, IRON, 1.0);
	}
}

// 盾の後ろの槍の穂先
void spear(inout vec4 acc, Px f, float x, float top) {
	vec2 q = f.p - vec2(x, top);
	if (abs(q.x) > 0.04 || q.y > 0.01 || q.y < -0.24) {
		return;
	}
	float d_shaft = max(abs(q.x) - 0.010, max(q.y + 0.08, -0.24 - q.y));
	part(acc, d_shaft, ink_of(LOG), LOG * 1.1, f.ow * 0.8, f.px);
	float t = clamp(-q.y / 0.09, 0.0, 1.0);
	float hw = 0.030 * sin(t * 3.1416 * 0.9 + 0.12);
	float d_head = max(abs(q.x) - hw, max(q.y, -0.09 - q.y));
	vec3 n = normalize(vec3(q.x > 0.0 ? 0.5 : -0.3, 0.0, 0.8));
	part(acc, d_head, ink_of(IRON), shade_mat(IRON * 1.5, n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
}

// 丸盾: 塗りを2色に分けた板、鉄の縁、中央の鉄の突起
void round_shield(inout vec4 acc, Px f, vec2 c, float r, float split) {
	vec2 q = f.p - c;
	if (length(q) > r + f.pad) {
		return;
	}
	float d = length(q) - r;
	float half_paint = step(0.0, q.x * cos(split) + q.y * sin(split));
	vec3 face = mix(PAINT, BONE, half_paint);
	vec3 n = normalize(vec3(q / r * 0.45, 0.85));
	face = shade_mat(face, n, 0.0, 0.3, 1.0);
	part(acc, d, ink_of(IRON), face, f.ow, f.px);
	float d_rim = abs(length(q) - r + 0.012) - 0.010;
	over(acc, shade_mat(BRASS, n, 1.0, 1.0, 1.0), cov(d_rim, f.px));
	vec2 bq = q;
	vec3 bn = normalize(vec3(bq / (r * 0.3) * 0.7, 0.7));
	part(acc, length(bq) - r * 0.28, ink_of(BRASS), shade_mat(BRASS, bn, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
}

void shield_wall(inout vec4 acc, Px f) {
	if (abs(f.p.x) > 0.34 || f.p.y < SHIELD_Y - 0.16) {
		return;
	}
	spear(acc, f, -0.290, 1.366);
	spear(acc, f, 0.290, 1.366);
	spear(acc, f, -0.105, 1.372);
	spear(acc, f, 0.105, 1.372);
	round_shield(acc, f, vec2(-SIDE_X, SHIELD_Y - 0.020), SIDE_R, 2.2);
	round_shield(acc, f, vec2(SIDE_X, SHIELD_Y - 0.020), SIDE_R, 0.9);
	round_shield(acc, f, vec2(0.0, SHIELD_Y), SHIELD_R, 1.5708);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - vec2(0.0, SHIELD_Y);
	add_light(acc, EMBER, exp(-dot(d, d) / 0.030) * 0.5 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	log_post(acc, f, -POST_X);
	log_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	timber_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y - 0.05) {
		shield_wall(acc, f);
	} else if (f.p.y < 0.0) {
		round_shield(acc, f, vec2(0.0, -PLATE_Y), 0.060, 1.5708);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
