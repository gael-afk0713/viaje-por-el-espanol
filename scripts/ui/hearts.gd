extends Control
## Corações do jogador na etiqueta do HUD: cheios em vermelho-carimbo, vazios só no contorno.

const STAMP := Color("#b8322a")
const INK := Color("#1d2840")
const STEP := 30.0

var hp := 3
var max_hp := 3
var _shake := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func set_hp(value: int, maximum: int) -> void:
	if value < hp:
		_shake = 0.35
	hp = value
	max_hp = maximum
	_resize()
	queue_redraw()


func _resize() -> void:
	custom_minimum_size = Vector2(max_hp * STEP, 30)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		queue_redraw()


func _heart(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(c + Vector2(x, -y) * s / 17.0)
	return pts


func _draw() -> void:
	for i in max_hp:
		var c := Vector2(STEP * i + STEP * 0.5, size.y * 0.5 + 1.0)
		if _shake > 0.0 and i == hp:
			c.x += sin(_shake * 60.0) * 3.0
		var pts := _heart(c, 12.0)
		if i < hp:
			draw_colored_polygon(pts, STAMP)
		else:
			draw_colored_polygon(pts, Color(INK, 0.1))
			pts.append(pts[0])
			draw_polyline(pts, Color(INK, 0.45), 2.0, true)
