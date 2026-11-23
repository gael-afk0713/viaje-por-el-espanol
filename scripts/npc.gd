extends Node3D
## Um morador do país (modelo Kenney animado). Olha para o jogador e gesticula quando fala.
## Guardiões bloqueiam o caminho até o jogador acertar a pergunta.

const Character = preload("res://scripts/character.gd")

var data: Dictionary = {}
var is_guard := false
var target: Node3D = null

var visual: Node3D
var marker: Label3D
var _blocker: StaticBody3D
var _t := 0.0
var _wheelchair := false
var _face_camera := false
var _walk_away := false


func _ready() -> void:
	_t = randf() * 10.0
	_wheelchair = data.get("wheelchair", false)
	visual = Character.build(data["model"], _wheelchair)
	add_child(visual)
	visual.rotation.y = PI
	# começa a animação de descanso num ponto aleatório, para os moradores não ficarem sincronizados
	var ap: AnimationPlayer = visual.get_meta("anim", null)
	if ap:
		ap.seek(randf() * ap.current_animation_length, true)

	var tag := _label(data["name"], 40, Vector3(0, 2.05, 0))
	tag.modulate = Color("#fff3c4")
	add_child(tag)
	marker = _label("?" if is_guard else "!", 110, Vector3(0, 2.6, 0))
	marker.modulate = Color("#ffcc33")
	add_child(marker)

	if is_guard:
		var badge := _label("GUARDIÁN", 30, Vector3(0, 1.8, 0))
		badge.modulate = Color("#ffcc33")
		add_child(badge)
		_blocker = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 20.0, 3.0)
		shape.shape = box
		shape.position.y = 10.0
		_blocker.add_child(shape)
		add_child(_blocker)


func _label(text: String, size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.008
	l.outline_size = 12
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l


func _process(delta: float) -> void:
	_t += delta
	marker.position.y = 2.6 + sin(_t * 4.0) * 0.08

	var want := visual.rotation.y
	if _walk_away:
		want = PI * 0.5
	elif _face_camera:
		want = -PI * 0.5
	elif target != null:
		want = 0.0 if target.global_position.x > global_position.x else PI
	visual.rotation.y = lerp_angle(visual.rotation.y, want, 1.0 - exp(-8.0 * delta))


func talk() -> void:
	if not is_guard:
		marker.visible = false
	Character.play_once(visual, "wheelchair-look-right" if _wheelchair else "interact-right")


func react_no() -> void:
	Character.play_once(visual, "emote-no")


func react_yes() -> void:
	Character.play_once(visual, "emote-yes")


func step_aside() -> void:
	marker.visible = false
	if _blocker:
		_blocker.queue_free()
		_blocker = null
	_walk_away = true
	Character.play(visual, "walk")
	var tw := create_tween()
	tw.tween_property(self, "position:z", -1.2, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_walk_away = false
		_face_camera = true
		Character.play_once(visual, "emote-yes"))
