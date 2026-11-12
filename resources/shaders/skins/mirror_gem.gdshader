shader_type canvas_item;
// スキン「宝玉」(ミラー)。GameDesign.md 31章 / Architecture.md 10.19節。

#define SKIN_SAND_COLOR vec3(0.98, 0.40, 0.66)
#define SKIN_SAND_KIND KIND_CRYSTAL
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_parts.gdshaderinc"

const vec3 ROSE_GOLD = vec3(1.0, 0.70, 0.58);
const float GEM_POST_X = 0.68;
const vec2 POST_GEM_HALF = vec2(0.104, 0.160);

// 宝石の照りの向き。鏡のように、カーソルのある側の面が光る。
vec3 mirror_light() {
	vec2 l = look;
	if (length(l) > 1.0) {
		l = normalize(l);
	}
	return normalize(vec3(l * 0.9 + vec2(-0.25, 0.30), 0.75));
}

// 虹の帯がゆっくり宝石を渡る
vec3 prism(float t) {
	return 0.5 + 0.5 * cos(6.2832 * (t + vec3(0.0, 0.33, 0.67)));
}

float prism_band(vec2 p) {
	float x = p.x * 0.8 + p.y * 0.5 - (fract(clock * 0.10) * 4.0 - 2.0);
	return exp(-pow(x / 0.12, 2.0));
}

// 菱形に面を切った宝石。q は中心からの位置、hs は半分の大きさ。
vec3 cut_gem(vec2 q, vec2 hs, float px) {
	vec2 s = q / hs;
	float table = step(abs(s.x) + abs(s.y), 0.42);
	vec3 fn = table > 0.5 ? vec3(0.0, 0.0, 1.0) : normalize(vec3(sign(s.x) * 0.55, sign(s.y) * 0.55, 0.62));
	// 菱形の4面を上下でもう1度割る
	fn.x += (abs(s.y) < 0.5 * (1.0 - abs(s.x)) ? 0.0 : 0.18 * sign(s.x)) * (1.0 - table);
	fn = normalize(fn);
	float lit = clamp(dot(fn, mirror_light()), 0.0, 1.0);
	vec3 deep = sand_color * sand_color * 0.45;
	vec3 c = mix(deep, sand_color, smoothstep(0.15, 0.6, lit));
	c = mix(c, mix(sand_color, vec3(1.0), 0.75), smoothstep(0.72, 0.94, lit));
	c = mix(c, c * 0.6 + prism(s.x * 0.3 + clock * 0.05) * 0.6, prism_band(q / hs * 0.4) * 0.45);
	// 面の境目の細い光
	float edge_w = max(0.04, px / min(hs.x, hs.y) * 0.9);
	float seam = 1.0 - smoothstep(0.0, edge_w, abs(abs(s.x) + abs(s.y) - 0.42));
	seam = max(seam, (1.0 - smoothstep(0.0, edge_w, min(abs(s.x), abs(s.y)))) * (1.0 - table));
	return mix(c, vec3(1.0), seam * 0.35 * smoothstep(0.03, 0.012, px));
}

// 宝石に映る光の点。カーソルのある側へ寄る。
void gem_glint(inout vec4 acc, Px f, vec2 q, vec2 hs) {
	vec2 at = mirror_light().xy * hs * vec2(0.55, 0.45);
	add_light(acc, vec3(1.0, 0.97, 0.99), star4(q - at, min(hs.x, hs.y) * 1.3) * 0.9);
}

void post_gem(inout vec4 acc, Px f, vec2 c) {
	vec2 q = f.p - c;
	if (abs(q.x) > POST_GEM_HALF.x + 0.05 + f.pad || abs(q.y) > POST_GEM_HALF.y + 0.13 + f.pad) {
		return;
	}
	// 銀の台座: 宝石を囲む菱形の枠と、柱に沿って上下へ伸びる尖り
	float d_spike = sd_rhombus(q, vec2(0.056, POST_GEM_HALF.y + 0.125));
	vec3 sn = normalize(vec3(sign(q.x) * 0.6, sign(q.y) * 0.2, 0.75));
	part(acc, d_spike, ink_of(SILVER), shade_mat(SILVER, sn, 1.0, 1.0, 1.0), f.ow, f.px);
	float d_mount = sd_rhombus(q, POST_GEM_HALF + vec2(0.026, 0.040));
	vec3 n = normalize(vec3(sign(q.x) * 0.5, sign(q.y) * 0.4, 0.75));
	part(acc, d_mount, ink_of(SILVER), shade_mat(ROSE_GOLD, n, 1.0, 1.0, 1.0), f.ow, f.px);
	float d_gem = sd_rhombus(q, POST_GEM_HALF);
	part(acc, d_gem, ink_of(sand_color) * 0.7, cut_gem(q, POST_GEM_HALF, f.px), f.ow * 0.7, f.px);
	gem_glint(acc, f, q, POST_GEM_HALF);
}

// 天板の上の水晶の房。中央が高く、左右は外へ傾く。
void crystal(inout vec4 acc, Px f, vec2 base, float w, float h, float lean) {
	vec2 q = rot(f.p - base, -lean);
	if (abs(q.x) > w + f.pad || q.y < -f.pad || q.y > h + f.pad) {
		return;
	}
	float tip_h = w * 1.3;
	float d_body = max(abs(q.x) - w, -q.y);
	float d_tip = (q.y - h + tip_h * abs(q.x) / w) / sqrt(1.0 + pow(tip_h / w, 2.0));
	float d = max(d_body, d_tip);
	float sx = q.x / w;
	bool on_tip = q.y > h - tip_h * (1.0 - abs(sx));
	vec3 fn = normalize(vec3(sx < -0.35 ? -0.55 : (sx > 0.35 ? 0.55 : 0.0), on_tip ? 0.6 : 0.0, 0.75));
	fn = normalize(vec3(rot(fn.xy, lean), fn.z));
	float lit = clamp(dot(fn, mirror_light()), 0.0, 1.0);
	vec3 c = mix(sand_color * 0.55, mix(sand_color, vec3(1.0), 0.55), smoothstep(0.2, 0.85, lit));
	c = mix(c, vec3(1.0), smoothstep(0.88, 0.98, lit) * 0.8);
	c = mix(c, c * 0.6 + prism(q.y * 2.0 + clock * 0.05) * 0.6, prism_band(f.p * 1.6) * 0.5);
	part(acc, d, ink_of(sand_color) * 0.6, c, f.ow, f.px);
}

void skin_back(inout vec4 acc, Px f) {
}

void skin_frame(inout vec4 acc, Px f) {
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -GEM_POST_X : GEM_POST_X;
		draw_column(acc, f, cx, 0.046, -1.02, 1.02, ROSE_GOLD, 0.55);
		draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.032), SILVER, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.895), vec2(0.064, 0.014), SILVER, 1.0);
		draw_band(acc, f, vec2(cx, f.side * 0.340), vec2(0.060, 0.014), SILVER, 1.0);
		post_gem(acc, f, vec2(cx, 0.0));
	}
	draw_collars(acc, f, ROSE_GOLD, 1.0);
	float d = draw_slab(acc, f, f.side * 1.098, vec2(0.82, 0.078), 0.03, SILVER, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - f.side * 1.098);
	float rim = 1.0 - smoothstep(0.0, max(0.008, f.px * 0.7), abs(abs(q.y) - 0.050) - 0.007);
	inlay(acc, d, ROSE_GOLD, rim * step(abs(q.x), 0.78), f);
	// 板の小さな宝石の列
	for (int k = 0; k < 2; k++) {
		vec2 gc = vec2(k == 0 ? -0.46 : 0.46, f.side * 1.098);
		vec2 gq = f.p - gc;
		float dg = sd_rhombus(gq, vec2(0.034, 0.026));
		inlay(acc, d, cut_gem(gq, vec2(0.034, 0.026), f.px), cov(dg, f.px), f);
	}
	if (f.p.y > 0.0) {
		crystal(acc, f, vec2(-0.16, 1.140), 0.044, 0.130, 0.62);
		crystal(acc, f, vec2(0.16, 1.140), 0.044, 0.130, -0.62);
		crystal(acc, f, vec2(-0.085, 1.150), 0.054, 0.190, 0.30);
		crystal(acc, f, vec2(0.085, 1.150), 0.054, 0.190, -0.30);
		crystal(acc, f, vec2(0.0, 1.150), 0.068, 0.236, 0.0);
	} else {
		// 底板の中央: 銀の台に楕円の宝石
		vec2 mq = f.p - vec2(0.0, -1.098);
		float d_m = sd_ellipse(mq, vec2(0.105, 0.070));
		part(acc, d_m, ink_of(SILVER), shade_mat(SILVER, normalize(vec3(mq / vec2(0.105, 0.07) * 0.6, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
		float d_g = sd_ellipse(mq, vec2(0.074, 0.048));
		part(acc, d_g, ink_of(sand_color) * 0.7, cut_gem(mq, vec2(0.074, 0.048), f.px), f.ow * 0.6, f.px);
		gem_glint(acc, f, mq, vec2(0.074, 0.048));
	}
	// 照りの強い瞬間に、宝石の先がきらめく
	float tw = pow(clamp(dot(vec3(0.0, 0.6, 0.8), mirror_light()), 0.0, 1.0), 6.0);
	add_light(acc, vec3(1.0, 0.95, 0.98), star4(f.p - vec2(0.0, 1.372), 0.10) * (0.35 + 0.65 * tw) * (0.6 + 0.4 * sin(clock * 2.3)));
}

#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"
#include "res://resources/shaders/hourglass/skin_main.gdshaderinc"
