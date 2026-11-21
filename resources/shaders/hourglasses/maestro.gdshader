shader_type canvas_item;
// 指揮者(マエストロ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は先を突き合わせた2本の指揮棒、板には両端に反復記号を置いた五線。天板の上に開いた総譜と指揮棒。後ろに舞台の照明。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 EBONY = vec3(0.13, 0.11, 0.14);
const vec3 IVORY = vec3(0.95, 0.91, 0.82);
const vec3 SHAFT = vec3(0.92, 0.92, 0.95);
const vec3 CORK = vec3(0.62, 0.42, 0.26);
const vec3 VELVET = vec3(0.62, 0.12, 0.22);
const vec3 SPOT = vec3(1.0, 0.95, 0.86);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float BATON_TIP_R = 0.012;
const float BATON_BASE_R = 0.034;
const float GRIP_Y = 0.86;
const vec2 GRIP_HALF = vec2(0.050, 0.075);
const vec2 SCORE = vec2(0.0, 1.268);
const float SCORE_K = 1.42;

// 指揮棒の柱: 中央で先が触れ合い、端へ向けて太り、端に木の握り
void baton_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float t = smoothstep(0.02, GRIP_Y, f.ay);
	float r = mix(BATON_TIP_R, BATON_BASE_R, t);
	float d = max(abs(lx) - r, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(SHAFT, n, 0.1, 1.0, f.ao);
	// 砂の色の細い螺旋
	float sp = abs(fract(f.p.y * 4.0 + lx / r * 0.25) - 0.5);
	c = mix(c, sand_color * 0.85, (1.0 - smoothstep(0.02, 0.06, sp)) * step(0.15, f.ay) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(SHAFT) * 0.6, c, f.ow, f.px);
	// 木の握り
	vec2 gq = vec2(lx, f.p.y - f.side * GRIP_Y);
	float d_grip = sd_ellipse(gq, GRIP_HALF);
	vec3 gn = normalize(vec3(gq / GRIP_HALF * 0.7, 0.7));
	part(acc, d_grip, ink_of(CORK), shade_mat(CORK, gn, 0.0, 0.7, f.ao), f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), GOLD, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.765), vec2(0.040, 0.012), GOLD, 1.0);
	// 先が触れ合う所のきらめき
	add_light(acc, mix(sand_color, vec3(1.0), 0.5), star4(f.p - vec2(cx, 0.0), 0.075) * 0.9);
}

// 反復記号: 太い線・細い線・2つの点(right が真なら右向きの終わり)
float repeat_sign(vec2 q, float right) {
	float s = right > 0.5 ? -1.0 : 1.0;
	float x = q.x * s;
	float thick = max(abs(x) - 0.008, abs(q.y) - 0.050);
	float thin = max(abs(x - 0.020) - 0.003, abs(q.y) - 0.050);
	float dot_a = length(vec2(x - 0.040, q.y - 0.016)) - 0.008;
	float dot_b = length(vec2(x - 0.040, q.y + 0.016)) - 0.008;
	return min(min(thick, thin), min(dot_a, dot_b));
}

void staff_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, VELVET, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float lines = 0.0;
	for (int k = -2; k <= 2; k++) {
		float dl = max(abs(q.y - float(k) * 0.020) - 0.0025, abs(q.x) - 0.70);
		lines = max(lines, cov(dl, f.px));
	}
	inlay(acc, d, GOLD * 0.85, lines * 0.8, f);
	float signs = min(repeat_sign(q - vec2(-0.70, 0.0), 0.0), repeat_sign(q - vec2(0.70, 0.0), 1.0));
	inlay(acc, d, GOLD, cov(signs, f.px), f);
	// 中央に砂の色の音符が2つ(同じ音をもう一度)
	for (int k = -1; k <= 1; k += 2) {
		vec2 nq = q - vec2(float(k) * 0.07, -0.010);
		float d_head = sd_ellipse(rot(nq, 0.4), vec2(0.018, 0.012));
		float d_stem = max(abs(nq.x - 0.016) - 0.003, max(-nq.y, nq.y - 0.052));
		inlay(acc, d, mix(sand_color, vec3(1.0), 0.25), cov(min(d_head, d_stem), f.px), f);
	}
}

// 開いた総譜と、その上へ斜めに掛けた指揮棒
void score_and_baton(inout vec4 acc, Px f) {
	vec2 q = (f.p - SCORE) / SCORE_K;
	if (abs(q.x) > 0.24 + f.pad || abs(q.y) > 0.09 + f.pad) {
		return;
	}
	f.px /= SCORE_K;
	f.ow /= SCORE_K;
	// 2枚のページ(綴じ目へ向けて少し下がる)
	for (int s = -1; s <= 1; s += 2) {
		vec2 pq = vec2(q.x * float(s), q.y);
		vec2 lq = pq - vec2(0.080, -0.020 + pq.x * 0.12);
		float d_page = sd_round_box(lq, vec2(0.076, 0.040), 0.006);
		vec3 pc = shade_mat(IVORY, normalize(vec3(0.15 * float(s), 0.25, 0.95)), 0.0, 0.5, 1.0);
		float staff = 0.0;
		for (int k = -1; k <= 1; k++) {
			staff = max(staff, cov(max(abs(lq.y - float(k) * 0.018) - 0.0018, abs(lq.x) - 0.060), f.px));
		}
		pc = mix(pc, EBONY, staff * 0.7);
		part(acc, d_page, ink_of(IVORY) * 0.8, pc, f.ow * 0.7, f.px);
	}
	float d_spine = sd_round_box(q - vec2(0.0, -0.024), vec2(0.008, 0.040), 0.004);
	part(acc, d_spine, ink_of(VELVET), VELVET, f.ow * 0.6, f.px);
	// 指揮棒: 左下の象牙の握りから右上の細い先へ
	vec2 a = vec2(-0.190, -0.050);
	vec2 b = vec2(0.190, 0.042);
	float tt = clamp(dot(q - a, b - a) / dot(b - a, b - a), 0.0, 1.0);
	float r = mix(0.011, 0.004, tt);
	float d_rod = sd_segment(q, a, b) - r;
	part(acc, d_rod, ink_of(EBONY) * 0.5, mix(EBONY, SILVER, 0.25), f.ow * 0.6, f.px);
	float d_handle = sd_ellipse(rot(q - a, -0.39), vec2(0.030, 0.014));
	part(acc, d_handle, ink_of(IVORY), shade_mat(IVORY, normalize(vec3(0.0, 0.4, 0.9)), 0.0, 0.9, 1.0), f.ow * 0.7, f.px);
	add_light(acc, mix(sand_color, vec3(1.0), 0.4), star4(q - b, 0.060));
}

// 舞台の照明: 上から広がる光の円錐
void art_back(inout vec4 acc, Px f) {
	float y = 1.32 - f.p.y;
	float half_w = 0.14 + y * 0.24;
	float beam = 1.0 - smoothstep(half_w * 0.55, half_w, abs(f.p.x));
	float fade = 1.0 - smoothstep(0.6, 2.4, y);
	add_light(acc, mix(SPOT, sand_color, 0.25), beam * fade * 0.30 * canvas_window(f.p) * (1.0 - acc.a));
}

void art_frame(inout vec4 acc, Px f) {
	baton_post(acc, f, -POST_X);
	baton_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	staff_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		score_and_baton(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
