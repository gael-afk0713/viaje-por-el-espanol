extends CharacterBody3D
## Personagem: anda só no eixo X/Y (2.5D), com pulo "justo":
## coyote time, buffer de pulo e altura variável (soltar o botão = pulo curto).

signal fell
signal got_hurt
signal died
signal hp_changed

const MAX_HP := 3
const ATTACK_TIME := 0.34      # duração do golpe de espada
const ATTACK_ACTIVE := 0.2     # janela em que o golpe acerta
const ATTACK_COOLDOWN := 0.4
const ATTACK_REACH := 2.2

const Character = preload("res://scripts/character.gd")

const SPEED := 7.5
const ACCEL_GROUND := 60.0
const ACCEL_AIR := 35.0
const JUMP_VELOCITY := 12.5
const GRAVITY := 34.0
const FALL_GRAVITY_MULT := 1.4
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14
const FALL_LIMIT_Y := -12.0

var frozen := false
var respawn_point := Vector3.ZERO
var facing := 1.0

var visual: Node3D
var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := true
var _invuln := 0.0   # tempo piscando depois de encostar num monstro
var _stun := 0.0     # tempo sem controle durante o empurrão
var _shadow: MeshInstance3D
var hp := MAX_HP
var attack_id := 0            # muda a cada golpe (cada monstro só leva 1 dano por golpe)
var _attack_t := 0.0
var _attack_cd := 0.0
var _slash: MeshInstance3D
var _slash_mat: StandardMaterial3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)

	# o aventureiro: modelo "male-f" do Kenney Mini Characters
	visual = Character.build("male-f")
	add_child(visual)
	_build_sword()
	_build_slash()
	_build_blob_shadow()


## Espada simples (lâmina, guarda e cabo) presa na mão direita do personagem.
func _build_sword() -> void:
	var sk: Skeleton3D = visual.find_children("*", "Skeleton3D", true, false).front()
	if sk == null or sk.find_bone("arm-right") < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "arm-right"
	sk.add_child(att)
	var sword := Node3D.new()
	# o personagem é escalado 2,3x; a espada fica no tamanho certo dentro dessa escala
	sword.position = Vector3(0.0, -0.17, 0.05)
	sword.rotation_degrees = Vector3(90, 0, 0)
	att.add_child(sword)
	var parts := [
		[Vector3(0.07, 0.4, 0.02), Vector3(0, 0.26, 0), Color("#dfe6ee"), 0.25],
		[Vector3(0.2, 0.045, 0.05), Vector3(0, 0.05, 0), Color("#c8962e"), 0.4],
		[Vector3(0.035, 0.1, 0.035), Vector3(0, -0.01, 0), Color("#5a3a22"), 0.9],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = p[2]
		m.metallic = 0.6 if p[3] < 0.5 else 0.0
		m.roughness = p[3]
		mi.material_override = m
		mi.position = p[1]
		sword.add_child(mi)


## Rastro do golpe: um arco claro na frente do personagem que aparece e some.
func _build_slash() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 14
	for i in seg:
		var a0 := lerpf(-1.1, 1.25, float(i) / seg)
		var a1 := lerpf(-1.1, 1.25, float(i + 1) / seg)
		var w0 := sin(float(i) / seg * PI)
		var w1 := sin(float(i + 1) / seg * PI)
		var p := [
			Vector3(cos(a0), sin(a0), 0) * 1.55, Vector3(cos(a0), sin(a0), 0) * (1.55 - 0.55 * w0),
			Vector3(cos(a1), sin(a1), 0) * 1.55, Vector3(cos(a1), sin(a1), 0) * (1.55 - 0.55 * w1),
		]
		for v in [p[0], p[1], p[2], p[2], p[1], p[3]]:
			st.set_uv(Vector2(float(i) / seg, 0))
			st.add_vertex(v)
	_slash = MeshInstance3D.new()
	_slash.mesh = st.commit()
	_slash_mat = StandardMaterial3D.new()
	_slash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash_mat.albedo_color = Color(1.0, 0.97, 0.82, 0.0)
	_slash.material_override = _slash_mat
	_slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slash.position = Vector3(0.1, 0.95, 0.35)
	_slash.visible = false
	add_child(_slash)


## Sombra redonda embaixo do personagem: mostra onde ele vai cair durante o pulo.
func _build_blob_shadow() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.55))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = false
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.3, 1.3)
	_shadow = MeshInstance3D.new()
	_shadow.mesh = plane
	_shadow.material_override = mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)


func _update_blob_shadow() -> void:
	var from := global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -30, 0))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_shadow.visible = false
		return
	_shadow.visible = true
	var dist: float = from.y - hit["position"].y
	var s := clampf(1.0 - dist * 0.08, 0.45, 1.0)
	_shadow.global_position = hit["position"] + Vector3(0, 0.04, 0)
	_shadow.scale = Vector3(s, 1.0, s)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote -= delta
	_buffer -= delta
	_invuln = maxf(0.0, _invuln - delta)
	_stun = maxf(0.0, _stun - delta)
	_attack_t = maxf(0.0, _attack_t - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	if not frozen and _stun <= 0.0 and _attack_cd <= 0.0 and Input.is_action_just_pressed("attack"):
		_start_attack()
	_update_slash()
	visual.visible = _invuln <= 0.0 or int(_invuln * 12.0) % 2 == 0

	var dir := 0.0
	if not frozen and _stun <= 0.0:
		dir = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			_buffer = JUMP_BUFFER

	if not on_floor:
		var g := GRAVITY * (FALL_GRAVITY_MULT if velocity.y < 0.0 else 1.0)
		velocity.y -= g * delta

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		visual.scale = Vector3(0.75, 1.3, 0.75)

	if not frozen and Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5

	var accel := ACCEL_GROUND if on_floor else ACCEL_AIR
	if _stun > 0.0:
		accel = 6.0
	velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
	velocity.z = 0.0
	if dir != 0.0:
		facing = signf(dir)

	move_and_slide()
	position.z = 0.0

	if is_on_floor() and not _was_on_floor:
		visual.scale = Vector3(1.3, 0.75, 1.3)
	_was_on_floor = is_on_floor()

	visual.scale = visual.scale.lerp(Vector3.ONE, 1.0 - exp(-12.0 * delta))
	if _attack_t <= 0.0:
		_update_animation()
	_update_blob_shadow()
	var target_rot := 0.0 if facing > 0.0 else PI
	visual.rotation.y = lerp_angle(visual.rotation.y, target_rot, 1.0 - exp(-15.0 * delta))

	if global_position.y < FALL_LIMIT_Y:
		respawn()


func _update_animation() -> void:
	var speed := absf(velocity.x)
	if not is_on_floor():
		Character.play(visual, "jump" if velocity.y > 0.0 else "fall")
	elif speed > 4.5:
		Character.play(visual, "sprint", speed / SPEED * 1.1)
	elif speed > 0.3:
		Character.play(visual, "walk", maxf(0.6, speed / 3.5))
	else:
		Character.play(visual, "idle")


func _start_attack() -> void:
	_attack_t = ATTACK_TIME
	_attack_cd = ATTACK_COOLDOWN
	attack_id += 1
	var ap: AnimationPlayer = visual.get_meta("anim", null)
	if ap and ap.has_animation("attack-melee-right"):
		ap.play("attack-melee-right", 0.05, 1.9)
		ap.seek(0.0, true)
	visual.scale = Vector3(1.15, 0.9, 1.15)


func _update_slash() -> void:
	if _attack_t <= 0.0:
		_slash.visible = false
		return
	var k := 1.0 - _attack_t / ATTACK_TIME   # 0 → 1 durante o golpe
	_slash.visible = true
	_slash.scale = Vector3(facing, 1.0, 1.0) * lerpf(0.8, 1.1, k)
	_slash.rotation.z = facing * lerpf(0.9, -0.5, k)
	_slash.position.x = facing * 0.15
	_slash_mat.albedo_color.a = 0.85 * (1.0 - k) * minf(1.0, k * 6.0)


## O golpe de espada está na janela em que acerta?
func is_attacking() -> bool:
	return _attack_t > ATTACK_TIME - ATTACK_ACTIVE


## O golpe atual alcança este ponto (na frente do personagem)?
func attack_reaches(target: Vector3) -> bool:
	if not is_attacking():
		return false
	var d := target - global_position
	var fx := d.x * facing
	return fx > -0.5 and fx < ATTACK_REACH and d.y > -1.2 and d.y < 2.2


## Recupera corações (moeda de coração ou ponto seguro novo).
func heal(amount := 1) -> bool:
	if hp >= MAX_HP:
		return false
	hp = mini(MAX_HP, hp + amount)
	hp_changed.emit()
	return true


## Monstro acertou: perde um coração, leva um empurrão e pisca por um tempo.
## Sem corações, volta ao último ponto seguro com os corações cheios.
func hurt(from_x: float) -> void:
	if _invuln > 0.0 or frozen:
		return
	hp -= 1
	hp_changed.emit()
	if hp <= 0:
		hp = MAX_HP
		global_position = respawn_point
		velocity = Vector3.ZERO
		_invuln = 1.6
		_stun = 0.0
		hp_changed.emit()
		died.emit()
		return
	_invuln = 1.3
	_stun = 0.35
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -facing
	velocity = Vector3(away * 9.0, 7.0, 0.0)
	got_hurt.emit()


## Pulou em cima de um monstro: quica para cima.
func bounce() -> void:
	velocity.y = 10.0
	_coyote = 0.0
	visual.scale = Vector3(0.75, 1.3, 0.75)


func respawn() -> void:
	global_position = respawn_point
	velocity = Vector3.ZERO
	fell.emit()
