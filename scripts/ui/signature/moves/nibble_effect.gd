extends SignatureMove
## ニブルの落砂(GameDesign.md 9章):駒から砂粒が1つ跳ねて体力のいちばん少ない駒へ飛び、
## かじるように三日月の噛み跡が残って火花が散る(打撃)。

const HOP := 0.16
const FLIGHT := 0.3
## 跳ね上がる高さ(駒の中心から)と砂粒の大きさ。
const HOP_HEIGHT := 30.0
const GRAIN := 3.4
const GRAIN_COLOR := Color(0.9, 0.78, 0.52, 1.0)
## 弧の膨らみ(2点間の距離に対する割合)。
const ARC := 0.3
## 噛み跡:対象の中心からのずれ、弧の半径と太さ、描く角度の幅。
const BITE_OFFSET := Vector2(10.0, -12.0)
const BITE_RADIUS := 9.0
const BITE_WIDTH := 3.0
const BITE_SPAN := 2.2
const BITE_POINTS := 12
const BITE_COLOR := Color(0.24, 0.18, 0.12, 1.0)


func impact_at() -> float:
	return HOP + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var target: Vector2 = targets[0]
	var peak := from - Vector2(0.0, HOP_HEIGHT)
	if t < HOP:
		var rise := ease(phase(t, 0.0, HOP), 0.5)
		ShapePaint.circle(
			item.get_canvas_item(), from.lerp(peak, rise), GRAIN, Color(GRAIN_COLOR, alpha)
		)
		return
	if t < impact_at():
		var flight := phase(t, HOP, FLIGHT)
		ShapePaint.circle(
			item.get_canvas_item(),
			_arc_point(peak, target, flight),
			GRAIN,
			Color(GRAIN_COLOR, alpha)
		)
		return
	var after := phase(t, impact_at(), FADE)
	var bite := target + BITE_OFFSET
	# 噛み跡は対象の中心へ口を向けた三日月にする。
	var facing := (target - bite).angle()
	ShapePaint.arc(
		item.get_canvas_item(),
		bite,
		BITE_RADIUS,
		facing - BITE_SPAN / 2.0,
		facing + BITE_SPAN / 2.0,
		BITE_POINTS,
		Color(BITE_COLOR, alpha),
		BITE_WIDTH,
		true
	)
	SignaturePaint.sparks(item, bite, after, alpha)


## 出どころから対象へ、上へ膨らむ弧の上の1点。
func _arc_point(start: Vector2, end: Vector2, progress: float) -> Vector2:
	var lift := start.distance_to(end) * ARC * 4.0 * progress * (1.0 - progress)
	return start.lerp(end, progress) - Vector2(0.0, lift)
