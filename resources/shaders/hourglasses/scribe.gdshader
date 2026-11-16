shader_type canvas_item;
// 書記(スクライブ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は立てた羽根ペン、板は綴じ紐で留めた紙の束。天板の上に羽根ペンを挿したインク壺。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 PAPER = vec3(0.96, 0.92, 0.82);
const vec3 PAPER_INK = vec3(0.40, 0.32, 0.26);
const vec3 FEATHER = vec3(0.92, 0.88, 0.94);
const vec3 INK = vec3(0.16, 0.12, 0.24);
const vec3 CORD = vec3(0.56, 0.36, 0.62);
const float QUILL_X = 0.69;
const vec2 SLAB_HALF = vec2(0.80, 0.084);
const vec2 POT = vec2(-0.03, 1.215);

// 羽根ペン: 軸、羽、金の先
void quill(inout vec4 acc, Px f, float cx, float y0, float y1, float lean) {
	vec2 q = vec2(f.p.x - cx - (f.p.y - y0) * lean, f.p.y);
	if (abs(q.x) > 0.10 + f.pad || q.y < y0 - 0.08 - f.pad || q.y > y1 + f.pad) {
		return;
	}
	float t = clamp((q.y - y0) / (y1 - y0), 0.0, 1.0);
	// 羽(上6割)
	float vane_t = clamp((t - 0.35) / 0.65, 0.0, 1.0);
	float hw = 0.075 * sin(3.1416 * pow(vane_t, 0.7)) * step(0.35, t);
	float d_vane = max(abs(q.x + 0.012 * (1.0 - vane_t)) - hw, max(y0 + (y1 - y0) * 0.35 - q.y, q.y - y1));
	float barb = abs(fract((q.y - abs(q.x) * 1.4) * 22.0) - 0.5);
	vec3 vc = mix(FEATHER * 0.80, FEATHER, smoothstep(0.1, 0.35, barb) * smoothstep(0.03, 0.012, f.px) + 0.3);
	vc = mix(vc, mix(CORD, sand_color, 0.5), smoothstep(0.6, 1.0, vane_t) * 0.5);
	part(acc, d_vane, ink_of(CORD), vc * mix(0.85, 1.0, step(q.x, 0.0)), f.ow * 0.8, f.px);
	// 軸
	float d_shaft = max(abs(q.x) - 0.010, max(y0 - q.y, q.y - y1));
	part(acc, d_shaft, ink_of(CORD), FEATHER * 0.9, f.ow * 0.6, f.px);
	// 金のペン先
	vec2 nq = q - vec2(0.0, y0);
	float d_nib = max(abs(nq.x) - 0.018 * clamp((nq.y + 0.07) / 0.07, 0.0, 1.0), max(-nq.y - 0.07, nq.y));
	part(acc, d_nib, ink_of(GOLD), shade_mat(GOLD, normalize(vec3(sign(nq.x) * 0.4, 0.0, 0.9)), 1.0, 1.0, 1.0), f.ow * 0.7, f.px);
}

void paper_slab(inout vec4 acc, Px f, float cy) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 少しずつずれた紙の束
	float d = sd_round_box(q, SLAB_HALF, 0.012);
	float sheet = fract(q.y / 0.021);
	vec3 c = mix(PAPER * 0.86, PAPER, smoothstep(0.0, 0.35, sheet));
	c = mix(c, PAPER * 0.80, smoothstep(0.72, 0.80, abs(q.x) / SLAB_HALF.x) * 0.5);
	part(acc, d, PAPER_INK, c, f.ow, f.px);
	// 綴じ紐と結び目
	for (int i = 0; i < 2; i++) {
		float x = i == 0 ? -0.52 : 0.52;
		float d_cord = sd_round_box(q - vec2(x, 0.0), vec2(0.016, SLAB_HALF.y + 0.006), 0.008);
		part(acc, d_cord, ink_of(CORD), CORD, f.ow * 0.7, f.px);
	}
	// 中央の封蝋
	vec3 gn = normalize(vec3(q / 0.05 * 0.6, 0.8));
	float d_seal = length(q) - 0.046 - 0.005 * sin(atan(q.y, q.x) * 9.0);
	part(acc, d_seal, ink_of(sand_color), shade_mat(sand_color, gn, 0.0, 1.0, 1.0), f.ow * 0.7, f.px);
}

// インク壺: 黒い硝子の壺と、挿した羽根ペン
void inkwell(inout vec4 acc, Px f) {
	quill(acc, f, POT.x + 0.02, POT.y + 0.02, POT.y + 0.16, 1.1);
	vec2 q = f.p - POT;
	if (abs(q.x) > 0.11 + f.pad || abs(q.y) > 0.09 + f.pad) {
		return;
	}
	float d_body = sd_round_box(q - vec2(0.0, -0.01), vec2(0.085, 0.050), 0.030);
	float d_neck = sd_round_box(q - vec2(0.0, 0.045), vec2(0.040, 0.016), 0.006);
	float d = min(d_body, d_neck);
	vec3 n = normalize(vec3(q / 0.09 * 0.6, 0.75));
	part(acc, d, vec3(0.04), shade_mat(INK, n, 0.4, 1.0, 1.0), f.ow, f.px);
	over(acc, vec3(1.0), cov(sd_ellipse(q - vec2(-0.045, 0.0), vec2(0.010, 0.022)), f.px) * 0.7);
}

void art_back(inout vec4 acc, Px f) {
}

void art_frame(inout vec4 acc, Px f) {
	quill(acc, f, -QUILL_X, -0.98, 1.00, 0.0);
	quill(acc, f, QUILL_X, -0.98, 1.00, 0.0);
	draw_collars(acc, f, CORD, 0.0);
	paper_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		inkwell(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
