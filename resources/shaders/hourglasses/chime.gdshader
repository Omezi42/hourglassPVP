shader_type canvas_item;
// 風鈴の管(チャイム)。GameDesign.md 9章 / Architecture.md 10.19節。
// 天板の左右の張り出しから長さの違う金属の管を吊るし、天板の上に半円の吊り枠と小さな鐘。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRONZE = vec3(0.70, 0.56, 0.34);
const vec3 TUBE = vec3(0.78, 0.80, 0.86);
const vec3 LACQUER = vec3(0.30, 0.26, 0.44);
const float POST_R = 0.036;
const vec2 SLAB_HALF = vec2(0.92, 0.078);
const vec2 BASE_HALF = vec2(0.80, 0.078);
const float TUBE_TOP = 0.92;

// 管1本(吊り糸つき)
void tube(inout vec4 acc, Px f, float cx, float len) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.04 + f.pad || f.p.y > PLATE_Y + f.pad || f.p.y < TUBE_TOP - len - f.pad) {
		return;
	}
	float d_thread = max(abs(lx) - 0.004, max(f.p.y - PLATE_Y + SLAB_HALF.y, TUBE_TOP - f.p.y));
	over(acc, ink_of(TUBE), cov(d_thread, f.px));
	float d = max(abs(lx) - 0.022, max(f.p.y - TUBE_TOP, TUBE_TOP - len - f.p.y));
	vec3 n = lathe_normal(clamp(lx / 0.022, -1.0, 1.0), 0.0);
	part(acc, d, ink_of(LACQUER), shade_mat(TUBE, n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
}

void slim_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, POST_R, -POST_H, POST_H, LACQUER, 0.2);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.072, 0.024), BRONZE, 1.0);
	draw_ball(acc, f, vec2(cx, 0.0), 0.050, BRONZE, 1.0);
}

void lacquer_slab(inout vec4 acc, Px f, float cy) {
	vec2 hs = cy > 0.0 ? SLAB_HALF : BASE_HALF;
	float d = draw_slab(acc, f, cy, hs, 0.03, LACQUER, 0.2, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > hs.x + f.pad || abs(q.y) > hs.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.050) - 0.005);
	inlay(acc, d, BRONZE, rim * step(abs(q.x), hs.x - 0.04), f);
	// 音の波の紋
	for (int k = 1; k <= 3; k++) {
		float r = 0.022 * float(k);
		float arc = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.7), abs(length(q + vec2(0.03, 0.0)) - r) - 0.004);
		inlay(acc, d, BRONZE, arc * step(-0.03, q.x) * step(abs(q.y), r * 0.8), f);
	}
	vec3 gn = normalize(vec3((q + vec2(0.03, 0.0)) / 0.024 * 0.6, 0.8));
	part(acc, length(q + vec2(0.03, 0.0)) - 0.022, ink_of(BRONZE), shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.6, f.px);
}

// 天板の上の半円の吊り枠と鐘
void hanger(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, 1.17);
	if (abs(q.x) > 0.16 + f.pad || q.y > 0.22 + f.pad) {
		return;
	}
	float d_arch = max(abs(length(q) - 0.13) - 0.014, -q.y);
	vec3 n = normalize(vec3(q / 0.13 * 0.5, 0.8));
	part(acc, d_arch, ink_of(BRONZE), shade_mat(BRONZE, n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	vec2 bq = q - vec2(0.0, 0.035);
	float yy = clamp((0.075 - bq.y) / 0.085, 0.0, 1.0);
	float d_bell = max(abs(bq.x) - mix(0.025, 0.060, yy * yy), max(bq.y - 0.075, -bq.y - 0.010));
	part(acc, d_bell, ink_of(BRONZE), shade_mat(mix(BRONZE, sand_color, 0.3), normalize(vec3(bq.x / 0.06, 0.2, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	slim_post(acc, f, -POST_X);
	slim_post(acc, f, POST_X);
	draw_collars(acc, f, BRONZE, 1.0);
	tube(acc, f, -0.80, 0.34);
	tube(acc, f, -0.89, 0.52);
	tube(acc, f, 0.80, 0.44);
	tube(acc, f, 0.89, 0.26);
	lacquer_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		hanger(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
