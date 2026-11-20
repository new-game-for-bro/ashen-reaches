class_name JoinCode
extends RefCounted

## Human-typeable lobby codes: 8 characters from a 31-symbol alphabet with the
## visually ambiguous glyphs removed (no I, L, O, 0, 1), ~39.6 bits of entropy
## and rejection sampling so the modulo mapping stays uniform.
##
## A code is an index, never a credential: it only tells the lobby *which* room
## to look up. Tickets (MatchTicket) carry the permission, so leaking a code
## costs nothing but a rate-limited lookup.

const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const LENGTH := 8
const SYMBOLS := 31
const CUTOFF := 248            ## 8 * 31: values at or above this would bias the map
const RANDOM_ATTEMPTS := 8


## Uppercases, drops spaces/hyphens/underscores, and rejects anything that could
## not be a code. Returns "" for unusable input so callers cannot mistake a
## malformed code for a valid one.
static func normalize(raw: String) -> String:
	var cleaned := ""
	for i in raw.length():
		var ch := raw.substr(i, 1).to_upper()
		if ch == "-" or ch == " " or ch == "_" or ch == "\t":
			continue
		if ALPHABET.find(ch) == -1:
			return ""
		cleaned += ch
	if cleaned.length() != LENGTH:
		return ""
	return cleaned


## Strict form check; the code must already be normalised.
static func is_valid(code: String) -> bool:
	return code.length() == LENGTH and normalize(code) == code


## Deterministic mapping from caller-supplied bytes, so tests need no RNG.
## Bytes at or above CUTOFF are skipped rather than folded, which avoids modulo
## bias; fewer than LENGTH usable bytes yields "".
static func from_bytes(bytes: PackedByteArray) -> String:
	var out := ""
	for byte in bytes:
		if byte >= CUTOFF:
			continue
		out += ALPHABET.substr(byte % SYMBOLS, 1)
		if out.length() == LENGTH:
			return out
	return ""


static func generate() -> String:
	var crypto := Crypto.new()
	for attempt in RANDOM_ATTEMPTS:
		var code := from_bytes(crypto.generate_random_bytes(32))
		if not code.is_empty():
			return code
	return ""


## "ABCD-EFGH" for display only; never store or compare the formatted form.
static func format(code: String) -> String:
	var clean := normalize(code)
	if clean.is_empty():
		return ""
	return clean.substr(0, 4) + "-" + clean.substr(4)
