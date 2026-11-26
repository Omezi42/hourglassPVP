shader_type canvas_item;
// 火の鳥(イグニス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は炎の羽根が駆け上がる金の柱、板は金に右へ駆ける火の筋と紅玉。天板の上で火の鳥が翼を大きく広げ、頭は駆ける向き(右)を向く。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 GOLD_DEEP = vec3(0.96, 0.74, 0.30);
const vec3 RUBY = vec3(0.92, 0.12, 0.20);
const float POST_R = 0.060;
const vec2 BIRD = vec2(0.02, 1.252);
const vec3 FLAME_RED = vec3(0.92, 0.22, 0.08);
const vec3 FLAME = vec3(1.0, 0.58, 0.10);
const vec3 FLAME_HOT = vec3(1.0, 0.96, 0.68);
const vec2 SLAB_HALF = vec2(0.82, 0.086);

// 右上へ駆ける火の筋1本。t は尾(0)から頭(1)までの位置
float comet(vec2 q, vec2 head, float len, float r, out float t) {
	vec2 dir = vec2(0.94, 0.34);
	vec2 pa = q - (head - dir * len);
	t = clamp(dot(pa, dir) / len, 0.0, 1.0);
	return length(pa - dir * len * t) - mix(r * 0.15, r, t * t);
}

// 烈砂の刻の印: 板の左右を右へ駆ける火の筋
void blaze_streaks(inout vec4 acc, Px f, float d, vec2 q) {
	if (abs(q.y) > 0.07) {
		return;
	}
	for (int k = 0; k < 6; k++) {
		float j = float(k % 3);
		float hx = k < 3 ? -0.16 - 0.20 * j : 0.33 + 0.20 * j;
		float t;
		float ds = comet(q, vec2(hx, 0.026), 0.17, 0.026, t);
		inlay(acc, d, FLAME_RED * 0.5, cov(ds - 0.007, f.px), f);
		inlay(acc, d, mix(FLAME_RED, FLAME, smoothstep(0.0, 0.7, t)), cov(ds, f.px), f);
		inlay(acc, d, FLAME_HOT, cov(ds + 0.008, f.px) * smoothstep(0.55, 0.9, t), f);
	}
}

// 炎の舌: 根元から先へ細り、先は上へ反る
float tongue(vec2 q, vec2 root, vec2 tip, float r0, out float t) {
	vec2 ba = tip - root;
	t = clamp(dot(q - root, ba) / dot(ba, ba), 0.0, 1.0);
	vec2 bend = vec2(0.0, 0.025 * t * t - 0.008 * sin(t * 9.0));
	return length(q - root - ba * t - bend) - mix(0.004, r0, pow(1.0 - t, 0.55));
}

void flame(inout vec4 acc, Px f, vec2 root, vec2 tip, float r0) {
	float t;
	float d = tongue(f.p, root, tip, r0, t);
	over(acc, FLAME_RED * 0.55, cov(d - 0.012, f.px));
	over(acc, FLAME_RED, cov(d - 0.006, f.px));
	over(acc, FLAME, cov(d, f.px));
	over(acc, FLAME_HOT, cov(d + 0.018, f.px) * smoothstep(0.8, 0.1, t));
}

// 金の柱に、上を向いた炎の羽根が段に重なる
void feather_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_R + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	float u = clamp(lx / POST_R, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	part(acc, d, ink_of(GOLD_DEEP), shade_mat(GOLD_DEEP, n, 1.0, 1.0, f.ao), f.ow, f.px);
	// 羽根: 縦に並ぶ尖った葉の形。先は上
	float row = 0.16;
	float ly = mod(f.p.y + 0.04, row) - row * 0.5;
	float w = 0.040 * (0.5 - ly / row);
	float d_leaf = max(abs(lx) - w, abs(ly) - row * 0.45);
	vec3 fc = mix(FLAME_RED, FLAME, smoothstep(-0.06, 0.05, ly));
	over(acc, FLAME_RED * 0.5, cov(d_leaf - 0.006, f.px) * cov(d, f.px));
	over(acc, shade_mat(fc, n, 0.0, 0.6, 1.0), cov(d_leaf, f.px) * cov(d, f.px));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.092, 0.032), GOLD_DEEP, 1.0);
}

void gold_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, GOLD_DEEP, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	blaze_streaks(acc, f, d, q);
	draw_ball(acc, f, vec2(0.0, cy), 0.034, RUBY, 0.3);
}

// 翼1枚: 付け根から外上へ扇に開く炎の羽根を4本。外の羽根から重ねる
void wing(inout vec4 acc, Px f, float s) {
	vec2 root = BIRD + vec2(s * 0.035, 0.015);
	flame(acc, f, root, BIRD + vec2(s * 0.46, 0.006), 0.034);
	flame(acc, f, root, BIRD + vec2(s * 0.42, 0.050), 0.036);
	flame(acc, f, root, BIRD + vec2(s * 0.33, 0.085), 0.036);
	flame(acc, f, root, BIRD + vec2(s * 0.20, 0.100), 0.032);
}

void firebird(inout vec4 acc, Px f) {
	if (abs(f.p.x) > 0.56 || f.p.y < PLATE_Y) {
		return;
	}
	wing(acc, f, -1.0);
	wing(acc, f, 1.0);
	// 胴と頭: 白く灼けた雫の胴に、右を向いた頭と金の嘴
	vec2 q = f.p - BIRD;
	float d_body = sd_ellipse(q - vec2(0.0, 0.005), vec2(0.050, 0.040));
	part(acc, d_body, FLAME_RED * 0.5, mix(FLAME, FLAME_HOT, smoothstep(0.04, -0.01, length(q))), f.ow * 0.8, f.px);
	vec2 hq = q - vec2(0.045, 0.052);
	part(acc, length(hq) - 0.028, FLAME_RED * 0.5, FLAME_HOT, f.ow * 0.8, f.px);
	float d_beak = sd_rhombus(hq - vec2(0.034, -0.004), vec2(0.020, 0.008));
	part(acc, d_beak, ink_of(GOLD_DEEP), GOLD_DEEP, f.ow * 0.6, f.px);
	over(acc, vec3(0.2, 0.05, 0.05), cov(length(hq - vec2(0.010, 0.006)) - 0.006, f.px));
	// 冠羽
	flame(acc, f, BIRD + vec2(0.035, 0.072), BIRD + vec2(0.0, 0.104), 0.018);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = vec2(f.p.x * 0.5, f.p.y - 1.29);
	add_light(acc, FLAME, exp(-dot(d, d) / 0.03) * 0.8 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	feather_post(acc, f, -POST_X);
	feather_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD_DEEP, 1.0);
	gold_slab(acc, f, f.side * PLATE_Y);
	firebird(acc, f);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
