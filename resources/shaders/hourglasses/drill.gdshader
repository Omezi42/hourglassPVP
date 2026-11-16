shader_type canvas_item;
// 掘り抜く錐(ドリル)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱はねじを切った鋼の軸、板は鋲を打った鉄に黄緑の塗り。天板の上に螺旋の溝を刻んだ錐の穂先。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STEEL = vec3(0.62, 0.66, 0.72);
const vec3 IRON = vec3(0.36, 0.38, 0.42);
const vec3 PAINT = vec3(0.70, 0.78, 0.30);
const float SCREW_R = 0.050;
const float THREAD_PITCH = 0.085;
const vec2 SLAB_HALF = vec2(0.80, 0.084);
const float BIT_BASE = 1.15;
const float BIT_TIP = 1.39;
const float BIT_HALF = 0.17;

// ねじの軸: 斜めの山と谷を交互に
void screw_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > SCREW_R + 0.02 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float u = clamp(lx / SCREW_R, -1.0, 1.0);
	float phase = fract((f.p.y + u * 0.025) / THREAD_PITCH);
	float crest = abs(phase - 0.5) * 2.0;
	float r = SCREW_R + 0.010 * (1.0 - crest);
	float d = max(abs(lx) - r, f.ay - POST_H);
	vec3 n = lathe_normal(u, (phase - 0.5) * 1.6);
	vec3 c = shade_mat(STEEL, n, 1.0, 1.0, f.ao);
	float fine = smoothstep(0.03, 0.012, f.px);
	c = mix(c, c * 0.55, (1.0 - smoothstep(0.0, 0.25, crest)) * fine * 0.8);
	part(acc, d, ink_of(IRON), c, f.ow, f.px);
	// 六角のナット(上下と中央)
	for (int j = 0; j < 3; j++) {
		float y = j == 0 ? 0.0 : (j == 1 ? 0.93 : -0.93);
		vec2 q = vec2(lx, f.p.y - y);
		float dn = sd_round_box(q, vec2(0.086, 0.036), 0.008);
		float face = abs(q.x) / 0.086;
		vec3 nn = normalize(vec3(face > 0.55 ? sign(q.x) * 0.6 : 0.0, 0.0, 0.8));
		part(acc, dn, ink_of(IRON), shade_mat(IRON * 1.35, nn, 1.0, 1.0, 1.0), f.ow, f.px);
	}
}

void riveted_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, IRON, 1.0, 0.8);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 黄緑に塗った帯と鋲の列
	float band = step(abs(q.y), 0.036) * step(abs(q.x), 0.74);
	inlay(acc, d, mix(PAINT, sand_color, 0.35), band, f);
	for (int k = -3; k <= 3; k++) {
		if (k == 0 && cy < 0.0) {
			continue;
		}
		draw_ball(acc, f, vec2(float(k) * 0.22, cy), 0.020, STEEL, 1.0);
	}
}

// 天板の上の錐: 円錐に螺旋の溝
void drill_bit(inout vec4 acc, Px f) {
	vec2 q = vec2(f.p.x, f.p.y - BIT_BASE);
	float h = BIT_TIP - BIT_BASE;
	if (abs(q.x) > BIT_HALF + f.pad || q.y < -f.pad || q.y > h + f.pad) {
		return;
	}
	float t = clamp(q.y / h, 0.0, 1.0);
	float w = BIT_HALF * (1.0 - t);
	float d = max(abs(q.x) - w, -q.y);
	float u = clamp(q.x / max(w, 0.001), -1.0, 1.0);
	float flute = fract(q.y / 0.055 + u * 0.35);
	vec3 n = lathe_normal(u, 0.4);
	vec3 c = shade_mat(STEEL, n, 1.0, 1.0, 1.0);
	c = mix(c, c * 0.45, (1.0 - smoothstep(0.0, 0.35, flute)) * smoothstep(0.03, 0.012, f.px));
	part(acc, d, ink_of(IRON), c, f.ow, f.px);
	// 根元の黄緑の襟
	draw_band(acc, f, vec2(0.0, BIT_BASE + 0.012), vec2(0.12, 0.020), PAINT, 0.3);
}

// 板の中央の六角ボルトの頭(黄緑の座金つき)
void bolt_head(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > 0.11 + f.pad || abs(q.y) > 0.11 + f.pad) {
		return;
	}
	vec3 wn = normalize(vec3(q / 0.09 * 0.5, 0.8));
	part(acc, length(q) - 0.074, ink_of(PAINT), shade_mat(mix(PAINT, sand_color, 0.35), wn, 0.3, 1.0, 1.0), f.ow, f.px);
	vec2 h = abs(q);
	float d_hex = max(h.x * 0.866 + h.y * 0.5, h.y) - 0.050;
	float face = q.x * 0.866 + q.y * 0.5;
	vec3 n = normalize(vec3(sign(face) * 0.35, sign(q.y) * 0.2, 0.85));
	part(acc, d_hex, ink_of(IRON), shade_mat(STEEL, n, 1.0, 1.0, 1.0), f.ow, f.px);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	screw_post(acc, f, -POST_X);
	screw_post(acc, f, POST_X);
	draw_collars(acc, f, IRON * 1.3, 1.0);
	riveted_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y < 0.0) {
		bolt_head(acc, f, -PLATE_Y);
	}
	if (f.p.y > PLATE_Y) {
		drill_bit(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
