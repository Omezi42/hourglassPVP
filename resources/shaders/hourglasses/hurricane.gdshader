shader_type canvas_item;
// 大嵐(ハリケーン)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は風の帯が螺旋に巻きつく風化した石、板には稲妻の走る黒雲。天板の上に立ちのぼる漏斗雲。後ろに斜めの風の筋。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 STONE = vec3(0.52, 0.54, 0.58);
const vec3 CLOUD = vec3(0.20, 0.22, 0.30);
const vec3 BOLT = vec3(1.0, 0.93, 0.55);
const vec2 SLAB_HALF = vec2(0.80, 0.082);
const float COL_R = 0.042;
const float WIND_R = 0.060;
const float WIND_FREQ = 3.2;
const vec2 FUNNEL = vec2(0.0, 1.180);
const float FUNNEL_H = 0.185;

// 風化した石の柱に、風の帯が螺旋に巻きつく(奥の半周は柱の後ろへ隠れる)
void wind_column(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > WIND_R + 0.03 + f.pad || f.ay > POST_H + f.pad) {
		return;
	}
	float ph = f.p.y * WIND_FREQ * 6.2832 + cx * 3.0;
	float band_x = WIND_R * sin(ph);
	float d_band = abs(lx - band_x) - 0.016 * (0.6 + 0.4 * abs(cos(ph)));
	d_band = max(d_band, f.ay - POST_H + 0.06);
	vec3 band_c = mix(sand_color, vec3(1.0), 0.2) * mix(0.6, 1.0, cos(ph) * 0.5 + 0.5);
	if (cos(ph) < 0.0) {
		part(acc, d_band, ink_of(sand_color) * 0.7, band_c, f.ow * 0.5, f.px);
	}
	float d = max(abs(lx) - COL_R, f.ay - POST_H);
	vec3 n = lathe_normal(clamp(lx / COL_R, -1.0, 1.0), 0.0);
	vec3 c = shade_mat(STONE, n, 0.0, 0.3, f.ao);
	c *= 0.85 + 0.25 * vnoise(f.p * vec2(30.0, 8.0));
	part(acc, d, ink_of(STONE), c, f.ow, f.px);
	if (cos(ph) >= 0.0) {
		part(acc, d_band, ink_of(sand_color) * 0.7, band_c, f.ow * 0.5, f.px);
	}
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.084, 0.028), CLOUD * 1.6, 0.5);
}

// 稲妻のジグザグ(上から下へ3折れ)
float bolt(vec2 q) {
	float d = sd_segment(q, vec2(-0.010, 0.050), vec2(0.012, 0.006));
	d = min(d, sd_segment(q, vec2(0.012, 0.006), vec2(-0.012, 0.000)));
	d = min(d, sd_segment(q, vec2(-0.012, 0.000), vec2(0.010, -0.050)));
	return d - 0.006;
}

void storm_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, CLOUD, 0.1, 0.6);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	float puff = vnoise(q * vec2(14.0, 22.0) + cy * 7.0);
	inlay(acc, d, CLOUD * 1.8, smoothstep(0.55, 0.75, puff) * 0.6, f);
	for (int k = -2; k <= 2; k++) {
		vec2 bq = q - vec2(float(k) * 0.30, 0.0);
		inlay(acc, d, BOLT, cov(bolt(bq), f.px), f);
		add_light(acc, BOLT, cov(bolt(bq) - 0.02, f.px) * 0.15 * cov(d, f.px));
	}
}

// 漏斗雲: 下で細く上で広がる渦。帯が斜めに巻いて回る
void funnel(inout vec4 acc, Px f) {
	vec2 q = f.p - FUNNEL;
	float t = clamp(q.y / FUNNEL_H, 0.0, 1.0);
	float half_w = mix(0.022, 0.155, t * t) + 0.012 * sin(t * 9.0);
	float sway = 0.03 * sin(t * 4.0);
	if (q.y < -0.01 - f.pad || q.y > FUNNEL_H + f.pad || abs(q.x - sway) > half_w + f.pad) {
		return;
	}
	float d = max(abs(q.x - sway) - half_w, max(-q.y, q.y - FUNNEL_H));
	float u = (q.x - sway) / max(half_w, 0.001);
	vec3 n = normalize(vec3(u * 0.8, 0.2, sqrt(max(1.0 - u * u, 0.0)) + 0.2));
	vec3 c = shade_mat(mix(STONE, sand_color, 0.5), n, 0.0, 0.4, 1.0);
	float swirl = fract(q.y * 26.0 - u * 1.6);
	c = mix(c, mix(sand_color, vec3(1.0), 0.5), smoothstep(0.55, 0.7, swirl) * (1.0 - smoothstep(0.85, 1.0, swirl)));
	c = mix(c, CLOUD, 0.25 * (1.0 - t));
	part(acc, d, ink_of(STONE), c, f.ow * 0.7, f.px);
}

void art_back(inout vec4 acc, Px f) {
	float streak = fract((f.p.x + f.p.y * 0.6) * 5.0 + vnoise(f.p * 3.0) * 0.6);
	float line = 1.0 - smoothstep(0.0, 0.06, abs(streak - 0.5));
	add_light(acc, mix(sand_color, vec3(1.0), 0.5), line * 0.10 * canvas_window(f.p) * (1.0 - acc.a));
}

void art_frame(inout vec4 acc, Px f) {
	wind_column(acc, f, -POST_X);
	wind_column(acc, f, POST_X);
	draw_collars(acc, f, STONE, 0.2);
	storm_slab(acc, f, f.side * PLATE_Y);
	if (f.p.y > PLATE_Y) {
		funnel(acc, f);
	}
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
