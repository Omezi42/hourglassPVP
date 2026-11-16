shader_type canvas_item;
// 塩の結晶(ソルト)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は四角い塩の結晶を積んだもの、板は白い岩塩。天板の上に結晶の小さな塊。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 SALT = vec3(0.92, 0.95, 0.97);
const vec3 SALT_SHADE = vec3(0.64, 0.74, 0.80);
const vec3 SALT_INK = vec3(0.26, 0.36, 0.44);
const float STACK_X = 0.68;
const int CUBES = 8;
const vec2 SLAB_HALF = vec2(0.82, 0.084);

// 塩の立方体を斜めから: 正面・上面・側面
void salt_cube(inout vec4 acc, Px f, vec2 c, float s, float tilt) {
	vec2 q = rot(f.p - c, tilt);
	if (abs(q.x) > s * 1.5 + f.pad || abs(q.y) > s * 1.5 + f.pad) {
		return;
	}
	float depth = s * 0.45;
	float d_front = sd_round_box(q - vec2(-depth * 0.3, -depth * 0.3), vec2(s), 0.006);
	vec2 tq = q - vec2(depth * 0.2, s - depth * 0.05);
	float d_top = max(abs(tq.x - tq.y * 0.6) - s, abs(tq.y) - depth * 0.55);
	vec2 sq = q - vec2(s - depth * 0.05, depth * 0.2);
	float d_side = max(abs(sq.y - sq.x * 0.6) - s, abs(sq.x) - depth * 0.55);
	float d = min(d_front, min(d_top, d_side));
	vec3 col = d_front <= min(d_top, d_side) ? mix(SALT_SHADE, SALT, 0.75) : (d_top < d_side ? SALT : SALT_SHADE * 0.95);
	// 結晶の段の筋
	float step_line = abs(fract(max(abs(q.x), abs(q.y)) / s * 2.0) - 0.5);
	col = mix(col * 0.88, col, smoothstep(0.08, 0.25, step_line));
	col = mix(col, mix(sand_color, vec3(1.0), 0.6), 0.15);
	part(acc, d, SALT_INK, col, f.ow * 0.8, f.px);
}

void salt_stack(inout vec4 acc, Px f, float cx) {
	if (abs(f.p.x - cx) > 0.13 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float span = 2.0 * POST_H / float(CUBES);
	int k = int(clamp(floor((f.p.y + POST_H) / span), 0.0, float(CUBES - 1)));
	for (int j = max(k - 1, 0); j <= min(k + 1, CUBES - 1); j++) {
		float y = -POST_H + span * (float(j) + 0.5);
		float sk = float(j) + cx * 4.0;
		float tilt = (hash21(vec2(sk, 3.0)) - 0.5) * 0.25;
		salt_cube(acc, f, vec2(cx + (hash21(vec2(sk, 1.0)) - 0.5) * 0.03, y), span * 0.36, tilt);
	}
}

void rock_salt_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, SALT * 0.94, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 岩塩の割れ目と、薄く差す砂の色
	vec2 g = q * vec2(6.0, 12.0) + cy;
	float vein = abs(vnoise(g) - 0.5);
	inlay(acc, d, SALT_SHADE, (1.0 - smoothstep(0.02, 0.06, vein)) * 0.7 * smoothstep(0.03, 0.012, f.px), f);
	inlay(acc, d, mix(sand_color, SALT, 0.45), smoothstep(0.55, 0.8, vnoise(q * 5.0 + 3.0)) * 0.5, f);
	salt_cube(acc, f, vec2(0.0, cy), 0.040, 0.0);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	salt_stack(acc, f, -STACK_X);
	salt_stack(acc, f, STACK_X);
	draw_collars(acc, f, SALT_SHADE, 0.3);
	rock_salt_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		salt_cube(acc, f, vec2(-0.10, 1.230), 0.048, 0.20);
		salt_cube(acc, f, vec2(0.08, 1.222), 0.040, -0.15);
		salt_cube(acc, f, vec2(-0.01, 1.300), 0.042, -0.05);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
