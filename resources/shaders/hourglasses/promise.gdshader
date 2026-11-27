shader_type canvas_item;
// 約束(プロミス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は羊皮紙を螺旋に巻きつけ朱の紐で縛った黒檀の軸、板は黒檀に金の縁と、文字の行を連ねた証文と朱の封蝋。
// 天板の上に大きな朱の封蝋が立ち、刻印の砂時計の下から二本の紐の端が垂れ、後ろに羽根ペンが斜めに差してある。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 EBONY = vec3(0.16, 0.12, 0.11);
const vec3 VELLUM = vec3(0.92, 0.86, 0.70);
const vec3 SCRIPT = vec3(0.30, 0.22, 0.16);
const vec3 CORD = vec3(0.74, 0.14, 0.12);
const vec3 QUILL = vec3(0.94, 0.94, 0.90);
const vec2 SLAB_HALF = vec2(0.82, 0.088);
const float POST_R = 0.058;
const float WRAP = 0.16;
// 天板の封蝋の中心と半径、紐の垂れる先、羽根ペンの根元と先
const vec2 SEAL = vec2(0.0, 1.292);
const float SEAL_R = 0.074;
const float TAIL_Y = 1.194;
const vec2 QUILL_A = vec2(0.150, 1.200);
const vec2 QUILL_B = vec2(-0.170, 1.372);

// 朱の封蝋: 縁の揺らいだ円盤に、刻印の砂時計
float seal_sd(vec2 p, float r) {
	float a = atan(p.y, p.x);
	return length(p) - r * (1.0 + 0.06 * sin(a * 7.0) + 0.03 * sin(a * 13.0 + 1.0));
}

// 羊皮紙を螺旋に巻きつけ、朱の紐で縛った黒檀の軸
void scroll_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) <= POST_R + f.pad && f.ay <= POST_H + f.pad) {
		float d = max(abs(lx) - POST_R, f.ay - POST_H);
		vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
		float turn = fract((f.p.y + lx * 1.2) / WRAP);
		vec3 sheet = mix(VELLUM * 0.82, VELLUM, smoothstep(0.0, 0.8, turn));
		part(acc, d, ink_of(VELLUM), shade_mat(sheet, n, 0.0, 0.3, f.ao), f.ow, f.px);
		over(acc, ink_of(VELLUM), cov(min(turn, 1.0 - turn) * WRAP - 0.003, f.px) * 0.6 * step(abs(lx), POST_R - 0.004));
		float line = abs(fract(turn * 4.0) - 0.5);
		over(acc, SCRIPT, smoothstep(0.08, 0.0, line) * step(0.2, turn) * step(turn, 0.8) * step(0.4, fract(lx * 30.0 + f.p.y * 4.0)) * 0.45 * step(abs(lx), POST_R - 0.01));
	}
	for (int k = 0; k < 2; k++) {
		float y = k == 0 ? 0.30 : 0.64;
		draw_band(acc, f, vec2(cx, f.side * y), vec2(POST_R + 0.006, 0.012), CORD, 0.0);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.086, 0.030), EBONY, 0.2);
	draw_band(acc, f, vec2(cx, f.side * 0.918), vec2(0.072, 0.008), GOLD, 1.0);
}

void ebony_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, EBONY, 0.2, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = sd_round_box(q, SLAB_HALF - vec2(0.020, 0.016), 0.02);
	inlay(acc, d, GOLD, cov(abs(rim) - 0.005, f.px), f);
	float sheet = sd_round_box(q - vec2(-0.04, 0.0), vec2(0.60, 0.050), 0.010);
	inlay(acc, d, ink_of(VELLUM), cov(sheet - 0.004, f.px), f);
	inlay(acc, d, VELLUM * mix(0.88, 1.0, vnoise(q * 30.0)), cov(sheet, f.px), f);
	for (int k = 0; k < 3; k++) {
		float y = 0.026 - 0.024 * float(k);
		float words = step(0.3, fract(q.x * 9.0 + hash21(vec2(floor(q.x * 9.0), float(k))) * 0.5));
		inlay(acc, d, SCRIPT, cov(abs(q.y - y) - 0.004, f.px) * words * step(-0.58, q.x) * step(q.x, 0.36 - 0.12 * float(k)), f);
	}
	vec2 s = q - vec2(0.48, -0.010);
	inlay(acc, d, ink_of(CORD), cov(seal_sd(s, 0.042) - 0.004, f.px), f);
	inlay(acc, d, mix(CORD, sand_color, 0.5), cov(seal_sd(s, 0.042), f.px), f);
	inlay(acc, d, CORD * 0.7, cov(abs(length(s) - 0.024) - 0.004, f.px), f);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.76 : 0.76, cy), 0.022, GOLD, 1.0);
	}
}

// 天板の上の朱の封蝋、垂れる紐、斜めに差した羽根ペン
void wax_seal(inout vec4 acc, Px f) {
	vec2 q = f.p;
	if (abs(q.x) > 0.30 || q.y < 1.16 || q.y > 1.40) {
		return;
	}
	vec2 qa = q - QUILL_A;
	vec2 dir = normalize(QUILL_B - QUILL_A);
	float along = dot(qa, dir);
	float across = dot(qa, vec2(-dir.y, dir.x));
	float len = length(QUILL_B - QUILL_A);
	float vane = mix(0.006, 0.040, smoothstep(0.08, 0.30, along)) * smoothstep(len + 0.01, len - 0.08, along);
	float d_vane = max(abs(across) - vane, max(0.06 - along, along - len));
	vec3 plume = QUILL * mix(0.82, 1.0, step(0.5, fract(along * 60.0 + abs(across) * 40.0)));
	part(acc, d_vane, ink_of(QUILL) * 1.4, plume, f.ow * 0.8, f.px);
	float d_shaft = max(abs(across) - 0.006, max(-along, along - len));
	part(acc, d_shaft, ink_of(QUILL), QUILL * 0.9, f.ow * 0.4, f.px);
	float d_nib = max(abs(across) - 0.006 * clamp(along / 0.05, 0.0, 1.0), max(-along, along - 0.06));
	part(acc, d_nib, ink_of(GOLD), GOLD, f.ow * 0.5, f.px);
	for (int k = 0; k < 2; k++) {
		float sx = k == 0 ? -1.0 : 1.0;
		float t = clamp((SEAL.y - q.y) / (SEAL.y - TAIL_Y), 0.0, 1.0);
		float x = sx * (0.018 + 0.040 * t) + 0.006 * sin(t * 9.0);
		float d_tail = max(abs(q.x - x) - 0.013, max(TAIL_Y - q.y + abs(q.x - x) * 0.9 - 0.004, q.y - SEAL.y));
		part(acc, d_tail, ink_of(CORD), CORD * mix(0.8, 1.05, t), f.ow * 0.7, f.px);
	}
	vec2 s = q - SEAL;
	float d_seal = seal_sd(s, SEAL_R);
	vec3 n = normalize(vec3(s / SEAL_R * 0.4, 0.85));
	vec3 wax = shade_mat(mix(CORD, sand_color, 0.5), n, 0.0, 1.0, 1.0);
	part(acc, d_seal, ink_of(CORD), wax, f.ow, f.px);
	float d_ring = abs(length(s) - SEAL_R * 0.72) - 0.005;
	over(acc, CORD * 0.6, cov(d_ring, f.px));
	vec2 g = vec2(abs(s.x), s.y);
	float d_glass = max(abs(g.x) - 0.030 * abs(s.y) / 0.036 - 0.004, abs(s.y) - 0.036);
	d_glass = min(d_glass, max(abs(s.x) - 0.030, abs(abs(s.y) - 0.038) - 0.005));
	over(acc, CORD * 0.55, cov(d_glass, f.px));
	over(acc, GOLD, cov(d_glass + 0.003, f.px) * 0.5);
	over(acc, vec3(1.0), cov(sd_segment(s, vec2(-0.040, 0.024), vec2(-0.022, 0.044)) - 0.005, f.px) * 0.5);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 1.2, f.p.y - 1.29);
	add_light(acc, sand_color, exp(-dot(d, d) / 0.012) * 0.40 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	scroll_post(acc, f, -POST_X);
	scroll_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	ebony_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		wax_seal(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
