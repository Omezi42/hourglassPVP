shader_type canvas_item;
// 井戸(ウェル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は煉瓦積み、板は厚い木の蓋。天板の上に屋根と滑車の付いた井戸と吊られた桶。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 BRICK = vec3(0.66, 0.36, 0.26);
const vec3 MORTAR = vec3(0.80, 0.76, 0.68);
const vec3 TIMBER = vec3(0.48, 0.34, 0.22);
const vec3 SLATE_ROOF = vec3(0.30, 0.34, 0.42);
const vec3 IRON = vec3(0.26, 0.27, 0.30);
const float POST_HALF = 0.060;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 WELL = vec2(0.0, 1.175);
const float WELL_K = 1.15;

void brick_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	vec2 g = vec2(lx / 0.060, f.p.y / 0.036);
	float row = floor(g.y);
	vec2 cell = vec2(fract(g.x + 0.5 * mod(row, 2.0)), fract(g.y));
	float mortar = max(step(0.86, cell.y), step(0.92, cell.x));
	vec3 bc = BRICK * (0.85 + 0.25 * hash21(vec2(floor(g.x + 0.5 * mod(row, 2.0)), row) + cx));
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.7 ? 0.6 : (face < -0.7 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(mix(bc, MORTAR, mortar * smoothstep(0.03, 0.012, f.px)), n, 0.0, 0.4, f.ao);
	part(acc, d, ink_of(BRICK), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.026), TIMBER, 0.0);
}

void lid_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, TIMBER, 0.0, 0.5);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float plank = abs(fract(q.y / 0.040 + 0.5) - 0.5);
	inlay(acc, d, TIMBER * 0.6, (1.0 - smoothstep(0.03, 0.08, plank)) * step(abs(q.x), 0.78), f);
	for (int s = -1; s <= 1; s += 2) {
		vec2 bq = q - vec2(float(s) * 0.50, 0.0);
		inlay(acc, d, IRON, cov(sd_round_box(bq, vec2(0.030, 0.060), 0.004), f.px), f);
		inlay(acc, d, SILVER, cov(length(bq - vec2(0.0, 0.030)) - 0.007, f.px) + cov(length(bq + vec2(0.0, 0.030)) - 0.007, f.px), f);
	}
	inlay(acc, d, sand_color, cov(length(q) - 0.032, f.px), f);
}

// 井戸: 石の井筒、2本の柱と三角屋根、滑車と縄、吊られた桶
void well_house(inout vec4 acc, Px f) {
	vec2 q = (f.p - WELL) / WELL_K;
	if (abs(q.x) > 0.20 + f.pad || q.y < -0.10 - f.pad || q.y > 0.19 + f.pad) {
		return;
	}
	f.px /= WELL_K;
	f.ow /= WELL_K;
	// 屋根
	vec2 rq = q - vec2(0.0, 0.140);
	float d_roof = max(abs(rq.x) * 0.45 + rq.y - 0.030, -rq.y - 0.012);
	d_roof = max(d_roof, abs(rq.x) - 0.150);
	part(acc, d_roof, ink_of(SLATE_ROOF), shade_mat(SLATE_ROOF, normalize(vec3(sign(rq.x) * 0.3, 0.5, 0.8)), 0.0, 0.6, 1.0), f.ow * 0.8, f.px);
	// 柱と横木
	for (int s = -1; s <= 1; s += 2) {
		float d_p = max(abs(q.x - float(s) * 0.095) - 0.010, max(-q.y, q.y - 0.130));
		part(acc, d_p, ink_of(TIMBER), TIMBER, f.ow * 0.6, f.px);
	}
	part(acc, max(abs(q.y - 0.105) - 0.007, abs(q.x) - 0.105), ink_of(TIMBER), TIMBER * 1.2, f.ow * 0.6, f.px);
	// 縄と桶
	part(acc, max(abs(q.x) - 0.003, max(-q.y + 0.050, q.y - 0.105)), vec3(0.1), vec3(0.82, 0.72, 0.50), f.ow * 0.3, f.px);
	draw_ball(acc, f, WELL + vec2(0.0, 0.105) * WELL_K, 0.016 * WELL_K, SILVER, 1.0);
	vec2 bq = q - vec2(0.0, 0.032);
	float d_bucket = max(abs(bq.x) - (0.026 - bq.y * 0.2), abs(bq.y) - 0.020);
	part(acc, d_bucket, ink_of(TIMBER), mix(TIMBER * 1.2, sand_color, step(0.012, bq.y)), f.ow * 0.6, f.px);
	// 石の井筒
	vec2 wq = q - vec2(0.0, -0.030);
	float d_wall = sd_round_box(wq, vec2(0.130, 0.042), 0.010);
	vec2 g = vec2(wq.x / 0.044, wq.y / 0.028);
	float row = floor(g.y);
	float joint = max(step(0.88, fract(g.y)), step(0.92, fract(g.x + 0.5 * mod(row, 2.0))));
	vec3 sc = mix(MORTAR * 0.92, MORTAR * 0.6, joint * smoothstep(0.03, 0.012, f.px));
	part(acc, d_wall, ink_of(MORTAR * 0.6), shade_mat(sc, normalize(vec3(wq.x / 0.13 * 0.5, 0.0, 0.85)), 0.0, 0.4, 1.0), f.ow, f.px);
	part(acc, sd_ellipse(wq - vec2(0.0, 0.042), vec2(0.130, 0.012)), ink_of(MORTAR * 0.6), mix(sand_color, vec3(0.1), 0.3), f.ow * 0.6, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	brick_post(acc, f, -POST_X);
	brick_post(acc, f, POST_X);
	draw_collars(acc, f, TIMBER, 0.0);
	lid_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		well_house(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
