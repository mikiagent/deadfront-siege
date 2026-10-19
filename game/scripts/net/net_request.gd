class_name NetRequest
extends RefCounted
## One request from NetClient.request(). `await req.done` right away, then read ok / r / err.
## Completion always comes at least one frame later, so an immediate await never misses it.
## Client-only err codes: "timeout" (no answer in time) and "offline" (not connected).

signal done(req: NetRequest)

var id := 0
var op := ""
var frame := ""
var deadline := 0.0
var finished := false
var ok := false
var r: Dictionary = {}
var err := ""
var msg := ""

func finish(res: Dictionary) -> void:
	if finished:
		return
	finished = true
	ok = res.get("ok") == true
	if ok:
		r = res["r"] if res.get("r") is Dictionary else {}
	else:
		err = str(res.get("err", "server_error"))
		msg = str(res.get("msg", ""))
	done.emit(self)
