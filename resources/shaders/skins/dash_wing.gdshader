shader_type canvas_item;
// スキン「天翼」(ダッシュ)。GameDesign.md 31章 / Architecture.md 10.19節。

#define SKIN_SAND_COLOR vec3(0.56, 0.88, 1.0)
#define SKIN_SAND_KIND 0
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_parts.gdshaderinc"

const vec3 SKY = vec3(0.34, 0.76, 0.84);
const vec3 PLUME = vec3(0.97, 0.98, 1.0);
const vec3 PLUME_SHADE = vec3(0.64, 0.74, 0.90);
const vec3 PLUME_INK = vec3(0.13, 0.18, 0.32);
const vec3 PLUME_LINE = vec3(0.46, 0.56, 0.74);
const float WING_POST_X = 0.62;
// 翼の腕(柱の頭から外の上へ)。羽根はこの腕から下へ垂れる。
const vec2 ARM0 = vec2(0.50, 0.80);
const vec2 ARM1 = vec2(0.82, 1.22);
const int FEATHERS = 7;
const int COVERTS = 4;

// 羽ばたきの角度(外へ開く向きが正)。砂が落ちている間は大きく羽ばたく。i は羽根の順で、内の羽根ほど遅れて動く。
float flap(float i) {
	float amp = 0.014 + 0.026 * flow;
	return 0.012 * flow + amp * sin(clock * (1.6 + 1.8 * flow) - i * 0.30);
}

// 羽根1枚の距離。q は根元からの位置、dir は向き。t は長さの位置(0〜1)、s は幅の位置(-1〜1、dir の左が正)。
float feather_d(vec2 q, vec2 dir, float len, float w, out float t, out float s) {
	float a = dot(q, dir);
	float c = dir.x * q.y - dir.y * q.x;
	t = a / len;
	float tc = clamp(t, 0.0, 1.0);
	float hw = w * sqrt(smoothstep(0.0, 0.22, tc)) * sqrt(max(1.0 - tc * tc * tc, 0.0));
	s = c / max(hw, 0.0001);
	float slope = w * 3.0 * tc * tc / max(len * sqrt(max(1.0 - tc * tc * tc, 0.02)), 0.0001);
	return max((abs(c) - hw) / sqrt(1.0 + slope * slope), max(-a, a - len));
}

// 風切り羽 k(0=外の最も長い羽根)。
float primary_d(vec2 lq, int k, out float t, out float s, out float w) {
	float u = 1.0 - float(k) / float(FEATHERS - 1);
	vec2 base = mix(ARM0, ARM1, u) - vec2(0.0, 0.03);
	float ang = mix(-0.36, -0.02, u) + flap(float(k)) * (0.4 + 0.6 * u);
	vec2 dir = vec2(sin(ang), -cos(ang));
	float len = mix(0.56, 1.86, pow(u, 1.1));
	w = mix(0.060, 0.074, u);
	return feather_d(lq - base, dir, len, w, t, s);
}

// 雨覆い k: 腕に沿った丸い羽根の列。
float covert_d(vec2 lq, int k, out vec2 sq) {
	float u = (float(k) + 0.3) / float(COVERTS);
	vec2 c = mix(ARM0, ARM1, u) - vec2(0.0, 0.12);
	vec2 cq = rot(lq - c, 0.16);
	sq = cq / vec2(0.066, 0.14);
	return sd_ellipse(cq, vec2(0.066, 0.14));
}

// 翼の面。光は左上から来るため、物の左側が明るい(s_phys は物の左が負)。
vec3 plume_color(float s_phys, float t, float w, float px) {
	float lit = smoothstep(-0.7, 0.5, -s_phys + 0.25);
	vec3 c = mix(PLUME_SHADE, PLUME, lit);
	c = mix(c, mix(sand_color, PLUME, 0.40), smoothstep(0.60, 1.0, t) * 0.60);
	float rachis = 1.0 - smoothstep(0.0, max(0.008, px * 0.8), abs(s_phys) * w - 0.003);
	c = mix(c, PLUME_LINE, rachis * 0.40 * smoothstep(0.1, 0.3, t) * (1.0 - smoothstep(0.70, 0.92, t)));
	// 砂が落ちている間、羽根を根元から先へ光が走る
	float run = fract(clock * 0.9 - t * 0.6 + w * 7.0);
	return mix(c, vec3(1.0), flow * 0.35 * exp(-pow((run - 0.5) / 0.06, 2.0)));
}

void draw_wing(inout vec4 acc, Px f, float side_x) {
	vec2 lp = vec2(f.p.x * side_x, f.p.y);
	if (lp.x < 0.28 || lp.y > 1.34 || lp.y < -0.86) {
		return;
	}
	// 翼全体が根元を軸に開く
	vec2 lq = ARM0 + rot(lp - ARM0, -flap(0.0) * 0.6);
	float t;
	float s;
	float w;
	vec2 sq;
	float d_arm = sd_segment(lq, ARM0, ARM1) - 0.060;
	// 外形は太い輪郭で囲い(縮めても形が読める)、中の重なりは細い線にする
	float d_all = d_arm;
	for (int k = 0; k < FEATHERS; k++) {
		d_all = min(d_all, primary_d(lq, k, t, s, w));
	}
	for (int k = 0; k < COVERTS; k++) {
		d_all = min(d_all, covert_d(lq, k, sq));
	}
	if (d_all > f.ow + f.px) {
		return;
	}
	over(acc, PLUME_INK, cov(d_all - f.ow, f.px));
	float line_w = max(0.007, f.px * 0.7);
	for (int k = 0; k < FEATHERS; k++) {
		float d = primary_d(lq, k, t, s, w);
		part(acc, d, PLUME_LINE, plume_color(s * side_x, t, w, f.px), line_w, f.px);
	}
	for (int k = 0; k < COVERTS; k++) {
		float d = covert_d(lq, k, sq);
		float lit = smoothstep(-0.7, 0.6, -sq.x * side_x + sq.y * 0.5);
		part(acc, d, PLUME_LINE, mix(PLUME_SHADE, PLUME, lit), line_w, f.px);
	}
	// 腕: 上の縁に金の縁取り
	vec2 ad = normalize(ARM1 - ARM0);
	float across = (ad.x * (lq.y - ARM0.y) - ad.y * (lq.x - ARM0.x)) / 0.060;
	vec3 arm_col = mix(PLUME_SHADE, PLUME, smoothstep(-0.8, 0.4, across));
	part(acc, d_arm, PLUME_LINE, arm_col, line_w, f.px);
	float edge = 1.0 - smoothstep(0.0, max(0.010, f.px), abs(across - 0.55) * 0.060 - 0.010);
	over(acc, shade_mat(GOLD, normalize(vec3(0.0, 0.6, 0.8)), 1.0, 1.0, 1.0), edge * cov(d_arm, f.px));
}

// 金の小さな翼に挟まれた宝石(板の中央と天板の上)
void winged_gem(inout vec4 acc, Px f, vec2 c, float k) {
	vec2 q = (f.p - c) / k;
	float pk = f.px / k;
	if (abs(q.x) > 0.36 + pk * 3.0 || abs(q.y) > 0.20 + pk * 3.0) {
		return;
	}
	float ow = f.ow / k;
	for (int j = 0; j < 3; j++) {
		float i = float(j);
		vec2 wq = vec2(abs(q.x), q.y) - vec2(0.05, 0.0);
		float ang = 1.25 - 0.32 * i + 0.10 * sin(clock * 1.6 - i * 0.4) * (0.4 + 0.6 * flow);
		vec2 dir = vec2(sin(ang), cos(ang));
		float t;
		float s;
		float d = feather_d(wq, dir, 0.30 - 0.06 * i, 0.055, t, s);
		if (d < ow + pk) {
			vec3 n = normalize(vec3(-s * 0.5 * sign(q.x), 0.4, 0.8));
			part(acc, d, ink_of(GOLD), shade_mat(GOLD, n, 1.0, 1.0, 1.0), ow, pk);
		}
	}
	float d_gem = sd_rhombus(q, vec2(0.075, 0.11));
	part(acc, d_gem, ink_of(GOLD), GOLD, ow, pk);
	vec3 gem = mix(sand_color * 0.7, mix(sand_color, vec3(1.0), 0.7), step(q.x + q.y * 0.6, 0.0));
	over(acc, gem, cov(sd_rhombus(q, vec2(0.045, 0.072)), pk));
}

// 翼はガラスの後ろ(ガラスと柱の間からも羽根が見える)
void skin_back(inout vec4 acc, Px f) {
	draw_wing(acc, f, 1.0);
	draw_wing(acc, f, -1.0);
}

void skin_frame(inout vec4 acc, Px f) {
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -WING_POST_X : WING_POST_X;
		draw_column(acc, f, cx, 0.046, -1.02, 1.02, SKY, 0.35);
		draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.082, 0.032), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.880), vec2(0.062, 0.016), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, 0.0), vec2(0.064, 0.022), GOLD, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.055), vec2(0.056, 0.012), GOLD, 1.0);
	}
	draw_collars(acc, f, GOLD, 1.0);
	float d = draw_slab(acc, f, f.side * 1.098, vec2(0.74, 0.080), 0.04, SILVER, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.050) - 0.005);
	inlay(acc, d, GOLD, rim * step(abs(q.x), 0.70), f);
	if (f.p.y < 0.0) {
		winged_gem(acc, f, vec2(0.0, -1.098), 0.42);
	} else {
		winged_gem(acc, f, vec2(0.0, 1.255), 0.62);
	}
}

#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_main.gdshaderinc"
