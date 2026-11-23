extends Node3D
## Monstro entre as vilas. Modelos do Kenney Graveyard Kit (CC0): fantasma, esqueleto, vampiro e zumbi.
##
## - Anda de um lado para o outro; quando vê o jogador, vai atrás dele.
## - Perto do jogador, se prepara (agacha, treme e mostra um "!") e dá um bote para a frente.
## - Para vencer: 2 golpes de espada, ou pular em cima (vence na hora).

signal defeated

const Character = preload("res://scripts/character.gd")
const MODELS := ["ghost", "skeleton", "vampire", "zombie"]
const SCALE := 2.0
# altura da cabeça do monstro (para saber se o jogador pulou em cima)
const HEAD := 0.75
const TOP := 1.6
const MAX_HP := 2
const SIGHT := 6.5         # distância em que ele percebe o jogador
const REACH := 1.8         # distância em que começa o ataque
const WINDUP := 0.6        # tempo de aviso antes do bote
const LUNGE := 0.26
const RECOVER := 0.75
const COOLDOWN := 1.3

var player = null
var x_min := 0.0
var x_max := 0.0
var speed := 2.0
var model := ""
var hp := MAX_HP

var body: Node3D
var _dir := 1.0
var _t := 0.0
var _dead := false
var _state := "patrol"
var _state_t := 0.0
var _cooldown := 0.0
var _last_hit := -1
var _knock := 0.0
var _alert: Label3D
var _bar: Node3D
var _bar_fill: MeshInstance3D


func _ready() -> void:
	_t = randf() * 5.0
	if model == "":
		model = MODELS[randi() % MODELS.size()]
	body = Character.build(model, false, Character.MONSTER_DIR, SCALE)
	add_child(body)
	# depois de atacar, volta a andar (e não a ficar parado)
	body.set_meta("rest", "walk")
	_walk_anim()

	_alert = Label3D.new()
	_alert.text = "!"
	_alert.font_size = 120
	_alert.pixel_size = 0.01
	_alert.outline_size = 24
	_alert.modulate = Color("#ff4a3a")
	_alert.outline_modulate = Color("#1d2840")
	_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_alert.no_depth_test = true
	_alert.position = Vector3(0, 2.75, 0.3)
	_alert.visible = false
	add_child(_alert)

	# barrinha de vida: aparece depois do primeiro golpe
	_bar = Node3D.new()
	_bar.position = Vector3(0, 2.35, 0.4)
	_bar.visible = false
	add_child(_bar)
	_bar_box(Vector3(1.0, 0.18, 0.02), Vector3.ZERO, Color("#1d2840"))
	_bar_fill = _bar_box(Vector3(0.9, 0.1, 0.03), Vector3(0, 0, 0.01), Color("#e8483a"))


func _bar_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	_bar.add_child(mi)
	return mi


func _walk_anim() -> void:
	# zumbi anda devagar arrastando o pé; os outros andam normal
	Character.play(body, "walk", 0.7 if model == "zombie" else 1.0)


func _set_state(s: String) -> void:
	_state = s
	_state_t = 0.0
	_alert.visible = s == "windup"
	match s:
		"patrol":
			_walk_anim()
		"chase":
			Character.play(body, "sprint" if model != "zombie" else "walk", 1.0 if model != "zombie" else 1.3)
		"windup":
			Character.play(body, "idle")
		"lunge":
			Character.play_once(body, "attack-melee-right")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_state_t += delta
	_cooldown = maxf(0.0, _cooldown - delta)

	var d := Vector3.ZERO
	var sees := false
	if player != null:
		d = player.global_position - global_position
		sees = absf(d.x) < SIGHT and d.y > -1.0 and d.y < 3.0 and not player.frozen

	if _knock != 0.0:
		position.x += _knock * delta
		_knock = move_toward(_knock, 0.0, 40.0 * delta)

	var squash := Vector3.ONE
	match _state:
		"patrol":
			position.x += _dir * speed * delta
			if position.x > x_max:
				_dir = -1.0
			elif position.x < x_min:
				_dir = 1.0
			if sees:
				_set_state("chase")
		"chase":
			if d.x != 0.0:
				_dir = signf(d.x)
			if not sees:
				_set_state("patrol")
			elif absf(d.x) < REACH and absf(d.y) < 1.5 and _cooldown <= 0.0:
				_set_state("windup")
			elif absf(d.x) > 1.0:
				position.x += _dir * speed * 1.6 * delta
		"windup":
			# aviso bem visível: agacha, treme e mostra "!"
			var k := minf(1.0, _state_t / WINDUP)
			squash = Vector3(1.0 + 0.18 * k, 1.0 - 0.2 * k, 1.0 + 0.18 * k)
			body.position.x = sin(_t * 70.0) * 0.06 * k
			_alert.scale = Vector3.ONE * (1.0 + 0.25 * sin(_t * 18.0))
			if _state_t >= WINDUP:
				body.position.x = 0.0
				_set_state("lunge")
		"lunge":
			squash = Vector3(0.85, 1.15, 0.85)
			position.x += _dir * 8.0 * delta
			if player != null and absf(d.x) < 1.25 and d.y > -0.6 and d.y < TOP:
				player.hurt(global_position.x)
			if _state_t >= LUNGE:
				_cooldown = COOLDOWN
				_set_state("recover")
		"recover":
			if _state_t >= RECOVER:
				_set_state("chase" if sees else "patrol")
		"hurt":
			if _state_t >= 0.4:
				_set_state("chase" if sees else "patrol")

	# não sai da sua área (o chão existe ali)
	position.x = clampf(position.x, x_min - 2.0, x_max + 2.0)
	body.scale = body.scale.lerp(squash, 1.0 - exp(-14.0 * delta))
	body.rotation.y = lerp_angle(body.rotation.y, 0.0 if _dir > 0.0 else PI, 1.0 - exp(-10.0 * delta))
	if model == "ghost":
		# o fantasma flutua
		body.position.y = 0.25 + sin(_t * 2.5) * 0.12

	if player == null:
		return
	# golpe de espada do jogador
	if player.attack_id != _last_hit and player.attack_reaches(global_position + Vector3(0, 0.8, 0)):
		_last_hit = player.attack_id
		_take_hit()
		return
	# pulou em cima: vence na hora. Encostar de lado machuca.
	if absf(d.x) < 0.8 and d.y > -0.6 and d.y < TOP:
		if player.velocity.y < 0.0 and d.y > HEAD:
			_defeat(true)
		elif player._invuln <= 0.0 and _state != "hurt":
			Character.play_once(body, "attack-melee-right")
			player.hurt(global_position.x)


func _take_hit() -> void:
	hp -= 1
	if hp <= 0:
		_defeat(false)
		return
	var f := float(hp) / MAX_HP
	_bar_fill.scale.x = f
	_bar_fill.position.x = -0.45 * (1.0 - f)
	_bar.visible = true
	_alert.visible = false
	body.position.x = 0.0
	_knock = signf(global_position.x - player.global_position.x) * 9.0
	body.scale = Vector3(1.35, 0.7, 1.35)
	_set_state("hurt")
	_cooldown = maxf(_cooldown, 0.6)


func _defeat(stomped: bool) -> void:
	_dead = true
	_alert.visible = false
	_bar.visible = false
	if stomped:
		player.bounce()
	defeated.emit()
	Character.play(body, "die", 1.4, 0.05)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(body, "scale", Vector3(1.3, 0.05, 1.3), 0.15)
	tw.tween_property(body, "scale", Vector3.ONE * 0.01, 0.15)
	tw.tween_callback(queue_free)
