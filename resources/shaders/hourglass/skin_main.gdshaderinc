// スキンの fragment()(Architecture.md 10.19節)。スキンのシェーダーの最後に読む。
// skin_back()(ガラスの後ろ)→ ガラス玉と砂 → skin_frame()(枠と飾り)の順に重ねる。
// 400x532 の矩形へ貼る。座標は本体と同じで、上へ広いぶん(TOP_EXTRA)を天板の上の飾りに使える。

const float TOP_EXTRA = 0.0963;

void fragment() {
	vec4 vertex_color = COLOR;
	vec2 p = vec2((UV.x - 0.5) * 2.0 * HALF.x, -HALF.y + (1.0 - UV.y) * (2.0 * HALF.y + TOP_EXTRA));
	float px = max(length(vec2(dFdx(p.x), dFdy(p.x))), 0.00001);
	Px f = frag_setup(p, px);
	vec4 acc = vec4(0.0);
	skin_back(acc, f);
	draw_glass(acc, f);
	skin_frame(acc, f);
	COLOR = vec4(acc.rgb * vertex_color.rgb, acc.a * vertex_color.a);
}
