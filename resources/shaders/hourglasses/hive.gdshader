shader_type canvas_item;
// 藁の巣(ハイヴ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱と板は編んだ籐、天板の上に藁を巻いた丸い巣(スケップ)。巣の口から砂の色のひと粒が飛び出す。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STRAW = vec3(0.86, 0.72, 0.44);
const vec3 STRAW_DARK = vec3(0.56, 0.42, 0.20);
const vec3 CANE = vec3(0.66, 0.50, 0.30);
const float POST_R = 0.052;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 SKEP = vec2(0.0, 1.175);

// 籐の編み目: 斜めに交わる2方向の帯
vec3 wicker(vec2 p, vec3 base, float px) {
	float a = fract((p.x + p.y) * 14.0);
	float b = fract((p.x - p.y) * 14.0);
	float over_a = step(0.5, fract(floor((p.x - p.y) * 14.0) * 0.5));
	float band = over_a > 0.5 ? a : b;
	vec3 c = mix(base * 0.70, base * 1.08, smoothstep(0.0, 0.3, band) * (1.0 - smoothstep(0.7, 1.0, band)));
	return mix(base, c, smoothstep(0.03, 0.012, px));
}

void wicker_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = wicker(f.p * vec2(1.6, 1.0), CANE, f.px) * (0.72 + 0.34 * clamp(dot(n, LIGHT_DIR) + 0.3, 0.0, 1.0));
	part(acc, d, ink_of(STRAW_DARK), c * f.ao, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), STRAW_DARK, 0.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.068, 0.018), mix(STRAW_DARK, sand_color, 0.4), 0.0);
}

void wicker_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, SLAB_HALF, 0.04);
	float v = q.y / SLAB_HALF.y;
	float shade = 0.82 + 0.25 * smoothstep(-1.0, 0.8, v);
	part(acc, d, ink_of(STRAW_DARK), wicker(q, CANE, f.px) * shade, f.ow, f.px);
	// 縁を巻いた太い籐
	float rim = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(abs(q.y) - SLAB_HALF.y + 0.014) - 0.010);
	over(acc, STRAW_DARK * 1.2, rim * cov(d, f.px));
}

// スケップ: 藁の段を重ねた釣鐘形、下の口、出てくる粒
void skep(inout vec4 acc, Px f) {
	vec2 q = f.p - SKEP;
	if (abs(q.x) > 0.24 + f.pad || q.y < -f.pad || q.y > 0.22 + f.pad) {
		return;
	}
	float t = clamp(q.y / 0.20, 0.0, 1.0);
	float hw = 0.165 * sqrt(max(1.0 - t * t, 0.0));
	float d = max(abs(q.x) - hw, max(-q.y, q.y - 0.20));
	float coil = fract(q.y / 0.034);
	vec3 c = mix(STRAW_DARK, STRAW, smoothstep(0.0, 0.35, coil) * (1.0 - smoothstep(0.75, 1.0, coil)));
	c *= 0.80 + 0.25 * smoothstep(0.1, -0.1, q.x / max(hw, 0.01));
	part(acc, d, ink_of(STRAW_DARK), c, f.ow, f.px);
	// 口
	float d_door = max(sd_ellipse(q - vec2(0.0, 0.0), vec2(0.040, 0.040)), -q.y);
	over(acc, vec3(0.10, 0.07, 0.04), cov(d_door, f.px));
	// 飛び出すひと粒
	for (int k = 0; k < 3; k++) {
		vec2 mq = q - vec2(0.10 + 0.05 * float(k), 0.03 + 0.045 * float(k));
		if (k == 0) {
			mq = q - vec2(-0.20, 0.060);
		}
		vec3 mn = normalize(vec3(mq / 0.02 * 0.6, 0.8));
		part(acc, length(mq) - 0.017, ink_of(sand_color), shade_mat(sand_color, mn, 0.0, 1.0, 1.0), f.ow * 0.6, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	wicker_post(acc, f, -POST_X);
	wicker_post(acc, f, POST_X);
	draw_collars(acc, f, STRAW_DARK, 0.0);
	wicker_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		skep(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
