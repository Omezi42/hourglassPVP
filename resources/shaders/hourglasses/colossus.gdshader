shader_type canvas_item;
// 巨像(コロッサス)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は鋲で留めた青銅の鎧板を重ねた脚、板は鋲打ちの青銅板。天板の上に、目の奥が砂の色に光る巨像の兜。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRONZE = vec3(0.62, 0.42, 0.24);
const vec3 PATINA = vec3(0.36, 0.60, 0.52);
const vec3 PLUME = vec3(0.62, 0.14, 0.16);
const float LEG_R = 0.062;
const vec2 SLAB_HALF = vec2(0.84, 0.090);
const vec2 HELM = vec2(0.0, 1.215);
const float HELM_K = 1.2;

// 緑青の浮いた青銅: 窪みほど緑が濃い
vec3 aged_bronze(vec2 p, float cavity) {
	float n = vnoise(p * 14.0) * 0.7 + vnoise(p * 37.0) * 0.3;
	return mix(BRONZE, PATINA, smoothstep(0.50, 0.95, n + cavity * 0.4) * 0.55);
}

void armored_leg(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > LEG_R + 0.03 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	// 鎧板の段: 1枚ごとに下端がわずかに張り出す
	float seg = 0.15;
	float u = fract((f.p.y + 0.02) / seg);
	float bulge = 0.010 * smoothstep(0.55, 1.0, 1.0 - u);
	float r = LEG_R + bulge;
	float d = max(abs(lx) - r, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), (0.5 - u) * 0.8);
	float seam = 1.0 - smoothstep(0.0, 0.10, min(u, 1.0 - u));
	vec3 c = shade_mat(aged_bronze(f.p, seam), n, 1.0, 0.9, f.ao);
	c *= 1.0 - 0.35 * seam * smoothstep(0.03, 0.012, f.px);
	// 板ごとの鋲
	float rivet_y = (fract((f.p.y + 0.02) / seg) - 0.14) * seg;
	float rivet = 0.0;
	for (int s = -1; s <= 1; s += 2) {
		rivet = max(rivet, cov(length(vec2(lx - float(s) * r * 0.55, rivet_y)) - 0.008, f.px));
	}
	c = mix(c, BRONZE * 1.5, rivet * step(abs(f.p.y), 0.82));
	part(acc, d, ink_of(BRONZE), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.094, 0.030), BRONZE, 1.0);
}

void riveted_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, BRONZE, 1.0, 0.9);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 縁の鋲の列
	float rx = q.x - floor(q.x / 0.080 + 0.5) * 0.080;
	float rivet = cov(length(vec2(rx, abs(q.y) - 0.060)) - 0.010, f.px) * step(abs(q.x), 0.80);
	inlay(acc, d, BRONZE * 1.6, rivet, f);
	inlay(acc, d, BRONZE * 0.5, step(abs(abs(q.x) - 0.12), 0.006) * step(abs(q.y), 0.046), f);
	// 中央の砂の色の宝玉
	inlay(acc, d, BRONZE * 1.4, cov(sd_rhombus(q, vec2(0.070, 0.050)), f.px), f);
	inlay(acc, d, sand_color, cov(sd_rhombus(q, vec2(0.050, 0.034)), f.px), f);
}

// 兜: 丸い鉢、頬当て、T字の覗き穴、鼻当て、頭頂から後ろへ流れる馬毛の飾り
void colossus_helm(inout vec4 acc, Px f) {
	vec2 q = (f.p - HELM) / HELM_K;
	if (abs(q.x) > 0.20 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= HELM_K;
	f.ow /= HELM_K;
	// 馬毛の飾り(兜の後ろに描く)
	vec2 cq = q - vec2(0.0, 0.030);
	float ca = atan(cq.y, cq.x);
	float cr = length(cq);
	float d_crest = max(abs(cr - 0.080) - 0.020, -cq.y + 0.010);
	d_crest = max(d_crest, abs(cq.x) - 0.150);
	float strand = 0.85 + 0.15 * sin(ca * 70.0);
	part(acc, d_crest, ink_of(PLUME), shade_mat(mix(PLUME, sand_color, 0.25) * strand, normalize(vec3(cos(ca) * 0.4, sin(ca) * 0.4, 0.8)), 0.0, 0.5, 1.0), f.ow * 0.8, f.px);
	part(acc, sd_round_box(q - vec2(0.0, 0.092), vec2(0.016, 0.028), 0.006), ink_of(BRONZE), shade_mat(BRONZE, normalize(vec3(0.0, 0.3, 0.9)), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	// 鉢と頬当て
	vec2 hq = q - vec2(0.0, -0.005);
	float d_bowl = length(hq * vec2(1.0, 0.95)) - 0.090;
	float d_cheek = sd_round_box(hq - vec2(0.0, -0.050), vec2(0.072 - (hq.y + 0.05) * -0.25, 0.050), 0.020);
	float d_helm = min(d_bowl, d_cheek);
	vec3 n = normalize(vec3(hq.x / 0.09 * 0.7, hq.y / 0.09 * 0.5, 0.75));
	vec3 c = shade_mat(aged_bronze(q, 0.0), n, 1.0, 1.0, 1.0);
	// 額の帯
	c = mix(c, BRONZE * 1.35, step(abs(hq.y - 0.030), 0.008) * step(abs(hq.x), 0.085));
	part(acc, d_helm, ink_of(BRONZE), c, f.ow, f.px);
	// T字の覗き穴と鼻当て: 奥が砂の色に光る
	float d_eyes = sd_round_box(hq - vec2(0.0, 0.002), vec2(0.064, 0.012), 0.008);
	float d_mouth = sd_round_box(hq - vec2(0.0, -0.040), vec2(0.014, 0.038), 0.007);
	float d_slit = max(min(d_eyes, d_mouth), -sd_round_box(hq - vec2(0.0, -0.016), vec2(0.008, 0.030), 0.003));
	vec3 inner = mix(vec3(0.05, 0.03, 0.04), sand_color, 0.5 + 0.5 * step(abs(hq.y - 0.002), 0.012) * smoothstep(0.064, 0.020, abs(hq.x)));
	part(acc, d_slit, vec3(0.04), inner, f.ow * 0.5, f.px);
}

void art_back(inout vec4 acc, Px f) {
	for (int s = -1; s <= 1; s += 2) {
		vec2 q = f.p - (HELM + vec2(float(s) * 0.041, -0.004));
		add_light(acc, sand_color, exp(-dot(q, q) / 0.0012) * 0.7);
	}
}

void art_frame(inout vec4 acc, Px f) {
	armored_leg(acc, f, -POST_X);
	armored_leg(acc, f, POST_X);
	draw_collars(acc, f, BRONZE, 1.0);
	riveted_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		colossus_helm(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
