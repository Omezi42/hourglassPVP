shader_type canvas_item;
// 頁(ページ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は縦に巻いた羊皮紙の巻物、板には書きかけの行。天板の上にめくれかけた頁の開いた本。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 VELLUM = vec3(0.94, 0.88, 0.74);
const vec3 INK = vec3(0.22, 0.18, 0.24);
const vec3 COVER = vec3(0.32, 0.22, 0.44);
const vec3 WALNUT = vec3(0.42, 0.28, 0.18);
const float SCROLL_R = 0.050;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 BOOK = vec2(0.0, 1.205);
const float BOOK_K = 1.2;

// 巻物の柱: 紙の巻きの縁がのぞき、上下に木の軸
void scroll_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - SCROLL_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / SCROLL_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(VELLUM, n, 0.0, 0.5, f.ao);
	// 巻いた紙の重なり(斜めの細い線)
	float edge = abs(fract(f.p.y / 0.090 - lx * 2.0) - 0.5);
	c = mix(c, VELLUM * 0.7, (1.0 - smoothstep(0.02, 0.06, edge)) * smoothstep(0.03, 0.012, f.px));
	// 紙に透ける文字の行
	float row = step(abs(fract(f.p.y / 0.030) - 0.5), 0.10) * step(abs(lx), SCROLL_R * 0.6) * step(0.5, hash21(vec2(floor(f.p.y / 0.030), cx)));
	c = mix(c, INK * 1.6, row * 0.35 * step(abs(f.p.y), 0.70));
	part(acc, d, ink_of(VELLUM * 0.6), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), WALNUT, 0.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.060, 0.016), mix(COVER, sand_color, 0.4), 0.0);
}

void writing_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, VELLUM, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 書きかけの行: 右へ行くほど途切れる
	float rowi = floor(q.y / 0.026 + 0.5);
	float in_row = step(abs(fract(q.y / 0.026 + 0.5) - 0.5), 0.14) * step(abs(rowi), 1.0);
	float word = step(0.25, hash21(vec2(floor(q.x / 0.05), rowi)));
	float stop = step(q.x, 0.60 - 0.30 * (rowi + 1.0));
	inlay(acc, d, INK, in_row * word * stop * step(-0.74, q.x), f);
	// 羽根ペンの先から垂れた砂の色のインク
	inlay(acc, d, sand_color, cov(length(q - vec2(0.62, -0.026)) - 0.020, f.px), f);
}

// 開いた本: 表紙、左右の頁、めくれて持ち上がる1枚
void open_book(inout vec4 acc, Px f) {
	vec2 q = (f.p - BOOK) / BOOK_K;
	if (abs(q.x) > 0.24 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= BOOK_K;
	f.ow /= BOOK_K;
	float d_cover = sd_round_box(q - vec2(0.0, -0.060), vec2(0.200, 0.018), 0.008);
	part(acc, d_cover, ink_of(COVER), shade_mat(COVER, normalize(vec3(0.0, 0.4, 0.85)), 0.0, 0.6, 1.0), f.ow, f.px);
	// 左右の頁(中央へ沈む弧)
	for (int s = -1; s <= 1; s += 2) {
		vec2 pq = vec2(q.x * float(s), q.y);
		float top = -0.010 + 0.030 * smoothstep(0.0, 0.18, pq.x) - 0.010 * smoothstep(0.12, 0.19, pq.x);
		float d_page = max(max(pq.y - top, -pq.y - 0.052), max(-pq.x, pq.x - 0.188));
		vec3 pc = mix(VELLUM * 0.85, VELLUM, smoothstep(0.0, 0.08, pq.x));
		float lines = step(abs(fract((pq.y + 0.04) / 0.014) - 0.5), 0.12) * step(0.03, pq.x) * step(pq.x, 0.16) * step(pq.y, top - 0.010);
		pc = mix(pc, INK * 1.4, lines * 0.6);
		part(acc, d_page, ink_of(VELLUM * 0.6), pc, f.ow * 0.6, f.px);
	}
	// めくれる頁: 中央の綴じ目から右上へ弧を描いて立つ
	vec2 tq = q - vec2(0.0, -0.010);
	float ang = atan(tq.y, tq.x);
	float r = length(tq);
	float d_turn = max(max(abs(ang - 1.0) - 0.42, r - 0.110), 0.020 - r);
	vec3 tc = mix(VELLUM, mix(VELLUM, sand_color, 0.4), smoothstep(0.02, 0.11, r));
	part(acc, d_turn, ink_of(VELLUM * 0.6), shade_mat(tc, normalize(vec3(-0.4, 0.3, 0.85)), 0.0, 0.6, 1.0), f.ow * 0.6, f.px);
	// しおりの紐
	float d_ribbon = max(abs(q.x + 0.030 + (q.y + 0.06) * 0.2) - 0.006, max(-q.y - 0.105, q.y + 0.050));
	part(acc, d_ribbon, ink_of(sand_color), sand_color, f.ow * 0.4, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - (BOOK + vec2(0.04, 0.05));
	add_light(acc, mix(VELLUM, sand_color, 0.4), exp(-dot(q, q) / 0.010) * 0.35);
}

void art_frame(inout vec4 acc, Px f) {
	scroll_post(acc, f, -POST_X);
	scroll_post(acc, f, POST_X);
	draw_collars(acc, f, WALNUT, 0.0);
	writing_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		open_book(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
