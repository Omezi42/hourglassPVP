// 砂時計の絵の fragment()(Architecture.md 10.19節)。カードのシェーダーの最後に読む。
// layer 0=後ろ(art_back) / 1=枠(art_frame)を描く。ビルド前に焼く道具だけが使う。
// 400x532 の矩形へ貼る。座標は本体と同じで、上へ広いぶん(TOP_EXTRA)を天板の上の飾りに使える。

// 透明な下地へ焼くので、乗算済みの合成にして色をそのまま書く(混ぜる合成だと半透明の光の色に不透明度が二重に掛かる)。
render_mode blend_premul_alpha;

const float TOP_EXTRA = 0.0963;
uniform int layer = 0;

void fragment() {
	vec4 vertex_color = COLOR;
	vec2 p = vec2((UV.x - 0.5) * 2.0 * HALF.x, -HALF.y + (1.0 - UV.y) * (2.0 * HALF.y + TOP_EXTRA));
	float px = max(length(vec2(dFdx(p.x), dFdy(p.x))), 0.00001);
	Px f = frag_setup(p, px);
	vec4 acc = vec4(0.0);
	if (layer == 0) {
		art_back(acc, f);
	} else {
		art_frame(acc, f);
	}
	COLOR = vec4(acc.rgb * vertex_color.rgb, acc.a * vertex_color.a);
}
