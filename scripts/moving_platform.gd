extends AnimatableBody3D
## Plataforma que vai e volta no eixo X, levando o jogador junto.

var amplitude := 2.5
var speed := 1.2

var _origin := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	_origin = position
	sync_to_physics = true


func _physics_process(delta: float) -> void:
	_time += delta
	position.x = _origin.x + sin(_time * speed) * amplitude
