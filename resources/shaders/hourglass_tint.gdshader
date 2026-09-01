shader_type canvas_item;
// 砂時計の絵の色を1段ぶん回す(Architecture.md 4.1節)。
// tools/tint_hourglass_icons.gd の _tint() と同じ式で、明度と彩度の下駄を足してある。
//
// 焼き付け専用に使うため blend_disabled にしてある。透明な下地と混ぜると
// 縁の半透明な画素で色があらかじめアルファ倍され、読み戻した絵が暗くなる。
render_mode blend_disabled, unshaded;

uniform sampler2D source_art : filter_nearest;
uniform float hue_shift = 0.0;
uniform float saturation = 1.0;
uniform float saturation_bias = 0.0;
uniform float saturation_floor = 0.0;
uniform float value_scale = 1.0;
uniform float value_bias = 0.0;
uniform float threshold = 0.0;

vec3 to_hsv(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float d = mx - mn;
	float h = 0.0;
	if (d > 1e-6) {
		if (mx == c.r) {
			h = mod((c.g - c.b) / d, 6.0);
		} else if (mx == c.g) {
			h = (c.b - c.r) / d + 2.0;
		} else {
			h = (c.r - c.g) / d + 4.0;
		}
	}
	return vec3(h / 6.0, mx > 0.0 ? d / mx : 0.0, mx);
}

vec3 to_rgb(vec3 hsv) {
	float h = fract(hsv.x) * 6.0;
	float f = fract(h);
	float p = hsv.z * (1.0 - hsv.y);
	float q = hsv.z * (1.0 - f * hsv.y);
	float t = hsv.z * (1.0 - (1.0 - f) * hsv.y);
	int i = int(floor(h)) % 6;
	if (i == 0) return vec3(hsv.z, t, p);
	if (i == 1) return vec3(q, hsv.z, p);
	if (i == 2) return vec3(p, hsv.z, t);
	if (i == 3) return vec3(p, q, hsv.z);
	if (i == 4) return vec3(t, p, hsv.z);
	return vec3(hsv.z, p, q);
}

void fragment() {
	vec4 src = texture(source_art, UV);
	vec3 hsv = to_hsv(src.rgb);
	if (hsv.y >= threshold) {
		hsv.x = fract(hsv.x + hue_shift);
		hsv.y = clamp(max(hsv.y * saturation + saturation_bias, saturation_floor), 0.0, 1.0);
		hsv.z = clamp(hsv.z * value_scale + value_bias, 0.0, 1.0);
	}
	COLOR = vec4(to_rgb(hsv), src.a);
}
