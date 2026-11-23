extends Control
## "Passaporte" de uma partida: os 21 países em miniatura (7 x 3).
## País completado aparece com a bandeira; os outros, só o contorno tracejado.

const Flag = preload("res://scripts/ui/flag.gd")
const INK := Color("#1d2840")

var countries: Array = []
var done := {}
const COLS := 7
const GAP := 6.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if countries.is_empty():
		return
	var rows := int(ceil(countries.size() / float(COLS)))
	var w := (size.x - GAP * (COLS - 1)) / COLS
	var h := minf(w * 0.66, (size.y - GAP * (rows - 1)) / rows)
	for i in countries.size():
		var c: Dictionary = countries[i]
		var r := Rect2(Vector2((i % COLS) * (w + GAP), (i / COLS) * (h + GAP)), Vector2(w, h))
		if done.has(c["id"]):
			Flag.draw_flag(self, r, c)
		else:
			_dashed(r)


func _dashed(r: Rect2) -> void:
	var col := Color(INK, 0.28)
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for k in 4:
		draw_dashed_line(pts[k], pts[k + 1], col, 1.0, 3.0)
