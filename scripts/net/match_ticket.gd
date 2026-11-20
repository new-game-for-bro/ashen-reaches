class_name MatchTicket
extends RefCounted

## Short-lived, signed proof that the lobby cleared this player for this match.
##
## NetworkManager already accepts ENet peers on a 16-player dedicated server.
## Nothing in that path decides *who* is allowed to spawn, so a stranger who
## finds the port joins the round. This adds that decision without touching the
## transport: the lobby issues a ticket, the server verifies it during the
## handshake, and only then does MultiplayerSpawner create a body.
##
## Pure functions, no SceneTree, no peer, no autoloads — so it tests headlessly
## and offline modes never construct it.

const VERSION := 1
const DEFAULT_TTL_MS := 60_000
const MAX_IAT_SKEW_MS := 5_000
const MIN_SECRET_BYTES := 32


## Returns "payload.signature" (base64url, unpadded), or "" if the request is
## unusable — an empty token must be treated as "do not connect".
##
## now_ms is wall-clock unix milliseconds (Time.get_unix_time_from_system() * 1000),
## not ticks: tickets cross machines and only wall time is comparable.
static func issue(
	secret: PackedByteArray,
	claims: Dictionary,
	now_ms: int,
	ttl_ms: int = DEFAULT_TTL_MS
) -> String:
	if secret.size() < MIN_SECRET_BYTES:
		push_error("MatchTicket: signing secret must be at least %d bytes" % MIN_SECRET_BYTES)
		return ""
	var player_id := str(claims.get("player_id", ""))
	if player_id.is_empty():
		push_error("MatchTicket: player_id is required")
		return ""
	var payload := {
		"v": VERSION,
		"p": player_id,
		"l": str(claims.get("lobby_id", "")),
		"s": str(claims.get("server_id", "")),
		"n": str(claims.get("nonce", _random_nonce())),
		"iat": now_ms,
		"exp": now_ms + maxi(1_000, ttl_ms),
	}
	var encoded := _b64url_encode(JSON.stringify(payload).to_utf8_buffer())
	var signature := _b64url_encode(_sign(secret, encoded.to_utf8_buffer()))
	if signature.is_empty():
		return ""
	return "%s.%s" % [encoded, signature]


## Returns the verified claims, or {} if the token is invalid, expired, forged,
## issued for another server, or clocked implausibly into the future.
## Pair with ReplayCache.consume(claims["nonce"], now_ms) to block reuse.
static func verify(
	secret: PackedByteArray,
	token: String,
	now_ms: int,
	expected_server_id: String = ""
) -> Dictionary:
	if secret.size() < MIN_SECRET_BYTES or token.count(".") != 1:
		return {}
	var parts := token.split(".")
	var encoded: String = parts[0]
	var provided := _b64url_decode(parts[1])
	if provided.is_empty():
		return {}
	if not _constant_time_equals(_sign(secret, encoded.to_utf8_buffer()), provided):
		return {}
	var raw := _b64url_decode(encoded)
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var payload: Dictionary = parsed
	if int(payload.get("v", 0)) != VERSION:
		return {}
	if now_ms >= int(payload.get("exp", 0)):
		return {}
	if int(payload.get("iat", 0)) > now_ms + MAX_IAT_SKEW_MS:
		return {}
	var server_id := str(payload.get("s", ""))
	if not expected_server_id.is_empty() and server_id != expected_server_id:
		return {}
	var player_id := str(payload.get("p", ""))
	var nonce := str(payload.get("n", ""))
	if player_id.is_empty() or nonce.is_empty():
		return {}
	return {
		"player_id": player_id,
		"lobby_id": str(payload.get("l", "")),
		"server_id": server_id,
		"nonce": nonce,
		"expires_at_ms": int(payload.get("exp", 0)),
	}


static func _sign(secret: PackedByteArray, data: PackedByteArray) -> PackedByteArray:
	var ctx := HMACContext.new()
	if ctx.start(HashingContext.HASH_SHA256, secret) != OK:
		return PackedByteArray()
	ctx.update(data)
	return ctx.finish()


static func _constant_time_equals(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	var diff := 0
	for i in a.size():
		diff |= a[i] ^ b[i]
	return diff == 0


static func _b64url_encode(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


static func _b64url_decode(text: String) -> PackedByteArray:
	var padded := text.replace("-", "+").replace("_", "/")
	while padded.length() % 4 != 0:
		padded += "="
	return Marshalls.base64_to_raw(padded)


static func _random_nonce() -> String:
	var out := ""
	for byte in Crypto.new().generate_random_bytes(16):
		out += "%02x" % byte
	return out


## Remembers nonces for the life of a ticket, so a captured token cannot be
## replayed even while it is still within its TTL. One instance per server.
class ReplayCache:
	var ttl_ms: int = 120_000
	var _seen: Dictionary = {}

	## True the first time a nonce is presented, false on every reuse.
	func consume(nonce: String, now_ms: int) -> bool:
		_prune(now_ms)
		if nonce.is_empty() or _seen.has(nonce):
			return false
		_seen[nonce] = now_ms + ttl_ms
		return true

	func size() -> int:
		return _seen.size()

	func _prune(now_ms: int) -> void:
		for key in _seen.keys():
			if int(_seen[key]) <= now_ms:
				_seen.erase(key)
