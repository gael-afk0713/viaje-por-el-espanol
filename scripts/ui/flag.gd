extends Control
## Bandeira simplificada (listras + cantão), desenhada em 2D. Usada no HUD e nos selos do menu.

var country: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_country(c: Dictionary) -> void:
	country = c
	queue_redraw()


func _draw() -> void:
	draw_flag(self, Rect2(Vector2.ZERO, size), country)


static func draw_flag(ci: CanvasItem, r: Rect2, c: Dictionary) -> void:
	var cols: Array = c.get("flag", [])
	if cols.is_empty():
		return
	var n := cols.size()
	for i in n:
		var col := Color(cols[i])
		if c.get("flag_dir", "h") == "v":
			ci.draw_rect(Rect2(r.position.x + r.size.x * i / n, r.position.y, r.size.x / n + 0.5, r.size.y), col)
		else:
			ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / n, r.size.x, r.size.y / n + 0.5), col)
	if c.has("flag_canton"):
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x * 0.38, r.size.y * 0.5)), Color(c["flag_canton"]))
	ci.draw_rect(r, Color(0.11, 0.16, 0.25, 0.35), false, 1.0)
