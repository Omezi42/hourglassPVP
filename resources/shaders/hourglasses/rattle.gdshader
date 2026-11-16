shader_type canvas_item;
// 振り鳴らし(ラトル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は木の玉を連ねた紐、天板の上に瓢箪の鳴子。板の中央に小さな鈴。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BEAD = vec3(0.72, 0.42, 0.26);
const vec3 BEAD_ALT = vec3(0.86, 0.70, 0.46);
const vec3 GOURD = vec3(0.84, 0.62, 0.30);
const vec3 WOOD = vec3(0.50, 0.32, 0.20);
const float STRING_X = 0.68;
const float BEAD_STEP = 0.135;
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const vec2 GOURD_AT = vec2(0.06, 1.245);

// 紐に連ねた玉: 大小を交互に
void bead_string(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d_cord = max(abs(lx) - 0.010, f.ay - POST_H);
	part(acc, d_cord, ink_of(WOOD), WOOD * 0.8, f.ow * 0.6, f.px);
	float k = floor(f.p.y / BEAD_STEP + 0.5);
	for (int j = -1; j <= 1; j++) {
		float kk = k + float(j);
		float y = kk * BEAD_STEP;
		if (abs(y) > POST_H - 0.04) {
			continue;
		}
		bool big = mod(kk, 2.0) == 0.0;
		float r = big ? 0.068 : 0.046;
		vec2 q = vec2(lx, f.p.y - y);
		if (length(q) > r + f.pad) {
			continue;
		}
		vec3 n = normalize(vec3(q, sqrt(max(r * r - dot(q, q), 0.0)) + 0.004));
		vec3 col = big ? BEAD : BEAD_ALT;
		part(acc, length(q) - r, ink_of(col), shade_mat(col, n, 0.0, 1.0, f.ao), f.ow, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.070, 0.024), WOOD, 0.0);
}

void wood_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, WOOD, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 斜めの刻みの帯
	float notch = abs(fract((q.x + q.y) * 10.0) - 0.5);
	inlay(acc, d, WOOD * 1.3, step(abs(q.y), 0.034) * step(abs(q.x), 0.76) * smoothstep(0.1, 0.25, notch), f);
	// 中央の鈴
	vec2 bq = q - vec2(0.0, -0.004);
	vec3 n = normalize(vec3(bq / 0.04 * 0.6, 0.8));
	part(acc, length(bq) - 0.040, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow * 0.8, f.px);
	over(acc, ink_of(GOLD), cov(sd_round_box(bq - vec2(0.0, -0.010), vec2(0.026, 0.005), 0.004), f.px));
}

// 瓢箪の鳴子: 柄と、くびれた胴に砂の色の帯
void gourd(inout vec4 acc, Px f) {
	if (length(f.p - GOURD_AT) > 0.30 + f.pad) {
		return;
	}
	vec2 q = rot(f.p - GOURD_AT, -1.45);
	float d_handle = sd_round_box(q - vec2(0.0, -0.11), vec2(0.018, 0.09), 0.012);
	part(acc, d_handle, ink_of(WOOD), shade_mat(WOOD, normalize(vec3(q.x / 0.018 * 0.6, 0.0, 0.8)), 0.0, 0.6, 1.0), f.ow * 0.8, f.px);
	float d_low = length(q - vec2(0.0, 0.035)) - 0.070;
	float d_up = length(q - vec2(0.0, 0.135)) - 0.050;
	float d = min(d_low, d_up);
	vec2 nq = d_low < d_up ? (q - vec2(0.0, 0.035)) / 0.07 : (q - vec2(0.0, 0.135)) / 0.05;
	vec3 n = normalize(vec3(nq * 0.7, 0.7));
	vec3 c = shade_mat(GOURD, n, 0.0, 1.0, 1.0);
	c = mix(c, mix(sand_color, GOURD, 0.3), step(abs(q.y - 0.035), 0.016));
	part(acc, d, ink_of(GOURD), c, f.ow, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	bead_string(acc, f, -STRING_X);
	bead_string(acc, f, STRING_X);
	draw_collars(acc, f, WOOD, 0.0);
	wood_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		gourd(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
