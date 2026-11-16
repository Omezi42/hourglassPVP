shader_type canvas_item;
// 毒(ポイズン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 緑青の浮いた銅の柱に蛇が巻きつき、天板の上に毒の小瓶。板の縁から毒が垂れる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 COPPER = vec3(0.66, 0.40, 0.26);
const vec3 VERDIGRIS = vec3(0.36, 0.66, 0.56);
const vec3 SNAKE = vec3(0.22, 0.50, 0.24);
const vec3 BELLY = vec3(0.86, 0.78, 0.44);
const float POST_R = 0.040;
const float COIL_AMP = 0.062;
const float COIL_FREQ = 1.6;
const vec2 SLAB_HALF = vec2(0.80, 0.082);

vec3 corroded(vec3 base, vec2 p, float px) {
	float spot = smoothstep(0.62, 0.80, vnoise(p * 22.0));
	return mix(base, VERDIGRIS, spot * 0.7 * smoothstep(0.03, 0.012, px) + spot * 0.3);
}

// 銅の柱と、それに巻きつく蛇(頭は柱の上で内を向く)
void snake_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.16 + f.pad || f.ay > POST_H + 0.12 + f.pad) {
		return;
	}
	float ph = f.p.y * COIL_FREQ * 6.2832 + cx * 3.0;
	float front = cos(ph);
	float body_w = 0.026 * (0.6 + 0.4 * smoothstep(-1.0, 0.4, f.p.y));
	float sx = COIL_AMP * sin(ph);
	float d_snake = max(abs(lx - sx) - body_w, max(-0.92 - f.p.y, f.p.y - 0.80));
	// 後ろを回る胴を先に、柱、手前の胴の順
	// 背に黒い菱の斑
	float diamond = step(abs(fract(f.p.y * 9.0) - 0.5) * 2.0 + abs(lx - sx) / body_w, 0.7);
	vec3 scales = mix(SNAKE, vec3(0.06, 0.10, 0.06), diamond * 0.8);
	if (front < 0.0) {
		part(acc, d_snake, vec3(0.04, 0.08, 0.04), scales * 0.75, f.ow * 0.8, f.px);
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	part(acc, d, ink_of(COPPER), corroded(shade_mat(COPPER, n, 1.0, 1.0, f.ao), f.p + cx, f.px), f.ow, f.px);
	if (front >= 0.0) {
		vec3 c = mix(scales, BELLY, smoothstep(0.3, 1.0, (lx - sx) / body_w * sign(cx)) * 0.6);
		part(acc, d_snake, vec3(0.04, 0.08, 0.04), c, f.ow * 0.8, f.px);
	}
	// 頭: 胴の上端から内へ
	vec2 hq = vec2((lx - COIL_AMP * sin(0.80 * COIL_FREQ * 6.2832 + cx * 3.0)) * -sign(cx), f.p.y - 0.84);
	float tongue = min(sd_segment(hq, vec2(0.10, -0.005), vec2(0.15, -0.005)), min(sd_segment(hq, vec2(0.15, -0.005), vec2(0.17, 0.010)), sd_segment(hq, vec2(0.15, -0.005), vec2(0.17, -0.020)))) - 0.005;
	part(acc, tongue, vec3(0.3, 0.02, 0.04), vec3(0.85, 0.18, 0.22), f.ow * 0.4, f.px);
	float d_head = sd_ellipse(hq - vec2(0.045, 0.0), vec2(0.064, 0.040));
	vec3 hn = normalize(vec3((hq - vec2(0.045, 0.0)) / vec2(0.064, 0.04) * 0.6, 0.75));
	part(acc, d_head, vec3(0.04, 0.08, 0.04), shade_mat(SNAKE * 1.15, hn, 0.0, 1.0, 1.0), f.ow * 0.8, f.px);
	over(acc, vec3(1.0, 0.92, 0.30), cov(length(hq - vec2(0.062, 0.014)) - 0.013, f.px));
	over(acc, vec3(0.05), cov(sd_ellipse(hq - vec2(0.062, 0.014), vec2(0.004, 0.011)), f.px));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.028), COPPER, 1.0);
}

void copper_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, COPPER, 1.0, 0.9);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + 0.08 + f.pad) {
		return;
	}
	float spot = smoothstep(0.62, 0.80, vnoise(q * vec2(18.0, 22.0) + cy));
	inlay(acc, d, VERDIGRIS, spot * 0.75, f);
	// 毒の滴が下の縁から垂れる(天板だけ)
	if (cy > 0.0) {
		float cell = floor(q.x * 3.0 + 0.5);
		float dx = q.x - cell / 3.0;
		float len = 0.03 + 0.05 * hash21(vec2(cell, 5.0));
		float yb = q.y + SLAB_HALF.y;
		float d_drip = max(abs(dx) - 0.012, max(yb - 0.005, -yb - len));
		d_drip = min(d_drip, length(vec2(dx, yb + len)) - 0.022);
		over(acc, mix(sand_color, vec3(0.6, 1.0, 0.3), 0.3), cov(d_drip, f.px) * step(abs(q.x), 0.72));
	}
	// 中央の髑髏の印
	vec2 sq = q - vec2(0.0, 0.006);
	float d_skull = min(sd_ellipse(sq - vec2(0.0, 0.008), vec2(0.040, 0.034)), sd_round_box(sq - vec2(0.0, -0.026), vec2(0.022, 0.014), 0.004));
	inlay(acc, d, BELLY, cov(d_skull, f.px), f);
	float eyes = min(length(sq - vec2(-0.015, 0.008)) - 0.010, length(sq - vec2(0.015, 0.008)) - 0.010);
	inlay(acc, d, SNAKE * 0.4, cov(eyes, f.px), f);
}

// 天板の上の毒の小瓶
void vial(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, 1.258);
	if (abs(q.x) > 0.10 + f.pad || abs(q.y) > 0.12 + f.pad) {
		return;
	}
	float d_body = length(q + vec2(0.0, 0.025)) - 0.070;
	float d_neck = sd_round_box(q - vec2(0.0, 0.055), vec2(0.022, 0.040), 0.006);
	float d = min(d_body, d_neck);
	part(acc, d, ink_of(VERDIGRIS), mix(vec3(0.80, 0.90, 0.92), vec3(1.0), step(q.x, -0.02) * 0.5), f.ow, f.px);
	float liquid = step(q.y + 0.025, 0.010 + 0.006 * sin(q.x * 60.0));
	over(acc, mix(sand_color, vec3(0.5, 0.95, 0.3), 0.35), liquid * cov(d_body + f.ow * 0.5, f.px));
	draw_band(acc, f, vec2(0.0, 1.258 + 0.098), vec2(0.028, 0.014), COPPER, 1.0);
	over(acc, vec3(1.0), cov(length(q - vec2(-0.030, -0.005)) - 0.012, f.px) * 0.8);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	draw_collars(acc, f, COPPER, 1.0);
	copper_slab(acc, f, f.side * PLATE_Y);
	snake_post(acc, f, -POST_X);
	snake_post(acc, f, POST_X);
	if (f.p.y > PLATE_Y) {
		vial(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
