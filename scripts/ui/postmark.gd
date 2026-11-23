extends Control
## Carimbo postal (círculo duplo inclinado com texto), como nos cartões-postais.

const STAMP := Color("#b8322a")
const FONT := preload("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf")

var text := "¡HECHO!"
var sub := ""
var radius := 54.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius, radius) * 2.0


func _draw() -> void:
	draw_postmark(self, size * 0.5, radius, text, sub)


static func draw_postmark(ci: CanvasItem, center: Vector2, r: float, label: String, small := "") -> void:
	var col := Color(STAMP, 0.88)
	ci.draw_set_transform(center, -0.22, Vector2.ONE)
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, col, maxf(2.0, r * 0.06), true)
	ci.draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 48, col, maxf(1.0, r * 0.025), true)
	# o texto encolhe para caber dentro do círculo interno
	var fs := _fit(label, r * 0.34, r * 1.45)
	var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var dy := fs * 0.35 if small == "" else 0.0
	ci.draw_string(FONT, Vector2(-w * 0.5, dy), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if small != "":
		var fs2 := _fit(small, r * 0.2, r * 1.3)
		var w2 := FONT.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		ci.draw_string(FONT, Vector2(-w2 * 0.5, fs2 * 1.5), small, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _fit(t: String, start: float, max_w: float) -> int:
	var fs := int(start)
	while fs > 6 and FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	return fs
