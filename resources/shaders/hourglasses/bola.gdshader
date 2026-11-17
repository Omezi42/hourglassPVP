shader_type canvas_item;
// 投げ錘(ボーラ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は革紐を巻いた狩りの杖、底板に巻いた縄。天板の上に、紐の先へ石の錘を3つ結んだボーラ。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 WOOD = vec3(0.54, 0.38, 0.22);
const vec3 CORD = vec3(0.78, 0.66, 0.44);
const vec3 STONE = vec3(0.50, 0.52, 0.60);
const vec3 INDIGO = vec3(0.28, 0.30, 0.66);
const float POST_R = 0.046;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 KNOT = vec2(0.0, 1.235);

void hunter_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(WOOD, n, 0.0, 0.5, f.ao);
	// 交差して巻いた藍の紐
	float x1 = fract((f.p.y + lx * 1.2) * 6.0);
	float x2 = fract((f.p.y - lx * 1.2) * 6.0);
	float lace = max(1.0 - smoothstep(0.0, 0.12, abs(x1 - 0.5) - 0.02), 1.0 - smoothstep(0.0, 0.12, abs(x2 - 0.5) - 0.02));
	c = mix(c, shade_mat(INDIGO, n, 0.0, 0.5, f.ao), lace * step(abs(f.p.y), 0.55) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(WOOD), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), INDIGO, 0.0);
	draw_band(acc, f, vec2(cx, f.side * 0.58), vec2(0.066, 0.016), INDIGO, 0.0);
}

void rope_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, WOOD, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 板に巻きつけた縄
	float twist = fract((q.x + q.y * 1.4) * 16.0);
	vec3 rc = mix(CORD * 0.72, CORD * 1.08, smoothstep(0.0, 0.4, twist) * (1.0 - smoothstep(0.6, 1.0, twist)));
	inlay(acc, d, rc, step(abs(q.y), 0.036) * step(abs(q.x), 0.76), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.030, f.px), f);
}

// ボーラ: 結び目から3本の紐、先に石の錘
void bola_weights(inout vec4 acc, Px f) {
	vec2 q = f.p - KNOT;
	if (abs(q.x) > 0.30 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	vec2 ends[3] = vec2[3](vec2(-0.21, -0.03), vec2(0.20, -0.04), vec2(0.03, 0.10));
	for (int k = 0; k < 3; k++) {
		float d_cord = sd_segment(q, vec2(0.0), ends[k]) - 0.007;
		part(acc, d_cord, ink_of(CORD), CORD, f.ow * 0.6, f.px);
	}
	for (int k = 0; k < 3; k++) {
		vec2 sq = q - ends[k];
		float r = k == 2 ? 0.040 : 0.048;
		vec3 n = normalize(vec3(sq / r * 0.7, 0.7));
		vec3 col = k == 1 ? mix(STONE, sand_color, 0.45) : STONE;
		part(acc, length(sq) - r, ink_of(STONE), shade_mat(col, n, 0.0, 0.6, 1.0), f.ow, f.px);
		// 錘を包む紐の網
		float net = step(abs(sq.x), 0.006) + step(abs(sq.y), 0.006);
		over(acc, ink_of(CORD) * 1.5, min(net, 1.0) * cov(length(sq) - r, f.px) * 0.6);
	}
	part(acc, length(q) - 0.020, ink_of(CORD), INDIGO, f.ow * 0.7, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	hunter_post(acc, f, -POST_X);
	hunter_post(acc, f, POST_X);
	draw_collars(acc, f, INDIGO, 0.0);
	rope_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		bola_weights(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
