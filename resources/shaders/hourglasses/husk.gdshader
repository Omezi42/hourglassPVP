shader_type canvas_item;
// 空の莢(ハスク)。GameDesign.md 9章 / Architecture.md 10.19節。
// 乾いて筋の浮いた莢の柱と板。天板の上に、割れて空になった種の莢がひとつ口を開けている。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PAPER = vec3(0.74, 0.76, 0.66);
const vec3 PAPER_DARK = vec3(0.42, 0.46, 0.40);
const float POD_POST_R = 0.060;
const vec2 SLAB_HALF = vec2(0.80, 0.084);
const float POD_Y = 1.255;

// 縦の筋の浮いた乾いた殻の色
vec3 husk_color(vec2 q, vec3 n, float stripes, float px) {
	vec3 c = shade_mat(PAPER, n, 0.0, 0.25, 1.0);
	float vein = abs(fract(q.x * stripes + vnoise(q * vec2(4.0, 1.5)) * 0.6) - 0.5);
	float fine = smoothstep(0.03, 0.012, px);
	c = mix(c, PAPER_DARK, (1.0 - smoothstep(0.04, 0.12, vein)) * 0.55 * fine);
	return mix(c, mix(PAPER, sand_color, 0.45), smoothstep(0.55, 0.85, vnoise(q * 9.0)) * 0.30);
}

// 縦に裂けた莢の柱: 裂け目から中の空洞が見える
void pod_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POD_POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float r = POD_POST_R * (0.86 + 0.14 * cos(f.p.y * 3.0));
	float d = max(abs(lx) - r, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), 0.0);
	vec3 c = husk_color(vec2(lx / r * 0.6, f.p.y), n, 3.0, f.px) * f.ao;
	// 中ほどの裂け目
	float slit_w = 0.020 * max(1.0 - abs(f.p.y - 0.32 * sign(cx)) / 0.30, 0.0);
	float slit = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(lx + 0.008 * sign(cx)) - slit_w);
	c = mix(c, PAPER_DARK * 0.45, slit);
	part(acc, d, ink_of(PAPER_DARK), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), PAPER_DARK, 0.0);
	// 縛った細い蔓
	draw_band(acc, f, vec2(cx, f.side * 0.70), vec2(0.070, 0.012), PAPER_DARK * 1.2, 0.0);
}

void husk_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, SLAB_HALF, 0.06);
	float v = q.y / SLAB_HALF.y;
	vec3 n = normalize(vec3(q.x / SLAB_HALF.x * 0.3, v * 0.6, 0.75));
	part(acc, d, ink_of(PAPER_DARK), husk_color(vec2(q.y * 3.0, q.x), n, 6.0, f.px), f.ow, f.px);
	// 中央に残ったひと粒
	vec3 sn = normalize(vec3(q / 0.04 * 0.6, 0.8));
	part(acc, sd_ellipse(q, vec2(0.040, 0.030)), ink_of(PAPER_DARK), shade_mat(sand_color, sn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
}

// 割れて口を開けた空の莢: 細長い殻の上が裂け、中の種の座だけが残る
void empty_pod(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, POD_Y);
	if (abs(q.x) > 0.30 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	// 両端が少し反り上がる
	vec2 bq = vec2(q.x, q.y - 0.55 * q.x * q.x);
	float d_shell = sd_ellipse(bq, vec2(0.26, 0.068));
	vec3 n = normalize(vec3(bq / vec2(0.26, 0.068) * 0.6, 0.75));
	part(acc, d_shell, ink_of(PAPER_DARK), husk_color(bq * vec2(1.0, 3.0), n, 2.5, f.px), f.ow, f.px);
	// 裂け目から見える空の中
	vec2 iq = bq - vec2(0.0, 0.016);
	float d_in = sd_ellipse(iq, vec2(0.205, 0.034));
	part(acc, d_in, ink_of(PAPER_DARK), mix(PAPER_DARK * 0.45, PAPER_DARK * 0.75, smoothstep(0.03, -0.03, iq.y)), f.ow * 0.6, f.px);
	// 空になった種の座
	for (int k = -2; k <= 2; k++) {
		vec2 sq = iq - vec2(float(k) * 0.075, -0.004);
		over(acc, PAPER * 0.85, cov(sd_ellipse(sq, vec2(0.022, 0.013)) , f.px) * 0.8);
	}
	// 柄
	float d_stem = sd_segment(q, vec2(0.25, 0.04), vec2(0.30, 0.09)) - 0.010;
	part(acc, d_stem, ink_of(PAPER_DARK), PAPER_DARK, f.ow * 0.8, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	pod_post(acc, f, -POST_X);
	pod_post(acc, f, POST_X);
	draw_collars(acc, f, PAPER_DARK, 0.0);
	husk_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		empty_pod(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
