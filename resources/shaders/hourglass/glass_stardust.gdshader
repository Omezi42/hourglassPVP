shader_type canvas_item;
// 全カード共通のガラスと砂(砂の質感「stardust」)。Architecture.md 10.19節。
// 砂の色・量・流れは uniform で外から渡す。質感は uniform にしない(分岐が全部コンパイルされ重くなるため)。

#define SAND_KIND KIND_STARDUST
#include "res://resources/shaders/hourglass/hourglass_lib.gdshaderinc"
#include "res://resources/shaders/hourglass/hourglass_glass.gdshaderinc"

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 2.0 * HALF.x, -HALF.y + (1.0 - UV.y) * (2.0 * HALF.y + 0.0963));
	float px = max(length(vec2(dFdx(p.x), dFdy(p.x))), 0.00001);
	Px f = frag_setup(p, px);
	vec4 acc = vec4(0.0);
	draw_glass(acc, f);
	COLOR = vec4(acc.rgb * COLOR.rgb, acc.a * COLOR.a);
}
