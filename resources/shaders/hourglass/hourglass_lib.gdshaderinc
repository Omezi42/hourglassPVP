// 砂時計のコード描画の共通部: uniform・定数・道具(Architecture.md 10.19節)。
// スキンは SKIN_SAND_COLOR / SKIN_SAND_KIND を #define してから読むと、砂の色と質感が定数になる。
const int KIND_GRAIN = 1;
const int KIND_LIQUID = 2;
const int KIND_CRYSTAL = 3;
const int KIND_GLOW = 4;
const int KIND_STARDUST = 5;

#ifdef SKIN_SAND_COLOR
const vec3 sand_color = SKIN_SAND_COLOR;
#else
uniform vec3 sand_color : source_color = vec3(0.93, 0.66, 0.24);
#endif
uniform vec3 frame_color : source_color = vec3(0.75, 0.47, 0.24);
uniform vec3 trim_color : source_color = vec3(0.86, 0.66, 0.30);
// 0=塗りの木 / 1=金属
uniform float frame_metal : hint_range(0.0, 1.0) = 0.0;
// 石のざらつき
uniform float frame_rough : hint_range(0.0, 1.0) = 0.0;
// 柱の玉と輪・受け金を真鍮にする割合
uniform float trim_amount : hint_range(0.0, 1.0) = 0.0;
// 上の部屋・下の部屋の砂の量(0〜1。見かけの面積に比例)
uniform float sand_top : hint_range(0.0, 1.0) = 0.8;
uniform float sand_bottom : hint_range(0.0, 1.0) = 0.0;
// 落ちる砂の筋の濃さ
uniform float flow : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 0.6;
// ガラスの面の濃さ(0=ほぼ透明 / 1=不透明)
uniform float glass_body : hint_range(0.0, 1.0) = 0.3;
// 砂の質感(0=さらさら / 1=粒 / 2=液体 / 3=結晶 / 4=光 / 5=星屑)
#ifdef SKIN_SAND_KIND
const int sand_kind = SKIN_SAND_KIND;
#else
uniform int sand_kind = 0;
#endif

// 動きの時計(秒)。本体へ入れるときは TIME か、演出の進み具合を渡す。
uniform float clock = 0.0;
// 視線の向き(-1〜1)。カーソルや狙っている相手の方向を渡す。
uniform vec2 look = vec2(0.0);
// 1体ごとの模様の違い
uniform float seed = 0.0;

const vec2 HALF = vec2(1.0136, 1.3);
const float GLASS_H = 0.93;
const float GLASS_R = 0.53;
const float NECK_R = 0.058;
const float NECK_HALF = 0.012;
const float WALL = 0.036;
const float TILT = 0.19;
const float POST_X = 0.672;
const float POST_H = 1.02;
const float BEAD_R = 0.098;
const float RING_Y = 0.128;
const vec2 RING_HALF = vec2(0.086, 0.023);
const float CUP_Y = 0.968;
const vec2 CUP_HALF = vec2(0.086, 0.034);
const float PLATE_Y = 1.098;
const vec2 PLATE_HALF = vec2(0.80, 0.092);
const float PLATE_ROUND = 0.045;
const float COLLAR_Y = 0.968;
const vec2 COLLAR_HALF = vec2(0.50, 0.052);
const float OUTLINE = 0.019;
const float PILE_AREA = 0.5;
const float MOUND_STEEP = 0.62;
const float MOUND_SPAN = 1.0;
const float MOUND_AREA = 1.0;
const float MOUND_TIP = 0.14;
const vec3 LIGHT_DIR = vec3(-0.502, 0.622, 0.602);
const vec3 HALF_VEC = vec3(-0.280, 0.347, 0.895);
const vec3 CAUSTIC_DIR = vec3(0.56, -0.60, 0.57);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + 17.3));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float glass_r(float y) {
	float s = clamp((abs(y) - NECK_HALF) / (GLASS_H - NECK_HALF), 0.0, 1.0);
	float t = sin(1.5708 * min(s / 0.70, 1.0));
	float r = NECK_R + (GLASS_R - NECK_R) * pow(t, mix(1.6, 1.0, s));
	float k = max(s - 0.70, 0.0) / 0.62;
	return r * sqrt(1.0 - k * k);
}

float post_body_r(float ay) {
	float k = clamp((ay / POST_H - 0.16) / 0.84, 0.0, 1.0);
	return 0.056 + 0.034 * sin(3.1416 * pow(k, 0.72));
}

vec3 lathe_normal(float u, float slope) {
	return normalize(vec3(u, -slope, sqrt(max(1.0 - u * u, 0.0)) + 0.02));
}

// 3段の塗り分け(境目はやや硬く、段の中にゆるい傾き)。影は彩度を残して沈める。
vec3 tone3(vec3 base, float ndl) {
	vec3 dark = base * base * 0.55 + base * vec3(0.22, 0.18, 0.24);
	vec3 lit = min(base * 1.14 + vec3(0.09, 0.075, 0.045), vec3(1.0));
	vec3 c = mix(dark, base, smoothstep(0.12, 0.28, ndl));
	c = mix(c, lit, smoothstep(0.66, 0.78, ndl));
	return c * (0.93 + 0.10 * clamp(ndl, -0.4, 1.0));
}

// 塗りの木と金属を metal で混ぜる。gloss は照りの強さ(0=石のようなつや消し)。
vec3 shade_mat(vec3 base, vec3 n, float metal, float gloss, float ao) {
	float ndl = dot(n, LIGHT_DIR);
	vec3 wood = tone3(base, ndl);
	float spec = smoothstep(0.90, 0.97, dot(n, HALF_VEC));
	wood = mix(wood, vec3(1.0, 0.97, 0.90), spec * 0.30 * gloss);
	float rim = pow(1.0 - n.z, 3.0) * max(n.x, 0.0);
	wood += rim * 0.20 * vec3(0.55, 0.65, 1.0);

	// 金属: 映り込みの帯(空・光の筋・床の照り返し)で明暗を強く分ける
	vec3 r = vec3(2.0 * n.z * n.x, 2.0 * n.z * n.y, 2.0 * n.z * n.z - 1.0);
	float sky = smoothstep(-0.25, 0.55, r.y);
	float strip = exp(-pow((r.x + 0.52) / 0.2, 2.0)) * smoothstep(-0.5, 0.2, r.y);
	float bounce = exp(-pow((r.y + 0.55) / 0.22, 2.0)) * 0.35;
	float env = 0.42 + 0.62 * sky + 0.9 * strip + bounce;
	vec3 metal_col = base * env;
	metal_col = mix(metal_col, vec3(1.0, 0.96, 0.82), smoothstep(1.2, 1.8, env) * 0.8);
	metal_col += pow(max(dot(n, HALF_VEC), 0.0), 70.0) * 0.6;

	return mix(wood, metal_col, metal) * ao;
}

vec3 shade_solid(vec3 base, vec3 n, float metal, float ao) {
	return shade_mat(base, n, metal, 1.0 - frame_rough, ao);
}

// 輪郭に沿って走る、両端の丸い映り込み。uc は中心線の位置(半径に対する比)。
float streak(vec2 p, float gr, float uc, float w, float y0, float y1, float px) {
	float dx = p.x - uc * gr;
	float dy = max(max(y0 - p.y, p.y - y1), 0.0);
	float d = length(vec2(dx, dy)) - w;
	return clamp(0.5 - d / max(px, w * 0.25), 0.0, 1.0);
}

void over(inout vec4 acc, vec3 c, float a) {
	float na = a + acc.a * (1.0 - a);
	acc.rgb = (c * a + acc.rgb * acc.a * (1.0 - a)) / max(na, 0.0001);
	acc.a = na;
}

// 輪郭を先に、面を後に重ねる。
void part(inout vec4 acc, float d, vec3 ink, vec3 fill, float ow, float px) {
	over(acc, ink, clamp(0.5 - (d - ow) / px, 0.0, 1.0));
	over(acc, fill, clamp(0.5 - d / px, 0.0, 1.0));
}

// 砂の質感。base へ模様を重ねて返す。
vec3 sand_surface(vec3 base, vec3 dark, vec3 lit, vec2 p, float px) {
	float fine = smoothstep(0.022, 0.008, px);
	if (sand_kind == KIND_LIQUID) {
		vec2 cell = floor(p / 0.11);
		vec2 center = (cell + 0.25 + 0.5 * hash22(cell)) * 0.11;
		float radius = 0.012 + 0.014 * hash21(cell + 9.0);
		float ring = 1.0 - smoothstep(0.0, max(0.006, px), abs(length(p - center) - radius));
		return mix(base, vec3(1.0), ring * 0.55 * step(0.5, hash21(cell + 5.0)) * fine);
	}
	if (sand_kind == KIND_CRYSTAL) {
		vec2 g = p / 0.13;
		vec2 gi = floor(g);
		float d1 = 9.0;
		float d2 = 9.0;
		vec2 nearest = vec2(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 o = gi + vec2(float(x), float(y));
				float d = length(g - (o + hash22(o)));
				if (d < d1) {
					d2 = d1;
					d1 = d;
					nearest = o;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
		float facet = hash21(nearest + 2.0);
		vec3 col = mix(base * 0.72, mix(base, lit, 0.7), facet);
		float seam = 1.0 - smoothstep(0.02, 0.02 + max(0.05, px / 0.13), d2 - d1);
		return mix(col, vec3(1.0), seam * 0.7);
	}
	if (sand_kind == KIND_STARDUST) {
		vec3 col = mix(base * base * 0.42, base * 0.72, 0.45);
		vec2 cell = floor(p / 0.045);
		vec2 dd = abs(p - (cell + 0.25 + 0.5 * hash22(cell)) * 0.045);
		float core = 1.0 - smoothstep(0.0, max(0.008, px * 0.9), length(dd));
		float ray = (1.0 - smoothstep(0.0, max(0.003, px * 0.5), min(dd.x, dd.y)))
				* (1.0 - smoothstep(0.004, 0.02, max(dd.x, dd.y)));
		float star = max(core, ray * fine) * step(0.55, hash21(cell + 4.0));
		return mix(col, vec3(1.0, 0.97, 0.86), star);
	}
	if (sand_kind == KIND_GRAIN) {
		vec2 cell = floor(p / 0.036);
		float d = length(p - (cell + 0.25 + 0.5 * hash22(cell)) * 0.036);
		float dot_cov = 1.0 - smoothstep(0.008, 0.008 + max(0.004, px), d);
		vec3 speck = hash21(cell + 3.1) > 0.5 ? lit : dark;
		return mix(base, speck, dot_cov * mix(0.45, 0.85, fine));
	}
	// さらさら(既定)と光: 細かい粒。画素の大きさに合わせて段を選ぶ(縮めてもちらつかない)。
	float lod = log2(max(px * 1.3 * 150.0, 1.0));
	float l0 = floor(lod);
	float g0 = 150.0 / exp2(l0);
	float grain = mix(hash21(floor(p * g0)), hash21(floor(p * g0 * 0.5)), lod - l0);
	float sparkle = step(0.975, hash21(floor(p * g0 * 0.5) + 7.0)) * fine;
	vec3 col = base * (1.0 + (grain - 0.4) * mix(0.02, 0.055, fine));
	return col + sparkle * 0.08 * lit;
}


// 1画素ぶんの情報。fragment() で1度作り、各部品へ渡す。
struct Px {
	vec2 p;
	float px;
	float ow;
	float pad;
	float ay;
	float side;
	float ao;
	float glow_k;
};

vec2 local_pos(vec2 uv) {
	vec2 p = (uv - 0.5) * 2.0 * HALF;
	p.y = -p.y;
	return p;
}

Px frag_setup(vec2 p, float px) {
	Px f;
	f.p = p;
	f.px = px;
	f.ow = max(OUTLINE, 1.15 * px);
	f.pad = f.ow + px;
	f.ay = abs(p.y);
	f.side = p.y >= 0.0 ? 1.0 : -1.0;
	// 上の板の下・下の板の上へ落ちる影
	float plate_edge = PLATE_Y - PLATE_HALF.y;
	float ao_top = 1.0 - 0.45 * exp(-max(plate_edge - p.y, 0.0) / 0.075) * step(0.0, p.y);
	float ao_bottom = 1.0 - 0.25 * exp(-max(plate_edge + p.y, 0.0) / 0.05) * step(p.y, 0.0);
	f.ao = ao_top * ao_bottom;
	f.glow_k = sand_kind == KIND_GLOW ? 1.0 : glow * 0.6;
	return f;
}

vec3 ink_of(vec3 base) {
	return base * base * 0.22 + vec3(0.03, 0.02, 0.03);
}

float cov(float d, float px) {
	return clamp(0.5 - d / px, 0.0, 1.0);
}

vec2 rot(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float sd_ellipse(vec2 p, vec2 r) {
	float k0 = length(p / r);
	float k1 = length(p / (r * r));
	return k0 * (k0 - 1.0) / max(k1, 0.0001);
}

float sd_rhombus(vec2 p, vec2 b) {
	p = abs(p);
	float h = clamp((-2.0 * (p.x * b.x - p.y * b.y) + b.x * b.x - b.y * b.y) / dot(b, b), -1.0, 1.0);
	float d = length(p - 0.5 * b * vec2(1.0 - h, 1.0 + h));
	return d * sign(p.x * b.y + p.y * b.x - b.x * b.y);
}

// 4方向へ伸びるきらめき
float star4(vec2 d, float size) {
	d = abs(d) / size;
	float core = exp(-dot(d, d) * 9.0);
	float rays = exp(-min(d.x, d.y) * 20.0) * max(1.0 - max(d.x, d.y), 0.0);
	return clamp(core + rays * 0.85, 0.0, 1.0);
}

// 光(発光・後光)を重ねる。地が無い所では色つきの薄い膜になる。
void add_light(inout vec4 acc, vec3 c, float a) {
	a = clamp(a, 0.0, 1.0);
	acc.rgb = mix(acc.rgb, acc.rgb + c * a, step(0.001, acc.a));
	acc.rgb = min(acc.rgb, vec3(1.0));
	float na = a + acc.a * (1.0 - a);
	acc.rgb = mix(c, acc.rgb, acc.a / max(na, 0.0001));
	acc.a = na;
}
