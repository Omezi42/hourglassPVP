shader_type canvas_item;
// 燃えさしの芯(ウィック)。GameDesign.md 9章 / Architecture.md 10.19節。
// 蝋の垂れた煤けた木の柱と、燠火の筋が走る板。天板の上には吹き消した太い蝋燭が載り、芯の先に赤い燠が残って細い煙が昇る。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 SOOT = vec3(0.33, 0.26, 0.22);
const vec3 WAX = vec3(0.97, 0.91, 0.78);
const vec3 BRASS = vec3(0.86, 0.64, 0.30);
const vec3 SMOKE = vec3(0.78, 0.76, 0.80);
const vec3 EMBER = vec3(1.0, 0.44, 0.14);
const vec3 EMBER_HOT = vec3(1.0, 0.88, 0.56);
const float POST_HALF = 0.060;
const vec2 SLAB_HALF = vec2(0.82, 0.086);
// 蝋燭: 皿の高さ、胴の半幅・高さ、芯の先
const float DISH_Y = 1.098;
const vec2 CANDLE_HALF = vec2(0.150, 0.102);
const vec2 WICK_TIP = vec2(0.028, 1.346);

void ember_seam(inout vec4 acc, Px f, float d, vec2 q, float half_x) {
	float line = cov(abs(q.y) - 0.008, f.px) * step(abs(q.x), half_x);
	inlay(acc, d, mix(EMBER, EMBER_HOT, cov(abs(q.y) - 0.003, f.px)), line, f);
}

// 垂れた蝋の筋: 上端から長さの違う雫が下がる。戻り値は距離
float drips(vec2 q, float top, float seed_x, float span) {
	float k = floor(q.x / span + 0.5);
	float lx = q.x - k * span;
	float len = 0.035 + 0.075 * hash21(vec2(k + seed_x, 3.0));
	float y0 = top - len;
	float d_bar = max(abs(lx) - span * 0.30, max(y0 - q.y, q.y - top));
	float d_tip = length(vec2(lx, q.y - y0)) - span * 0.36;
	return min(d_bar, d_tip);
}

void sooty_post(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > POST_HALF + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float d = max(abs(lx) - POST_HALF, f.ay - POST_H);
	float u = clamp(lx / POST_HALF, -1.0, 1.0);
	vec3 n = lathe_normal(u, 0.0);
	float fine = smoothstep(0.03, 0.012, f.px);
	vec3 c = shade_mat(SOOT, n, 0.0, 0.3, f.ao);
	c *= 0.88 + 0.24 * vnoise(vec2(f.p.x * 60.0, f.p.y * 9.0)) * fine;
	part(acc, d, ink_of(SOOT), c, f.ow, f.px);
	// 上の受けから垂れる蝋
	float d_wax = drips(vec2(lx + POST_HALF, f.p.y), 0.93, cx, 0.060);
	d_wax = max(d_wax, d);
	over(acc, shade_mat(WAX, n, 0.0, 0.8, 1.0), cov(d_wax, f.px));
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.092, 0.030), BRASS, 1.0);
}

void soot_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.02, SOOT * 1.15, 0.0, 0.3);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	ember_seam(acc, f, d, q, 0.72);
	for (int k = 0; k < 2; k++) {
		draw_ball(acc, f, vec2(k == 0 ? -0.74 : 0.74, cy), 0.022, BRASS, 1.0);
	}
}

// 吹き消した蝋燭: 真鍮の皿、垂れた蝋をまとう胴、曲がった芯
void candle(inout vec4 acc, Px f) {
	vec2 q = f.p - vec2(0.0, DISH_Y);
	if (abs(q.x) > 0.30 || q.y < -0.06 || q.y > 0.26) {
		return;
	}
	float d_dish = sd_ellipse(q, vec2(0.235, 0.036));
	vec2 hq = q - vec2(0.255, 0.022);
	float d_handle = abs(length(hq) - 0.036) - 0.011;
	part(acc, d_handle, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(hq / 0.05 * 0.6, 0.75)), 1.0, 1.0, 1.0), f.ow, f.px);
	part(acc, d_dish, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(q.x / 0.235 * 0.4, 0.5, 0.75)), 1.0, 1.0, 1.0), f.ow, f.px);
	vec2 cq = q - vec2(0.0, CANDLE_HALF.y + 0.008);
	float top_dip = 0.012 * (1.0 - pow(cq.x / CANDLE_HALF.x, 2.0));
	float d_body = sd_round_box(cq, CANDLE_HALF, 0.018);
	d_body = max(d_body, cq.y - CANDLE_HALF.y + top_dip);
	vec3 n = normalize(vec3(clamp(cq.x / CANDLE_HALF.x, -1.0, 1.0) * 0.7, 0.0, 0.7));
	vec3 wax = shade_mat(WAX, n, 0.0, 0.7, 1.0);
	// 上ほど芯の燠に照らされて温かい
	wax = mix(wax, wax * vec3(1.0, 0.86, 0.68), smoothstep(-0.02, CANDLE_HALF.y, cq.y) * 0.4);
	part(acc, d_body, WAX * 0.40, wax, f.ow, f.px);
	// 縁からあふれて垂れた蝋(胴より明るく、細い縁で浮かせる)
	float d_drip = drips(vec2(cq.x + CANDLE_HALF.x + 0.02, cq.y), CANDLE_HALF.y - 0.002, 11.0, 0.062);
	d_drip = max(d_drip, max(abs(cq.x) - CANDLE_HALF.x + 0.004, -CANDLE_HALF.y + 0.01 - cq.y));
	float d_pool = max(abs(cq.y - CANDLE_HALF.y + 0.012) - 0.014, abs(cq.x) - CANDLE_HALF.x + 0.004);
	d_drip = min(d_drip, d_pool);
	part(acc, d_drip, WAX * 0.62, mix(vec3(1.0, 0.98, 0.93), wax, 0.3), f.ow * 0.55, f.px);
	// 芯: 上へ伸びて先が右へ折れる
	float d_wick = min(
		sd_segment(f.p, vec2(0.0, DISH_Y + 2.0 * CANDLE_HALF.y - 0.004), vec2(0.004, WICK_TIP.y - 0.010)),
		sd_segment(f.p, vec2(0.004, WICK_TIP.y - 0.010), WICK_TIP)
	) - 0.008;
	part(acc, d_wick, vec3(0.02), vec3(0.10, 0.08, 0.07), f.ow * 0.7, f.px);
	float tip = cov(length(f.p - WICK_TIP) - 0.016, f.px);
	over(acc, EMBER, tip);
	over(acc, EMBER_HOT, cov(length(f.p - WICK_TIP) - 0.007, f.px));
}

// 芯から昇って左へ流れる煙(細い帯。先ほど薄く太い)
void smoke(inout vec4 acc, Px f) {
	vec2 q = f.p - WICK_TIP;
	if (q.y < -0.01 || q.y > 0.05 || q.x > 0.04 || q.x < -0.30) {
		return;
	}
	float best = 9.0;
	float best_t = 0.0;
	vec2 prev = vec2(0.0);
	for (int i = 1; i <= 12; i++) {
		float t = float(i) / 12.0;
		vec2 pt = vec2(-0.26 * t + 0.02 * sin(t * 9.0), 0.034 * sqrt(t) + 0.008 * sin(t * 14.0));
		float d = sd_segment(q, prev, pt);
		if (d < best) {
			best = d;
			best_t = t;
		}
		prev = pt;
	}
	float w = mix(0.008, 0.017, best_t);
	over(acc, SMOKE, cov(best - w, f.px) * (1.0 - best_t * 0.7) * 0.9);
}

void art_back(inout vec4 acc, Px f) {
	vec2 d = f.p - WICK_TIP;
	add_light(acc, EMBER, exp(-dot(d, d) / 0.016) * 0.75 * canvas_window(f.p));
	vec2 d2 = f.p - vec2(0.0, DISH_Y + 0.05);
	add_light(acc, EMBER, exp(-dot(d2, d2) / 0.030) * 0.25 * canvas_window(f.p));
}

void art_frame(inout vec4 acc, Px f) {
	sooty_post(acc, f, -POST_X);
	sooty_post(acc, f, POST_X);
	draw_collars(acc, f, SOOT * 1.4, 0.0);
	soot_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y - 0.05) {
		candle(acc, f);
		smoke(acc, f);
		add_light(acc, EMBER, star4(f.p - WICK_TIP, 0.07) * 0.9);
	} else if (f.p.y < 0.0) {
		vec2 mq = f.p - vec2(0.0, -PLATE_Y);
		float d_m = abs(length(mq) - 0.040) - 0.012;
		part(acc, d_m, ink_of(BRASS), shade_mat(BRASS, normalize(vec3(mq / 0.05 * 0.5, 0.8)), 1.0, 1.0, 1.0), f.ow, f.px);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
