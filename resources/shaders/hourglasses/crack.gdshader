shader_type canvas_item;
// ひびの奥の光(クラック)。GameDesign.md 9章 / Architecture.md 10.19節。
// 黒い黒曜石の枠を、奥で光る赤いひびが走る。天板の上に割れかけた石の卵、隙間から光が漏れる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 OBSIDIAN = vec3(0.20, 0.18, 0.22);
const vec3 OBSIDIAN_LIT = vec3(0.42, 0.40, 0.48);
const float POST_HALF = 0.062;
const vec2 SLAB_HALF = vec2(0.80, 0.084);
const vec2 EGG = vec2(0.0, 1.250);

vec3 ember() {
	return mix(sand_color, vec3(1.0, 0.86, 0.50), 0.35);
}

// 枝分かれするひび: 戻り値はひびの中心からの距離
float crack_lines(vec2 p, float k) {
	vec2 g = p * vec2(3.0, 2.0) + k;
	float n = vnoise(g) + 0.5 * vnoise(g * 2.3);
	float a = abs(n - 0.75);
	float b = abs(vnoise(g * 1.7 + 5.0) - 0.5);
	return min(a * 0.30, b * 0.40);
}

void obsidian_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H) + (vnoise(vec2(f.p.y * 9.0, cx)) - 0.5) * 0.010;
	float u = lx / POST_HALF;
	vec3 c = mix(OBSIDIAN, OBSIDIAN_LIT, smoothstep(0.6, -0.8, u) * 0.6);
	// 鏡のような照り
	c = mix(c, vec3(0.86, 0.84, 0.92), (1.0 - smoothstep(0.0, 0.10, abs(u + 0.45))) * 0.45);
	float cr = crack_lines(f.p, cx);
	float line = 1.0 - smoothstep(0.0, max(0.006, f.px), cr - 0.004);
	c = mix(c, ember(), line);
	part(acc, d, vec3(0.04), c * f.ao, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), OBSIDIAN_LIT, 0.6);
}

void obsidian_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, SLAB_HALF, 0.025) + (vnoise(q * 14.0 + cy) - 0.5) * 0.010;
	float v = q.y / SLAB_HALF.y;
	vec3 c = mix(OBSIDIAN, OBSIDIAN_LIT, smoothstep(0.3, 1.0, v) * 0.7);
	float cr = crack_lines(q * vec2(0.6, 1.0) + vec2(0.0, cy), cy + 2.0);
	c = mix(c, ember(), 1.0 - smoothstep(0.0, max(0.006, f.px), cr - 0.004));
	part(acc, d, vec3(0.04), c, f.ow, f.px);
}

// 割れかけた石の卵: ジグザグのひびから光が漏れる
void cracked_egg(inout vec4 acc, Px f) {
	vec2 q = f.p - EGG;
	if (abs(q.x) > 0.12 + f.pad || abs(q.y) > 0.14 + f.pad) {
		return;
	}
	float ry = q.y > 0.0 ? 0.125 : 0.100;
	float d = sd_ellipse(q, vec2(0.100, ry));
	vec3 n = normalize(vec3(q / vec2(0.100, ry) * 0.7, 0.7));
	vec3 c = shade_mat(OBSIDIAN_LIT * 0.8, n, 0.3, 1.0, 1.0);
	float zig = q.y - 0.02 - 0.022 * abs(fract(q.x * 9.0) - 0.5) * 2.0;
	float seam = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(zig) - 0.008);
	c = mix(c, vec3(1.0, 0.94, 0.80), seam);
	part(acc, d, vec3(0.04), c, f.ow, f.px);
}

// ひびから漏れる光(卵のまわり)
void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - EGG;
	add_light(acc, ember(), exp(-dot(d, d) / 0.050) * 0.95 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	obsidian_post(acc, f, -POST_X);
	obsidian_post(acc, f, POST_X);
	draw_collars(acc, f, OBSIDIAN_LIT, 0.6);
	obsidian_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		cracked_egg(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
