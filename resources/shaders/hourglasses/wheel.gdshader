shader_type canvas_item;
// 荷車の車輪(ホイール)。GameDesign.md 9章 / Architecture.md 10.19節。
// 器を荷台に載せ、下の左右に鉄の輪をはめた木の車輪。底板には轍の模様、天板の中央に小さな車輪。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PAINT = vec3(0.50, 0.26, 0.62);
const vec3 WOOD = vec3(0.58, 0.40, 0.24);
const vec3 IRON = vec3(0.34, 0.34, 0.38);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float WHEEL_X = 0.66;
const float WHEEL_Y = -1.03;
const float WHEEL_R = 0.26;
const float SPOKES = 8.0;

void cart_wheel(inout vec4 acc, Px f, vec2 c, float r) {
	vec2 q = f.p - c;
	float l = length(q);
	if (l > r + f.pad) {
		return;
	}
	float a = atan(q.y, q.x);
	// 鉄の輪
	float d_tire = abs(l - r * 0.91) - r * 0.09;
	vec3 tn = normalize(vec3(q / l * clamp((l - r * 0.91) / (r * 0.09), -1.0, 1.0), 0.6));
	part(acc, d_tire, ink_of(IRON), shade_mat(IRON, tn, 1.0, 0.8, 1.0), f.ow, f.px);
	// 木の外輪
	float d_rim = abs(l - r * 0.75) - r * 0.08;
	vec3 rn = normalize(vec3(q / l * clamp((l - r * 0.75) / (r * 0.08), -1.0, 1.0) * 0.6, 0.8));
	part(acc, d_rim, ink_of(WOOD), shade_mat(WOOD, rn, 0.0, 0.6, 1.0), f.ow, f.px);
	// 輻(スポーク)
	float sector = 6.2832 / SPOKES;
	float sa = mod(a + sector * 0.5, sector) - sector * 0.5;
	float d_spoke = max(abs(sin(sa) * l) - r * 0.045, max(r * 0.16 - l, l - r * 0.70));
	part(acc, d_spoke, ink_of(WOOD), shade_mat(PAINT, normalize(vec3(0.0, 0.0, 1.0)), 0.0, 0.6, 1.0), f.ow * 0.8, f.px);
	// 轂(こしき)
	vec3 hn = normalize(vec3(q / (r * 0.2), 0.8));
	part(acc, l - r * 0.20, ink_of(WOOD), shade_mat(WOOD, hn, 0.0, 0.8, 1.0), f.ow * 0.8, f.px);
	draw_ball(acc, f, c, r * 0.09, IRON * 1.4, 1.0);
}

void cart_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, 0.050, -POST_H, POST_H, PAINT, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), IRON, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.50), vec2(0.066, 0.018), IRON, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.066, 0.018), IRON, 1.0);
}

void cart_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, WOOD, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 紫に塗った帯に、轍(山形の刻み)を2列
	float band = step(abs(q.y), 0.046) * step(abs(q.x), 0.76);
	inlay(acc, d, PAINT, band, f);
	float chev = abs(fract(q.x * 7.0 + abs(q.y) * 6.0) - 0.5);
	float tread = step(0.010, abs(q.y)) * step(abs(q.y), 0.038) * (1.0 - smoothstep(0.10, 0.18, chev));
	inlay(acc, d, mix(PAINT, sand_color, 0.55), tread * band, f);
	for (int i = 0; i < 2; i++) {
		draw_ball(acc, f, vec2((i == 0 ? -1.0 : 1.0) * 0.76, cy), 0.022, IRON * 1.4, 1.0);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	cart_post(acc, f, -POST_X);
	cart_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	cart_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y < -0.7) {
		cart_wheel(acc, f, vec2(-WHEEL_X, WHEEL_Y), WHEEL_R);
		cart_wheel(acc, f, vec2(WHEEL_X, WHEEL_Y), WHEEL_R);
	}
	if (f.p.y > PLATE_Y) {
		cart_wheel(acc, f, vec2(0.0, 1.262), 0.110);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
