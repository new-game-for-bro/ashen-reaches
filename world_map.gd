extends Control

var markers: Array = []
var player: CharacterBody3D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var extent: float = min(size.x * 0.72, size.y * 0.78)
	var origin := Vector2((size.x - extent) / 2, (size.y - extent) / 2)
	var rect := Rect2(origin, Vector2(extent, extent))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.025, 0.82))
	draw_rect(rect, Color("292925"))
	draw_rect(rect, Color("b4a17f"), false, 2)
	var half := extent / 2.0
	draw_rect(Rect2(origin, Vector2(half, half)), Color("28372d"))
	draw_rect(Rect2(origin + Vector2(half, 0), Vector2(half, half)), Color("503c35"))
	draw_rect(Rect2(origin + Vector2(half, half), Vector2(half, half)), Color("48474a"))
	# Roads show the same three routes that appear in the world.
	var center := origin + Vector2(half, half)
	for destination in [Vector2(-48, -48), Vector2(48, -45), Vector2(47, 46)]:
		var end: Vector2 = origin + (destination + Vector2(70, 70)) / 140.0 * extent
		draw_line(center, end, Color("a89576"), 2.0)
	for i in range(1, 7):
		var offset := extent * float(i) / 7.0
		draw_line(origin + Vector2(offset, 0), origin + Vector2(offset, extent), Color(1, 1, 1, 0.045))
		draw_line(origin + Vector2(0, offset), origin + Vector2(extent, offset), Color(1, 1, 1, 0.045))
	draw_string(font, origin + Vector2(extent - 30, 25), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e8d9b9"))
	draw_string(font, origin + Vector2(12, 25), "ASHEN REACHES  /  WORLD MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e8d9b9"))
	for marker in markers:
		var world_pos: Vector3 = marker["pos"]
		var p := origin + Vector2((world_pos.x + 70.0) / 140.0 * extent, (world_pos.z + 70.0) / 140.0 * extent)
		draw_circle(p, 6, marker["color"])
		draw_string(font, p + Vector2(10, -5), marker["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f0e4ce"))
	if is_instance_valid(player):
		var p := origin + Vector2((player.position.x + 70.0) / 140.0 * extent, (player.position.z + 70.0) / 140.0 * extent)
		draw_circle(p, 6, Color("8fd4ec"))
		draw_string(font, p + Vector2(10, 14), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("bdefff"))
	draw_string(font, origin + Vector2(12, extent - 12), "M CLOSE   ·   GOLD: DUNGEONS   ·   BLUE: YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ded2bd"))
