extends SceneTree

## Headless checks for JoinCode. Run from the project root:
##   godot --headless --path . --script res://tests/join_code_test.gd

const Code = preload("res://scripts/net/join_code.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_test_generation()
	_test_deterministic_mapping()
	_test_normalisation()
	_test_rejection()
	print("--- %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(label: String, condition: bool) -> void:
	_checks += 1
	if condition:
		print("PASS  ", label)
	else:
		_failures += 1
		printerr("FAIL  ", label)


func _test_generation() -> void:
	var seen := {}
	var ambiguous := 0
	var bad_length := 0
	for i in 500:
		var code := Code.generate()
		if code.length() != Code.LENGTH:
			bad_length += 1
		for glyph in ["I", "L", "O", "0", "1"]:
			if code.contains(glyph):
				ambiguous += 1
		seen[code] = true
	check("every code is 8 characters", bad_length == 0)
	check("no ambiguous glyphs in 500 codes", ambiguous == 0)
	check("500 codes are distinct", seen.size() == 500)
	check("generated codes pass is_valid", Code.is_valid(Code.generate()))


func _test_deterministic_mapping() -> void:
	var bytes := PackedByteArray([0, 1, 2, 3, 4, 5, 6, 7])
	var mapped := Code.from_bytes(bytes)
	check("mapping is deterministic", mapped == Code.from_bytes(bytes))
	check("byte 0 maps to A", mapped.begins_with("A"))
	check("byte 1 maps to B", mapped.substr(1, 1) == "B")

	var symbols := {}
	for chunk in Code.SYMBOLS:
		var chunk_bytes := PackedByteArray()
		for offset in Code.LENGTH:
			chunk_bytes.append(chunk * Code.LENGTH + offset)
		var code := Code.from_bytes(chunk_bytes)
		for index in code.length():
			symbols[code.substr(index, 1)] = true
	check("all 31 symbols reachable, none outside the alphabet", symbols.size() == Code.SYMBOLS)

	check("bytes at the cutoff are skipped, not folded",
		Code.from_bytes(PackedByteArray([248, 249, 250, 251, 252, 253, 254, 255])) == "")
	check("too few usable bytes yields empty",
		Code.from_bytes(PackedByteArray([0, 1, 2])) == "")


func _test_normalisation() -> void:
	check("lowercase is accepted", Code.normalize("abcdefgh") == "ABCDEFGH")
	check("hyphen is stripped", Code.normalize("abcd-efgh") == "ABCDEFGH")
	check("surrounding spaces are stripped", Code.normalize("  abcd efgh  ") == "ABCDEFGH")
	check("display form round-trips", Code.normalize(Code.format("abcd-efgh")) == "ABCDEFGH")
	check("format inserts one hyphen", Code.format("abcdefgh") == "ABCD-EFGH")


func _test_rejection() -> void:
	check("ambiguous letter I rejected", Code.normalize("ABCDEFGI") == "")
	check("ambiguous digit 1 rejected", Code.normalize("ABCDEFG1") == "")
	check("ambiguous letter O rejected", Code.normalize("ABCDEFGO") == "")
	check("short code rejected", Code.normalize("ABCDEFG") == "")
	check("long code rejected", Code.normalize("ABCDEFGHJ") == "")
	check("punctuation rejected", Code.normalize("ABCDE!GH") == "")
	check("empty input rejected", Code.normalize("") == "")
	check("is_valid rejects lowercase", not Code.is_valid("abcdefgh"))
	check("is_valid rejects padded input", not Code.is_valid("abcd-efgh"))
