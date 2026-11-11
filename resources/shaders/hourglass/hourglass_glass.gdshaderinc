// 砂時計のコード描画のガラス玉と砂(Architecture.md 10.19節)。スキンは HOOK_CAVITY / HOOK_FRONT を定義して、ガラスの中と手前へ描き足せる。

void draw_glass(inout vec4 acc, Px f) {
	vec2 p = f.p;
	float px = f.px;
	float ow = f.ow;
	float pad = f.pad;
	float ay = f.ay;
	float side = f.side;
	float ao = f.ao;
	float glow_k = f.glow_k;
	bool liquid = sand_kind == KIND_LIQUID;
	vec3 ink_glass = vec3(0.13, 0.15, 0.22);

	// ---- ガラス ----
	float gr = 0.0;
	float gslope = 0.0;
	float gnorm = 1.0;
	float gd = 1.0;
	float g_cov = 0.0;
	if (abs(p.x) < GLASS_R + pad && ay < GLASS_H + 0.03 + pad) {
		gr = glass_r(p.y);
		gslope = (glass_r(ay + 0.004) - glass_r(ay - 0.004)) / 0.008;
		gnorm = sqrt(1.0 + gslope * gslope);
		gd = (abs(p.x) - gr) / gnorm;
		gd = max(gd, ay - (GLASS_H + 0.03));
		g_cov = clamp(0.5 - gd / px, 0.0, 1.0);
		float g_ring = clamp(0.5 - (gd - ow) / px, 0.0, 1.0) * (1.0 - g_cov);
		over(acc, ink_glass, g_ring);
	}

	if (g_cov > 0.0) {
		float u = clamp(p.x / gr, -1.0, 1.0);
		vec3 gn = lathe_normal(u, gslope * side);
		float wall = min(WALL, gr * 0.42);
		float inner_d = (abs(p.x) - (gr - wall)) / gnorm;
		float cavity = clamp(0.5 - inner_d / px, 0.0, 1.0);

		// ガラスの肉(外周の帯)と内側の空間
		vec3 tint = vec3(0.72, 0.81, 0.94);
		float edge = smoothstep(0.30, 1.0, abs(u));
		float skylight = smoothstep(-0.4, 1.0, gn.y * 0.8 - u * 0.5);
		vec3 cav = tint * mix(mix(0.56, 0.84, glass_body), mix(1.02, 1.06, glass_body), skylight);
		cav = mix(cav, tint * mix(0.60, 0.74, glass_body), edge * 0.6);
		float cav_a = mix(mix(0.18, 0.90, glass_body), mix(0.52, 0.96, glass_body), edge);
		cav_a = mix(cav_a, 1.0, skylight * 0.12);
		// 光が抜ける側(右下)の内側に明るい三日月
		float caustic = pow(max(dot(gn, CAUSTIC_DIR), 0.0), 5.0) * smoothstep(0.25, 0.8, abs(u));
		caustic *= p.y >= 0.0 ? 0.35 : 1.0;
		cav = mix(cav, vec3(0.93, 0.97, 1.0), caustic * 0.50);
		cav_a = mix(cav_a, 1.0, caustic * 0.40);
		vec3 shell = mix(vec3(0.97, 0.99, 1.0), tint * 0.78, smoothstep(-0.5, 0.9, u));
		float shell_a = mix(0.78, 0.97, glass_body);

		// ---- 砂 ----
		float rin = max(gr - wall, 0.0001);
		float us = clamp(p.x / rin, -1.0, 1.0);

		// 上の部屋
		float has_top = step(0.002, sand_top);
		float lt = GLASS_H * 0.84 * pow(max(sand_top, 0.0001), 0.6);
		float rl = glass_r(lt) - min(WALL, glass_r(lt) * 0.42);
		float ex = sqrt(max(rl * rl - p.x * p.x, 0.0));
		float y_front = lt - TILT * ex;
		float y_back = lt + TILT * ex;
		float m_top_all = clamp(0.5 - (p.y - y_back) / px, 0.0, 1.0) * has_top;
		m_top_all *= clamp(0.5 + (p.y + 0.02) / px, 0.0, 1.0);
		float m_top_body = clamp(0.5 - (p.y - y_front) / px, 0.0, 1.0);

		// 下の部屋(山)。少ないうちは山だけ、壁へ届いたら底から積み上がる。液体は山を作らない。
		float yf = -GLASS_H;
		float rf = glass_r(GLASS_H * 0.7) - WALL;
		float area = sand_bottom * PILE_AREA;
		float hm_max = liquid ? 0.0 : MOUND_STEEP * MOUND_SPAN * rf;
		float area_m = MOUND_AREA * hm_max * hm_max / MOUND_STEEP;
		float hm = min(sqrt(area * MOUND_STEEP / MOUND_AREA), hm_max);
		float base = max(area - area_m, 0.0) / (2.0 * rf * 0.9);
		float mw = max(hm / MOUND_STEEP, 0.0001);
		float mt = abs(p.x) / mw;
		float cone = 1.0 + MOUND_TIP - sqrt(mt * mt + MOUND_TIP * MOUND_TIP);
		float mound = hm * 0.5 * (cone + sqrt(cone * cone + 0.003));
		float y_s = yf + base + mound;
		float rb = glass_r(yf + base) - WALL;
		float pile_ex = sqrt(max(rb * rb - p.x * p.x, 0.0));
		float y_c = yf + base - TILT * pile_ex;
		if (liquid) {
			y_s = yf + base + TILT * pile_ex;
		}
		float has_bottom = step(0.002, sand_bottom);
		float m_pile = clamp(0.5 - (p.y - y_s) / px, 0.0, 1.0) * step(p.y, 0.0) * has_bottom;
		float m_pile_body = clamp(0.5 - (p.y - y_c) / px, 0.0, 1.0);

		// 落ちる筋(下ほど細く、ところどころ途切れる)
		float y_apex = yf + base + hm;
		float fall_t = clamp(-p.y / max(-y_apex, 0.001), 0.0, 1.0);
		float stream_w = mix(0.020, 0.011, fall_t) + 0.003 * sin(p.y * 41.0 + clock * 13.0);
		float dash = hash21(vec2(floor((p.y + clock * 1.9) * 30.0), 5.0));
		float broken = liquid ? 1.0 : mix(1.0, step(0.35, dash), smoothstep(0.35, 1.0, fall_t));
		float m_stream = clamp(0.5 - (abs(p.x) - stream_w) / px, 0.0, 1.0) * broken;
		m_stream *= step(p.y, 0.03) * step(y_apex - 0.02, p.y) * flow * has_top;

		// 砂の色
		vec3 s_dark = pow(sand_color, vec3(1.7)) * 0.80;
		vec3 s_lit = mix(sand_color * 1.12, vec3(1.0, 0.96, 0.86), 0.30);
		if (sand_kind == KIND_GLOW) {
			s_dark = mix(sand_color, vec3(1.0), 0.15);
			s_lit = mix(sand_color, vec3(1.0), 0.75);
		}
		float lat = clamp(0.62 - 0.55 * us, 0.0, 1.0);
		vec3 s_mid = mix(s_dark, sand_color, 0.92);
		vec3 s_body = mix(s_dark, s_mid, smoothstep(0.0, 0.55, lat));
		s_body = mix(s_body, s_lit, (0.20 + 0.45 * glow_k) * smoothstep(0.5, 1.0, lat));

		// 上の砂: 手前の面は下ほど沈め、上の面(楕円)は明るく
		float depth_top = clamp((y_front - p.y) / 0.55, 0.0, 1.0);
		vec3 top_body = mix(s_body, s_dark, depth_top * 0.40);
		float er = length(vec2(p.x / max(rl, 0.001), (p.y - lt) / max(TILT * rl, 0.001)));
		vec3 top_cap = mix(mix(sand_color, s_lit, 0.75), s_mid, smoothstep(0.2, 1.0, er) * 0.35);
		if (!liquid) {
			top_cap = mix(top_cap, s_mid, flow * (1.0 - smoothstep(0.0, 0.6, er)) * 0.8);
		}
		if (liquid) {
			float wave = sin(er * 16.0 - clock * 5.0) * (1.0 - smoothstep(0.5, 1.0, er));
			top_cap = mix(top_cap, vec3(1.0), max(wave, 0.0) * 0.30 * flow);
		}
		vec3 top_col = sand_surface(mix(top_cap, top_body, m_top_body), s_dark, s_lit, p, px);
		float lip = 1.0 - smoothstep(0.0, max(0.012, 1.2 * px), abs(p.y - y_front));
		top_col = mix(top_col, vec3(1.0, 0.98, 0.92), lip * (liquid ? 0.65 : 0.30) * step(abs(p.x), rl));

		// 下の山: 斜面は左が明るく右が陰、手前は下ほど沈める
		float dzdx = -MOUND_STEEP * mt / sqrt(mt * mt + MOUND_TIP * MOUND_TIP) * sign(p.x) * step(mt, 1.1);
		float slope_lit = liquid ? 0.75 : clamp(0.5 + 0.8 * dzdx, 0.0, 1.0);
		vec3 pile_face = mix(mix(s_dark, s_mid, 0.72), mix(sand_color, s_lit, 0.7), slope_lit);
		float depth_pile = clamp((y_c - p.y) / 0.55, 0.0, 1.0);
		vec3 pile_body = mix(s_body, s_dark, depth_pile * 0.40);
		if (liquid) {
			float pr = length(vec2(p.x / max(rb, 0.001), (p.y - (yf + base)) / max(TILT * rb, 0.001)));
			float wave = sin(pr * 14.0 - clock * 5.0) * (1.0 - smoothstep(0.5, 1.0, pr));
			pile_face = mix(pile_face, vec3(1.0), max(wave, 0.0) * 0.30 * flow * has_top);
		}
		vec3 pile_col = sand_surface(mix(pile_face, pile_body, m_pile_body), s_dark, s_lit, p, px);
		float ridge = 1.0 - smoothstep(0.0, max(0.014, 1.3 * px), abs(p.y - (liquid ? y_c : y_s)));
		pile_col = mix(pile_col, vec3(1.0, 0.98, 0.9), ridge * (liquid ? 0.6 : 0.40 * slope_lit));

		// 砂の明かりがガラスへ漏れる
		float halo_top = exp(-max(p.y - y_back, 0.0) / 0.11) * has_top * step(0.0, p.y);
		float halo_bottom = exp(-max(p.y - y_s, 0.0) / 0.14) * has_bottom * step(p.y, 0.0);
		float halo = max(halo_top, halo_bottom);
		cav = mix(cav, s_lit, halo * 0.55 * glow_k + glow_k * 0.10 * float(sand_kind == KIND_GLOW));
		cav_a = mix(cav_a, 1.0, halo * 0.4 * glow_k);

#ifdef HOOK_CAVITY
		hook_cavity(cav, cav_a, f, u);
#endif

		// 底の楕円(ガラス越しに見える奥の縁)
		float floor_arc = abs(p.y - (yf + 0.012 + TILT * sqrt(max(rf * rf - p.x * p.x, 0.0))));
		float floor_line = (1.0 - smoothstep(0.0, max(0.008, px), floor_arc)) * step(p.y, 0.0);
		cav = mix(cav, vec3(1.0), floor_line * 0.22);

		vec3 stream_col = mix(sand_color, s_lit, 0.55);
		cav = mix(cav, stream_col, m_stream);
		cav_a = mix(cav_a, 1.0, m_stream);
		cav = mix(cav, top_col, m_top_all);
		cav_a = mix(cav_a, 1.0, m_top_all);
		cav = mix(cav, pile_col, m_pile);
		cav_a = mix(cav_a, 1.0, m_pile);

#ifdef HOOK_FRONT
		hook_front(cav, cav_a, f, u);
#endif

		// ---- 手前の面の映り込み ----
		float refl = 0.0;
		if (p.y >= 0.0) {
			refl += 0.66 * streak(p, gr, -0.62, 0.050, 0.40, 0.80, px);
			refl += 0.55 * streak(p, gr, -0.86, 0.014, 0.50, 0.76, px);
			refl += 0.22 * streak(p, gr, 0.74, 0.026, 0.26, 0.58, px);
		} else {
			refl += 0.58 * streak(p, gr, -0.62, 0.046, -0.72, -0.34, px);
			refl += 0.48 * streak(p, gr, -0.86, 0.014, -0.66, -0.44, px);
			refl += 0.22 * streak(p, gr, 0.74, 0.026, -0.80, -0.50, px);
		}
		float gspec = pow(max(dot(gn, HALF_VEC), 0.0), 120.0);
		refl = clamp(refl + gspec * 0.35, 0.0, 1.0);
		cav = mix(cav, vec3(1.0), refl);
		cav_a = mix(cav_a, 1.0, refl * 0.9);

		vec3 g_rgb = mix(shell, cav, cavity);
		float g_a = mix(shell_a, cav_a, cavity);
		// 輪郭のすぐ内側に細い縁の光(暗い地でガラスの形を拾う)
		float rim_band = 1.0 - smoothstep(0.0, max(0.011, 1.1 * px), -gd);
		float rim_side = mix(0.80, 0.34, smoothstep(-0.3, 0.3, u));
		g_rgb = mix(g_rgb, vec3(1.0), rim_band * rim_side);
		g_a = mix(g_a, 1.0, rim_band * rim_side);
		g_rgb *= ao;
		over(acc, g_rgb, g_a * g_cov);
	}
}
