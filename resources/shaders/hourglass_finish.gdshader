shader_type canvas_item;
// 色変換の後に、砂の質感と枠の素材を重ねる(Architecture.md 4.1節 / GameDesign.md 9章)。
// region は原本の領域マスク(R=砂 / G=枠 / B=ガラスの内側)。
// 枠の素材は原本の明度から描くため、色変換で枠が何色に染まっていても同じ素材になる。
//
// 焼き付け専用に使うため blend_disabled にしてある(hourglass_tint.gdshader と同じ理由)。
render_mode blend_disabled, unshaded;

const int TEXTURE_GRAIN = 1;
const int TEXTURE_LIQUID = 2;
const int TEXTURE_CRYSTAL = 3;
const int TEXTURE_GLOW = 4;
const int TEXTURE_STARDUST = 5;
const int FRAME_WOOD = 1;
const int FRAME_IRON = 2;
const int FRAME_BRASS = 3;
const int FRAME_STONE = 4;
const int FRAME_EBONY = 5;
const int FRAME_PORCELAIN = 6;

uniform sampler2D source_art : filter_nearest;
uniform sampler2D master_art : filter_nearest;
uniform sampler2D region : filter_nearest;
uniform vec2 px_size = vec2(400.0, 513.0);
uniform int texture_kind = 0;
uniform int frame_kind = 0;
// その絵の砂の色。光がガラスへ漏らす色に使う。
uniform vec4 sand_color : source_color = vec4(1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 17.3));
}

vec3 to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// 格子1マスに1つ、マスの中のどこかへ置いた点までの距離。
float cell_point(vec2 px, float cell_px, out vec2 cell) {
	cell = floor(px / cell_px);
	vec2 center = (cell + 0.2 + 0.6 * hash2(cell)) * cell_px;
	return length(px - center);
}

vec3 sand_texture(vec3 hsv, vec2 px, vec2 uv) {
	vec3 base = to_rgb(hsv);
	vec2 cell;
	if (texture_kind == TEXTURE_GRAIN) {
		float d = cell_point(px, 7.0, cell);
		float grain = 1.0 - smoothstep(1.6, 2.6, d);
		float shade = hash(cell + 3.1) > 0.5 ? 1.35 : 0.55;
		return mix(base, base * shade, grain * 0.9);
	}
	if (texture_kind == TEXTURE_LIQUID) {
		float v = mix(0.80, 0.98, smoothstep(0.0, 0.5, hsv.z));
		vec3 col = to_rgb(vec3(hsv.x, clamp(hsv.y * 1.15, 0.0, 1.0), v));
		float streak = smoothstep(0.012, 0.0, abs(uv.x - 0.36)) * step(0.7, hsv.z);
		col = mix(col, vec3(1.0), streak * 0.75);
		float d = cell_point(px, 26.0, cell);
		float radius = 3.0 + 3.0 * hash(cell + 9.0);
		float bubble = smoothstep(1.6, 0.4, abs(d - radius)) * step(0.55, hash(cell + 5.0));
		return mix(col, vec3(1.0), bubble * 0.8);
	}
	if (texture_kind == TEXTURE_CRYSTAL) {
		vec2 g = px / 30.0;
		vec2 gi = floor(g);
		float d1 = 9.0;
		float d2 = 9.0;
		vec2 nearest = vec2(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 o = gi + vec2(float(x), float(y));
				float d = length(g - (o + hash2(o)));
				if (d < d1) {
					d2 = d1;
					d1 = d;
					nearest = o;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
		float facet = 0.72 + 0.5 * hash(nearest);
		float edge = 1.0 - smoothstep(0.03, 0.08, d2 - d1);
		vec3 col = to_rgb(vec3(hsv.x, hsv.y * 0.85, clamp(0.55 + 0.45 * facet, 0.0, 1.0)));
		return mix(col, vec3(1.0), edge * 0.85);
	}
	if (texture_kind == TEXTURE_GLOW) {
		vec3 col = to_rgb(vec3(hsv.x, hsv.y * 0.55, 1.0));
		cell = floor(px / 18.0);
		vec2 dd = abs(px - (cell + 0.2 + 0.6 * hash2(cell)) * 18.0);
		float star = (1.0 - smoothstep(0.6, 1.4, min(dd.x, dd.y)))
				* (1.0 - smoothstep(2.0, 6.0, max(dd.x, dd.y)))
				* step(0.55, hash(cell + 2.0));
		return mix(col, vec3(1.0), star);
	}
	if (texture_kind == TEXTURE_STARDUST) {
		vec3 col = to_rgb(vec3(hsv.x, clamp(hsv.y * 1.1, 0.0, 1.0), hsv.z * 0.32));
		float d = cell_point(px, 9.0, cell);
		float star = (1.0 - smoothstep(0.7, 1.8, d)) * step(0.6, hash(cell + 4.0));
		return mix(col, vec3(1.0, 0.97, 0.85), star);
	}
	return base;
}

vec3 frame_material(vec3 original, vec3 tinted, vec2 px) {
	float v = to_hsv(original).z;
	if (frame_kind == FRAME_WOOD) {
		return original;
	}
	if (frame_kind == FRAME_IRON) {
		return to_rgb(vec3(0.6, 0.10, clamp((v - 0.5) * 1.5 + 0.62, 0.0, 1.0)));
	}
	if (frame_kind == FRAME_BRASS) {
		float shine = smoothstep(0.82, 0.95, v);
		return to_rgb(vec3(0.125, mix(0.78, 0.35, shine), clamp(v * 1.2, 0.0, 1.0)));
	}
	if (frame_kind == FRAME_STONE) {
		float noise = hash(floor(px / 3.0)) * 0.12 - 0.06;
		return to_rgb(vec3(0.09, 0.07, clamp(v * 0.85 + noise, 0.0, 1.0)));
	}
	if (frame_kind == FRAME_EBONY) {
		return to_rgb(vec3(0.02, 0.5, clamp(v * 0.42, 0.0, 1.0)));
	}
	if (frame_kind == FRAME_PORCELAIN) {
		return to_rgb(vec3(0.11, 0.13, clamp(0.5 + v * 0.5, 0.0, 1.0)));
	}
	return tinted;
}

void fragment() {
	vec4 src = texture(source_art, UV);
	vec4 reg = texture(region, UV);
	vec2 px = UV * px_size;
	vec3 col = src.rgb;
	col = mix(col, sand_texture(to_hsv(src.rgb), px, UV), reg.r);
	if (texture_kind == TEXTURE_GLOW) {
		float glass = reg.b * (1.0 - reg.r);
		vec3 spill = to_rgb(vec3(to_hsv(sand_color.rgb).x, 0.45, 1.0));
		col = mix(col, spill, glass * 0.35);
	}
	col = mix(col, frame_material(texture(master_art, UV).rgb, src.rgb, px), reg.g);
	COLOR = vec4(col, src.a);
}
