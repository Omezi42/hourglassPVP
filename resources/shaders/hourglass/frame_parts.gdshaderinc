// 砂時計の枠の部品(Architecture.md 10.19節)。hourglass_lib の後に読む。

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
