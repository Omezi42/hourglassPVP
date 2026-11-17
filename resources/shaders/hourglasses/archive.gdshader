shader_type canvas_item;
// 書庫(アーカイブ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は背表紙を見せて積んだ本、板は書棚の棚板。天板の上に本立てに並べた数冊の本。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 SHELF = vec3(0.50, 0.34, 0.20);
const vec3 INK = vec3(0.18, 0.12, 0.08);
const float STACK_X = 0.68;
const float BOOK_HALF = 0.072;
const vec2 SLAB_HALF = vec2(0.82, 0.080);

vec3 book_color(float k) {
	float h = hash21(vec2(k, 4.0));
	vec3 a = vec3(0.56, 0.20, 0.18);
	vec3 b = vec3(0.20, 0.36, 0.30);
	vec3 c = vec3(0.24, 0.26, 0.48);
	vec3 d = vec3(0.62, 0.48, 0.26);
	return h < 0.25 ? a : (h < 0.5 ? b : (h < 0.75 ? c : d));
}

// 背表紙: 帯と箔押しの線、ときどき砂の色の帯
void book_spine(inout vec4 acc, Px f, vec2 c, vec2 hs, float k) {
	vec2 q = f.p - c;
	if (abs(q.x) > hs.x + f.pad || abs(q.y) > hs.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, hs, 0.008);
	vec3 col = book_color(k);
	vec3 n = normalize(vec3(0.0, q.y / hs.y * 0.6, 0.8));
	vec3 fill = shade_mat(col, n, 0.0, 0.5, f.ao);
	float gilt = step(abs(abs(q.x) - hs.x * 0.65), 0.006);
	fill = mix(fill, GOLD, gilt * 0.85);
	fill = mix(fill, sand_color, step(0.7, hash21(vec2(k, 2.0))) * step(abs(q.x), hs.x * 0.35));
	part(acc, d, INK, fill, f.ow * 0.8, f.px);
}

void book_stack(inout vec4 acc, Px f, float cx) {
	if (abs(f.p.x - cx) > BOOK_HALF + 0.03 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float y = -POST_H;
	for (int k = 0; k < 24; k++) {
		float sk = float(k) + cx * 5.0;
		float h = 0.070 + hash21(vec2(sk, 1.0)) * 0.08;
		float yc = y + h * 0.5;
		if (abs(f.p.y - yc) < h * 0.5 + f.pad) {
			float w = BOOK_HALF * (0.86 + 0.18 * hash21(vec2(sk, 3.0)));
			float ox = (hash21(vec2(sk, 5.0)) - 0.5) * 0.03;
			book_spine(acc, f, vec2(cx + ox, yc), vec2(w, h * 0.5 - 0.002), sk);
		}
		y += h;
		if (y > POST_H) {
			break;
		}
	}
}

void shelf_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, SHELF, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float grain = abs(fract(q.y * 22.0 + vnoise(q * vec2(2.0, 8.0)) * 1.2) - 0.5);
	inlay(acc, d, SHELF * 0.8, (1.0 - smoothstep(0.05, 0.15, grain)) * 0.5 * smoothstep(0.03, 0.012, f.px), f);
	// 棚の札: 真鍮の枠に砂の色の札
	inlay(acc, d, GOLD, cov(sd_round_box(q, vec2(0.075, 0.034), 0.006), f.px), f);
	inlay(acc, d, mix(sand_color, vec3(1.0), 0.4), cov(sd_round_box(q, vec2(0.060, 0.022), 0.004), f.px), f);
}

// 天板の上に立てた本と、傾いた1冊、本立ての金具
void standing_books(inout vec4 acc, Px f) {
	float base = PLATE_Y + SLAB_HALF.y;
	if (f.p.y < base - f.pad || f.p.y > base + 0.24 || abs(f.p.x) > 0.30 + f.pad) {
		return;
	}
	for (int k = 0; k < 4; k++) {
		float x = -0.13 + float(k) * 0.058;
		float h = 0.15 + hash21(vec2(float(k), 8.0)) * 0.05;
		book_spine(acc, f, vec2(x, base + h * 0.5), vec2(0.026, h * 0.5), float(k) + 20.0);
	}
	// 寄りかかった1冊
	vec2 q = rot(f.p - vec2(0.15, base + 0.075), -0.45);
	float d = sd_round_box(q, vec2(0.026, 0.080), 0.006);
	part(acc, d, INK, shade_mat(book_color(31.0), normalize(vec3(0.3, 0.2, 0.9)), 0.0, 0.5, 1.0), f.ow * 0.8, f.px);
	// 本立ての金具
	float d_end = sd_round_box(f.p - vec2(-0.175, base + 0.065), vec2(0.010, 0.065), 0.004);
	part(acc, d_end, INK, GOLD, f.ow * 0.7, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	book_stack(acc, f, -STACK_X);
	book_stack(acc, f, STACK_X);
	draw_collars(acc, f, SHELF, 0.0);
	shelf_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		standing_books(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
