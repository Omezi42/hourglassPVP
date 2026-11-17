shader_type canvas_item;
// 漂流(ドリフト)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は波に洗われた流木、板には打ち寄せる波。天板の上に波間で揺れる手紙入りの小瓶。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 DRIFTWOOD = vec3(0.70, 0.64, 0.56);
const vec3 SEA = vec3(0.20, 0.46, 0.62);
const vec3 FOAM = vec3(0.90, 0.95, 0.96);
const vec3 BOTTLE = vec3(0.46, 0.74, 0.62);
const float POST_R = 0.048;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 FLASK = vec2(0.0, 1.220);

void driftwood_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	// 曲がって節のある流木
	float bend = 0.014 * sin(f.p.y * 3.4 + cx * 4.0);
	float r = POST_R * (0.86 + 0.14 * vnoise(vec2(f.p.y * 6.0, cx)));
	float x = lx - bend;
	float d = max(abs(x) - r, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(x / r, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(DRIFTWOOD, n, 0.0, 0.4, f.ao);
	float grain = abs(fract(x * 40.0 + vnoise(vec2(x * 8.0, f.p.y * 1.5)) * 2.0) - 0.5);
	c = mix(c, DRIFTWOOD * 0.6, (1.0 - smoothstep(0.04, 0.14, grain)) * smoothstep(0.03, 0.012, f.px));
	// 節
	vec2 kq = vec2(x * 1.6, fract(f.p.y * 1.3 + cx) - 0.5);
	c = mix(c, DRIFTWOOD * 0.45, step(length(kq * vec2(1.0, 4.0)), 0.05));
	part(acc, d, ink_of(DRIFTWOOD), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.026), SEA, 0.0);
	// 巻きついた海藻の縄
	draw_band(acc, f, vec2(cx, f.side * 0.50), vec2(0.064, 0.018), mix(SEA, BOTTLE, 0.5), 0.0);
}

void wave_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, DRIFTWOOD, 0.0, 0.4);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 板に描いた波: 青い海と白い波頭
	float wave = 0.010 + 0.016 * sin(q.x * 18.0);
	inlay(acc, d, SEA, step(q.y, wave) * step(-0.054, q.y) * step(abs(q.x), 0.76), f);
	float crest = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(q.y - wave) - 0.005);
	inlay(acc, d, FOAM, crest * step(abs(q.x), 0.76), f);
	inlay(acc, d, sand_color, cov(length(q - vec2(0.0, -0.02)) - 0.028, f.px), f);
}

// 波間の小瓶: 斜めに浮かび、中に巻いた手紙、コルクの栓
void message_bottle(inout vec4 acc, Px f) {
	vec2 q0 = f.p - FLASK;
	if (abs(q0.x) > 0.28 + f.pad || abs(q0.y) > 0.16 + f.pad) {
		return;
	}
	float wy = -0.075 + 0.016 * sin(q0.x * 30.0);
	float d_wave = max(max(q0.y - wy, -q0.y - 0.115), abs(q0.x) - 0.26);
	vec2 q = rot(q0 - vec2(-0.01, 0.0), 0.28);
	float d_body = sd_round_box(q, vec2(0.130, 0.050), 0.040);
	float d_neck = sd_round_box(q - vec2(0.160, 0.0), vec2(0.040, 0.022), 0.008);
	vec3 n = normalize(vec3(0.0, q.y / 0.05 * 0.7, 0.7));
	part(acc, min(d_body, d_neck), ink_of(BOTTLE), shade_mat(BOTTLE, n, 0.0, 1.0, 1.0), f.ow, f.px);
	// 中の手紙(巻紙)と砂の色の封蝋
	float d_scroll = sd_round_box(q - vec2(-0.01, 0.0), vec2(0.075, 0.022), 0.010);
	part(acc, d_scroll, ink_of(FOAM), mix(vec3(0.94, 0.88, 0.72), vec3(0.80, 0.72, 0.54), step(0.0, q.y)), f.ow * 0.5, f.px);
	part(acc, length(q - vec2(-0.01, 0.0)) - 0.016, ink_of(sand_color), sand_color, f.ow * 0.4, f.px);
	float shine = step(abs(q.y - 0.030), 0.006) * step(abs(q.x + 0.02), 0.08);
	over(acc, vec3(1.0), shine * cov(d_body, f.px) * 0.7);
	part(acc, sd_round_box(q - vec2(0.215, 0.0), vec2(0.018, 0.020), 0.005), ink_of(DRIFTWOOD), vec3(0.62, 0.44, 0.26), f.ow * 0.6, f.px);
	// 小瓶を浮かべる波
	part(acc, d_wave, ink_of(SEA), mix(SEA, SEA * 1.3, smoothstep(-0.11, -0.07, q0.y)), f.ow * 0.6, f.px);
	float foam = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(q0.y - wy) - 0.006);
	over(acc, FOAM, foam * step(abs(q0.x), 0.26));
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	driftwood_post(acc, f, -POST_X);
	driftwood_post(acc, f, POST_X);
	draw_collars(acc, f, SEA, 0.0);
	wave_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		message_bottle(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
