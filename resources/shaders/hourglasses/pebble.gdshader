shader_type canvas_item;
// 川の小石(ペブル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は丸い小石を縦に積んだもの、板はなめらかな粘板岩。天板の上の小石のまわりに砂が溜まる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 SLATE = vec3(0.40, 0.44, 0.46);
const vec3 INK = vec3(0.14, 0.15, 0.16);
const float STACK_X = 0.68;
const int STONES = 7;
const vec2 SLAB_HALF = vec2(0.80, 0.078);

vec3 pebble_tone(float k) {
	float h = hash21(vec2(k, 7.0));
	vec3 a = vec3(0.70, 0.66, 0.60);
	vec3 b = vec3(0.56, 0.58, 0.60);
	vec3 c = vec3(0.76, 0.70, 0.62);
	return h < 0.33 ? a : (h < 0.66 ? b : c);
}

void smooth_pebble(inout vec4 acc, Px f, vec2 c, vec2 hs, float k) {
	vec2 q = f.p - c;
	if (abs(q.x) > hs.x + f.pad || abs(q.y) > hs.y + f.pad) {
		return;
	}
	float d = sd_ellipse(q, hs);
	vec3 n = normalize(vec3(q / hs * 0.75, 0.65));
	vec3 col = shade_mat(pebble_tone(k), n, 0.0, 0.8, f.ao);
	float speck = step(0.82, vnoise(q * 50.0 + k)) * smoothstep(0.03, 0.012, f.px);
	col = mix(col, col * 0.7, speck * 0.5);
	part(acc, d, INK, col, f.ow, f.px);
}

void pebble_stack(inout vec4 acc, Px f, float cx) {
	if (abs(f.p.x - cx) > 0.14 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float span = 2.0 * POST_H / float(STONES);
	for (int k = 0; k < STONES; k++) {
		float y = -POST_H + span * (float(k) + 0.5);
		float sk = float(k) + cx * 5.0;
		vec2 hs = vec2(0.085 + hash21(vec2(sk, 1.0)) * 0.03, span * 0.5 + 0.012);
		float ox = (hash21(vec2(sk, 2.0)) - 0.5) * 0.04;
		smooth_pebble(acc, f, vec2(cx + ox, y), hs, sk);
	}
}

void slate_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.05, SLATE, 0.0, 0.9);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 層の筋と、上の縁に積もった砂
	float layer = abs(fract(q.y * 16.0 + q.x * 0.6 + vnoise(q * 3.0) * 0.5) - 0.5);
	inlay(acc, d, SLATE * 0.8, (1.0 - smoothstep(0.05, 0.15, layer)) * 0.5 * smoothstep(0.03, 0.012, f.px), f);
	float drift = SLAB_HALF.y - 0.022 - 0.014 * vnoise(vec2(q.x * 7.0, cy));
	inlay(acc, d, mix(sand_color, vec3(1.0), 0.15), step(drift, q.y) * smoothstep(0.75, 0.55, abs(q.x)), f);
	smooth_pebble(acc, f, vec2(0.0, cy), vec2(0.060, 0.040), 3.0 + cy);
}

// 天板の上: 小石と、まわりに溜まった砂の小山
void pebble_top(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, PLATE_Y + SLAB_HALF.y - 0.01);
	if (abs(q.x) > 0.34 + f.pad || q.y > 0.20 + f.pad) {
		return;
	}
	float mound = max(abs(q.x) - 0.30, q.y - 0.075 * (1.0 - pow(min(abs(q.x) / 0.30, 1.0), 2.0)));
	mound = max(mound, -q.y - 0.01);
	vec3 sand = mix(sand_color * 0.8, mix(sand_color, vec3(1.0), 0.25), smoothstep(-0.2, 0.2, -q.x));
	part(acc, mound, ink_of(sand_color), sand, f.ow * 0.7, f.px);
	smooth_pebble(acc, f, vec2(0.02, PLATE_Y + SLAB_HALF.y + 0.085), vec2(0.105, 0.072), 11.0);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	pebble_stack(acc, f, -STACK_X);
	pebble_stack(acc, f, STACK_X);
	draw_collars(acc, f, SLATE * 0.9, 0.0);
	slate_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		pebble_top(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
