class_name RankedWaitFunnel
extends RefCounted
## ランクマッチの最初の待機を、始めてから対局が決まるかやめるまで数える
## (GameDesign.md 22章 / Architecture.md 10.9節)。2回目以降の待機は追わない。

var _host: Node
var _active := false
## 待機が終わった後に残ったタイマーを無効にするための番号。
var _serial := 0


func _init(host: Node) -> void:
	_host = host


func begin() -> void:
	if _active or FunnelService.has_reached(FunnelService.RANKED_WAIT):
		return
	_active = true
	FunnelService.reach(FunnelService.RANKED_WAIT)
	_count_seconds(_serial)


func switched_to_cpu() -> void:
	if _active:
		FunnelService.reach(FunnelService.RANKED_CPU)


## `step` が空なら何も数えずに追跡だけを終える(通信の失敗など)。
func end(step: String = "") -> void:
	if not _active:
		return
	_active = false
	_serial += 1
	if not step.is_empty():
		FunnelService.reach(step)


func _count_seconds(serial: int) -> void:
	var elapsed := 0
	for seconds: int in FunnelService.RANKED_WAIT_SECONDS:
		await _host.get_tree().create_timer(seconds - elapsed).timeout
		elapsed = seconds
		if serial != _serial:
			return
		FunnelService.reach(FunnelService.ranked_wait_after(seconds))
