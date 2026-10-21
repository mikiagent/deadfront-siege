class_name NetMarketClient
extends MarketClient
## The live transport: market ops over the game's socket (Game.net, NET's NetClient, relayed by
## the server into VaultBridge.client - W1-INT's relay, exchange-spec §2 and §10).
## Duck-typed: NetClient is not a class on this base, so nothing here is typed against it.
## NetClient puts its own rid on every envelope; a request that timed out is resent with
## NetClient.retry(req) under that same rid, never as a new request (contract 5.3).

const RETRIES := 2

var net: Object

func _init(p_net: Object) -> void:
	net = p_net
	account = int(net.get("account_id")) if net.get("account_id") is int else -1

func is_online() -> bool:
	return net != null and bool(net.call("is_online"))

func kind() -> StringName:
	return &"net"

func label() -> String:
	return "Island Market"

func _send(op: String, a: Dictionary) -> Dictionary:
	var body := a.duplicate()
	body.erase("rid") # the envelope carries NetClient's rid; the relay copies it into a.rid
	var req: Variant = net.call("request", op, body)
	await req.done
	for i in RETRIES:
		if str(req.err) != "timeout":
			break
		req = net.call("retry", req)
		await req.done
	if req.ok:
		return {"ok": true, "r": req.r}
	return {"ok": false, "err": str(req.err), "msg": str(req.msg)}
