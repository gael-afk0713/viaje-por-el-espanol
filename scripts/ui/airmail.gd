extends Control
## Faixas de "correio aéreo" (listras diagonais vermelhas e azuis) no topo e na base
## de um cartão-postal. Fica atrás do conteúdo do painel.

const RED := Color("#b8322a")
const BLUE := Color("#2c4f9e")
const BAND := 7.0
const INSET := 12.0
const STRIPE := 13.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	_band(INSET, size.x - INSET, INSET)
	_band(INSET, size.x - INSET, size.y - INSET - BAND)


func _band(x0: float, x1: float, y: float) -> void:
	var x := x0 - BAND
	var i := 0
	while x < x1:
		if i % 2 == 0:
			var a := clampf(x + BAND, x0, x1)
			var b := clampf(x + BAND + STRIPE, x0, x1)
			var c := clampf(x + STRIPE, x0, x1)
			var d := clampf(x, x0, x1)
			if (b - a) + (c - d) > 1.0:
				draw_colored_polygon(PackedVector2Array([Vector2(a, y), Vector2(b, y), Vector2(c, y + BAND), Vector2(d, y + BAND)]),
					RED if i % 4 == 0 else BLUE)
		x += STRIPE
		i += 1
