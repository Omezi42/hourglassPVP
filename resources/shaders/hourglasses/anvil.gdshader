shader_type canvas_item;
// 金床(アンヴィル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は鋲を打った鍛鉄の角柱、板は叩き跡の残る鋼。天板の上に金槌を載せた金床と火の粉。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 IRON = vec3(0.40, 0.41, 0.45);
const vec3 STEEL = vec3(0.56, 0.58, 0.62);
const vec3 HOT = vec3(1.0, 0.56, 0.20);
const vec3 HANDLE = vec3(0.54, 0.38, 0.24);
const float POST_HALF = 0.058;
const vec2 SLAB_HALF = vec2(0.82, 0.084);
const vec2 ANVIL = vec2(0.0, 1.200);
const float ANVIL_K = 1.15;

void wrought_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(IRON, n, 0.8, 0.8, f.ao);
	// 叩き跡のむら
	c *= 0.88 + 0.2 * vnoise(f.p * vec2(40.0, 26.0) + cx);
	// 鋲
	vec2 rq = vec2(abs(lx) - 0.034, fract(f.p.y / 0.17) * 0.17 - 0.085);
	float rivet = length(rq) - 0.010;
	c = mix(c, shade_mat(STEEL, normalize(vec3(rq / 0.01 * 0.6, 0.7)), 1.0, 1.0, f.ao), cov(rivet, f.px) * step(abs(f.p.y), POST_H - 0.06));
	part(acc, d, ink_of(IRON), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), STEEL, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.072, 0.026), mix(IRON, HOT, 0.35), 1.0);
}

void steel_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, IRON, 1.0, 0.9);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 鎚目: 浅い丸いへこみ
	vec2 g = q / 0.050;
	vec2 cell = fract(g) - 0.5;
	float dent = smoothstep(0.42, 0.30, length(cell + (hash22(floor(g)) - 0.5) * 0.3));
	inlay(acc, d, STEEL * 0.9, dent * 0.35 * step(abs(q.x), 0.78) * smoothstep(0.03, 0.012, f.px), f);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.060) - 0.005);
	inlay(acc, d, STEEL, rim * step(abs(q.x), 0.78), f);
	inlay(acc, d, HOT, cov(length(q) - 0.036, f.px), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.024, f.px), f);
}

// 金床: 角の伸びた天面、くびれた胴、広い足、上に寝かせた金槌
void anvil_block(inout vec4 acc, Px f) {
	vec2 q = (f.p - ANVIL) / ANVIL_K;
	if (abs(q.x) > 0.24 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= ANVIL_K;
	f.ow /= ANVIL_K;
	float d_face = sd_round_box(q - vec2(0.020, 0.045), vec2(0.130, 0.026), 0.006);
	// 角(ホーン): 左へ細く尖る
	vec2 hq = q - vec2(-0.110, 0.050);
	float d_horn = max(abs(hq.y + hq.x * 0.25) - (0.022 + hq.x * 0.25), max(hq.x - 0.0, -hq.x - 0.090));
	float d_waist = max(abs(q.x - 0.020) - (0.050 + abs(q.y + 0.015) * 0.9), max(q.y - 0.020, -q.y - 0.060));
	float d_foot = sd_round_box(q - vec2(0.020, -0.075), vec2(0.105, 0.020), 0.006);
	float d = min(min(d_face, d_horn), min(d_waist, d_foot));
	vec3 n = normalize(vec3(0.0, q.y > 0.02 ? 0.6 : 0.0, 0.8));
	vec3 c = shade_mat(IRON * 1.15, n, 1.0, 1.0, 1.0);
	c = mix(c, STEEL * 1.25, step(0.060, q.y) * step(-0.110, q.x));
	part(acc, d, ink_of(IRON), c, f.ow, f.px);
	// 金槌
	vec2 mq = rot(q - vec2(0.060, 0.092), 0.18);
	float d_shaft = sd_round_box(mq - vec2(-0.040, 0.0), vec2(0.085, 0.009), 0.004);
	part(acc, d_shaft, ink_of(HANDLE), HANDLE, f.ow * 0.6, f.px);
	float d_head = sd_round_box(mq - vec2(0.055, 0.0), vec2(0.022, 0.030), 0.004);
	part(acc, d_head, ink_of(IRON), shade_mat(STEEL, normalize(vec3(0.0, mq.y / 0.03 * 0.6, 0.8)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
	// 天面に置いた赤熱の鉄片(砂の色)
	part(acc, sd_round_box(q - vec2(-0.040, 0.078), vec2(0.040, 0.008), 0.004), ink_of(HOT), mix(HOT, sand_color, 0.5), f.ow * 0.5, f.px);
}

// 火の粉
void art_back(inout vec4 acc, Px f) {
	vec2 q = f.p - (ANVIL + vec2(-0.040, 0.090));
	add_light(acc, HOT, exp(-dot(q, q) / 0.004) * 0.6);
	for (int k = 0; k < 6; k++) {
		vec2 sp = vec2(-0.12 + 0.05 * float(k), 0.05 + 0.03 * hash21(vec2(float(k), 3.0)));
		add_light(acc, mix(HOT, sand_color, 0.4), star4(q - sp, 0.026) * 0.8);
	}
}

void art_frame(inout vec4 acc, Px f) {
	wrought_post(acc, f, -POST_X);
	wrought_post(acc, f, POST_X);
	draw_collars(acc, f, STEEL, 1.0);
	steel_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		anvil_block(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
