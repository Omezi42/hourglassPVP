// 砂時計の絵の fragment()(Architecture.md 10.19節)。カードのシェーダーの最後に読む。
// ART_STATIC があれば止めた部分を描く(layer 0=後ろ / 1=枠)。無ければ動きだけを描く:
// 自分の下の焼いた絵(under_tex)を読み、その上へ motion_back() / motion_front() を重ねる。
// 400x532 の矩形へ貼る。座標は本体と同じで、上へ広いぶん(TOP_EXTRA)を天板の上の飾りに使える。

const float TOP_EXTRA = 0.0963;
// 0=ガラスの後ろ / 1=枠の手前
uniform int layer = 0;
#ifndef ART_STATIC
uniform sampler2D under_tex : filter_linear;
#endif

void fragment() {
	vec4 vertex_color = COLOR;
	vec2 p = vec2((UV.x - 0.5) * 2.0 * HALF.x, -HALF.y + (1.0 - UV.y) * (2.0 * HALF.y + TOP_EXTRA));
	float px = max(length(vec2(dFdx(p.x), dFdy(p.x))), 0.00001);
	Px f = frag_setup(p, px);
#ifdef ART_STATIC
	vec4 acc = vec4(0.0);
	if (layer == 0) {
		art_back(acc, f);
	} else {
		art_frame(acc, f);
	}
#else
	vec4 acc = texture(under_tex, UV);
	if (layer == 0) {
		motion_back(acc, f);
	} else {
		motion_front(acc, f);
	}
#endif
	COLOR = vec4(acc.rgb * vertex_color.rgb, acc.a * vertex_color.a);
}
