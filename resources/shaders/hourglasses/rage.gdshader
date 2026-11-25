shader_type canvas_item;
// 憤激(レイジ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 内側から赤く灼けたひびの走る黒鉄の柱と板。天板の上には紅玉をはめた鉄の額から、太い2本の角が反り上がる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 IRON = vec3(0.24, 0.23, 0.25);
const vec3 HORN = vec3(0.90, 0.82, 0.66);
const vec3 HORN_TIP = vec3(0.24, 0.18, 0.16);
const vec3 RUBY = vec3(0.92, 0.12, 0.18);
const vec3 EMBER = vec3(1.0, 0.36, 0.14);
const vec3 EMBER_HOT = vec3(1.0, 0.84, 0.52);
const float POST_HALF = 0.062;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
const vec2 BOSS = vec2(0.0, 1.196);
const int HORN_STEPS = 14;

void ember_seam(inout vec4 acc, Px f, float d, vec2 q, float half_x) {
	float line = cov(abs(q.y) - 0.008, f.px) * step(abs(q.x), half_x);
	inlay(acc, d, mix(EMBER, EMBER_HOT, cov(abs(q.y) - 0.003, f.px)), line, f);
}

// 縦に走るぎざぎざのひび。戻り値は距離
float crack(vec2 q, float seed_k) {
	float y = q.y * 7.0 + seed_k;
	float i = floor(y);
	float a = (hash21(vec2(i, seed_k)) - 0.5) * 0.05;
	float b = (hash21(vec2(i + 1.0, seed_k)) - 0.5) * 0.05;
	float x = mix(a, b, fract(y));
	return abs(q.x - x);
}

void cracked_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float face = lx / POST_HALF;
	vec3 n = normalize(vec3(face > 0.65 ? 0.6 : (face < -0.65 ? -0.6 : 0.0), 0.0, 0.8));
	vec3 c = shade_mat(IRON, n, 1.0, 0.6, f.ao);
	float d_crack = crack(vec2(lx, f.p.y), cx * 5.0);
	float glow_w = cov(d_crack - 0.010, f.px);
	float core = cov(d_crack - 0.0035, f.px);
	c = mix(c, c * 0.55 + EMBER * 0.25, cov(d_crack - 0.024, f.px));
	c = mix(c, EMBER, glow_w);
	c = mix(c, EMBER_HOT, core);
	part(acc, d, vec3(0.06), c, f.ow, f.px);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.094, 0.030), IRON * 1.5, 1.0);
	draw_band(acc, f, vec2(cx, 0.0), vec2(0.080, 0.022), IRON * 1.5, 1.0);
}

void iron_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, IRON, 1.0, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	ember_seam(acc, f, d, q, 0.72);
	for (int k = -3; k <= 3; k += 2) {
		draw_ball(acc, f, vec2(float(k) * 0.245, cy), 0.020, IRON * 1.8, 1.0);
	}
}

vec2 horn_point(float t, float sx) {
	float x = 0.085 + 0.275 * (1.0 - (1.0 - t) * (1.0 - t));
	float y = BOSS.y - 0.010 + 0.180 * t * t;
	return vec2(sx * x, y);
}

// 外へ張り出してから上へ反る角。根元は太く、先は黒く尖る
void horn(inout vec4 acc, Px f, float sx) {
	vec2 q = f.p;
	if (q.x * sx < 0.03 || q.x * sx > 0.42 || q.y < BOSS.y - 0.08 || q.y > 1.40) {
		return;
	}
	float best = 9.0;
	float best_t = 0.0;
	vec2 prev = horn_point(0.0, sx);
	for (int i = 1; i <= HORN_STEPS; i++) {
		float t = float(i) / float(HORN_STEPS);
		vec2 pt = horn_point(t, sx);
		vec2 pa = q - prev;
		vec2 ba = pt - prev;
		float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		float tt = (float(i) - 1.0 + h) / float(HORN_STEPS);
		float w = mix(0.068, 0.007, pow(tt, 0.8));
		float d = length(pa - ba * h) - w;
		if (d < best) {
			best = d;
			best_t = tt;
		}
		prev = pt;
	}
	float ring = smoothstep(0.0, 0.35, sin(best_t * 42.0) * 0.5 + 0.5);
	vec3 base = mix(HORN, HORN_TIP, smoothstep(0.45, 0.95, best_t));
	vec3 c = base * mix(0.78, 1.06, ring);
	part(acc, best, ink_of(HORN) * 0.6, c, f.ow, f.px);
}

void boss(inout vec4 acc, Px f) {
	vec2 q = f.p - BOSS;
	if (abs(q.x) > 0.14 || abs(q.y) > 0.12) {
		return;
	}
	float d = sd_rhombus(q, vec2(0.118, 0.092));
	d = max(d, sd_round_box(q, vec2(0.096, 0.080), 0.02));
	vec3 n = normalize(vec3(sign(q.x) * 0.35, sign(q.y) * 0.35, 0.85));
	part(acc, d, vec3(0.05), shade_mat(IRON * 1.5, n, 1.0, 1.0, 1.0), f.ow, f.px);
	float d_gem = sd_rhombus(q, vec2(0.042, 0.036));
	vec2 s = q / vec2(0.042, 0.036);
	vec3 face = mix(RUBY * 0.6, mix(RUBY, vec3(1.0), 0.45), smoothstep(0.4, -0.6, s.x + s.y));
	part(acc, d_gem, vec3(0.25, 0.02, 0.04), face, f.ow * 0.8, f.px);
	add_light(acc, EMBER_HOT, star4(q - vec2(-0.012, 0.012), 0.05) * 0.6);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - BOSS - vec2(0.0, 0.06);
	add_light(acc, EMBER, exp(-dot(d, d) / 0.030) * 0.6 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	cracked_post(acc, f, -POST_X);
	cracked_post(acc, f, POST_X);
	draw_collars(acc, f, IRON * 1.4, 1.0);
	iron_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y - 0.05) {
		horn(acc, f, -1.0);
		horn(acc, f, 1.0);
		boss(acc, f);
	} else if (f.p.y < 0.0) {
		vec2 mq = f.p - vec2(0.0, -PLATE_Y);
		float d_m = sd_rhombus(mq, vec2(0.060, 0.046));
		part(acc, d_m, vec3(0.25, 0.02, 0.04), mix(RUBY * 0.7, mix(RUBY, vec3(1.0), 0.4), smoothstep(0.03, -0.03, mq.x + mq.y)), f.ow, f.px);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
