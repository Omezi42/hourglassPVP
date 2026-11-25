shader_type canvas_item;
// 受け流し(パリィ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 革を巻いた握りの柱と、燠火の筋が走る黒鉄の板。天板の上で2本のサーベルが交差し、刃の噛み合う所に火花が散る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 IRON = vec3(0.26, 0.27, 0.31);
const vec3 STEEL = vec3(0.74, 0.78, 0.84);
const vec3 LEATHER = vec3(0.50, 0.29, 0.16);
const vec3 BRASS = vec3(0.86, 0.64, 0.30);
const vec3 EMBER = vec3(1.0, 0.44, 0.14);
const vec3 EMBER_HOT = vec3(1.0, 0.88, 0.56);
const float POST_HALF = 0.058;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
// 交差の中心と、刃の向き(右上へ)・長さ・幅
const vec2 CROSS = vec2(0.0, 1.190);
const vec2 BLADE_DIR = vec2(0.820, 0.572);
const float BLADE_TIP = 0.30;
const float GUARD_Y = -0.150;
const float BLADE_W = 0.032;

void ember_seam(inout vec4 acc, Px f, float d, vec2 q, float half_x) {
	float line = cov(abs(q.y) - 0.008, f.px) * step(abs(q.x), half_x);
	inlay(acc, d, mix(EMBER, EMBER_HOT, cov(abs(q.y) - 0.003, f.px)), line, f);
}

// 革を斜めに巻いた握りの柱
void wrapped_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float u = clamp(lx / POST_HALF, -1.0, 1.0);
	float fine = smoothstep(0.03, 0.012, f.px);
	float g = fract(f.p.y * 8.0 + asin(u) * 0.32 * sign(cx));
	vec3 n = lathe_normal(u, (0.5 - g) * 0.9 * fine);
	vec3 c = shade_mat(LEATHER, n, 0.0, 0.5, f.ao);
	c *= mix(1.0, mix(0.58, 1.0, smoothstep(0.0, 0.3, sin(g * 3.1416))), fine);
	part(acc, d, ink_of(LEATHER), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.090, 0.030), IRON * 1.4, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.46), vec2(0.072, 0.018), STEEL, 1.0);
}

void iron_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, IRON, 1.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	ember_seam(acc, f, d, q, 0.70);
	for (int k = 0; k < 2; k++) {
		float x = k == 0 ? -0.74 : 0.74;
		draw_ball(acc, f, vec2(x, cy), 0.022, BRASS, 1.0);
	}
}

// 刃の局所座標(y が刃の向き)
vec2 blade_local(vec2 p, vec2 dir) {
	vec2 r = p - CROSS;
	return vec2(dot(r, vec2(dir.y, -dir.x)), dot(r, dir));
}

void sabre(inout vec4 acc, Px f, vec2 dir) {
	vec2 q = blade_local(f.p, dir);
	if (abs(q.x) > 0.11 || q.y < -0.32 || q.y > BLADE_TIP + 0.02) {
		return;
	}
	// 刃: 先へ細る。片刃の反りを x へ少し足す
	float curve = 0.035 * sign(dir.x) * pow(clamp(q.y / BLADE_TIP, 0.0, 1.0), 2.0);
	vec2 bq = vec2(q.x - curve, q.y);
	float hw = BLADE_W * clamp((BLADE_TIP - bq.y) / 0.07, 0.0, 1.0);
	float d_blade = max(abs(bq.x) - hw, max(GUARD_Y - bq.y, bq.y - BLADE_TIP));
	vec3 n = normalize(vec3(bq.x > 0.0 ? 0.55 : -0.25, 0.0, 0.85));
	vec3 steel = shade_mat(STEEL, n, 1.0, 1.0, 1.0);
	steel = mix(steel, vec3(1.0), cov(abs(bq.x + 0.004) - 0.003, f.px) * 0.6);
	part(acc, d_blade, ink_of(STEEL) * 0.7, steel, f.ow, f.px);
	// 鍔・握り・柄頭
	float d_guard = sd_round_box(q - vec2(0.0, GUARD_Y), vec2(0.074, 0.016), 0.013);
	part(acc, d_guard, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(0.0, 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	float d_grip = sd_round_box(q - vec2(0.0, GUARD_Y - 0.060), vec2(0.019, 0.046), 0.009);
	float wrap = smoothstep(0.0, 0.3, sin(fract(q.y * 40.0) * 3.1416));
	part(acc, d_grip, ink_of(LEATHER), LEATHER * mix(0.6, 1.1, wrap), f.ow, f.px);
	vec2 pq = q - vec2(0.0, GUARD_Y - 0.125);
	vec3 pn = normalize(vec3(pq / 0.028 * 0.7, 0.7));
	part(acc, length(pq) - 0.028, ink_of(BRASS), shade_mat(BRASS, pn, 1.0, 1.0, 1.0), f.ow, f.px);
}

// 刃の噛み合う所の火花
void clash_spark(inout vec4 acc, Px f) {
	vec2 q = f.p - CROSS;
	if (dot(q, q) > 0.03) {
		return;
	}
	add_light(acc, EMBER, star4(q, 0.13) * 0.85);
	add_light(acc, EMBER_HOT, star4(q, 0.06));
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - CROSS;
	add_light(acc, EMBER, exp(-dot(d, d) / 0.022) * 0.55 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	wrapped_post(acc, f, -POST_X);
	wrapped_post(acc, f, POST_X);
	draw_collars(acc, f, IRON * 1.3, 1.0);
	iron_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y - 0.06) {
		sabre(acc, f, vec2(-BLADE_DIR.x, BLADE_DIR.y));
		sabre(acc, f, BLADE_DIR);
		clash_spark(acc, f);
	} else if (f.p.y < 0.0) {
		vec2 mq = f.p - vec2(0.0, -PLATE_Y);
		float d_m = sd_rhombus(mq, vec2(0.075, 0.050));
		part(acc, d_m, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(sign(mq.x) * 0.3, sign(mq.y) * 0.3, 0.85)), 1.0, 1.0, 1.0), f.ow, f.px);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
