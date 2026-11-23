extends Control
## Desenho por cima do botão de país no menu: picote de selo nas bordas, bandeira,
## pontinhos de progresso (palavras) e o carimbo quando o país foi completado.

const Flag = preload("res://scripts/ui/flag.gd")
const Postmark = preload("res://scripts/ui/postmark.gd")
const STAMP := Color("#b8322a")
const INK_2 := Color("#55607a")

var country: Dictionary = {}
var got := 0
var total := 3
var done := false
var hole := Color("#142033")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var s := size
	# picote: semicírculos da cor do fundo "mordendo" as bordas
	var step := 11.0
	var r := 3.2
	var nx := int((s.x - 8.0) / step)
	var ox := (s.x - (nx - 1) * step) * 0.5
	for i in nx:
		draw_circle(Vector2(ox + i * step, 0.0), r, hole)
		draw_circle(Vector2(ox + i * step, s.y), r, hole)
	var ny := int((s.y - 8.0) / step)
	var oy := (s.y - (ny - 1) * step) * 0.5
	for i in ny:
		draw_circle(Vector2(0.0, oy + i * step), r, hole)
		draw_circle(Vector2(s.x, oy + i * step), r, hole)
	Flag.draw_flag(self, Rect2(14, 13, 44, 28), country)
	# palavras desbloqueadas
	for i in total:
		var c := Vector2(s.x - 18 - (total - 1 - i) * 14, 27)
		if i < got:
			draw_circle(c, 5.0, STAMP)
		else:
			draw_arc(c, 4.5, 0.0, TAU, 20, INK_2, 1.5, true)
	if done:
		Postmark.draw_postmark(self, Vector2(s.x - 34, s.y - 30), 25.0, "¡HECHO!")
