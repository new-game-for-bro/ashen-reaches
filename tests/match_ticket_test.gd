extends SceneTree

## Headless checks for MatchTicket. Run from the project root:
##   godot --headless --path . --script res://tests/match_ticket_test.gd

const Ticket = preload("res://scripts/net/match_ticket.gd")

var _checks := 0
var _failures := 0
var _secret := "0123456789abcdef0123456789abcdef".to_utf8_buffer()


func _initialize() -> void:
	_test_round_trip()
	_test_secret_and_claim_rules()
	_test_tampering()
	_test_expiry()
	_test_server_binding()
	_test_replay_cache()
	print("--- %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(label: String, condition: bool) -> void:
	_checks += 1
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)


func _flip(text: String) -> String:
	var replacement := "A" if text.substr(0, 1) != "A" else "B"
	return replacement + text.substr(1)


func _test_round_trip() -> void:
	var token := Ticket.issue(_secret, {"player_id": "p1", "lobby_id": "l1", "server_id": "s1"}, 10_000)
	check("token issued", not token.is_empty())
	check("token has exactly one separator", token.count(".") == 1)
	check("token is unpadded base64url", not token.contains("="))
	var verified := Ticket.verify(_secret, token, 10_500)
	check("verify returns claims", not verified.is_empty())
	check("player round-trips", verified.get("player_id", "") == "p1")
	check("lobby round-trips", verified.get("lobby_id", "") == "l1")
	check("server round-trips", verified.get("server_id", "") == "s1")
	check("nonce is 32 hex chars", str(verified.get("nonce", "")).length() == 32)
	var second := Ticket.issue(_secret, {"player_id": "p1"}, 10_000)
	var other := Ticket.verify(_secret, second, 10_500)
	check("each ticket gets a fresh nonce",
		not other.is_empty() and other["nonce"] != verified["nonce"])


func _test_secret_and_claim_rules() -> void:
	check("short secret refused",
		Ticket.issue("too-short".to_utf8_buffer(), {"player_id": "p"}, 0) == "")
	check("missing player_id refused", Ticket.issue(_secret, {}, 0) == "")
	check("verify refuses a short secret",
		Ticket.verify("short".to_utf8_buffer(), Ticket.issue(_secret, {"player_id": "p"}, 0), 0) == {})


func _test_tampering() -> void:
	var token := Ticket.issue(_secret, {"player_id": "p1", "server_id": "s1"}, 0)
	var parts := token.split(".")
	var payload_part: String = parts[0]
	var swapped := payload_part.substr(0, 2) + _flip(payload_part.substr(2)) if payload_part.length() > 2 else ""
	check("modified payload rejected",
		Ticket.verify(_secret, "%s.%s" % [swapped, parts[1]], 1_000) == {})
	check("modified signature rejected",
		Ticket.verify(_secret, "%s.%s" % [parts[0], _flip(parts[1])], 1_000) == {})
	check("wrong signing secret rejected",
		Ticket.verify("ffffffffffffffffffffffffffffffff".to_utf8_buffer(), token, 1_000) == {})
	check("random string rejected", Ticket.verify(_secret, "garbage", 1_000) == {})
	check("extra separator rejected", Ticket.verify(_secret, token + ".x", 1_000) == {})
	check("empty signature rejected", Ticket.verify(_secret, parts[0] + ".", 1_000) == {})


func _test_expiry() -> void:
	var token := Ticket.issue(_secret, {"player_id": "p"}, 0, 60_000)
	check("valid just before expiry", not Ticket.verify(_secret, token, 59_999).is_empty())
	check("rejected at the expiry instant", Ticket.verify(_secret, token, 60_000) == {})
	check("rejected long after expiry", Ticket.verify(_secret, token, 120_000) == {})
	var future := Ticket.issue(_secret, {"player_id": "p"}, 100_000)
	check("issuer clock far ahead rejected", Ticket.verify(_secret, future, 1_000) == {})
	var slightly_ahead := Ticket.issue(_secret, {"player_id": "p"}, 3_000)
	check("small clock skew tolerated", not Ticket.verify(_secret, slightly_ahead, 1_000).is_empty())
	check("sub-second ttl clamped up", not Ticket.verify(_secret,
		Ticket.issue(_secret, {"player_id": "p"}, 0, 1), 500).is_empty())


func _test_server_binding() -> void:
	var token := Ticket.issue(_secret, {"player_id": "p", "server_id": "eu-1"}, 0)
	check("matching server accepted", not Ticket.verify(_secret, token, 1_000, "eu-1").is_empty())
	check("different server rejected", Ticket.verify(_secret, token, 1_000, "eu-2") == {})


func _test_replay_cache() -> void:
	var cache = Ticket.ReplayCache.new()
	check("first use accepted", cache.consume("n1", 0))
	check("reuse rejected", not cache.consume("n1", 10))
	check("different nonce accepted", cache.consume("n2", 20))
	check("empty nonce rejected", not cache.consume("", 30))
	check("nonce available again after the ttl", cache.consume("n1", 200_000))
	check("cache pruned both expired entries", cache.size() == 1)
	check("pruned nonce is usable again", cache.consume("n2", 200_010))
