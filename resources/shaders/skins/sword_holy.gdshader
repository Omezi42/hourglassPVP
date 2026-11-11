shader_type canvas_item;
// スキン「聖剣」(ソード)。GameDesign.md 31章 / Architecture.md 10.19節。

#define SKIN_SAND_COLOR vec3(1.0, 0.88, 0.66)
#define SKIN_SAND_KIND KIND_GLOW
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_parts.gdshaderinc"

const vec3 HOLY = vec3(1.0, 0.93, 0.72);
const float SWORD_X = 0.70;
const float BLADE_Y0 = -0.60;
const float TIP_START = 1.17;
const float SWORD_TIP = 1.37;
const float GUARD_Y = -0.62;
const float GRIP_TOP = -0.64;
const float GRIP_BOTTOM = -0.95;
const float POMMEL_Y = -0.968;

float holy_strength() {
	// 聖剣の光は上の砂(体力)が残っているほど強い
	return 0.35 + 0.65 * clamp(sand_top / 0.85, 0.0, 1.0);
}

void sword_aura(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, 0.05);
	float r = length(q * vec2(1.0, 0.80));
	float ang = atan(q.y, q.x);
	float rays = pow(0.5 + 0.5 * sin(ang * 8.0 + clock * 0.35), 12.0);
	float fall = exp(-max(r - 0.55, 0.0) / 0.20) * smoothstep(0.40, 0.70, r);
	float a = (0.16 + 0.30 * rays * smoothstep(0.03, 0.015, f.px)) * fall * holy_strength();
	add_light(acc, vec3(1.0, 0.86, 0.52), a * canvas_window(f.p));
}

void draw_sword(inout vec4 acc, Px f, float cx) {
	vec2 q = vec2(f.p.x - cx, f.p.y);
	if (abs(q.x) > 0.24 + f.pad || q.y > SWORD_TIP + f.pad || q.y < -1.03 - f.pad) {
		return;
	}
	vec3 ink = vec3(0.10, 0.11, 0.18);
	// 刃: 菱形の断面。左の面が明るく右が陰、中央に稜線
	float t = clamp((q.y - BLADE_Y0) / (TIP_START - BLADE_Y0), 0.0, 1.0);
	float w = mix(0.062, 0.048, t) * clamp((SWORD_TIP - q.y) / (SWORD_TIP - TIP_START), 0.0, 1.0);
	float d_blade = max((abs(q.x) - w) * 0.96, BLADE_Y0 - q.y);
	if (d_blade < f.ow + f.px) {
		float along = smoothstep(-0.6, 1.3, q.y);
		vec3 lit = mix(vec3(0.80, 0.84, 0.90), vec3(0.98, 0.99, 1.0), along);
		vec3 shade = mix(vec3(0.44, 0.48, 0.58), vec3(0.64, 0.68, 0.77), along);
		vec3 c = q.x < 0.0 ? lit : shade;
		float ridge = 1.0 - smoothstep(0.0, max(0.006, f.px * 0.8), abs(q.x));
		c = mix(c, vec3(1.0), ridge * 0.65);
		float bevel = 1.0 - smoothstep(0.0, max(0.010, f.px), abs(abs(q.x) - w * 0.72));
		c = mix(c, c * 0.82, bevel * 0.5 * step(0.0, q.x));
		c += HOLY * 0.10 * holy_strength();
		// 刃の上を光が昇っていく
		float gy = fract(clock * 0.16 + (cx > 0.0 ? 0.43 : 0.0)) * 3.4 - 1.0;
		float glint = exp(-pow((q.y - gy + q.x * 1.4) / 0.05, 2.0));
		c = mix(c, vec3(1.0, 0.98, 0.92), glint * 0.9);
		part(acc, d_blade, ink, min(c, vec3(1.0)), f.ow, f.px);
	}
	// 柄: 濃紺の革に金の巻き線
	vec2 hq = q - vec2(0.0, (GRIP_TOP + GRIP_BOTTOM) * 0.5);
	float d_grip = sd_round_box(hq, vec2(0.031, (GRIP_TOP - GRIP_BOTTOM) * 0.5), 0.012);
	if (d_grip < f.ow + f.px) {
		vec3 n = lathe_normal(clamp(q.x / 0.031, -1.0, 1.0), 0.0);
		float wrap = smoothstep(0.35, 0.65, abs(fract((q.y + q.x * 0.9) * 26.0) * 2.0 - 1.0));
		wrap = mix(0.5, wrap, smoothstep(0.03, 0.012, f.px));
		vec3 leather = shade_mat(vec3(0.86, 0.86, 0.92), n, 0.0, 0.6, 1.0);
		vec3 wire = shade_mat(GOLD, n, 1.0, 1.0, 1.0);
		part(acc, d_grip, ink, mix(leather, wire, wrap * 0.6), f.ow, f.px);
	}
	// 刃の根元の金具(葉の形の透かし)
	vec2 lq = q - vec2(0.0, GUARD_Y + 0.15);
	float d_leaf = max(sd_rhombus(lq, vec2(0.050, 0.15)), -sd_rhombus(lq - vec2(0.0, 0.02), vec2(0.020, 0.07)));
	if (d_leaf < f.ow + f.px) {
		vec3 n = normalize(vec3(lq.x * 6.0, lq.y * 1.5, 0.8));
		part(acc, d_leaf, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
	}
	// 鍔: 金の横木、両端は上へ反って玉で終わる、中央に砂の色の宝石
	vec2 gq = q - vec2(0.0, GUARD_Y);
	float bend = 0.9 * gq.x * gq.x;
	vec2 bq = vec2(gq.x, gq.y - bend);
	float d_bar = sd_round_box(bq, vec2(0.17, 0.026), 0.022);
	float d_end = length(vec2(abs(gq.x) - 0.185, gq.y - 0.9 * 0.185 * 0.185 - 0.012)) - 0.036;
	float d_mount = sd_rhombus(gq, vec2(0.060, 0.080));
	float d_guard = min(min(d_bar, d_end), d_mount);
	if (d_guard < f.ow + f.px) {
		vec3 n;
		if (d_end < min(d_bar, d_mount)) {
			vec2 e = vec2(abs(gq.x) - 0.185, gq.y - 0.9 * 0.185 * 0.185 - 0.012) * vec2(sign(gq.x), 1.0);
			n = normalize(vec3(e, sqrt(max(0.036 * 0.036 - dot(e, e), 0.0)) + 0.004));
		} else {
			n = normalize(vec3(gq.x * 2.0, bq.y / 0.026 * 0.7, 0.75));
		}
		part(acc, d_guard, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
		float d_gem = sd_rhombus(gq, vec2(0.034, 0.050));
		vec3 gem = mix(sand_color * 0.75, mix(sand_color, vec3(1.0), 0.65), step(gq.x + gq.y * 0.5, 0.0));
		over(acc, gem, cov(d_gem, f.px));
	}
	draw_ball(acc, f, vec2(cx, POMMEL_Y), 0.046, GOLD, 1.0);
}

void sword_tip_sparkle(inout vec4 acc, Px f, float cx) {
	float gy = fract(clock * 0.16 + (cx > 0.0 ? 0.43 : 0.0)) * 3.4 - 1.0;
	float k = exp(-pow((gy - SWORD_TIP + 0.06) / 0.10, 2.0));
	add_light(acc, vec3(1.0, 0.97, 0.88), star4(f.p - vec2(cx, SWORD_TIP - 0.04), 0.13) * k);
}

void skin_back(inout vec4 acc, Px f) {
	sword_aura(acc, f);
}

void skin_frame(inout vec4 acc, Px f) {
	draw_sword(acc, f, -SWORD_X);
	draw_sword(acc, f, SWORD_X);
	draw_collars(acc, f, SILVER, 1.0);
	float d = draw_slab(acc, f, f.side * 1.098, vec2(0.80, 0.078), 0.03, SILVER, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	float line = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.040) - 0.004);
	inlay(acc, d, GOLD * 1.05, line * step(abs(q.x), 0.72), f);
	float d_mark = sd_rhombus(q, vec2(0.075, 0.052));
	inlay(acc, d, GOLD, cov(d_mark, f.px), f);
	vec3 gem = mix(sand_color, vec3(1.0), 0.45 * step(q.x + q.y, 0.0));
	inlay(acc, d, gem, cov(sd_rhombus(q, vec2(0.044, 0.030)), f.px), f);
	sword_tip_sparkle(acc, f, -SWORD_X);
	sword_tip_sparkle(acc, f, SWORD_X);
}

// 光の粒がガラスの中をゆっくり昇る
void hook_cavity(inout vec3 cav, inout float cav_a, Px f, float u) {
	vec2 q = vec2(f.p.x, f.p.y - clock * 0.12);
	vec2 cell = floor(q / 0.13);
	vec2 c = (cell + 0.2 + 0.6 * hash22(cell + seed)) * 0.13;
	float tw = 0.5 + 0.5 * sin(clock * 3.0 + hash21(cell) * 6.28);
	float m = star4(q - c, 0.032 + 0.012 * tw) * step(0.55, hash21(cell + 4.0)) * tw;
	m *= smoothstep(0.032, 0.014, f.px) * holy_strength();
	cav = mix(cav, vec3(1.0, 0.97, 0.86), m * 0.9);
	cav_a = mix(cav_a, 1.0, m * 0.7);
}

#define HOOK_CAVITY
#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_main.gdshaderinc"
