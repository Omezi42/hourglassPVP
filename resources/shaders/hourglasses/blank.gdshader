shader_type canvas_item;
// 紋を削られた器(ブランク)。GameDesign.md 9章 / Architecture.md 10.19節。
// 飾りのない白い石の枠。柱の飾り枠も天板の上の楕円の紋章も、中身が削り取られて引っかき傷だけが残る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STONE = vec3(0.84, 0.82, 0.86);
const vec3 STONE_INK = vec3(0.34, 0.30, 0.40);
const vec3 SCRAPED = vec3(0.66, 0.62, 0.72);
const float POST_HALF = 0.056;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 MEDAL = vec2(0.0, 1.250);

// 削り跡: 斜めの細い引っかき傷
float scratches(vec2 q, float px) {
	float a = abs(fract((q.x * 0.8 + q.y) * 34.0 + vnoise(q * 9.0) * 0.6) - 0.5);
	float b = abs(fract((q.x * -0.6 + q.y) * 27.0 + 0.3) - 0.5);
	float fine = smoothstep(0.03, 0.012, px);
	return max(1.0 - smoothstep(0.03, 0.08, a), (1.0 - smoothstep(0.02, 0.06, b)) * 0.6) * fine;
}

void plain_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(STONE, n, 0.0, 0.4, f.ao);
	// 飾り枠(中は削られている)
	for (int j = 0; j < 2; j++) {
		vec2 cq = vec2(lx, f.p.y - (j == 0 ? 0.45 : -0.45));
		float d_frame = sd_round_box(cq, vec2(0.034, 0.14), 0.02);
		float rim = 1.0 - smoothstep(0.0, max(0.006, f.px), abs(d_frame) - 0.005);
		c = mix(c, STONE_INK, rim * 0.6);
		c = mix(c, mix(SCRAPED, SCRAPED * 0.8, scratches(cq + cx, f.px)), cov(d_frame + 0.006, f.px));
	}
	part(acc, d, STONE_INK, c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), STONE * 0.9, 0.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.072, 0.020), STONE * 0.9, 0.0);
}

void plain_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, STONE, 0.0, 0.4);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 帯の銘も削り取られている
	float d_band = sd_round_box(q, vec2(0.40, 0.034), 0.01);
	inlay(acc, d, STONE_INK, (1.0 - smoothstep(0.0, max(0.006, f.px), abs(d_band) - 0.004)) * 0.6, f);
	inlay(acc, d, mix(SCRAPED, SCRAPED * 0.8, scratches(q * 1.3 + cy, f.px)), cov(d_band + 0.006, f.px), f);
	inlay(acc, d, mix(sand_color, STONE, 0.3), cov(length(q - vec2(0.55, 0.0)) - 0.018, f.px) + cov(length(q + vec2(0.55, 0.0)) - 0.018, f.px), f);
}

// 楕円の紋章: 縁だけが残り、中は削られた跡と、隅に残った砂の色のかけら
void empty_medal(inout vec4 acc, Px f) {
	vec2 q = f.p - MEDAL;
	if (abs(q.x) > 0.16 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	float d_out = sd_ellipse(q, vec2(0.140, 0.110));
	vec3 n = normalize(vec3(q / vec2(0.14, 0.11) * 0.6, 0.75));
	part(acc, d_out, STONE_INK, shade_mat(STONE, n, 0.0, 0.5, 1.0), f.ow, f.px);
	float d_in = sd_ellipse(q, vec2(0.100, 0.074));
	over(acc, STONE_INK, cov(d_in, f.px) - cov(d_in + 0.006, f.px));
	over(acc, mix(SCRAPED, SCRAPED * 0.78, scratches(q * 1.6, f.px)), cov(d_in + 0.006, f.px));
	vec2 cq = q - vec2(0.055, 0.035);
	over(acc, sand_color, cov(sd_rhombus(rot(cq, 0.5), vec2(0.018, 0.012)), f.px));
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	plain_post(acc, f, -POST_X);
	plain_post(acc, f, POST_X);
	draw_collars(acc, f, STONE * 0.9, 0.0);
	plain_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		empty_medal(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
