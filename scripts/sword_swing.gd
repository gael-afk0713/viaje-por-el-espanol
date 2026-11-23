extends SkeletonModifier3D
## Golpe de espada por cima da cabeça: o braço direito sobe por trás do ombro
## (preparação), desce rápido na frente (golpe) e volta. O tronco gira junto.
## Roda depois das animações do Kenney, então dá para atacar andando ou pulando.

## 0..1 ao longo do golpe; < 0 = sem golpe (só a postura de guarda).
var progress := -1.0

var _arm := -1
var _torso := -1

# Etapas do golpe (fração do tempo total)
const WIND_END := 0.28    # fim da preparação (espada lá atrás, por cima do ombro)
const HIT_END := 0.52     # fim do golpe (espada na frente, embaixo)

# Ângulo do braço no plano do golpe: 0 = para baixo, 90 = para a frente, 180 = para cima.
# A lâmina fica sempre 90° à frente do braço (como num punho fechado).
const A_GUARD := 38.0     # guarda: braço um pouco à frente, lâmina apontando para a frente e para cima
const A_UP := 215.0       # preparação: espada atrás da cabeça
const A_HIT := -12.0      # fim do golpe: lâmina passou da horizontal, na frente
const ARM_OUT := 70.0     # o quanto o braço fica afastado do corpo
const GUARD_WEIGHT := 0.85


func _ready() -> void:
	var sk := get_skeleton()
	if sk:
		_arm = sk.find_bone("arm-right")
		_torso = sk.find_bone("torso")


func _process_modification_with_delta(_delta: float) -> void:
	_apply()


## Ponta da lâmina: ângulo (graus) no plano do golpe, para o rastro acompanhar.
func blade_angle() -> float:
	return _arm_angle(progress) + 90.0


func _arm_angle(k: float) -> float:
	if k < 0.0:
		return A_GUARD
	if k < WIND_END:
		return lerpf(A_GUARD, A_UP, _ease_out(k / WIND_END))
	if k < HIT_END:
		return lerpf(A_UP, A_HIT, _ease_in((k - WIND_END) / (HIT_END - WIND_END)))
	return lerpf(A_HIT, A_GUARD, _smooth((k - HIT_END) / (1.0 - HIT_END)))


func _apply() -> void:
	var sk := get_skeleton()
	if sk == null or _arm < 0:
		return
	var k := clampf(progress, -1.0, 1.0)
	var a := _arm_angle(k)
	var w := GUARD_WEIGHT
	var twist := 0.0
	if k >= 0.0:
		# no golpe o braço é todo do golpe; no fim volta a misturar com a animação
		w = lerpf(1.0, GUARD_WEIGHT, _smooth(clampf((k - 0.75) / 0.25, 0.0, 1.0)))
		if k < WIND_END:
			twist = lerpf(0.0, -24.0, _ease_out(k / WIND_END))
		elif k < HIT_END:
			twist = lerpf(-24.0, 20.0, _ease_in((k - WIND_END) / (HIT_END - WIND_END)))
		else:
			twist = lerpf(20.0, 0.0, _smooth((k - HIT_END) / (1.0 - HIT_END)))
	var target := Quaternion(Vector3.RIGHT, deg_to_rad(-a)) * Quaternion(Vector3.BACK, deg_to_rad(ARM_OUT))
	var cur := sk.get_bone_pose_rotation(_arm)
	sk.set_bone_pose_rotation(_arm, cur.slerp(target, w))
	if _torso >= 0 and k >= 0.0:
		var lean := 7.0 * sin(clampf(k / HIT_END, 0.0, 1.0) * PI)
		var tq := Quaternion(Vector3.UP, deg_to_rad(twist)) * Quaternion(Vector3.RIGHT, deg_to_rad(lean))
		sk.set_bone_pose_rotation(_torso, sk.get_bone_pose_rotation(_torso) * tq)


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 2.0)


static func _ease_in(t: float) -> float:
	return t * t * t


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
