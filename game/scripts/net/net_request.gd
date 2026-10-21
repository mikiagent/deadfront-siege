class_name NetRequest
extends RefCounted
## One request from NetClient.request(). `await req.done` right away, then read ok / r / err.
## Completion always comes at least one frame later, so an immediate await never misses it.
## Client-only err codes: "timeout" (no answer in time) and "offline" (not connected, or the
## connection dropped after the request was sent). After either, the server may or may not
## have applied it: NetClient.retry(req) resends under the same rid, so a mutating op still
## applies at most once.

signal done(req: NetRequest)

var id := 0
var op := ""
var a: Dictionary = {}
var rid := ""
var frame := ""
var deadline := 0.0
var sent := false  ## written to a socket at least once
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
	r = res["r"] if res.get("r") is Dictionary else {}  # a failure may carry details too (limit_reached: next_instance)
	if not ok:
		err = str(res.get("err", "server_error"))
		msg = str(res.get("msg", ""))
	done.emit(self)
