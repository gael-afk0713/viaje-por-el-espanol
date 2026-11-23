extends RefCounted
## Carrega um personagem do pacote Kenney Mini Characters (CC0, www.kenney.nl)
## já virado para +X (lado direito da tela) e no tamanho do jogo.
## Gire o nó devolvido em Y (0 = direita, PI = esquerda) para virar o personagem.
##
## Animações disponíveis no pacote: idle, walk, sprint, jump, fall, emote-yes, emote-no,
## interact-left/right, pick-up, sit, crouch, wheelchair-*, attack-*, die...

const MODEL_DIR := "res://assets/kenney_mini_characters/"
const MODEL_SCALE := 2.3
const LOOPING := ["idle", "walk", "sprint", "fall", "sit", "static", "wheelchair-sit"]


const MONSTER_DIR := "res://assets/kenney_graveyard/"

## Materiais com a paleta "menos pastel" (colormap_real.png), um por material original.
static var _real_mats := {}


## dir: pasta do pacote (Mini Characters ou Graveyard Kit, que usam o mesmo esqueleto).
static func build(model: String, wheelchair := false, dir := MODEL_DIR, scale := MODEL_SCALE) -> Node3D:
	var pivot := Node3D.new()
	var scene: PackedScene = load(dir + "character-" + model + ".glb")
	var inst: Node3D = scene.instantiate()
	inst.scale = Vector3.ONE * scale
	inst.rotation_degrees.y = 90.0
	pivot.add_child(inst)
	var real := dir + "Textures/colormap_real.png"
	if ResourceLoader.exists(real):
		_apply_palette(inst, load(real))

	if wheelchair:
		var chair: Node3D = (load(MODEL_DIR + "wheelchair.glb") as PackedScene).instantiate()
		inst.add_child(chair)

	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if ap:
		for a in LOOPING:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		pivot.set_meta("anim", ap)
		pivot.set_meta("rest", "wheelchair-sit" if wheelchair else "idle")
		ap.play(pivot.get_meta("rest"))
	return pivot


## Troca a textura de cores pela versão menos pastel.
static func _apply_palette(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i)
			if base is BaseMaterial3D and base.albedo_texture != null:
				var key := base.get_instance_id()
				if not _real_mats.has(key):
					var m: BaseMaterial3D = base.duplicate()
					m.albedo_texture = tex
					_real_mats[key] = m
				mi.set_surface_override_material(i, _real_mats[key])
	for c in node.get_children():
		_apply_palette(c, tex)


## Toca uma animação (sem reiniciar se já estiver tocando).
static func play(pivot: Node3D, anim: String, speed := 1.0, blend := 0.15) -> void:
	var ap: AnimationPlayer = pivot.get_meta("anim", null)
	if ap == null or not ap.has_animation(anim):
		return
	ap.speed_scale = speed
	if ap.current_animation != anim:
		ap.play(anim, blend)


## Toca uma animação uma vez e depois volta para a pose de descanso.
static func play_once(pivot: Node3D, anim: String) -> void:
	var ap: AnimationPlayer = pivot.get_meta("anim", null)
	if ap == null or not ap.has_animation(anim):
		return
	ap.speed_scale = 1.0
	ap.play(anim, 0.1)
	ap.queue(pivot.get_meta("rest"))
