shader_type canvas_item;
// 灯る蝋燭(グロウ)。GameDesign.md 9章 / Architecture.md 10.19節。
// 柱は真鍮の燭台に立てた太い蝋燭で、天板の上に炎が灯る。蝋は板へ垂れ、炎の光は後ろへ広がる。

#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/frame_parts.gdshaderinc"

const vec3 WAX = vec3(0.96, 0.90, 0.78);
const vec3 WAX_SHADE = vec3(0.76, 0.64, 0.50);
const vec3 BRASS = vec3(0.86, 0.64, 0.30);
const vec3 FLAME = vec3(1.0, 0.82, 0.40);
const float CANDLE_X = 0.68;
const float CANDLE_R = 0.060;
const float WICK_Y = 1.24;
const vec2 SLAB_HALF = vec2(0.76, 0.078);

void candle(inout vec4 acc, Px f, float cx) {
	float lx = f.p.x - cx;
	if (abs(lx) > 0.14 + f.pad || f.p.y < -1.04 - f.pad || f.p.y > WICK_Y + 0.14 + f.pad) {
		return;
	}
	float d = max(abs(lx) - CANDLE_R, max(-0.92 - f.p.y, f.p.y - WICK_Y + 0.01 * cos(lx * 40.0)));
	// 垂れた蝋の筋
	float drip_x = abs(fract((lx + cx) * 18.0) - 0.5) / 18.0;
	float drip_len = 0.10 + 0.20 * hash21(vec2(floor((lx + cx) * 18.0), cx));
	float d_drip = max(max(drip_x - 0.012, abs(lx) - CANDLE_R - 0.008), max(f.p.y - WICK_Y, WICK_Y - drip_len - f.p.y));
	d = min(d, d_drip);
	vec3 n = lathe_normal(clamp(lx / CANDLE_R, -1.0, 1.0), 0.0);
	vec3 c = mix(WAX_SHADE, WAX, smoothstep(-0.2, 0.7, dot(n, LIGHT_DIR)));
	// 上ほど炎に照らされる
	c = mix(c, mix(WAX, FLAME, 0.4), smoothstep(0.6, WICK_Y, f.p.y) * 0.5);
	part(acc, d, ink_of(WAX_SHADE), c, f.ow, f.px);
	// 燭台: 受け皿と台
	draw_band(acc, f, vec2(cx, -0.93), vec2(0.115, 0.022), BRASS, 1.0);
	draw_column(acc, f, cx, 0.034, -1.02, -0.94, BRASS, 1.0);
	draw_band(acc, f, vec2(cx, f.side * 0.955), vec2(0.080, 0.020), BRASS, 1.0);
	// 芯と炎
	float d_wick = sd_segment(f.p, vec2(cx, WICK_Y), vec2(cx, WICK_Y + 0.025)) - 0.006;
	over(acc, vec3(0.12), cov(d_wick, f.px));
	vec2 fq = f.p - vec2(cx, WICK_Y + 0.060);
	float fy = clamp((fq.y + 0.04) / 0.11, 0.0, 1.0);
	float d_flame = abs(fq.x) - 0.034 * sin(3.1416 * pow(fy, 0.7)) * (1.0 - fy * 0.3);
	d_flame = max(d_flame, max(-fq.y - 0.04, fq.y - 0.07));
	over(acc, FLAME, cov(d_flame, f.px));
	over(acc, vec3(1.0, 0.98, 0.88), cov(d_flame + 0.012, f.px));
}

void brass_slab(inout vec4 acc, Px f, float cy) {
	float d = draw_slab(acc, f, cy, SLAB_HALF, 0.03, BRASS, 1.0, 1.0);
	vec2 q = vec2(f.p.x, f.p.y - cy);
	if (abs(q.x) > SLAB_HALF.x + f.pad || abs(q.y) > SLAB_HALF.y + f.pad) {
		return;
	}
	// 光の筋を彫った板と、中央の砂の色の灯
	float ray = 1.0 - smoothstep(0.0, max(0.008, f.px), abs(fract(atan(q.y, q.x) / 6.2832 * 16.0) - 0.5) * length(q) * 0.4 - 0.002);
	inlay(acc, d, BRASS * 0.7, ray * step(0.06, length(q)) * step(length(q), 0.20) * 0.6, f);
	vec3 gn = normalize(vec3(q / 0.045 * 0.6, 0.8));
	part(acc, length(q) - 0.042, ink_of(BRASS), mix(shade_mat(sand_color, gn, 0.0, 1.0, 1.0), vec3(1.0, 0.95, 0.80), 0.25), f.ow * 0.7, f.px);
}

// 炎の光(上の砂が少ないほど=返すほど明るい)
void art_back(inout vec4 acc, Px f) {
	float k = 0.45 + 0.55 * (1.0 - sand_top / 0.85);
	for (int i = 0; i < 2; i++) {
		float cx = i == 0 ? -CANDLE_X : CANDLE_X;
		vec2 d = f.p - vec2(cx, WICK_Y + 0.05);
		add_light(acc, mix(FLAME, sand_color, 0.3), exp(-dot(d, d) / 0.045) * 0.75 * k * canvas_window(f.p * vec2(0.92, 1.0)));
	}
}

void art_frame(inout vec4 acc, Px f) {
	draw_collars(acc, f, BRASS, 1.0);
	brass_slab(acc, f, f.side * PLATE_Y);
	candle(acc, f, -CANDLE_X);
	candle(acc, f, CANDLE_X);
}

#include "res://resources/shaders/hourglass/art_main.gdshaderinc"
