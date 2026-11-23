extends Control
## Botões de toque para celular/iPad: ◀ ▶ para andar e um botão grande para pular.
## Aceita vários dedos ao mesmo tempo (andar e pular juntos).
## - Aparecem sozinhos em telas de toque (e sempre que a tela é tocada).
## - Somem assim que qualquer tecla do teclado é apertada.

const BUTTONS := [
	{"id": "left", "action": "move_left", "radius": 72.0},
	{"id": "right", "action": "move_right", "radius": 72.0},
	{"id": "jump", "action": "jump", "radius": 88.0},
	{"id": "attack", "action": "attack", "radius": 68.0},
]

var active := false
var _touches := {}   # índice do dedo -> id do botão
var _held := {}      # ação -> true


## Configuração "Botões de toque": "auto", "always" ou "never".
static var mode := "auto"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_mode()


func apply_mode() -> void:
	match mode:
		"always":
			_set_active(true)
		"never":
			_set_active(false)
		_:
			_set_active(DisplayServer.is_touchscreen_available())


func _set_active(value: bool) -> void:
	active = value
	visible = value
	if not value:
		_touches.clear()
		_refresh()


func _center(id: String) -> Vector2:
	var s := size
	match id:
		"left":
			return Vector2(110, s.y - 110)
		"right":
			return Vector2(275, s.y - 110)
		"attack":
			return Vector2(s.x - 330, s.y - 90)
		_:
			return Vector2(s.x - 130, s.y - 125)


func _button_at(pos: Vector2) -> String:
	for b in BUTTONS:
		# área de toque um pouco maior que o desenho, para facilitar
		if pos.distance_to(_center(b["id"])) <= b["radius"] * 1.25:
			return b["id"]
	return ""


func _input(event: InputEvent) -> void:
	if mode != "auto":
		if mode == "never" or not (event is InputEventScreenTouch or event is InputEventScreenDrag):
			return
	if event is InputEventKey and event.pressed:
		if active:
			_set_active(false)
		return

	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if not active:
		_set_active(true)
	# só controla o personagem durante a fase (HUD visível)
	if not get_parent().is_visible_in_tree():
		if not _touches.is_empty():
			_touches.clear()
			_refresh()
		return

	var idx: int = event.index
	if event is InputEventScreenTouch:
		if event.pressed:
			var id := _button_at(event.position)
			if id != "":
				_touches[idx] = id
		else:
			_touches.erase(idx)
	elif _touches.has(idx):
		# arrastar o dedo de ◀ para ▶ troca de direção sem levantar o dedo
		var id := _button_at(event.position)
		if id == "left" or id == "right":
			_touches[idx] = id
	_refresh()


func _refresh() -> void:
	var want := {}
	for id in _touches.values():
		for b in BUTTONS:
			if b["id"] == id:
				want[b["action"]] = true
	for action in _held.keys():
		if not want.has(action):
			Input.action_release(action)
	for action in want.keys():
		if not _held.has(action):
			Input.action_press(action)
	_held = want
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and not _touches.is_empty():
		_touches.clear()
		_refresh()


const PAPER := Color("#f4ead5")
const INK := Color("#1d2840")
const STAMP := Color("#b8322a")
const FONT := preload("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf")


## Visual de "cartão-postal": setas em discos de papel creme e o pulo como um carimbo vermelho.
func _draw() -> void:
	var pressed := _touches.values()
	for b in BUTTONS:
		var id: String = b["id"]
		var c := _center(id)
		var r: float = b["radius"]
		var down := pressed.has(id)
		var jump := id == "jump"
		var attack := id == "attack"
		var face := STAMP if jump else (INK if attack else PAPER)
		var glyph := PAPER if (jump or attack) else INK
		var lift := 0.0 if down else 4.0
		# sombra deslocada para baixo (some quando apertado = botão "afunda")
		draw_circle(c + Vector2(0, 5), r, Color(0.05, 0.07, 0.12, 0.28 if not down else 0.12))
		var cc := c + Vector2(0, 4.0 - lift)
		draw_circle(cc, r, Color(face, 0.9 if not down else 1.0))
		if down:
			draw_circle(cc, r, Color(0, 0, 0, 0.12))
		draw_arc(cc, r - 7.0, 0.0, TAU, 48, Color(glyph, 0.35), 2.0, true)
		var a := r * 0.36
		match id:
			"left":
				draw_colored_polygon(PackedVector2Array([cc + Vector2(-a, 0), cc + Vector2(a * 0.65, -a), cc + Vector2(a * 0.65, a)]), glyph)
			"right":
				draw_colored_polygon(PackedVector2Array([cc + Vector2(a, 0), cc + Vector2(-a * 0.65, -a), cc + Vector2(-a * 0.65, a)]), glyph)
			"attack":
				# espada: lâmina inclinada, guarda e cabo
				var dir := Vector2(1, -1).normalized()
				var nrm := Vector2(dir.y, -dir.x)
				var base := cc + Vector2(-a * 0.55, a * 0.35) - Vector2(0, 8)
				var tip2 := base + dir * a * 1.7
				draw_colored_polygon(PackedVector2Array([base + nrm * 5, tip2 - dir * 8 + nrm * 5, tip2, tip2 - dir * 8 - nrm * 5, base - nrm * 5]), glyph)
				draw_line(base + nrm * 13, base - nrm * 13, glyph, 6.0, true)
				draw_line(base, base - dir * 14, glyph, 7.0, true)
				var text2 := "ATACAR"
				var w2 := FONT.get_string_size(text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
				draw_string(FONT, cc + Vector2(-w2 * 0.5, a + 18), text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, glyph)
			_:
				var tip := cc + Vector2(0, -a - 10)
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-a, a * 0.9), tip + Vector2(a, a * 0.9)]), glyph)
				var text := "SALTAR"
				var fs := 21
				var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(FONT, cc + Vector2(-w * 0.5, a + 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glyph)
