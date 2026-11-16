shader_type canvas_item;
// 盾を越える長槍(パイク)。GameDesign.md 9章 / Architecture.md 10.19節。
// 器の後ろで2本の長槍が交差し、穂先が天板の上の左右へ抜ける。柱は角の鋼、板の中央に穂先の貫いた盾。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEEL = vec3(0.66, 0.70, 0.80);
const vec3 SHAFT = vec3(0.66, 0.46, 0.26);
const vec3 SLATE = vec3(0.34, 0.38, 0.54);
const float POST_HALF = 0.048;
const vec2 SLAB_HALF = vec2(0.80, 0.080);
const vec2 PIKE_FROM = vec2(-0.80, -1.20);
const vec2 PIKE_TO = vec2(0.84, 1.06);

// 長槍1本。a から b へ、b の先に穂先
void pike(inout vec4 acc, Px f, vec2 a, vec2 b) {
	vec2 dir = normalize(b - a);
	vec2 q = vec2(dot(f.p - a, vec2(dir.y, -dir.x)), dot(f.p - a, dir));
	float len = length(b - a);
	if (abs(q.x) > 0.08 + f.pad || q.y < -f.pad || q.y > len + 0.20 + f.pad) {
		return;
	}
	float d_shaft = max(abs(q.x) - 0.026, max(-q.y, q.y - len));
	vec3 n = lathe_normal(clamp(q.x / 0.026, -1.0, 1.0), 0.0);
	part(acc, d_shaft, ink_of(SHAFT), shade_mat(SHAFT, n, 0.0, 0.6, 1.0), f.ow * 0.8, f.px);
	// 穂先: 細長い菱形と根元の房
	vec2 hq = vec2(q.x, q.y - len - 0.10);
	float d_head = sd_rhombus(hq, vec2(0.058, 0.12));
	vec3 hc = mix(vec3(0.94, 0.96, 1.0), STEEL * 0.78, step(0.0, hq.x));
	part(acc, d_head, ink_of(SLATE), hc, f.ow * 0.8, f.px);
	draw_band(acc, f, a + dir * (len - 0.01), vec2(0.026, 0.026), sand_color, 0.0);
}

void square_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face < -0.5 ? -0.6 : (face > 0.5 ? 0.6 : 0.0), 0.0, 0.8));
	part(acc, d, ink_of(SLATE), shade_mat(STEEL, n, 1.0, 1.0, f.ao), f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.028), SLATE, 0.8);
	draw_band(acc, f, vec2(cx, f.side * 0.48), vec2(0.068, 0.016), SLATE, 0.8);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.068, 0.022), SLATE, 0.8);
}

void slate_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.025, SLATE, 0.6, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.052) - 0.005);
	inlay(acc, d, STEEL, rim * step(abs(q.x), 0.76), f);
	// 盾と、それを貫く穂先
	vec2 sq = q - vec2(0.0, 0.004);
	float d_shield = max(abs(sq.x) - 0.052 + max(-sq.y, 0.0) * 0.55, abs(sq.y) - 0.050);
	inlay(acc, d, STEEL, cov(d_shield, f.px), f);
	inlay(acc, d, mix(sand_color, SLATE, 0.3), cov(d_shield + 0.010, f.px), f);
	float d_spear = sd_rhombus(rot(sq, 0.6), vec2(0.016, 0.085));
	inlay(acc, d, SILVER, cov(d_spear, f.px), f);
}

// 交差する長槍は器の後ろ
void art_back(inout vec4 acc, Px f) {
	pike(acc, f, PIKE_FROM, PIKE_TO);
	pike(acc, f, PIKE_FROM * vec2(-1.0, 1.0), PIKE_TO * vec2(-1.0, 1.0));
}

void art_frame(inout vec4 acc, Px f) {
	square_post(acc, f, -POST_X);
	square_post(acc, f, POST_X);
	draw_collars(acc, f, SLATE, 0.8);
	slate_slab(acc, f, f.side * PLATE_Y);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
