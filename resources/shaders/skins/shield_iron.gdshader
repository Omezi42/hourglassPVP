shader_type canvas_item;
// スキン「鉄の大盾」(シールド)。GameDesign.md 31章 / Architecture.md 10.19節。

#define SKIN_SAND_COLOR vec3(0.30, 0.40, 0.72)
#define SKIN_SAND_KIND KIND_GRAIN
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_parts.gdshaderinc"

const vec3 STEEL = vec3(0.28, 0.38, 0.54);
const vec3 STEEL_RIM = vec3(0.42, 0.50, 0.63);
const vec3 WARD = vec3(0.55, 0.85, 1.0);
const float SHIELD_HALF_W = 0.965;
const float SHIELD_TOP = 1.255;
const float SHIELD_CURVE_Y = -0.10;
const float SHIELD_TIP_Y = -1.06;
const float RIM_W = 0.070;
const float RIVET_STEP = 0.205;
const float IRON_POST_X = 0.66;

// 結界の強さ。上の砂(体力)が残っているほど強い。
float ward_strength() {
	return 0.25 + 0.75 * clamp(sand_top / 0.85, 0.0, 1.0);
}

// 盾の半幅(下は丸く絞られて、下の板の後ろで尖る)
float shield_w(float y) {
	float k = clamp((y - SHIELD_TIP_Y) / (SHIELD_CURVE_Y - SHIELD_TIP_Y), 0.0, 1.0);
	return SHIELD_HALF_W * pow(k, 0.55);
}

float shield_d(vec2 p) {
	float w = shield_w(p.y);
	float dw = (shield_w(p.y + 0.004) - w) / 0.004;
	float d_side = (abs(p.x) - w) / sqrt(1.0 + dw * dw);
	float top = SHIELD_TOP - 0.10 * pow(p.x / SHIELD_HALF_W, 2.0);
	return max(d_side, max(p.y - top, SHIELD_TIP_Y - p.y));
}

// 縁に沿って並ぶ鋲への距離。idx は鋲の通し番号(光を順に渡すため)。
float rivet_field(vec2 p, out float idx) {
	float on_top = step(SHIELD_TOP - 0.10, p.y);
	float y_line = clamp(p.y, SHIELD_TIP_Y + 0.25, SHIELD_TOP - 0.06);
	float s = mix(SHIELD_TOP - y_line, abs(p.x), on_top);
	idx = floor(s / RIVET_STEP + 0.5);
	float center_s = idx * RIVET_STEP;
	vec2 c;
	if (on_top > 0.5) {
		c = vec2(sign(p.x) * center_s, SHIELD_TOP - 0.10 * pow(center_s / SHIELD_HALF_W, 2.0) - RIM_W * 0.5);
	} else {
		float cy = SHIELD_TOP - center_s;
		c = vec2(sign(p.x) * (shield_w(cy) - RIM_W * 0.5), cy);
	}
	return length(p - c);
}

void draw_shield(inout vec4 acc, Px f) {
	vec2 p = f.p;
	if (abs(p.x) > SHIELD_HALF_W + f.pad * 4.0 + 0.08 || p.y > SHIELD_TOP + 0.10 || p.y < SHIELD_TIP_Y - 0.08) {
		return;
	}
	float d = shield_d(p);
	// 結界: 盾の外形に沿った青い光
	float ward = exp(-max(d, 0.0) / 0.05) * step(0.0, d) * ward_strength() * (0.75 + 0.25 * sin(clock * 1.7));
	add_light(acc, WARD, ward * 0.55 * canvas_window(p));
	if (d > f.ow + f.px) {
		return;
	}
	// 面: 左右へゆるく曲がった鋼
	vec3 n = normalize(vec3(p.x / SHIELD_HALF_W * 0.55, 0.12, 0.82));
	vec3 face = shade_mat(STEEL, n, 0.22, 0.8, 1.0);
	// 磨いた鋼を照りの帯がゆっくり滑る
	float sweep = fract(clock * 0.09) * 3.6 - 1.8;
	float sheen = exp(-pow((p.x * 0.8 + p.y * 0.6 - sweep) / 0.10, 2.0));
	face = mix(face, vec3(0.92, 0.97, 1.0), sheen * 0.35);
	// 結界の六角の網(大きく描くときだけ)
	vec2 hq = p * vec2(1.0, 1.1547) / 0.16;
	vec2 hi = floor(hq + vec2(0.5 * mod(floor(hq.y), 2.0), 0.0));
	vec2 hl = fract(hq + vec2(0.5 * mod(floor(hq.y), 2.0), 0.0)) - 0.5;
	float hex = smoothstep(0.40, 0.48, max(abs(hl.x), abs(hl.y) * 0.9 + abs(hl.x) * 0.3));
	float pass = exp(-pow((length(p) - fract(clock * 0.22) * 1.9) / 0.18, 2.0));
	face = mix(face, WARD, hex * (0.06 + 0.35 * pass) * ward_strength() * smoothstep(0.03, 0.012, f.px));
	// 縁: 明るい鋼の帯と内側の金の線
	float rim = smoothstep(-RIM_W - f.px, -RIM_W, d);
	vec3 rim_n = normalize(vec3(p.x / SHIELD_HALF_W * 0.7, 0.3, 0.7));
	vec3 col = mix(face, shade_mat(STEEL_RIM, rim_n, 0.35, 1.0, 1.0), rim);
	float trim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(d + RIM_W + 0.020) - 0.007);
	col = mix(col, shade_mat(GOLD, n, 1.0, 1.0, 1.0), trim);
	// 中央の十字の金の帯(ガラスのくびれの左右に見える)
	float band = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(p.y) - 0.040);
	band *= step(d, -RIM_W);
	col = mix(col, shade_mat(GOLD, normalize(vec3(0.0, p.y / 0.04 * 0.6, 0.8)), 1.0, 1.0, 1.0), band);
	// ガラスの後ろは描かない(ガラス越しの砂を基本の絵と同じ明るさで読ませる)
	float gd = abs(p.x) - (glass_r(p.y) + 0.035);
	gd = max(gd, f.ay - (GLASS_H + 0.05));
	float keep = max(cov(-gd, f.px), step(-RIM_W, d));
	vec4 layer = vec4(0.0);
	part(layer, d, ink_of(STEEL) * 0.8, col, f.ow, f.px);
	layer.a *= keep;
	over(acc, layer.rgb, layer.a);
	// 鋲: 縁と十字の帯に並び、光が順に渡る
	float idx;
	float dr = rivet_field(p, idx);
	float rr = 0.020;
	float glint = exp(-pow((fract(clock * 0.25) * 12.0 - idx) / 0.7, 2.0));
	if (dr < rr + f.pad) {
		part(acc, dr - rr, ink_of(STEEL_RIM) * 0.8, mix(STEEL_RIM, vec3(1.0), 0.25 + 0.7 * glint), f.ow * 0.6, f.px);
	}
	for (int k = 0; k < 2; k++) {
		float bx = (k == 0 ? -1.0 : 1.0) * 0.80;
		float db = length(p - vec2(bx, 0.0)) - 0.024;
		part(acc, db, ink_of(GOLD), shade_mat(GOLD, normalize(vec3((p - vec2(bx, 0.0)) / 0.024 * 0.7, 0.7)), 1.0, 1.0, 1.0), f.ow * 0.6, f.px);
	}
}

void skin_back(inout vec4 acc, Px f) {
	draw_shield(acc, f);
}

void skin_frame(inout vec4 acc, Px f) {
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -IRON_POST_X : IRON_POST_X;
		draw_column(acc, f, cx, 0.050, -1.02, 1.02, STEEL * 0.85, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.088, 0.034), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.885), vec2(0.070, 0.016), STEEL_RIM, 1.0);
		draw_band(acc, f, vec2(cx, 0.0), vec2(0.078, 0.040), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.075), vec2(0.066, 0.014), STEEL_RIM, 1.0);
	}
	draw_collars(acc, f, STEEL_RIM, 1.0);
	float d = draw_slab(acc, f, f.side * 1.098, vec2(0.84, 0.082), 0.03, STEEL * 0.8, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.056) - 0.006);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.80), f);
	// 板の鋲の列
	float rx = mod(q.x + 0.05, 0.10) - 0.05;
	float dr = length(vec2(rx, q.y)) - 0.017;
	inlay(acc, d, STEEL_RIM, cov(dr, f.px) * step(abs(q.x), 0.76) * step(0.16, abs(q.x)), f);
	if (f.p.y < 0.0) {
		// 底板の中央: 金の小さな盾の紋
		vec2 mq = f.p - vec2(0.0, -1.098);
		float mw = 0.075 * pow(clamp((mq.y + 0.070) / 0.10, 0.0, 1.0), 0.55);
		float d_m = max(abs(mq.x) - mw, max(mq.y - 0.050, -0.070 - mq.y));
		part(acc, d_m, ink_of(GOLD), shade_mat(GOLD, normalize(vec3(mq.x / 0.075 * 0.6, 0.3, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
		over(acc, STEEL, cov(max(abs(mq.x) - mw * 0.55, max(mq.y - 0.028, -0.048 - mq.y)), f.px));
	}
}

#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_main.gdshaderinc"
