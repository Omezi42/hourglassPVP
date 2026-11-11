// スキンの枠の部品(Architecture.md 10.19節)。hourglass_lib の後に読む。

const vec3 GOLD = vec3(0.93, 0.73, 0.33);
const vec3 SILVER = vec3(0.80, 0.83, 0.89);
const vec3 EYE_WHITE = vec3(0.97, 0.95, 0.90);

// キャンバスの端へ向けて 0 になる窓(後ろへ敷く光が矩形で切れて見えないように)
float canvas_window(vec2 p) {
	float wx = 1.0 - smoothstep(0.80, 1.0, abs(p.x));
	float wy = (1.0 - smoothstep(1.16, 1.38, p.y)) * smoothstep(-1.28, -1.10, p.y);
	return wx * wy;
}

// 縦の円柱
void draw_column(inout vec4 acc, Px f, float cx, float r, float y0, float y1, vec3 col, float metal) {
	float lx = f.p.x - cx;
	if (abs(lx) > r + f.pad || f.p.y < y0 - f.pad || f.p.y > y1 + f.pad) {
		return;
	}
	float d = max(abs(lx) - r, max(y0 - f.p.y, f.p.y - y1));
	vec3 n = lathe_normal(clamp(lx / r, -1.0, 1.0), 0.0);
	part(acc, d, ink_of(col), shade_mat(col, n, metal, 1.0, f.ao), f.ow, f.px);
}

// 横に寝た輪(柱の飾り輪・受け)
void draw_band(inout vec4 acc, Px f, vec2 c, vec2 hs, vec3 col, float metal) {
	vec2 q = f.p - c;
	if (abs(q.x) > hs.x + f.pad || abs(q.y) > hs.y + f.pad) {
		return;
	}
	float d = sd_round_box(q, hs, min(hs.y, 0.02));
	float ru = clamp(q.x / hs.x, -1.0, 1.0);
	float rv = clamp(q.y / hs.y, -1.0, 1.0);
	vec3 n = normalize(vec3(ru, rv * 0.85, sqrt(max(1.0 - ru * ru, 0.0)) * sqrt(max(1.0 - 0.72 * rv * rv, 0.0)) + 0.04));
	part(acc, d, ink_of(col), shade_mat(col, n, metal, 1.0, f.ao), f.ow, f.px);
}

void draw_ball(inout vec4 acc, Px f, vec2 c, float r, vec3 col, float metal) {
	vec2 q = f.p - c;
	if (length(q) > r + f.pad) {
		return;
	}
	vec3 n = normalize(vec3(q, sqrt(max(r * r - dot(q, q), 0.0)) + 0.004));
	part(acc, length(q) - r, ink_of(col), shade_mat(col, n, metal, 1.0, 1.0), f.ow, f.px);
}

// 天板・底板。正面は平ら、上下の縁だけ面取り。戻り値は板の距離(飾りを板の中へ切り抜くため)。
float draw_slab(inout vec4 acc, Px f, float cy, vec2 hs, float rr, vec3 col, float metal, float gloss) {
	vec2 q = vec2(f.p.x, f.p.y - cy);
	float d = sd_round_box(q, hs, rr);
	if (abs(q.x) > hs.x + f.pad || abs(q.y) > hs.y + f.pad) {
		return d;
	}
	float v = q.y / hs.y;
	float ny = smoothstep(0.38, 0.54, v) * 0.75 - smoothstep(0.42, 0.58, -v) * 0.8;
	float end_round = smoothstep(hs.x - 0.07, hs.x, abs(q.x)) * sign(q.x);
	vec3 n = normalize(vec3(q.x / hs.x * 0.22 + end_round * 0.9, ny, 0.72));
	part(acc, d, ink_of(col), shade_mat(col, n, metal, gloss, 1.0), f.ow, f.px);
	return d;
}

// 受け金(ガラスの上下)
void draw_collars(inout vec4 acc, Px f, vec3 col, float metal) {
	draw_band(acc, f, vec2(0.0, f.side * 0.968), vec2(0.50, 0.048), col, metal);
}

// 板の中だけに塗る(縁の面取りと輪郭を残す)
void inlay(inout vec4 acc, float slab_d, vec3 col, float a, Px f) {
	over(acc, col, a * cov(slab_d + f.ow * 0.6, f.px));
}

// 目。open は開き具合(0〜1)、look は視線(-1〜1)。
void draw_eye(inout vec4 acc, Px f, vec2 c, float hw, float hh, float open, vec3 iris_col) {
	vec2 q = f.p - c;
	if (abs(q.x) > hw + f.pad || abs(q.y) > hh + f.pad) {
		return;
	}
	float t = clamp(q.x / hw, -1.0, 1.0);
	float lid = hh * max(open, 0.04) * (1.0 - t * t);
	float d_eye = max(abs(q.y) - lid, abs(q.x) - hw);
	vec2 gaze = look;
	if (length(gaze) > 1.0) {
		gaze = normalize(gaze);
	}
	vec2 ic = vec2(gaze.x * hw * 0.42, gaze.y * hh * 0.30);
	float ir = hh * 0.82;
	float di = length(q - ic);
	// 白目は上瞼の影で上が沈む
	vec3 white = mix(EYE_WHITE, EYE_WHITE * vec3(0.72, 0.70, 0.80), smoothstep(-0.2, 1.0, q.y / max(lid, 0.001)));
	float iris = cov(di - ir, f.px);
	float ang = atan(q.y - ic.y, q.x - ic.x);
	float fiber = 0.85 + 0.15 * sin(ang * 14.0 + seed);
	vec3 iris_rgb = mix(iris_col * 0.45, iris_col * 1.15, smoothstep(ir, ir * 0.35, di)) * fiber;
	float pupil = cov(di - ir * 0.42, f.px);
	vec3 rgb = mix(white, iris_rgb, iris);
	rgb = mix(rgb, vec3(0.04, 0.02, 0.08), pupil);
	float hl = cov(length(q - ic - vec2(-ir * 0.35, ir * 0.35)) - ir * 0.22, f.px);
	rgb = mix(rgb, vec3(1.0), hl * 0.9);
	over(acc, vec3(0.08, 0.04, 0.12), cov(d_eye - f.ow * 0.9, f.px));
	over(acc, rgb, cov(d_eye, f.px));
}
