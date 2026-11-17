shader_type canvas_item;
// 積み石(ケルン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は平たい石を積み重ねた塔、板は苔むした石板。天板の上に大小の丸石を積んだケルン。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 SLATE = vec3(0.52, 0.54, 0.56);
const vec3 MOSS = vec3(0.36, 0.52, 0.28);
const float STACK_HALF = 0.070;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 CAIRN = vec2(0.0, 1.185);

vec3 stone_color(float k) {
	float h = hash21(vec2(k, 7.0));
	return mix(SLATE, vec3(0.62, 0.58, 0.52), h) * (0.88 + 0.2 * hash21(vec2(k, 9.0)));
}

void flat_stone(inout vec4 acc, Px f, vec2 c, vec2 hs, float k) {
	vec2 q = f.p - c;
	if (abs(q.x) > hs.x + f.pad || abs(q.y) > hs.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, hs, min(hs.y, 0.020));
	vec3 n = normalize(vec3(q.x / hs.x * 0.4, q.y / hs.y * 0.6, 0.75));
	vec3 col = shade_mat(stone_color(k), n, 0.0, 0.4, f.ao);
	col = mix(col, MOSS, step(0.6, vnoise(q * 30.0 + k)) * step(0.5, q.y / hs.y) * 0.7);
	part(acc, d, ink_of(SLATE), col, f.ow * 0.8, f.px);
}

void stone_stack(inout vec4 acc, Px f, float cx) {
	if (abs(f.p.x - cx) > STACK_HALF + 0.03 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float y = -POST_H;
	for (int k = 0; k < 30; k++) {
		float sk = float(k) + cx * 7.0;
		float h = 0.050 + hash21(vec2(sk, 1.0)) * 0.045;
		float yc = y + h * 0.5;
		if (abs(f.p.y - yc) < h * 0.5 + f.pad) {
			float w = STACK_HALF * (0.80 + 0.25 * hash21(vec2(sk, 3.0)));
			float ox = (hash21(vec2(sk, 5.0)) - 0.5) * 0.024;
			flat_stone(acc, f, vec2(cx + ox, yc), vec2(w, h * 0.5 - 0.003), sk);
		}
		y += h;
		if (y > POST_H) {
			break;
		}
	}
}

void moss_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, SLATE, 0.0, 0.4);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float m = smoothstep(0.55, 0.70, vnoise(q * vec2(12.0, 20.0)) + (q.y / SLAB_HALF.y) * 0.25 * f.side);
	inlay(acc, d, MOSS, m * 0.8, f);
	// 刻んだ道しるべの矢印
	for (int s = -1; s <= 1; s += 2) {
		vec2 aq = vec2(q.x * float(s) - 0.40, q.y);
		float d_arrow = max(abs(aq.y) - (0.028 - aq.x * 0.6), max(-aq.x, aq.x - 0.050));
		d_arrow = min(d_arrow, max(abs(aq.y) - 0.007, max(-aq.x - 0.10, aq.x)));
		inlay(acc, d, SLATE * 0.55, cov(d_arrow, f.px), f);
	}
	inlay(acc, d, sand_color, cov(length(q) - 0.032, f.px), f);
}

// ケルン: 下ほど大きい丸石を積み、頂きに砂の色の小石
void cairn_stack(inout vec4 acc, Px f) {
	vec2 q = f.p - CAIRN;
	if (abs(q.x) > 0.20 + f.pad || q.y < -0.10 - f.pad || q.y > 0.20 + f.pad) {
		return;
	}
	vec3 stones[5] = vec3[5](vec3(-0.010, -0.050, 0.110), vec3(0.012, 0.035, 0.085), vec3(-0.008, 0.100, 0.062), vec3(0.006, 0.148, 0.045), vec3(0.0, 0.182, 0.030));
	vec2 ry[5] = vec2[5](vec2(1.0, 0.42), vec2(1.0, 0.48), vec2(1.0, 0.55), vec2(1.0, 0.62), vec2(1.0, 0.75));
	for (int k = 0; k < 5; k++) {
		vec2 sq = (q - stones[k].xy) / ry[k];
		float r = stones[k].z;
		float d = (length(sq) - r) * ry[k].y;
		vec3 col = k == 4 ? sand_color : stone_color(float(k) + 40.0);
		vec3 n = normalize(vec3(sq / r * 0.6, 0.75));
		col = shade_mat(col, n, 0.0, 0.5, 1.0);
		col = mix(col, MOSS, step(0.62, vnoise(sq * 40.0 + float(k))) * step(0.3, sq.y / r) * step(float(k), 2.5) * 0.7);
		part(acc, d, ink_of(SLATE), col, f.ow * 0.8, f.px);
	}
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	stone_stack(acc, f, -POST_X);
	stone_stack(acc, f, POST_X);
	draw_collars(acc, f, SLATE, 0.0);
	moss_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		cairn_stack(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
