shader_type canvas_item;
// 炉(フォージ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 槌目の付いた鍛鉄の柱は下ほど赤く焼け、天板の上の坩堝には熔けた金属が光る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 IRON = vec3(0.40, 0.44, 0.50);
const vec3 IRON_INK = vec3(0.10, 0.11, 0.13);
const vec3 HEAT = vec3(1.0, 0.46, 0.16);
const vec3 BRICK = vec3(0.62, 0.32, 0.22);
const float POST_HALF = 0.058;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec2 CRUCIBLE = vec2(0.0, 1.262);

// 槌目: 浅い凹みの点描
float hammered(vec2 p) {
	vec2 cell = floor(p / 0.045);
	vec2 c = (cell + 0.5 + (hash22(cell) - 0.5) * 0.6) * 0.045;
	return smoothstep(0.022, 0.0, length(p - c));
}

void wrought_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.65 ? 0.6 : (face < -0.65 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(IRON, n, 1.0, 0.7, f.ao);
	c = mix(c, c * 0.78, hammered(f.p + cx) * smoothstep(0.03, 0.012, f.px));
	// 下ほど焼けて赤い
	float heat = smoothstep(-0.20, -1.0, f.p.y);
	c = mix(c, mix(HEAT, vec3(1.0, 0.85, 0.5), smoothstep(-0.8, -1.0, f.p.y)), heat * 0.75);
	part(acc, d, IRON_INK, c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.028), IRON * 0.8, 1.0);
	draw_band(acc, f, vec2(cx, 0.25), vec2(0.076, 0.018), IRON * 0.8, 1.0);
}

void forge_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, cy < 0.0 ? BRICK : IRON, cy < 0.0 ? 0.0 : 1.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	if (cy < 0.0) {
		// 炉の煉瓦と、中央の焚き口
		float row = floor(q.y / 0.055);
		float bx = fract(q.x / 0.13 + mod(row, 2.0) * 0.5);
		float joint = max(step(abs(fract(q.y / 0.055) - 0.5), 0.40) * 0.0 + (1.0 - smoothstep(0.0, 0.10, min(fract(q.y / 0.055), 1.0 - fract(q.y / 0.055)))), 1.0 - smoothstep(0.0, 0.06, min(bx, 1.0 - bx)));
		inlay(acc, d, BRICK * 0.55, joint * smoothstep(0.03, 0.012, f.px), f);
		float d_mouth = max(sd_round_box(q - vec2(0.0, -0.010), vec2(0.13, 0.050), 0.04), -q.y - 0.07);
		inlay(acc, d, vec3(0.08), cov(d_mouth, f.px), f);
		inlay(acc, d, mix(HEAT, vec3(1.0, 0.9, 0.5), smoothstep(0.0, -0.05, q.y)), cov(d_mouth + 0.014, f.px), f);
	} else {
		for (int k = -3; k <= 3; k++) {
			draw_ball(acc, f, vec2(float(k) * 0.24, cy), 0.018, IRON * 1.2, 1.0);
		}
		inlay(acc, d, mix(sand_color, IRON, 0.3), step(abs(q.y), 0.010) * step(abs(q.x), 0.74), f);
	}
}

// 坩堝: 鉄の器に熔けた金属、両脇の取っ手
void crucible(inout vec4 acc, Px f) {
	vec2 q = (f.p - CRUCIBLE) / 1.3;
	if (abs(q.x) > 0.17 + f.pad || abs(q.y) > 0.13 + f.pad) {
		return;
	}
	f.px /= 1.3;
	f.ow /= 1.3;
	float w = mix(0.070, 0.115, clamp((q.y + 0.07) / 0.14, 0.0, 1.0));
	float d_body = max(abs(q.x) - w, abs(q.y) - 0.070);
	float d_ring = min(length(vec2(abs(q.x) - 0.135, q.y - 0.02)) - 0.028, 1e3);
	d_ring = max(d_ring, -(length(vec2(abs(q.x) - 0.135, q.y - 0.02)) - 0.014));
	vec3 n = normalize(vec3(q.x / 0.12 * 0.8, 0.0, 0.6));
	part(acc, d_ring, IRON_INK, IRON, f.ow * 0.8, f.px);
	part(acc, d_body, IRON_INK, shade_mat(IRON, n, 1.0, 0.7, 1.0), f.ow, f.px);
	// 熔けた金属の面
	float d_melt = sd_ellipse(q - vec2(0.0, 0.065), vec2(0.105, 0.020));
	vec3 melt = mix(HEAT, vec3(1.0, 0.95, 0.70), smoothstep(0.02, -0.01, abs(q.x) - 0.04));
	part(acc, d_melt, vec3(0.3, 0.08, 0.02), mix(melt, sand_color, 0.25), f.ow * 0.6, f.px);
}

// 坩堝と焚き口の熱の照り返し
void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - CRUCIBLE - vec2(0.0, 0.07);
	add_light(acc, HEAT, exp(-dot(d, d) / 0.025) * 0.6 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	wrought_post(acc, f, -POST_X);
	wrought_post(acc, f, POST_X);
	draw_collars(acc, f, IRON * 0.8, 1.0);
	forge_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		crucible(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
