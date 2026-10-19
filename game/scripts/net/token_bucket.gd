class_name TokenBucket
extends RefCounted
## Token bucket rate limiter (contracts.md §5.4). The caller passes the clock in.

var rate: float
var burst: float
var tokens: float
var stamp: float

func _init(p_rate: float, p_burst: float, now: float) -> void:
	rate = p_rate
	burst = p_burst
	tokens = p_burst
	stamp = now

func take(now: float) -> bool:
	_refill(now)
	if tokens < 1.0:
		return false
	tokens -= 1.0
	return true

func is_full(now: float) -> bool:
	_refill(now)
	return tokens >= burst

func _refill(now: float) -> void:
	tokens = minf(burst, tokens + maxf(0.0, now - stamp) * rate)
	stamp = now
