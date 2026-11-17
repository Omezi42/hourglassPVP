shader_type canvas_item;
// 光輪(ハロー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 白い柱に羽根の紋を重ね、板にはステンドグラス。天板の上に浮かぶ光の輪と小さな翼。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PEARL = vec3(0.92, 0.92, 0.96);
const vec3 LEAD = vec3(0.20, 0.20, 0.26);
const vec3 HALO_LIGHT = vec3(1.0, 0.94, 0.70);
const float POST_R = 0.050;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 RING = vec2(0.0, 1.255);

// 羽根を重ねた白い柱
void feather_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.09 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(PEARL, n, 0.0, 1.0, f.ao);
	// 下向きに重なる羽根の鱗
	vec2 g = vec2(lx / 0.050, f.p.y / 0.070);
	float row = floor(g.y);
	vec2 cell = vec2(fract(g.x * 0.5 + 0.25 * mod(row, 2.0)) - 0.5, fract(g.y) - 1.0);
	float scale = length(cell * vec2(1.6, 1.0)) - 0.55;
	c = mix(c, mix(PEARL, sand_color, 0.35) * 0.82, (1.0 - smoothstep(0.0, 0.08, abs(scale))) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(PEARL * 0.6), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), GOLD, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.066, 0.018), GOLD, 1.0);
}

void stained_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, PEARL, 0.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 鉛の枠で区切った色ガラス
	vec2 g = q / vec2(0.090, 0.050);
	vec2 cell = floor(g);
	float h = hash21(cell);
	vec3 glass_col = h < 0.33 ? mix(sand_color, vec3(1.0), 0.2) : (h < 0.66 ? vec3(0.50, 0.66, 0.92) : vec3(0.96, 0.84, 0.50));
	float lead = max(step(0.44, abs(fract(g.x) - 0.5)), step(0.40, abs(fract(g.y) - 0.5)));
	float in_panel = step(abs(q.x), 0.74) * step(abs(q.y), 0.050);
	inlay(acc, d, glass_col, in_panel * (1.0 - lead), f);
	inlay(acc, d, LEAD, in_panel * lead, f);
	inlay(acc, d, GOLD, cov(length(q) - 0.034, f.px), f);
	inlay(acc, d, sand_color, cov(length(q) - 0.022, f.px), f);
}

// 光の輪: 斜めから見た金の環と、両脇の小さな翼
void halo_ring(inout vec4 acc, Px f) {
	vec2 q = f.p - RING;
	if (abs(q.x) > 0.26 + f.pad || abs(q.y) > 0.12 + f.pad) {
		return;
	}
	for (int s = -1; s <= 1; s += 2) {
		vec2 wq = vec2(q.x * float(s) - 0.150, q.y + 0.010);
		float d_wing = 1e3;
		for (int k = 0; k < 3; k++) {
			vec2 fq = rot(wq - vec2(0.020 * float(k), -0.010 * float(k)), -0.5 - 0.25 * float(k));
			d_wing = min(d_wing, sd_ellipse(fq, vec2(0.060 - 0.012 * float(k), 0.018)));
		}
		part(acc, d_wing, ink_of(PEARL * 0.7), shade_mat(PEARL, normalize(vec3(0.0, 0.4, 0.85)), 0.0, 0.8, 1.0), f.ow * 0.6, f.px);
	}
	vec2 eq = q / vec2(1.0, 0.36);
	float d_ring = (abs(length(eq) - 0.110) - 0.022) * 0.36;
	float front = step(q.y, 0.0);
	vec3 rc = mix(GOLD, mix(HALO_LIGHT, sand_color, 0.3), 0.4 + 0.4 * front);
	part(acc, d_ring, ink_of(GOLD), rc, f.ow * 0.6, f.px);
}

void art_back(inout vec4 acc, Px f) {
	vec2 q = (f.p - RING) / vec2(1.0, 0.5);
	float r = length(q);
	add_light(acc, mix(HALO_LIGHT, sand_color, 0.4), exp(-pow(r - 0.11, 2.0) / 0.0012) * 0.7 + exp(-r * r / 0.02) * 0.25);
}

void art_frame(inout vec4 acc, Px f) {
	feather_post(acc, f, -POST_X);
	feather_post(acc, f, POST_X);
	draw_collars(acc, f, GOLD, 1.0);
	stained_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		halo_ring(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
