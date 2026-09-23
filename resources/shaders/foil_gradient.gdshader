shader_type canvas_item;
// 金箔の縦グラデーション(TitleLogo)。白で描いた図形へ、ノードの縦位置に応じた
// 金の色を掛ける。掛け算にするのは、親のmodulate(起動時のフェード・押したときの光)を残すため。

uniform float top_y;
uniform float bottom_y;
uniform vec4 top_color : source_color;
uniform vec4 mid_color : source_color;
uniform vec4 bottom_color : source_color;
// 上寄りに1本だけ通す明るい帯(箔の照り返し)。位置は帯の中の割合。
uniform float sheen_at = 0.42;
uniform float sheen_width = 0.06;
uniform vec4 sheen_color : source_color;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float t = clamp((local_y - top_y) / (bottom_y - top_y), 0.0, 1.0);
	vec3 foil = t < 0.5
		? mix(top_color.rgb, mid_color.rgb, t * 2.0)
		: mix(mid_color.rgb, bottom_color.rgb, (t - 0.5) * 2.0);
	foil += sheen_color.rgb * (1.0 - smoothstep(0.0, sheen_width, abs(t - sheen_at)));
	COLOR.rgb *= foil;
}
