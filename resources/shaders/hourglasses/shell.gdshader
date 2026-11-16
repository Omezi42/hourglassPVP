shader_type canvas_item;
// 貝(シェル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は真珠色の巻貝を伸ばしたもの、天板の上に帆立貝が開き、中に真珠がひと粒眠る。板は螺鈿。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PEARL = vec3(0.94, 0.90, 0.88);
const vec3 PEARL_SHADE = vec3(0.70, 0.66, 0.72);
const vec3 CORAL = vec3(0.90, 0.56, 0.50);
const float SPIRE_X = 0.68;
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const vec2 SCALLOP = vec2(0.0, 1.170);

// 螺鈿の虹色
vec3 nacre(vec2 p, float k) {
	float h = fract(vnoise(p * 6.0) * 1.5 + p.x * 0.8 + k);
	vec3 rainbow = 0.5 + 0.5 * cos(6.2832 * (h + vec3(0.0, 0.33, 0.67)));
	return mix(PEARL, mix(rainbow, sand_color, 0.5), 0.16);
}

// 巻貝の柱: 斜めの螺旋の段で太さが脈打つ
void conch_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.10 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float ph = fract((f.p.y + lx * 0.6) * 5.0);
	float r = 0.048 + 0.020 * smoothstep(0.0, 0.8, ph) * (1.0 - smoothstep(0.85, 1.0, ph));
	float d = max(abs(lx) - r, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), (ph - 0.5) * 0.8);
	vec3 c = shade_mat(nacre(f.p, cx), n, 0.0, 1.0, f.ao);
	float groove = 1.0 - smoothstep(0.0, 0.12, ph);
	c = mix(c, PEARL_SHADE * 0.8, groove * 0.7 * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(PEARL_SHADE), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), CORAL, 0.0);
}

void nacre_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.04, PEARL_SHADE, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	inlay(acc, d, nacre(q * vec2(1.0, 3.0), cy), step(abs(q.y), 0.050) * step(abs(q.x), 0.76), f);
	// 珊瑚色の波の縁
	float wave = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.058 - 0.006 * sin(q.x * 40.0)) - 0.005);
	inlay(acc, d, CORAL, wave * step(abs(q.x), 0.76), f);
	if (cy < 0.0) {
		draw_ball(acc, f, vec2(0.0, cy), 0.036, PEARL, 0.4);
	}
}

// 帆立貝: 扇の肋と、手前で眠る真珠
void scallop(inout vec4 acc, Px f) {
	vec2 q = f.p - SCALLOP;
	if (abs(q.x) > 0.24 + f.pad || q.y < -0.04 - f.pad || q.y > 0.22 + f.pad) {
		return;
	}
	float r = length(q);
	float ang = atan(q.x, q.y);
	float d_fan = max(r - 0.20 - 0.010 * cos(ang * 18.0), abs(ang) - 1.15);
	d_fan = max(d_fan, -q.y);
	float rib = abs(fract(ang / 2.3 * 9.0) - 0.5);
	vec3 n = normalize(vec3(sin(ang) * 0.5, 0.4, 0.75));
	vec3 c = shade_mat(nacre(q * 2.0, 0.3), n, 0.0, 1.0, 1.0);
	c = mix(c * 0.78, c, smoothstep(0.08, 0.30, rib));
	part(acc, d_fan, ink_of(PEARL_SHADE), c, f.ow, f.px);
	// 蝶番の耳
	float d_ear = sd_round_box(q - vec2(0.0, 0.012), vec2(0.07, 0.022), 0.008);
	part(acc, d_ear, ink_of(PEARL_SHADE), shade_mat(PEARL, normalize(vec3(0.0, 0.3, 0.9)), 0.0, 1.0, 1.0), f.ow * 0.8, f.px);
	draw_ball(acc, f, SCALLOP + vec2(0.0, 0.075), 0.040, mix(PEARL, sand_color, 0.35), 0.4);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	conch_post(acc, f, -SPIRE_X);
	conch_post(acc, f, SPIRE_X);
	draw_collars(acc, f, CORAL, 0.0);
	nacre_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		scallop(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
