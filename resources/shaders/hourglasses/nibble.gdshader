shader_type canvas_item;
// かじり鼠(ニブル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 木の枠のあちこちに齧った跡。天板の上で小さな鼠が板の端を齧っている。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 WOOD = vec3(0.70, 0.54, 0.34);
const vec3 WOOD_INK = vec3(0.32, 0.22, 0.14);
const vec3 FUR = vec3(0.62, 0.60, 0.62);
const vec3 PINK = vec3(0.94, 0.66, 0.70);
const float POST_R = 0.050;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 MOUSE = vec2(0.10, 1.235);

// 齧り跡: 縁を半円で欠く
float bite(vec2 q, vec2 c, float r) {
	return -(length(q - c) - r);
}

void gnawed_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float side = cx > 0.0 ? -1.0 : 1.0;
	d = max(d, bite(vec2(lx, f.p.y), vec2(side * POST_R, 0.30), 0.028));
	d = max(d, bite(vec2(lx, f.p.y), vec2(side * POST_R, 0.34), 0.022));
	d = max(d, bite(vec2(lx, f.p.y), vec2(-side * POST_R, -0.46), 0.026));
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(WOOD, n, 0.0, 0.5, f.ao);
	float grain = abs(fract(lx * 28.0 + vnoise(vec2(lx * 8.0, f.p.y * 2.0)) * 0.8) - 0.5);
	c = mix(c, c * 0.84, (1.0 - smoothstep(0.05, 0.2, grain)) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, WOOD_INK, c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), WOOD * 0.8, 0.0);
	draw_ball(acc, f, vec2(cx, 0.0), 0.058, WOOD, 0.0);
}

void gnawed_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, SLAB_HALF, 0.03);
	// 縁の齧り跡(天板は右上、底板は左下)
	float s = sign(cy);
	for (int k = 0; k < 3; k++) {
		vec2 c = vec2(s * (0.40 + 0.05 * float(k)), s * SLAB_HALF.y);
		d = max(d, bite(q, c, 0.030 - 0.004 * float(k)));
	}
	float v = q.y / SLAB_HALF.y;
	vec3 n = normalize(vec3(0.0, smoothstep(0.4, 0.6, v) * 0.7 - smoothstep(0.4, 0.6, -v) * 0.7, 0.75));
	vec3 c = shade_mat(WOOD, n, 0.0, 0.5, 1.0);
	float grain = abs(fract(q.y * 20.0 + vnoise(q * vec2(2.0, 8.0)) * 1.2) - 0.5);
	c = mix(c, c * 0.84, (1.0 - smoothstep(0.05, 0.15, grain)) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, WOOD_INK, c, f.ow, f.px);
	// 中央の砂の色の木の実
	vec3 gn = normalize(vec3(q / 0.04 * 0.6, 0.8));
	part(acc, sd_ellipse(q, vec2(0.040, 0.032)), WOOD_INK, shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
	// 散った木屑
	if (cy > 0.0) {
		for (int k = 0; k < 3; k++) {
			vec2 cq = q - vec2(0.30 + 0.06 * float(k), SLAB_HALF.y + 0.012);
			over(acc, WOOD * 1.1, cov(sd_ellipse(rot(cq, float(k)), vec2(0.012, 0.006)), f.px));
		}
	}
}

// 鼠: 丸い胴、耳、鼻先、細い尾
void mouse(inout vec4 acc, Px f) {
	vec2 q = f.p - MOUSE;
	if (abs(q.x) > 0.28 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	float d_tail = sd_segment(q, vec2(0.08, -0.04), vec2(0.20, -0.02)) - 0.007;
	d_tail = min(d_tail, sd_segment(q, vec2(0.20, -0.02), vec2(0.25, 0.04)) - 0.006);
	part(acc, d_tail, ink_of(FUR), PINK, f.ow * 0.6, f.px);
	float d_body = sd_ellipse(q - vec2(0.02, -0.005), vec2(0.095, 0.068));
	float d_head = sd_ellipse(rot(q - vec2(-0.085, 0.010), -0.25), vec2(0.060, 0.048));
	float d_snout = sd_ellipse(q - vec2(-0.135, -0.005), vec2(0.030, 0.022));
	float d = min(d_body, min(d_head, d_snout));
	vec3 n = normalize(vec3((q - vec2(0.0, 0.0)) / 0.1 * 0.5, 0.8));
	part(acc, d, ink_of(FUR), shade_mat(FUR, n, 0.0, 0.5, 1.0), f.ow, f.px);
	// 耳
	vec2 eq = q - vec2(-0.075, 0.060);
	part(acc, length(eq) - 0.032, ink_of(FUR), FUR, f.ow * 0.8, f.px);
	over(acc, PINK, cov(length(eq) - 0.018, f.px));
	over(acc, PINK, cov(length(q - vec2(-0.165, -0.005)) - 0.010, f.px));
	over(acc, vec3(0.06), cov(length(q - vec2(-0.105, 0.018)) - 0.009, f.px));
	// 抱えた砂の粒
	vec3 gn = normalize(vec3((q - vec2(-0.12, -0.05)) / 0.03 * 0.6, 0.8));
	part(acc, length(q - vec2(-0.12, -0.055)) - 0.026, ink_of(sand_color), shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.6, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	gnawed_post(acc, f, -POST_X);
	gnawed_post(acc, f, POST_X);
	draw_collars(acc, f, WOOD * 0.8, 0.0);
	gnawed_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		mouse(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
