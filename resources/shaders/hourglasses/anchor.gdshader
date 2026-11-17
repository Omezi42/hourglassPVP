shader_type canvas_item;
// 錨(アンカー)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は太い船の綱を巻いた帆柱、板は丸窓のある船板。天板の上に綱を通した大きな錨。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 TEAK = vec3(0.50, 0.32, 0.20);
const vec3 ROPE = vec3(0.80, 0.68, 0.46);
const vec3 IRON = vec3(0.30, 0.32, 0.36);
const vec3 SEA = vec3(0.18, 0.36, 0.52);
const float MAST_R = 0.052;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec2 ANCHOR = vec2(0.0, 1.210);

void mast_post(inout vec4 acc, Px f, float cx) {
	draw_column(acc, f, cx, MAST_R, -POST_H, POST_H, TEAK, 0.0);
	// 綱を巻いた区間(上下)
	for (int k = -1; k <= 1; k += 2) {
		float y0 = float(k) * 0.52;
		vec2 q = vec2(f.p.x - cx, f.p.y - y0);
		if (abs(q.x) > 0.07 + f.pad || abs(q.y) > 0.17 + f.pad) {
			continue;
		}
		float d = max(abs(q.x) - (MAST_R + 0.012), abs(q.y) - 0.16);
		float twist = fract(q.y / 0.026 + q.x / (MAST_R + 0.012) * 0.3);
		vec3 n = lathe_normal(clamp(q.x / (MAST_R + 0.012), -1.0, 1.0), (twist - 0.5) * 1.4);
		vec3 rc = shade_mat(mix(ROPE, mix(ROPE, sand_color, 0.35), step(abs(q.y), 0.03)), n, 0.0, 0.5, f.ao);
		part(acc, d, ink_of(ROPE), rc, f.ow * 0.8, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.028), IRON, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.066, 0.018), IRON, 1.0);
}

void hull_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, TEAK, 0.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float plank = abs(fract(q.y / 0.042 + 0.5) - 0.5);
	inlay(acc, d, TEAK * 0.6, (1.0 - smoothstep(0.03, 0.08, plank)) * step(abs(q.x), 0.80), f);
	// 丸窓: 真鍮の縁と海の色のガラス、真ん中だけ砂の色
	for (int k = -2; k <= 2; k++) {
		vec2 pq = q - vec2(float(k) * 0.30, 0.0);
		vec3 gc = k == 0 ? sand_color : SEA;
		inlay(acc, d, GOLD, cov(length(pq) - 0.040, f.px), f);
		inlay(acc, d, gc, cov(length(pq) - 0.028, f.px), f);
		inlay(acc, d, vec3(1.0), cov(sd_ellipse(pq - vec2(-0.010, 0.010), vec2(0.008, 0.004)), f.px) * 0.7, f);
	}
}

// 錨: 上の輪、横木(ストック)、軸、弧を描く腕と爪、輪に通した綱
void ship_anchor(inout vec4 acc, Px f) {
	vec2 q = f.p - ANCHOR;
	if (abs(q.x) > 0.20 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	float d_ring = abs(length(q - vec2(0.0, 0.125)) - 0.020) - 0.007;
	float d_stock = sd_round_box(q - vec2(0.0, 0.080), vec2(0.085, 0.010), 0.005);
	float d_shank = max(abs(q.x) - 0.012, max(-q.y - 0.085, q.y - 0.110));
	vec2 aq = q - vec2(0.0, -0.010);
	float d_arm = max(abs(length(aq) - 0.085) - 0.012, aq.y + 0.010);
	// 爪: 腕の両端の三角
	float d_fluke = 1e3;
	for (int s = -1; s <= 1; s += 2) {
		vec2 fq = q - vec2(float(s) * 0.080, -0.010);
		fq.x *= float(s);
		d_fluke = min(d_fluke, max(max(-fq.y - 0.004, fq.y - 0.045), abs(fq.x) - (0.026 - fq.y * 0.55)));
	}
	float d = min(min(min(d_ring, d_stock), d_shank), min(d_arm, d_fluke));
	vec3 n = normalize(vec3(sin(q.x * 30.0) * 0.3, 0.3, 0.85));
	part(acc, d, ink_of(IRON), shade_mat(IRON * 1.3, n, 1.0, 1.0, 1.0), f.ow, f.px);
	// 横木の両端の玉
	for (int s = -1; s <= 1; s += 2) {
		draw_ball(acc, f, ANCHOR + vec2(float(s) * 0.090, 0.080), 0.013, IRON * 1.4, 1.0);
	}
	// 輪に通した綱
	float d_rope = abs(length((q - vec2(0.0, 0.065)) * vec2(1.0, 1.5)) - 0.075) - 0.008;
	d_rope = max(d_rope, -(q.y - 0.065));
	d_rope = max(d_rope, q.y - 0.125);
	vec3 rc = mix(ROPE, ROPE * 0.75, step(0.5, fract((q.x + q.y) * 40.0)));
	part(acc, d_rope, ink_of(ROPE), mix(rc, sand_color, 0.25), f.ow * 0.5, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	mast_post(acc, f, -POST_X);
	mast_post(acc, f, POST_X);
	draw_collars(acc, f, IRON, 1.0);
	hull_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		ship_anchor(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
