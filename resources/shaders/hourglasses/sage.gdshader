shader_type canvas_item;
// 賢者(セージ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は文字を刻んでねじれた樫の杖、板には星座。天板の上に眼鏡をかけた梟。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 OAK = vec3(0.46, 0.34, 0.22);
const vec3 INDIGO = vec3(0.16, 0.18, 0.36);
const vec3 STAR = vec3(0.96, 0.92, 0.74);
const vec3 OWL = vec3(0.62, 0.48, 0.34);
const float POST_R = 0.044;
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const vec2 PERCH = vec2(0.0, 1.188);
const float PERCH_K = 1.15;

void staff_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.08 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / POST_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(OAK, n, 0.0, 0.5, f.ao);
	// ねじれの溝
	float tw = abs(fract(f.p.y * 5.0 + lx / POST_R * 0.4) - 0.5);
	c = mix(c, OAK * 0.6, (1.0 - smoothstep(0.04, 0.12, tw)) * smoothstep(0.03, 0.012, f.px));
	// 光る刻み文字
	vec2 g = vec2(lx / 0.030, f.p.y / 0.045);
	float rune = step(abs(fract(g.y) - 0.5), 0.30) * step(abs(g.x), 0.4) * step(0.5, hash21(floor(g) + cx));
	c = mix(c, mix(sand_color, vec3(1.0), 0.3), rune * step(abs(f.p.y), 0.50) * step(0.25, abs(fract(g.y * 2.0) - 0.5)));
	part(acc, d, ink_of(OAK), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.026), INDIGO, 0.3);
	draw_band(acc, f, vec2(cx, f.side * 0.60), vec2(0.060, 0.016), GOLD, 1.0);
}

void constellation_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, INDIGO, 0.3, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	vec2 pts[6] = vec2[6](vec2(-0.66, -0.020), vec2(-0.50, 0.030), vec2(-0.34, -0.010), vec2(0.34, 0.020), vec2(0.50, -0.025), vec2(0.66, 0.025));
	float line = 0.0;
	float dots = 0.0;
	for (int k = 0; k < 6; k++) {
		dots = max(dots, cov(length(q - pts[k]) - 0.010, f.px));
		if (k != 2 && k != 5) {
			float ds = sd_segment(q, pts[k], pts[k + 1]);
			line = max(line, 1.0 - smoothstep(0.0, max(0.004, f.px), ds - 0.002));
		}
	}
	inlay(acc, d, STAR * 0.6, line, f);
	inlay(acc, d, STAR, dots, f);
	inlay(acc, d, sand_color, star4(q, 0.060), f);
}

// 梟: 丸い体、耳羽、大きな目と眼鏡、止まり木
void owl(inout vec4 acc, Px f) {
	vec2 q = (f.p - PERCH) / PERCH_K;
	if (abs(q.x) > 0.20 + f.pad || abs(q.y) > 0.16 + f.pad) {
		return;
	}
	f.px /= PERCH_K;
	f.ow /= PERCH_K;
	vec2 bq = q - vec2(0.0, -0.010);
	float d_body = sd_ellipse(bq, vec2(0.075, 0.085));
	vec2 hq = q - vec2(0.0, 0.065);
	float d_head = sd_ellipse(hq, vec2(0.070, 0.052));
	for (int s = -1; s <= 1; s += 2) {
		vec2 tq = q - vec2(float(s) * 0.050, 0.110);
		d_head = min(d_head, max(abs(tq.x) - 0.018 * (1.0 - tq.y / 0.040), max(-tq.y, tq.y - 0.040)));
	}
	vec3 n = normalize(vec3(bq / 0.08 * 0.6, 0.75));
	vec3 bc = shade_mat(OWL, n, 0.0, 0.5, 1.0);
	float belly = cov(sd_ellipse(bq - vec2(0.0, -0.015), vec2(0.046, 0.060)), f.px);
	float chev = step(0.6, fract(bq.y / 0.020 + abs(bq.x) * 20.0));
	bc = mix(bc, mix(vec3(0.94, 0.88, 0.76), OWL, chev * 0.5), belly);
	part(acc, min(d_body, d_head), ink_of(OWL), bc, f.ow, f.px);
	for (int s = -1; s <= 1; s += 2) {
		vec2 eq = q - vec2(float(s) * 0.030, 0.065);
		part(acc, length(eq) - 0.024, ink_of(OWL), vec3(0.98, 0.94, 0.80), f.ow * 0.5, f.px);
		over(acc, mix(sand_color, vec3(0.1), 0.2), cov(length(eq) - 0.012, f.px));
		over(acc, vec3(0.05), cov(length(eq) - 0.006, f.px));
		float d_rim = abs(length(eq) - 0.027) - 0.004;
		part(acc, d_rim, vec3(0.05), GOLD, f.ow * 0.3, f.px);
	}
	part(acc, sd_rhombus(q - vec2(0.0, 0.042), vec2(0.010, 0.014)), ink_of(GOLD), GOLD, f.ow * 0.4, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	staff_post(acc, f, -POST_X);
	staff_post(acc, f, POST_X);
	draw_collars(acc, f, INDIGO, 0.3);
	constellation_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		owl(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
