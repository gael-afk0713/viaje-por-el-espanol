extends Node3D
## Monta uma fase inteira a partir da "ficha" de um país (game_data.gd):
##
##   início → VILA 1 → bioma 1 (bosque / selva / deserto...) → CAVERNA → VILA 2 → bandeira
##
## - Chão e plataformas: Kenney Platformer Kit (blocos de grama), com 3 fileiras para trás.
## - Casas, barracas, fonte e lampiões: Kenney Fantasy Town Kit (casas montadas peça por peça).
## - Árvores, cactos, palmeiras, pedras e caverna: Kenney Nature Kit.
## - Entre as vilas: desafios, monstros e "escolha a plataforma com a palavra certa".
## A colisão é feita com caixas invisíveis simples; os modelos são só visuais.

signal npc_talked(index: int)
signal choice_landed(index: int, correct: bool)
signal monster_defeated
signal player_hurt
signal goal_reached
signal player_fell
signal player_died
signal hp_changed

const PlayerScript = preload("res://scripts/player.gd")
const MovingPlatformScript = preload("res://scripts/moving_platform.gd")
const NpcScript = preload("res://scripts/npc.gd")
const MonsterScript = preload("res://scripts/monster.gd")

const PK := "res://assets/kenney_platformer_kit/"
const NK := "res://assets/kenney_nature_kit/"
const FT := "res://assets/kenney_fantasy_town/"
const TEX := "res://assets/textures/"
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const BLADE_SHADER := preload("res://shaders/grass_blades.gdshader")
const RELIEF := {"grass": 0.3, "grass_village": 0.14, "desert": 0.35, "desert_village": 0.14, "cave": 0.2,
	"snow": 0.32, "sand": 0.22, "canyon": 0.35, "salt": 0.03, "jungle": 0.32}
const PATH_RELIEF := 0.07
const GROUND_FRONT := 1.56   # frente do chão (z)
const GROUND_BACK := -7.8    # fundo do chão (z)
# texturas do Fantasy Town sem o tom pastel (telhados em terracota, ardósia e madeira)
const FT_REAL := "res://assets/kenney_fantasy_town/Textures/colormap_real.png"
const FT_VARIATION := "res://assets/kenney_fantasy_town/Textures/variation-a_real.png"

const BLOCK := 2.08          # tamanho do bloco grande do Platformer Kit
const GS := 1.5              # escala dos blocos
const CELL := BLOCK * GS     # 3.12 m
const ROWS := 3              # fileiras de chão (frente + 2 para trás)
const DEPTH := 3.0           # profundidade da colisão
const VILLAGE_LEN := 36.0
const HOUSE_S := 2.2         # escala das peças das casas (1 andar = 2,2 m)
const CAVE_TOP := 6.6

const CHALLENGES := ["gaps", "monsters", "moving", "stairs", "high", "monsters"]
const MONSTER_MODELS := ["ghost", "skeleton", "vampire", "zombie"]

## Árvores/plantas por tipo de cenário do país (Nature Kit).
const FLORA := {
	"cactus": ["cactus_tall", "cactus_short", "cactus_tall", "rock_tallA", "rock_largeA", "plant_bushSmall"],
	"palms": ["tree_palmTall", "tree_palmBend", "tree_palmDetailedTall", "tree_palmShort", "plant_bushLarge", "tree_palmDetailedShort"],
	"mountains": ["tree_pineTallA", "tree_pineTallB", "tree_pineRoundA", "tree_pineDefaultA", "tree_pineRoundC", "rock_tallB"],
	"hills": ["tree_default", "tree_oak", "tree_detailed", "tree_fat", "tree_simple", "plant_bushLarge"],
	"city": ["tree_fat", "tree_default", "tree_simple", "tree_oak", "plant_bushLarge", "tree_small"],
}
const BIOME_NAME := {
	"cactus": "Desierto", "palms": "Selva", "mountains": "Montaña", "hills": "Bosque", "city": "Campo",
}

## Segunda zona de cada fase (entre as duas vilas), com o nome da placa.
const ZONE_NAME := {
	"cave": "Cueva", "snow": "Nevado", "beach": "Playa", "canyon": "Cañón",
	"jungle": "Selva", "lake": "Lago", "salt": "Salar", "fields": "Campos",
}

## O "mundo" de cada país: a segunda zona, a hora do dia, o marco que aparece
## ao fundo (feito de formas simples) e se tem mar no horizonte.
const WORLDS := {
	"mexico": {"zone": "canyon", "time": "golden", "landmark": "pyramid"},
	"guatemala": {"zone": "jungle", "time": "dawn", "landmark": "tall_temple"},
	"honduras": {"zone": "cave", "time": "day", "landmark": "stela"},
	"el_salvador": {"zone": "lake", "time": "golden", "landmark": "volcano_smoke"},
	"nicaragua": {"zone": "lake", "time": "day", "landmark": "twin_volcanoes"},
	"costa_rica": {"zone": "jungle", "time": "dawn", "landmark": "volcano_smoke"},
	"panama": {"zone": "lake", "time": "noon", "landmark": "ship"},
	"cuba": {"zone": "fields", "time": "golden", "landmark": "morro", "sea": true, "crop": "crops_leafsStageB"},
	"rep_dominicana": {"zone": "beach", "time": "noon", "landmark": "church", "sea": true},
	"puerto_rico": {"zone": "cave", "time": "dusk", "landmark": "fort", "sea": true},
	"colombia": {"zone": "fields", "time": "dawn", "landmark": "wax_palms", "crop": "plant_bushDetailed"},
	"venezuela": {"zone": "jungle", "time": "day", "landmark": "tepui"},
	"ecuador": {"zone": "snow", "time": "dawn", "landmark": "volcano_snow"},
	"peru": {"zone": "snow", "time": "golden", "landmark": "terraces"},
	"bolivia": {"zone": "salt", "time": "noon", "landmark": "volcano_snow"},
	"chile": {"zone": "canyon", "time": "dusk", "landmark": "moai"},
	"argentina": {"zone": "snow", "time": "day", "landmark": "obelisk"},
	"uruguay": {"zone": "beach", "time": "golden", "landmark": "lighthouse", "sea": true},
	"paraguay": {"zone": "lake", "time": "dawn", "landmark": "ruins"},
	"espana": {"zone": "fields", "time": "golden", "landmark": "windmills", "crop": "crops_wheatStageB"},
	"guinea": {"zone": "beach", "time": "dusk", "landmark": "volcano", "sea": true},
}

## Plantas e pedras de cada zona ("pk:" = modelo do Platformer Kit).
const ZONE_FLORA := {
	"snow": ["pk:tree-pine-snow", "tree_pineTallA", "pk:tree-pine-snow", "rock_tallB", "rock_largeB", "pk:tree-pine-snow-small"],
	"beach": ["tree_palmBend", "tree_palmTall", "tree_palmShort", "rock_largeA", "tree_palmDetailedShort", "tree_palmBend"],
	"canyon": ["rock_tallA", "rock_tallC", "rock_tallE", "cactus_tall", "rock_largeC", "rock_tallG"],
	"jungle": ["tree_palmDetailedTall", "tree_default_dark", "plant_bushLarge", "tree_fat_darkh", "tree_palmBend", "plant_bushDetailed"],
	"lake": ["plant_bushLarge", "grass_large", "plant_bush", "tree_oak", "plant_bushSmall", "grass_leafsLarge"],
	"salt": ["rock_smallA", "rock_smallC", "rock_largeB"],
	"fields": ["tree_oak", "tree_default", "plant_bushLarge", "tree_simple"],
}
const ZONE_SMALL := {
	"snow": ["rock_smallA", "rock_smallC", "stump_old"],
	"salt": ["rock_smallA", "rock_smallFlatA"],
	"canyon": ["rock_smallB", "rock_smallD", "cactus_short"],
	"beach": ["rock_smallA", "plant_bushSmall", "grass_large"],
}
const CANYON_RED := Color("#a9532f")
const SMALL_PLANTS := ["flower_redA", "flower_yellowB", "flower_purpleA", "grass_large", "mushroom_redGroup", "plant_bushSmall", "grass_leafsLarge"]

var country: Dictionary = {}
var people: Array = []       # moradores: {data, village, slot}
var choices: Array = []      # desafios de palavra: {question, correct, wrong, es, pt}
var player = null
var camera: Camera3D
var level_end_x := 0.0
var spawn_point := Vector3(2, 0.5, 0)
var monster_count := 0

var _npcs: Array = []        # nós dos moradores, na mesma ordem de "people"
var _monsters: Array = []
var _choice_state: Array = []
var _clouds: Array = []
var _checkpoints: Array = []
var _materials := {}
var _scenes := {}
var _goal_done := false
var _rng := RandomNumberGenerator.new()
var _variation_tex: Texture2D
var _ft_real_tex: Texture2D
var _blade_mats: Array = []
var _ground_segs: Array = []   # [x0, x1, bioma] de cada pedaço de chão
var world: Dictionary = {}
var _zones: Array = []         # [x0, x1, zona] da segunda zona
var _villages: Array = []      # x do centro de cada vila
var _pickups: Array = []       # corações que dão vida
## tablet/celular: menos grama, menos detalhes e resolução 3D um pouco menor
var low_quality := false


func setup(data: Dictionary, people_list: Array, choice_list: Array) -> void:
	country = data
	people = people_list
	choices = choice_list
	world = WORLDS.get(data["id"], {"zone": "cave", "time": "day", "landmark": ""})


## Qualidade escolhida nas configurações: "auto", "high" ou "low".
static var quality_mode := "auto"

## Tablet/celular (ou "--low" na linha de comando): versão mais leve.
static func is_low_end() -> bool:
	if quality_mode == "low":
		return true
	if quality_mode == "high":
		return false
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") 		or (OS.has_feature("web") and DisplayServer.is_touchscreen_available()) 		or OS.get_cmdline_user_args().has("--low")


## Modo vitrine (fundo da tela de início): a câmera passeia sozinha pela fase.
var attract := false
var _attract_t := 0.0


func _ready() -> void:
	low_quality = is_low_end()
	if low_quality:
		# desenha o 3D em 75% da resolução (a interface continua nítida)
		get_viewport().scaling_3d_scale = 0.75
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	else:
		get_viewport().scaling_3d_scale = 1.0
		get_viewport().msaa_3d = ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_DISABLED)
	_variation_tex = load(FT_VARIATION)
	_ft_real_tex = load(FT_REAL)
	_build_environment()
	_build_level()
	_build_grass()
	_build_backdrop()
	_spawn_player()
	_build_camera()
	for n in _npcs:
		n.target = player
	for m in _monsters:
		m.player = player


func _process(delta: float) -> void:
	for c in _clouds:
		c.position.x += delta * 0.6
		if c.position.x > level_end_x + 60.0:
			c.position.x = -60.0
	for h in _pickups:
		if is_instance_valid(h):
			h.rotation.y += delta * 2.0
			h.position.y = h.get_meta("y") + sin(Time.get_ticks_msec() * 0.003) * 0.15
	if player == null:
		return

	var p: Vector3 = player.global_position
	for m in _blade_mats:
		m.set_shader_parameter("player_pos", p)
	if player.is_on_floor():
		for cx in _checkpoints:
			if p.x > cx + 0.5 and cx + 1.0 > player.respawn_point.x:
				player.respawn_point = Vector3(cx + 1.0, 0.5, 0.0)
				# cada ponto seguro novo devolve um coração
				player.heal(1)

	if attract:
		# vai e volta devagar pela primeira metade da fase
		_attract_t += delta
		var span := maxf(10.0, minf(level_end_x * 0.5, 60.0))
		var k := 0.5 - 0.5 * cos(_attract_t * TAU / 70.0)
		camera.global_position = Vector3(8.0 + span * k, 3.1, 11.5)
		return

	var target := Vector3(p.x + player.facing * 1.8, maxf(p.y, 0.0) + 2.7, 11.0)
	target.x = clampf(target.x, 8.0, maxf(8.0, level_end_x - 8.0))
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-4.0 * delta))


func get_npc(index: int) -> Node3D:
	return _npcs[index]


# ---------------------------------------------------------------- montagem geral

func _build_environment() -> void:
	# céu mais "de verdade": azul mais profundo em cima, horizonte claro
	var sky_mat := ProceduralSkyMaterial.new()
	var top := Color(country["sky_top"])
	sky_mat.sky_top_color = Color.from_hsv(top.h, minf(1.0, top.s * 1.25 + 0.1), top.v * 0.85)
	sky_mat.sky_horizon_color = Color(country["sky_horizon"]).lerp(Color("#dfe8ee"), 0.45)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(country["ground"]).darkened(0.5)
	sky_mat.sun_angle_max = 20.0
	var sun_rot := Vector3(-52, -32, 0)
	var sun_col := Color("#fff1dc")
	var sun_k := 1.0
	match world.get("time", "day"):
		"golden":
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color("#ffc58a"), 0.55)
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color("#3d6aa8"), 0.3)
			sun_rot = Vector3(-24, -40, 0)
			sun_col = Color("#ffcf9a")
			sun_k = 0.95
		"dawn":
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color("#f4c2c6"), 0.5)
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color("#7090d0"), 0.3)
			sun_rot = Vector3(-28, 35, 0)
			sun_col = Color("#ffe2d4")
			sun_k = 0.9
		"dusk":
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color("#ff9a6a"), 0.6)
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color("#3a3f7a"), 0.45)
			sun_rot = Vector3(-15, -55, 0)
			sun_col = Color("#ffa66e")
			sun_k = 0.85
		"noon":
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color("#f4f9ff"), 0.3)
			sun_rot = Vector3(-72, -20, 0)
			sun_k = 1.1
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.ssao_enabled = true
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = sky_mat.sky_horizon_color
	env.fog_density = 0.004
	env.fog_sky_affect = 0.1

	# na web (renderizador Compatibility) a luz fica mais forte; compensamos aqui
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if compat:
		env.ambient_light_energy = 0.3
		env.tonemap_exposure = 0.8
		env.adjustment_saturation = 0.85
		env.glow_enabled = false
		env.fog_enabled = false

	if low_quality:
		env.ssao_enabled = false
		env.glow_enabled = false

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_col
	sun.light_energy = (0.8 if compat else 1.7) * sun_k
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0
	if low_quality:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 35.0
	add_child(sun)


func _layout() -> Array:
	# início → vila 1 → bioma do país (2 desafios + escolha) → caverna (2 desafios + escolha) → vila 2 → bandeira
	_rng.seed = hash(country["id"])
	var pool: Array = CHALLENGES.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var nature: String = country["deco"]
	var zone: String = world.get("zone", "cave")
	var towns: Array = country["towns"]
	# entre as vilas: bioma do país (2 desafios + escolha), trilha, segunda zona
	# (3 desafios + escolha) e mais um desafio antes da vila 2
	return [
		{"kind": "start", "biome": nature},
		{"kind": "village", "biome": "village", "arg": 0},
		{"kind": pool[0], "biome": nature, "sign": BIOME_NAME.get(nature, "Bosque")},
		{"kind": "choice", "biome": nature, "arg": 0},
		{"kind": pool[1], "biome": nature},
		{"kind": "trail", "biome": nature, "sign": "A " + str(towns[mini(1, towns.size() - 1)])},
		{"kind": pool[2], "biome": zone, "sign": ZONE_NAME.get(zone, "Cueva")},
		{"kind": "choice", "biome": zone, "arg": 1},
		{"kind": pool[3], "biome": zone},
		{"kind": pool[4], "biome": zone},
		{"kind": pool[5], "biome": nature},
		{"kind": "village", "biome": "village", "arg": 1},
		{"kind": "goal", "biome": nature},
	]


func _build_level() -> void:
	var x := 0.0
	for chunk in _layout():
		var kind: String = chunk["kind"]
		var biome: String = chunk["biome"]
		var x0 := x
		if kind != "goal":
			_checkpoints.append(x)
		match kind:
			"start":
				_ground(x, x + 8.0, biome)
				spawn_point = Vector3(x + 2.0, 0.5, 0.0)
				x += 8.0
			"village":
				_build_village(x, chunk["arg"])
				_villages.append(x + VILLAGE_LEN * 0.5)
				x += VILLAGE_LEN
			"monsters":
				_ground(x, x + 18.0, biome)
				_monster(x + 3.5, x + 8.0)
				_monster(x + 10.5, x + 15.5)
				_heart_pickup(x + 9.2, 3.2)
				x += 18.0
			"trail":
				# trilha longa entre as vilas: um monstro e um coração no caminho
				_ground(x, x + 26.0, biome)
				_platform(x + 9.0, 1.6, 3.0, biome)
				_heart_pickup(x + 10.5, 3.6)
				_monster(x + 14.0, x + 22.0)
				x += 26.0
			"gaps":
				_ground(x, x + 4.0, biome)
				_ground(x + 7.0, x + 10.0, biome)
				_ground(x + 13.0, x + 16.0, biome)
				x += 16.0
			"stairs":
				_ground(x, x + 15.0, biome)
				_platform(x + 3.0, 1.2, 2.5, biome)
				_platform(x + 6.5, 2.4, 2.5, biome)
				_platform(x + 10.0, 3.6, 2.5, biome)
				x += 15.0
			"moving":
				_ground(x, x + 4.0, biome)
				_moving_platform(x + 8.5, 0.0, 3.0, 2.5)
				_ground(x + 13.0, x + 17.0, biome)
				x += 17.0
			"high":
				_ground(x, x + 16.0, biome)
				_platform(x + 3.0, 1.8, 2.5, biome)
				_platform(x + 7.0, 3.6, 2.5, biome)
				_platform(x + 11.0, 1.8, 2.5, biome)
				_monster(x + 2.0, x + 14.0)
				x += 16.0
			"choice":
				_build_choice(x, chunk["arg"], biome)
				x += 26.0
			"goal":
				_ground(x, x + 14.0, biome)
				_build_goal(x + 9.0)
				x += 14.0
		if biome == "cave":
			_cave(x0, x)
			_zones.append([x0, x, biome])
		elif ZONE_NAME.has(biome):
			_flora(x0, x, biome, biome == "salt" or biome == "lake")
			_zones.append([x0, x, biome])
		elif biome != "village":
			_flora(x0, x, biome, kind == "start" or kind == "goal")
		if chunk.has("sign"):
			_sign(x0 + 1.6, chunk["sign"])

	level_end_x = x
	_invisible_wall(-0.5)
	_invisible_wall(level_end_x + 0.5)
	_build_zone_extras()


func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.position = spawn_point
	player.respawn_point = spawn_point
	player.fell.connect(_on_player_fell)
	player.got_hurt.connect(func() -> void: player_hurt.emit())
	player.died.connect(func() -> void: player_died.emit())
	player.hp_changed.connect(func() -> void: hp_changed.emit())
	add_child(player)


func _on_player_fell() -> void:
	# plataformas de palavra que caíram voltam ao lugar
	for st in _choice_state:
		if not st["solved"]:
			for pl in st["platforms"]:
				_restore_platform(pl)
	player_fell.emit()


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.rotation_degrees = Vector3(-8, 0, 0)
	add_child(camera)
	camera.global_position = Vector3(maxf(8.0, spawn_point.x), 2.7, 11.0)
	camera.current = true


# ---------------------------------------------------------------- utilitários

func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


func _place(path: String, pos: Vector3, rot_y := 0.0, scl := Vector3.ONE, parent: Node3D = null) -> Node3D:
	var n: Node3D = _scene(path).instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = scl
	(parent if parent != null else self).add_child(n)
	if path.begins_with(NK):
		_realify(n)
	elif path.begins_with(FT) and _ft_real_tex:
		_retexture(n, _ft_real_tex)
	return n


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		_materials[key] = m
	return _materials[key]


func _collider(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


func _visual_box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = _mat(color)
	mesh.position = pos
	add_child(mesh)
	return mesh


func _visual_mesh(mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	return c


func _label(text: String, size: int, pos: Vector3, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.008
	l.outline_size = 12
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)
	return l


# ---------------------------------------------------------------- chão e plataformas

## Paleta mais realista: tira o tom pastel (mais saturado, mais escuro) e puxa o
## verde-água dos modelos para verde de verdade.
static func _real(c: Color, darken := 0.8) -> Color:
	var h := c.h
	var s := c.s
	if s > 0.15 and h > 0.4 and h < 0.58:
		h = 0.25 + (h - 0.4) * 0.35
		s = s * 1.1 + 0.1
	s = minf(1.0, s * 1.3 + 0.05)
	return Color.from_hsv(h, s, c.v * darken, c.a)


## Troca as cores (pastel) dos modelos do Nature Kit pela paleta realista.
func _realify(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(s)
			if base is StandardMaterial3D and base.albedo_texture == null:
				var key := "real_%d" % base.get_instance_id()
				if not _materials.has(key):
					var m: StandardMaterial3D = base.duplicate()
					m.albedo_color = _real(base.albedo_color)
					m.roughness = maxf(m.roughness, 0.8)
					_materials[key] = m
				mi.set_surface_override_material(s, _materials[key])
	for c in node.get_children():
		_realify(c)


func _terrain_kind(biome: String) -> String:
	match biome:
		"cave", "snow", "canyon", "salt", "jungle":
			return biome
		"beach":
			return "sand"
	var base := "desert" if country.get("deco", "") == "cactus" else "grass"
	return base + ("_village" if biome == "village" else "")


## Altura dos montinhos: precisa ser IGUAL a relief_h() em shaders/terrain.gdshader.
func _height(x: float, z: float, biome: String) -> float:
	var n := 0.5 * sin(x * 0.9 + sin(z * 0.7) * 1.3) + 0.3 * sin(x * 2.3 + z * 1.7 + 1.3) + 0.2 * sin(z * 1.3 - x * 0.6 + 2.0)
	var a := lerpf(PATH_RELIEF, RELIEF[_terrain_kind(biome)], 1.0 - smoothstep(-5.0, -1.8, z))
	return a * (0.55 + 0.45 * n)


## Material do terreno (grama/areia em cima, terra dos lados), um por tipo de bioma.
func _terrain_mat(biome: String) -> ShaderMaterial:
	var kind := _terrain_kind(biome)
	var key := "terrain_" + kind
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	var grass_c := load(TEX + "grass_color.jpg")
	var grass_n := load(TEX + "grass_normal.jpg")
	var dirt_c := load(TEX + "dirt_color.jpg")
	var dirt_n := load(TEX + "dirt_normal.jpg")
	m.set_shader_parameter("side_tex", dirt_c)
	m.set_shader_parameter("side_nrm", dirt_n)
	m.set_shader_parameter("relief", RELIEF[kind])
	m.set_shader_parameter("path_relief", PATH_RELIEF)
	m.set_shader_parameter("top_tex", grass_c)
	m.set_shader_parameter("top_nrm", grass_n)
	m.set_shader_parameter("top_color", _grass_color())
	# terra clara e arenosa, como um torrão de verdade (mantém um pouco da cor do país)
	m.set_shader_parameter("side_color", _real(Color(country.get("ground", "#a0683f")), 0.9).lerp(Color("#9a7650"), 0.55))
	if kind == "cave":
		m.set_shader_parameter("top_tex", dirt_c)
		m.set_shader_parameter("top_nrm", dirt_n)
		m.set_shader_parameter("top_color", Color("#5e4836"))
		m.set_shader_parameter("side_color", Color("#4f4238"))
		m.set_shader_parameter("lip", 0.0)
	elif kind in ["snow", "sand", "canyon", "salt"]:
		var look: Array = {
			"snow": [Color("#eef3f8"), Color("#7a6f66"), 0.25, 0.25],
			"sand": [Color("#e0c690"), Color("#b08e5e"), 0.45, 0.15],
			"canyon": [Color("#b9663f"), Color("#8c4a2e"), 0.55, 0.1],
			"salt": [Color("#f1f0ea"), Color("#9a948a"), 0.12, 0.05],
		}[kind]
		m.set_shader_parameter("top_tex", dirt_c)
		m.set_shader_parameter("top_nrm", dirt_n)
		m.set_shader_parameter("top_color", look[0])
		m.set_shader_parameter("side_color", look[1])
		m.set_shader_parameter("top_detail", look[2])
		m.set_shader_parameter("lip", look[3])
	elif kind == "jungle":
		m.set_shader_parameter("top_color", _grass_color().darkened(0.12).lerp(Color("#2f5a1c"), 0.3))
	elif kind.begins_with("desert"):
		m.set_shader_parameter("top_tex", dirt_c)
		m.set_shader_parameter("top_nrm", dirt_n)
		m.set_shader_parameter("top_color", _real(Color(country.get("top", "#e9b44c")), 0.9))
		m.set_shader_parameter("top_detail", 0.55)
		m.set_shader_parameter("lip", 0.18)
	_materials[key] = m
	return m


## Verde da grama do país (mais natural que a cor pastel original).
func _grass_color() -> Color:
	var c := _real(Color(country.get("top", "#5cbf4a")), 0.62)
	# puxa um pouco para um verde de grama de verdade
	return c.lerp(Color("#4a6b2a"), 0.45)


## Bloco de terreno contínuo: cubo unitário escalado (o shader usa isso para achar o topo).
## A malha é subdividida para o relevo do topo e a terra irregular aparecerem.
func _terrain_box(pos: Vector3, size: Vector3, biome: String, parent: Node3D = null) -> MeshInstance3D:
	var step := 0.6 if low_quality else 0.4
	var sw := clampi(ceili(size.x / step), 1, 120)
	var sd := clampi(ceili(size.z / step), 1, 40)
	var sh := clampi(ceili(size.y / 0.5), 1, 16)
	var key := "box_%d_%d_%d" % [sw, sd, sh]
	if not _materials.has(key):
		var bm := BoxMesh.new()
		bm.subdivide_width = sw
		bm.subdivide_depth = sd
		bm.subdivide_height = sh
		_materials[key] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _materials[key]
	mi.material_override = _terrain_mat(biome)
	mi.position = pos
	mi.scale = size
	# o relevo sobe um pouco acima da caixa original
	mi.extra_cull_margin = 1.0
	(parent if parent != null else self).add_child(mi)
	return mi


## Chão: um bloco só, contínuo, com grama em cima e terra na frente (fundo de 3 "fileiras").
func _ground(x0: float, x1: float, biome := "") -> void:
	var w := x1 - x0
	_collider(Vector3(x0 + w * 0.5, -2.0, 0.0), Vector3(w, 4.0, DEPTH))
	_terrain_box(Vector3(x0 + w * 0.5, -4.0, (GROUND_FRONT + GROUND_BACK) * 0.5), Vector3(w, 8.0, GROUND_FRONT - GROUND_BACK), biome)
	_ground_segs.append([x0, x1, biome])


# ---------------------------------------------------------------- fios de grama
# Cada fio é um triângulo só (leve para tablet/celular). Os tufos são desenhados com MultiMesh,
# em pedaços de 12 m para a câmera só desenhar o que aparece na tela.
# Além do "tapete" de grama em cima, tem uma franja na borda que cai por cima da terra.

const GRASS_CHUNK := 12.0


func _grass_density(kind: String) -> Dictionary:
	var d: Dictionary = {
		"grass": {"path": 14.0, "back": 11.0, "fringe": 7.0},
		"grass_village": {"path": 7.0, "back": 5.0, "fringe": 4.0},
		"desert": {"path": 2.0, "back": 1.6, "fringe": 1.5},
		"desert_village": {"path": 1.0, "back": 0.8, "fringe": 1.0},
		"jungle": {"path": 16.0, "back": 13.0, "fringe": 8.0},
		"sand": {"path": 0.8, "back": 1.0, "fringe": 0.6},
		"canyon": {"path": 0.6, "back": 0.5, "fringe": 0.5},
		"snow": {"path": 0.0, "back": 0.0, "fringe": 0.0},
		"salt": {"path": 0.0, "back": 0.0, "fringe": 0.0},
	}[kind].duplicate()
	if low_quality:
		for k in d:
			d[k] *= 0.5
	return d


## Monta a grama de todo o chão (chamado depois de montar a fase).
func _build_grass() -> void:
	_ground_segs.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	for i in _ground_segs.size():
		var seg: Array = _ground_segs[i]
		var kind := _terrain_kind(seg[2])
		if kind == "cave":
			continue
		var dens := _grass_density(kind)
		var x := float(seg[0])
		while x < seg[1] - 0.05:
			var x_end := minf(x + GRASS_CHUNK, seg[1])
			var items: Array = []
			_scatter(items, x, x_end, -2.0, GROUND_FRONT - 0.05, dens["path"], 0.6, 1.05, seg[2])
			_scatter(items, x, x_end, GROUND_BACK + 0.2, -2.0, dens["back"], 0.7, 1.15, seg[2])
			_fringe_x(items, x, x_end, GROUND_FRONT, dens["fringe"], seg[2])
			_add_grass(items, kind, self)
			x = x_end
		# franja nas pontas que não encostam em outro pedaço de chão (beira dos buracos)
		var items2: Array = []
		var touches_left: bool = i > 0 and _ground_segs[i - 1][1] >= seg[0] - 0.01
		var touches_right: bool = i < _ground_segs.size() - 1 and _ground_segs[i + 1][0] <= seg[1] + 0.01
		if not touches_left:
			_fringe_z(items2, seg[0], -1.0, GROUND_BACK, GROUND_FRONT, dens["fringe"], seg[2])
		if not touches_right:
			_fringe_z(items2, seg[1], 1.0, GROUND_BACK, GROUND_FRONT, dens["fringe"], seg[2])
		if not items2.is_empty():
			_add_grass(items2, kind, self)


## Espalha tufos numa área retangular. Cada item: [é_franja, Transform3D].
## y0/x_off servem para a grama das plataformas (posição local dentro da plataforma).
func _scatter(items: Array, x0: float, x1: float, z0: float, z1: float, density: float,
		s_min: float, s_max: float, biome: String, y0 := 0.0, x_off := 0.0) -> void:
	var n := int((x1 - x0) * (z1 - z0) * density)
	for i in n:
		var x := _rng.randf_range(x0 + 0.05, x1 - 0.05)
		var z := _rng.randf_range(z0, z1)
		var s := _rng.randf_range(s_min, s_max)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.2), s))
		items.append([false, Transform3D(b, Vector3(x, y0 + _height(x + x_off, z, biome) - 0.02, z))])


## Franja ao longo da borda da frente (os fios se inclinam para fora, por cima da terra).
func _fringe_x(items: Array, x0: float, x1: float, z_edge: float, density: float, biome: String, y0 := 0.0, x_off := 0.0) -> void:
	var n := int((x1 - x0) * density)
	for i in n:
		var x := _rng.randf_range(x0, x1)
		var z := z_edge - _rng.randf_range(0.02, 0.12)
		var s := _rng.randf_range(0.6, 1.0)
		var b := Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5)).scaled(Vector3.ONE * s)
		items.append([true, Transform3D(b, Vector3(x, y0 + _height(x + x_off, z, biome) - 0.02, z))])


## Franja na lateral (ponta do bloco): side = -1 (esquerda) ou 1 (direita).
func _fringe_z(items: Array, x_edge: float, side: float, z0: float, z1: float, density: float, biome: String, y0 := 0.0, x_off := 0.0) -> void:
	var n := int((z1 - z0) * density)
	for i in n:
		var z := _rng.randf_range(z0, z1)
		var x := x_edge - side * _rng.randf_range(0.02, 0.12)
		var s := _rng.randf_range(0.6, 1.0)
		var b := Basis(Vector3.UP, side * PI * 0.5 + _rng.randf_range(-0.5, 0.5)).scaled(Vector3.ONE * s)
		items.append([true, Transform3D(b, Vector3(x, y0 + _height(x + x_off, z, biome) - 0.02, z))])


func _add_grass(items: Array, kind: String, parent: Node3D) -> void:
	for want_fringe in [false, true]:
		var list := items.filter(func(it) -> bool: return it[0] == want_fringe)
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _fringe_mesh() if want_fringe else _blade_mesh()
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _blade_mat(kind)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


## Tufo do tapete: 7 fios de um triângulo cada.
func _blade_mesh() -> ArrayMesh:
	if not _materials.has("blade_mesh"):
		_materials["blade_mesh"] = _make_clump(7, 0.13, 0.26, 0.02, 0.09, false)
	return _materials["blade_mesh"]


## Tufo da franja: fios mais compridos, todos inclinados para +Z (para fora da borda).
func _fringe_mesh() -> ArrayMesh:
	if not _materials.has("fringe_mesh"):
		_materials["fringe_mesh"] = _make_clump(5, 0.13, 0.24, 0.05, 0.12, true)
	return _materials["fringe_mesh"]


func _make_clump(count: int, h_min: float, h_max: float, lean_min: float, lean_max: float, outward: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 1234 + count
	for b in count:
		var ang := (PI * 0.5 + r.randf_range(-0.7, 0.7)) if outward else r.randf() * TAU
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var root := Vector3(r.randf_range(-0.09, 0.09), 0, r.randf_range(-0.09, 0.09))
		var h := r.randf_range(h_min, h_max)
		var hw := r.randf_range(0.022, 0.032)
		var tip := root + dir * r.randf_range(lean_min, lean_max) + Vector3(0, h, 0)
		for v in [[root - side * hw, 0.0], [root + side * hw, 0.0], [tip, 1.0]]:
			st.set_uv(Vector2(0.5, v[1]))
			st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


func _blade_mat(kind: String) -> ShaderMaterial:
	var key := "blade_" + kind
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = BLADE_SHADER
	if kind.begins_with("desert") or kind == "sand" or kind == "canyon":
		m.set_shader_parameter("base_color", Color("#7d6838"))
		m.set_shader_parameter("tip_color", Color("#b39a55"))
	else:
		var g := _grass_color()
		if kind == "jungle":
			g = g.darkened(0.15)
		m.set_shader_parameter("base_color", g.darkened(0.35))
		m.set_shader_parameter("tip_color", Color.from_hsv(g.h, minf(1.0, g.s * 1.1), minf(1.0, g.v * 1.3)))
	_materials[key] = m
	_blade_mats.append(m)
	return m


func _platform(x: float, top: float, w: float, biome := "") -> StaticBody3D:
	var body := _collider(Vector3(x + w * 0.5, top - 0.3, 0.0), Vector3(w, 0.6, DEPTH))
	_terrain_box(Vector3(0, -0.15, 0), Vector3(w, 0.9, DEPTH), biome, body)
	# grama em cima da plataforma (vai junto quando ela sobe ou cai)
	var kind := _terrain_kind(biome)
	if kind != "cave":
		var dens := _grass_density(kind)
		var cx := x + w * 0.5
		var items: Array = []
		var half := DEPTH * 0.5
		_scatter(items, -w * 0.5, w * 0.5, -half + 0.1, half - 0.1, dens["path"] * 0.8, 0.5, 0.9, biome, 0.3, cx)
		_fringe_x(items, -w * 0.5, w * 0.5, half, dens["fringe"], biome, 0.3, cx)
		_fringe_z(items, -w * 0.5, -1.0, -half, half, dens["fringe"], biome, 0.3, cx)
		_fringe_z(items, w * 0.5, 1.0, -half, half, dens["fringe"], biome, 0.3, cx)
		_add_grass(items, kind, body)
	return body


func _moving_platform(center_x: float, top: float, w: float, amplitude: float) -> void:
	var body := AnimatableBody3D.new()
	body.set_script(MovingPlatformScript)
	body.position = Vector3(center_x, top - 0.3, 0.0)
	body.set("amplitude", amplitude)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 0.6, DEPTH)
	shape.shape = box
	body.add_child(shape)
	_place(PK + "block-moving-large.glb", Vector3(0, 0.3 - 0.75, 0), 0.0, Vector3(w, GS, DEPTH), body)
	add_child(body)


func _invisible_wall(x: float) -> void:
	_collider(Vector3(x, 10.0, 0.0), Vector3(1.0, 40.0, DEPTH))


func _trigger(center: Vector3, size: Vector3, on_enter: Callable) -> void:
	var area := Area3D.new()
	area.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(on_enter)


func _sign(x: float, text: String) -> void:
	_place(PK + "sign.glb", Vector3(x, 0.0, -1.4), 0.0, Vector3.ONE * 3.2)
	var l := _label(text, 46, Vector3(x, 1.45, -1.18))
	l.modulate = Color("#fff3c4")


# ---------------------------------------------------------------- vilas

## Vila: casas coloniais (Fantasy Town) ao fundo, barracas, fonte, lampiões e moradores.
func _build_village(x: float, village_index: int) -> void:
	_ground(x, x + VILLAGE_LEN, "village")
	var towns: Array = country["towns"]
	var town: String = towns[mini(village_index, towns.size() - 1)]

	# placa de boas-vindas
	_place(PK + "sign.glb", Vector3(x + 2.2, 0.0, -1.4), 0.0, Vector3.ONE * 3.6)
	var board := _label("Bienvenidos a\n" + town, 30, Vector3(x + 2.2, 1.62, -1.15))
	board.modulate = Color("#fff3c4")

	# casas
	var hx := x + 4.5
	while hx < x + VILLAGE_LEN - 5.0:
		var cells := 2 if _rng.randf() < 0.4 else 3
		_house(hx, -3.7, cells, 1 if _rng.randf() < 0.35 else 2)
		hx += cells * HOUSE_S + _rng.randf_range(0.8, 2.0)

	# enfeites da praça
	_place(FT + "fountain-round.glb", Vector3(x + VILLAGE_LEN * 0.5, 0.02, -2.2), 0.0, Vector3.ONE * 1.4)
	_place(FT + "stall-red.glb", Vector3(x + 6.0, 0.0, -2.3), 0.0, Vector3.ONE * 2.0)
	_place(FT + "stall-green.glb", Vector3(x + VILLAGE_LEN - 7.0, 0.0, -2.3), 0.0, Vector3.ONE * 2.0)
	for lx in [x + 11.0, x + 25.0]:
		_place(FT + "lantern.glb", Vector3(lx, 0.0, -1.5), 0.0, Vector3.ONE * 1.7)
	_place(FT + "cart.glb", Vector3(x + VILLAGE_LEN - 3.0, 0.0, -2.5), 0.3, Vector3.ONE * 1.8)
	for i in 6:
		_place(NK + SMALL_PLANTS[_rng.randi() % SMALL_PLANTS.size()] + ".glb",
			Vector3(x + _rng.randf_range(1.0, VILLAGE_LEN - 1.0), 0.0, _rng.randf_range(-1.9, -1.4)),
			_rng.randf() * TAU, Vector3.ONE * 2.2)

	# moradores desta vila
	for pi in people.size():
		if people[pi]["village"] == village_index:
			_build_npc(x + people[pi]["slot"], pi)


## Casa montada com peças do Fantasy Town: fachada com janelas e porta, laterais e telhado.
func _house(left_x: float, front_z: float, cells: int, floors: int) -> void:
	var h := Node3D.new()
	h.scale = Vector3.ONE * HOUSE_S
	h.position = Vector3(left_x + 0.5 * HOUSE_S, 0.0, front_z - 0.5 * HOUSE_S)
	add_child(h)
	var door_cell := _rng.randi_range(0, cells - 1)
	var wood := _rng.randf() < 0.35
	var prefix := FT + ("wall-wood-" if wood else "wall-")
	var windows := ["window-shutters", "window-glass", "window-round", "window-small"]
	var win: String = windows[_rng.randi() % windows.size()]
	for f in floors:
		for cx in cells:
			var piece := prefix + (("door" if f == 0 and cx == door_cell else win)) + ".glb"
			_place(piece, Vector3(cx, f, 0), -PI * 0.5, Vector3.ONE, h)
		for cz in 2:
			_place(FT + ("wall-wood.glb" if wood else "wall.glb"), Vector3(cells - 1, f, -cz), 0.0, Vector3.ONE, h)
			_place(FT + ("wall-wood.glb" if wood else "wall.glb"), Vector3(0, f, -cz), PI, Vector3.ONE, h)
	for cx in cells:
		_place(FT + "roof-gable.glb", Vector3(cx, floors, -0.5), 0.0, Vector3(1, 1, 2), h)
	if _rng.randf() < 0.5:
		_place(FT + "chimney.glb", Vector3(cells - 1, floors + 0.2, -0.8), 0.0, Vector3.ONE, h)
	# metade das casas usa a paleta alternativa de cores do kit
	if _rng.randf() < 0.5 and _variation_tex:
		_retexture(h, _variation_tex)


func _retexture(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(s)
			if base is BaseMaterial3D:
				var key := "tex_%d_%d" % [base.get_instance_id(), tex.get_instance_id()]
				if not _materials.has(key):
					var m: BaseMaterial3D = base.duplicate()
					m.albedo_texture = tex
					_materials[key] = m
				mi.set_surface_override_material(s, _materials[key])
	for c in node.get_children():
		_retexture(c, tex)


func _build_npc(x: float, index: int) -> void:
	var npc := Node3D.new()
	npc.set_script(NpcScript)
	npc.set("data", people[index]["data"])
	# moradores ficam um pouco ao fundo (o jogador passa na frente deles)
	npc.position = Vector3(x, 0.0, -0.9)
	add_child(npc)
	# guarda na posição certa da lista (os moradores podem ser criados fora de ordem)
	while _npcs.size() <= index:
		_npcs.append(null)
	_npcs[index] = npc
	_trigger(Vector3(x, 1.5, 0.0), Vector3(3.6, 4.0, DEPTH), func(body: Node3D) -> void:
		if body == player:
			npc_talked.emit(index))


# ---------------------------------------------------------------- biomas

## Bioma aberto (bosque, selva, deserto...): árvores ao fundo e plantinhas na beira.
func _flora(x0: float, x1: float, biome: String, sparse: bool) -> void:
	var set_: Array = ZONE_FLORA.get(biome, FLORA.get(biome, FLORA["hills"]))
	var x := x0 + _rng.randf_range(0.5, 2.0)
	while x < x1:
		var mname: String = set_[_rng.randi() % set_.size()]
		var s := _rng.randf_range(2.6, 3.8)
		var path := NK + mname + ".glb"
		if mname.begins_with("pk:"):
			path = PK + mname.substr(3) + ".glb"
			s *= 0.75
		elif mname.begins_with("plant"):
			s *= 1.6
		elif mname.begins_with("rock"):
			s *= 0.8
		var tz := _rng.randf_range(-7.2, -3.6)
		# nos buracos não tem chão (de frente a fundo): nada de árvore flutuando
		if not _has_ground(x, 0.9):
			x += 0.6
			continue
		var n := _place(path, Vector3(x, _height(x, tz, biome) - 0.08, tz), _rng.randf() * TAU, Vector3.ONE * s)
		if biome == "canyon" and mname.begins_with("rock"):
			_tint(n, CANYON_RED.lerp(Color("#c9774a"), _rng.randf()))
		x += _rng.randf_range(2.5, 4.5) if sparse else _rng.randf_range(1.2, 2.6)
	var small: Array = ZONE_SMALL.get(biome, SMALL_PLANTS)
	var px := x0 + 0.8
	while px < x1 - 0.5:
		if _rng.randf() < 0.6 and _has_ground(px, 0.5):
			var pz := _rng.randf_range(-2.0, -1.3)
			var sn := _place(NK + small[_rng.randi() % small.size()] + ".glb",
				Vector3(px, _height(px, pz, biome) - 0.03, pz), _rng.randf() * TAU, Vector3.ONE * 2.2)
			if biome == "canyon":
				_tint(sn, CANYON_RED)
		px += _rng.randf_range(1.5, 3.0)


## Existe chão (bloco inteiro, de frente a fundo) neste x, com folga para os lados?
func _has_ground(x: float, margin: float) -> bool:
	for seg in _ground_segs:
		if x - margin >= seg[0] and x + margin <= seg[1]:
			return true
	return false


## Pinta um modelo inteiro de uma cor só (pedras vermelhas do cânion etc.).
func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _mat(color)
	for c in node.get_children():
		_tint(c, color)


## Coração que flutua girando: recupera um coração (só some se o jogador precisava).
func _heart_pickup(x: float, y: float) -> void:
	var h := _place(PK + "heart.glb", Vector3(x, y, 0.0), 0.0, Vector3.ONE * 1.5)
	h.set_meta("y", y)
	_pickups.append(h)
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.6
	shape.shape = sph
	area.add_child(shape)
	h.add_child(area)
	var take := func(body: Node3D) -> void:
		if body == player and player.heal(1):
			_pickups.erase(h)
			var tw := create_tween()
			tw.tween_property(h, "scale", Vector3.ONE * 2.2, 0.12)
			tw.tween_property(h, "scale", Vector3.ONE * 0.01, 0.15)
			tw.tween_callback(h.queue_free)
	area.body_entered.connect(take)


## Caverna: teto e parede de rocha, estalactites e tochas com luz.
func _cave(x0: float, x1: float) -> void:
	var n := maxi(1, roundi((x1 - x0) / CELL))
	var cw := (x1 - x0) / n
	for i in n:
		var cx := x0 + cw * (i + 0.5)
		for r in ROWS:
			_place(NK + "cliff_block_rock.glb", Vector3(cx, CAVE_TOP, -r * CELL), 0.0, Vector3(cw, 2.5, CELL))
		for k in 3:
			_place(NK + "cliff_block_rock.glb", Vector3(cx, k * 2.2, -ROWS * CELL + 0.6), 0.0, Vector3(cw, 2.3, 1.2))
		if _rng.randf() < 0.55:
			var st := _place(NK + "rock_tall" + "ABCDE"[_rng.randi() % 5] + ".glb",
				Vector3(cx + _rng.randf_range(-1.0, 1.0), CAVE_TOP + 0.1, _rng.randf_range(-5.0, -1.8)), 0.0, Vector3.ONE * 2.4)
			st.rotation.x = PI
	# tochas
	var tx := x0 + 4.0
	while tx < x1 - 2.0:
		_visual_mesh(_cyl(0.06, 0.08, 1.0), Vector3(tx, 2.4, -ROWS * CELL + 1.3), Color("#5d4037"))
		var flame := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.4
		flame.mesh = sm
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color("#ffb347")
		fm.emission_enabled = true
		fm.emission = Color("#ff9a2e")
		fm.emission_energy_multiplier = 3.0
		flame.material_override = fm
		flame.position = Vector3(tx, 3.0, -ROWS * CELL + 1.3)
		add_child(flame)
		var light := OmniLight3D.new()
		light.light_color = Color("#ffb066")
		light.light_energy = 2.2
		light.omni_range = 9.0
		light.position = Vector3(tx, 3.2, -ROWS * CELL + 2.2)
		add_child(light)
		tx += 11.0


# ---------------------------------------------------------------- desafio: plataforma com a palavra certa

## Uma placa pergunta "¿Cómo se dice ... aquí?" e duas plataformas flutuam sobre um buraco,
## cada uma com uma palavra. Pular na certa faz uma ponte surgir; na errada, ela cai.
func _build_choice(x: float, ci: int, biome: String) -> void:
	_ground(x, x + 5.0, biome)
	_ground(x + 21.0, x + 26.0, biome)
	if ci >= choices.size():
		_platform(x + 7.0, 0.8, 12.0, biome)
		return
	var ch: Dictionary = choices[ci]
	var q := _label("¿Cómo se dice «%s» aquí?" % ch["es"], 40, Vector3(x + 9.5, 4.5, -0.6))
	q.modulate = Color("#fff3c4")
	var hint := _label("Salta en la palabra correcta", 26, Vector3(x + 9.5, 3.95, -0.6))
	hint.modulate = Color("#dfe7ff")

	var correct_first := _rng.randf() < 0.5
	var st := {"solved": false, "platforms": [], "x": x, "biome": biome}
	_choice_state.append(st)
	for k in 2:
		var is_correct := (k == 0) == correct_first
		var word: String = ch["correct"] if is_correct else ch["wrong"]
		var px := x + 7.0 + k * 4.6
		var body := _platform(px, 1.0, 2.6, biome)
		var lbl := _label(word, 64, Vector3(px + 1.3, 2.4, 0.2), true)
		lbl.modulate = Color("#ffcc33")
		var pl := {"body": body, "label": lbl, "home": body.position, "correct": is_correct, "down": false}
		st["platforms"].append(pl)
		_trigger(Vector3(px + 1.3, 1.6, 0.0), Vector3(2.4, 1.0, DEPTH), func(b: Node3D) -> void:
			if b != player or st["solved"] or pl["down"] or player.velocity.y > 0.5:
				return
			choice_landed.emit(ci, pl["correct"])
			if pl["correct"]:
				_solve_choice(st, pl)
			else:
				_drop_platform(pl))


func _solve_choice(st: Dictionary, chosen: Dictionary) -> void:
	st["solved"] = true
	chosen["label"].modulate = Color("#7dff9a")
	for pl in st["platforms"]:
		if pl != chosen:
			_drop_platform(pl)
	# ponte que sobe do buraco até o outro lado
	var x: float = st["x"]
	# uma ponte inteira, emendada da plataforma certa até o chão do outro lado
	var start_x: float = chosen["home"].x + 1.3
	var b := _platform(start_x, 1.0, x + 21.5 - start_x, st["biome"])
	var final_y := b.position.y
	b.position.y -= 8.0
	var tw := create_tween()
	tw.tween_property(b, "position:y", final_y, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _drop_platform(pl: Dictionary) -> void:
	if pl["down"]:
		return
	pl["down"] = true
	pl["label"].modulate = Color("#ff7b7b")
	var body: StaticBody3D = pl["body"]
	var tw := create_tween()
	pl["tween"] = tw
	# treme por quase 1 segundo antes de cair: dá tempo de pular para a outra plataforma
	for i in 9:
		tw.tween_property(body, "position:x", pl["home"].x + 0.1, 0.05)
		tw.tween_property(body, "position:x", pl["home"].x - 0.1, 0.05)
	tw.tween_callback(func() -> void:
		body.get_child(0).set_deferred("disabled", true))
	tw.tween_property(body, "position:y", pl["home"].y - 14.0, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _restore_platform(pl: Dictionary) -> void:
	if not pl["down"]:
		return
	pl["down"] = false
	if pl.has("tween") and pl["tween"] != null and pl["tween"].is_valid():
		pl["tween"].kill()
	var body: StaticBody3D = pl["body"]
	body.position = pl["home"]
	body.get_child(0).set_deferred("disabled", false)
	pl["label"].modulate = Color("#ffcc33")


# ---------------------------------------------------------------- monstros e bandeira

func _monster(x_min: float, x_max: float) -> void:
	var m := Node3D.new()
	m.set_script(MonsterScript)
	m.position = Vector3((x_min + x_max) * 0.5, 0.0, 0.0)
	m.set("x_min", x_min)
	m.set("x_max", x_max)
	m.set("speed", _rng.randf_range(1.6, 2.6))
	m.set("model", MONSTER_MODELS[_rng.randi() % MONSTER_MODELS.size()])
	add_child(m)
	m.defeated.connect(func() -> void: monster_defeated.emit())
	_monsters.append(m)
	monster_count += 1


func _build_goal(x: float) -> void:
	_visual_mesh(_cyl(0.08, 0.08, 6.0), Vector3(x, 3.0, 0.0), Color("#eeeeee"))
	var colors: Array = country["flag"]
	var n := colors.size()
	var fx := x + 0.08
	for i in n:
		if country["flag_dir"] == "v":
			var w := 2.1 / n
			_visual_box(Vector3(fx + w * 0.5 + i * w, 5.3, 0.0), Vector3(w, 1.2, 0.08), Color(colors[i]))
		else:
			var h := 1.2 / n
			_visual_box(Vector3(fx + 1.05, 5.9 - h * 0.5 - i * h, 0.0), Vector3(2.1, h, 0.08), Color(colors[i]))
	if country.has("flag_canton"):
		_visual_box(Vector3(fx + 0.4, 5.6, 0.03), Vector3(0.8, 0.6, 0.08), Color(country["flag_canton"]))
	_label("¡META!", 64, Vector3(x, 6.7, 0.0))
	_place(PK + "chest.glb", Vector3(x + 2.5, 0.0, -1.2), -0.4, Vector3.ONE * 2.0)

	_trigger(Vector3(x, 2.0, 0.0), Vector3(1.6, 4.0, DEPTH), func(body: Node3D) -> void:
		if body == player and not _goal_done:
			_goal_done = true
			goal_reached.emit())


# ---------------------------------------------------------------- fundo em camadas

func _build_backdrop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(country["id"]) + 7
	var deco: String = country["deco"]
	var base := _real(Color(country["deco_color"]), 0.75)

	# chão do fundo (camada do meio) e terreno distante
	var mid := _real(Color(country["top"]), 0.8) if deco == "cactus" else _grass_color().darkened(0.1)
	_visual_box(Vector3(level_end_x * 0.5, -2.0, -22.0), Vector3(level_end_x + 160.0, 1.0, 28.0), mid)
	_visual_box(Vector3(level_end_x * 0.5, -3.5, -60.0), Vector3(level_end_x + 260.0, 1.0, 50.0),
		mid.darkened(0.15).lerp(Color(country["sky_horizon"]), 0.25))

	# camada do meio: árvores/plantas do país (Nature Kit), maiores
	var set_: Array = FLORA.get(deco, FLORA["hills"])
	var x := -40.0
	while x < level_end_x + 40.0:
		var mname: String = set_[rng.randi() % set_.size()]
		var s := rng.randf_range(3.5, 6.0)
		var tz := rng.randf_range(-26.0, -10.0)
		var rot := rng.randf() * TAU
		if not _in_open_zone(x):
			_place(NK + mname + ".glb", Vector3(x, -1.5, tz), rot, Vector3.ONE * s)
		x += rng.randf_range(1.5, 3.5)

	# camada distante: montanhas ou colinas
	x = -80.0
	while x < level_end_x + 80.0:
		var tint := base.lerp(Color(country["sky_horizon"]), rng.randf_range(0.35, 0.6))
		if deco == "mountains" or deco == "cactus":
			var mh := rng.randf_range(14.0, 30.0)
			var mz := rng.randf_range(-75.0, -45.0)
			_visual_mesh(_cyl(0.0, mh * 0.75, mh), Vector3(x, -3.0 + mh * 0.5, mz), tint)
			if deco == "mountains":
				_visual_mesh(_cyl(0.0, mh * 0.75 * 0.28, mh * 0.28), Vector3(x, -3.0 + mh * 0.86 + 0.05, mz), Color("#f4f6fb"))
		elif deco == "city":
			_house(x, rng.randf_range(-40.0, -32.0), 3, rng.randi_range(2, 3))
		else:
			var sm := SphereMesh.new()
			var r := rng.randf_range(8.0, 16.0)
			sm.radius = r
			sm.height = r * 2.0
			var hill := _visual_mesh(sm, Vector3(x, -3.5, rng.randf_range(-70.0, -45.0)), tint)
			hill.scale = Vector3(1.8, 0.55, 1.0)
		x += rng.randf_range(10.0, 20.0)

	_build_far_water()
	_build_landmarks()

	# nuvens que andam devagar
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(1, 1, 1)
	cloud_mat.roughness = 1.0
	x = -60.0
	while x < level_end_x + 60.0:
		var cloud := Node3D.new()
		cloud.position = Vector3(x, rng.randf_range(15.0, 24.0), rng.randf_range(-70.0, -45.0))
		for k in 4:
			var puff := MeshInstance3D.new()
			var sm := SphereMesh.new()
			var r := rng.randf_range(2.0, 3.6)
			sm.radius = r
			sm.height = r * 1.4
			puff.mesh = sm
			puff.material_override = cloud_mat
			puff.position = Vector3(k * 2.6 - 4.0, rng.randf_range(-0.6, 0.8), rng.randf_range(-1.0, 1.0))
			cloud.add_child(puff)
		add_child(cloud)
		_clouds.append(cloud)
		x += rng.randf_range(22.0, 40.0)


# ---------------------------------------------------------------- mundo de cada país: zonas

## A zona (praia, lago, salar) é aberta ao fundo: sem árvores na camada do meio.
func _in_open_zone(x: float, margin := 6.0) -> bool:
	for z in _zones:
		if z[2] in ["beach", "lake", "salt"] and x > z[0] - margin and x < z[1] + margin:
			return true
	return false


## Junta os pedaços seguidos da mesma zona e monta o que é próprio de cada uma.
func _build_zone_extras() -> void:
	var merged: Array = []
	for z in _zones:
		if not merged.is_empty() and merged[-1][2] == z[2] and absf(merged[-1][1] - z[0]) < 0.1:
			merged[-1][1] = z[1]
		else:
			merged.append(z.duplicate())
	for z in merged:
		var x0: float = z[0]
		var x1: float = z[1]
		match z[2]:
			"beach":
				_water(x0 - 6.0, x1 + 6.0, -0.55, GROUND_BACK - 0.1, -95.0, Color("#2b8fbf"))
				_visual_box(Vector3((x0 + x1) * 0.5, -0.5, GROUND_BACK - 0.35), Vector3(x1 - x0 + 12.0, 0.06, 0.5), Color("#eef6f6"))
				for i in 3:
					_place(NK + "canoe.glb", Vector3(_rng.randf_range(x0, x1), -0.5, _rng.randf_range(-14.0, -10.0)), _rng.randf() * TAU, Vector3.ONE * 3.0)
			"lake":
				_water(x0 - 6.0, x1 + 6.0, -0.6, GROUND_BACK - 0.1, -42.0, Color("#3f86a8"))
				var lx := x0
				while lx < x1:
					_place(NK + ("lily_large" if _rng.randf() < 0.6 else "lily_small") + ".glb",
						Vector3(lx, -0.55, _rng.randf_range(-12.0, -8.6)), _rng.randf() * TAU, Vector3.ONE * 2.5)
					lx += _rng.randf_range(2.0, 4.5)
				_place(NK + "canoe.glb", Vector3((x0 + x1) * 0.5, -0.55, -15.0), 0.4, Vector3.ONE * 3.2)
				# margem do outro lado do lago
				var bx := x0 - 6.0
				while bx < x1 + 6.0:
					_place(NK + ["tree_oak", "tree_default", "tree_tall"][_rng.randi() % 3] + ".glb",
						Vector3(bx, -1.5, _rng.randf_range(-46.0, -42.0)), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(4.0, 6.0))
					bx += _rng.randf_range(2.5, 5.0)
			"salt":
				# o Salar de Uyuni: branco e liso até o horizonte, quase um espelho
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color("#eef0f0")
				mat.roughness = 0.12
				mat.metallic = 0.15
				var mi := _visual_box(Vector3((x0 + x1) * 0.5, -0.3, -50.0), Vector3(x1 - x0 + 30.0, 0.2, 84.0), Color.WHITE)
				mi.material_override = mat
			"canyon":
				# paredões vermelhos em camadas atrás do caminho
				var cx := x0 - 2.0
				while cx < x1 + 2.0:
					var w := _rng.randf_range(5.0, 9.0)
					var h := _rng.randf_range(5.0, 10.0)
					var zc := _rng.randf_range(-24.0, -18.0)
					var y := -1.5
					var layer := 0
					while y < h - 1.5:
						var lh := minf(_rng.randf_range(1.6, 3.2), h - 1.5 - y)
						var col := CANYON_RED if layer % 2 == 0 else Color("#c27a4c")
						_visual_box(Vector3(cx + w * 0.5, y + lh * 0.5, zc), Vector3(w * (1.0 - layer * 0.04), lh, 5.0), col)
						y += lh
						layer += 1
					cx += w * _rng.randf_range(0.7, 0.95)
			"jungle":
				# parede de mata fechada ao fundo
				var jx := x0
				while jx < x1:
					_place(NK + ["tree_fat_darkh", "tree_default_dark", "tree_palmDetailedTall", "tree_detailed_dark"][_rng.randi() % 4] + ".glb",
						Vector3(jx, -1.5, _rng.randf_range(-9.5, -8.4)), _rng.randf() * TAU, Vector3.ONE * _rng.randf_range(4.5, 6.5))
					jx += _rng.randf_range(1.6, 3.0)
			"snow":
				_snowfall(x0, x1)
			"fields":
				var crop: String = world.get("crop", "crops_wheatStageB")
				var step := 2.0 if low_quality else 1.4
				var fx := x0 + 0.8
				while fx < x1 - 0.5:
					if not _has_ground(fx, 0.5):
						fx += step
						continue
					for rz in [-3.0, -4.3, -5.6, -6.9]:
						var hz := _height(fx, rz, z[2])
						_place(NK + crop + ".glb", Vector3(fx + _rng.randf_range(-0.2, 0.2), hz - 0.05, rz), _rng.randf() * TAU, Vector3.ONE * 2.4)
					fx += step
				var ex := x0
				while ex < x1:
					if _has_ground(ex, 0.9):
						_place(NK + "fence_simple.glb", Vector3(ex, _height(ex, -2.2, z[2]), -2.2), 0.0, Vector3(1.6, 2.0, 2.0))
					ex += 1.6


func _water(x0: float, x1: float, y: float, z_front: float, z_back: float, color: Color) -> void:
	var key := "water_" + color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.08
		m.metallic = 0.25
		m.metallic_specular = 0.8
		_materials[key] = m
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, z_front - z_back)
	mi.mesh = pm
	mi.material_override = _materials[key]
	mi.position = Vector3((x0 + x1) * 0.5, y, (z_front + z_back) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _snowfall(x0: float, x1: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = 120 if low_quality else 260
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3((x1 - x0) * 0.5 + 4.0, 0.5, 7.0)
	p.position = Vector3((x0 + x1) * 0.5, 11.0, -1.0)
	p.direction = Vector3(0.2, -1, 0)
	p.spread = 15.0
	p.gravity = Vector3(0, -1.2, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	add_child(p)


# ---------------------------------------------------------------- mundo de cada país: marcos ao fundo

func _haze(c: Color, k := 0.25) -> Color:
	return c.lerp(Color(country["sky_horizon"]), k)


## Pirâmide de degraus: devolve a altura do topo.
func _stepped(x: float, z: float, y0: float, w: float, d: float, tiers: int, th: float, shrink: float, color: Color) -> float:
	var y := y0
	for i in tiers:
		var k := 1.0 - shrink * i
		_visual_box(Vector3(x, y + th * 0.5, z), Vector3(w * k, th, d * k), color if i % 2 == 0 else color.darkened(0.07))
		y += th
	return y


func _volcano(x: float, z: float, h: float, color: Color, snow: bool, smoke: bool) -> void:
	var top_r := h * 0.1
	var bot_r := h * 0.95
	_visual_mesh(_cyl(top_r, bot_r, h), Vector3(x, -3.0 + h * 0.5, z), _haze(color))
	if snow:
		var cap := h * 0.28
		_visual_mesh(_cyl(top_r, top_r + (bot_r - top_r) * 0.28, cap), Vector3(x, -3.0 + h - cap * 0.5 + 0.05, z + 0.05), Color("#f4f6fb"))
	if smoke:
		for i in 5:
			var sm := SphereMesh.new()
			var r := top_r * (1.0 + i * 0.45)
			sm.radius = r
			sm.height = r * 1.6
			_visual_mesh(sm, Vector3(x + i * top_r * 0.9, -3.0 + h + r * 0.6 + i * top_r * 1.1, z), _haze(Color("#d8d8dc"), 0.15))


func _lighthouse(x: float, z: float, h: float) -> void:
	_place(NK + "rock_largeA.glb", Vector3(x, -3.0, z), 0.0, Vector3.ONE * 7.0)
	var segs := 6
	var y := 1.5
	for i in segs:
		var sh := h / segs
		var r0 := 1.5 - 0.5 * float(i) / segs
		var r1 := 1.5 - 0.5 * float(i + 1) / segs
		_visual_mesh(_cyl(r1, r0, sh), Vector3(x, y + sh * 0.5, z), Color("#f2f0ea") if i % 2 == 0 else Color("#c23a2e"))
		y += sh
	_visual_mesh(_cyl(1.4, 1.4, 0.3), Vector3(x, y + 0.15, z), Color("#2a2f3a"))
	var lamp := _visual_mesh(_cyl(0.75, 0.75, 1.3), Vector3(x, y + 0.95, z), Color("#ffe9a0"))
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("#ffe9a0")
	lm.emission_enabled = true
	lm.emission = Color("#ffd966")
	lm.emission_energy_multiplier = 2.5
	lamp.material_override = lm
	_visual_mesh(_cyl(0.0, 1.0, 1.2), Vector3(x, y + 2.2, z), Color("#c23a2e"))


func _garita(x: float, y: float, z: float, s: float, color: Color) -> void:
	_visual_mesh(_cyl(0.9 * s, 0.9 * s, 2.4 * s), Vector3(x, y + 1.2 * s, z), color)
	var dome := SphereMesh.new()
	dome.radius = 1.0 * s
	dome.height = 1.2 * s
	_visual_mesh(dome, Vector3(x, y + 2.5 * s, z), color.lightened(0.1))
	_visual_mesh(_cyl(0.0, 0.2 * s, 0.6 * s), Vector3(x, y + 3.2 * s, z), color.lightened(0.1))


func _build_landmarks() -> void:
	var kind: String = world.get("landmark", "")
	if kind == "":
		return
	var xs: Array = _villages.duplicate() if not _villages.is_empty() else [level_end_x * 0.3]
	# um terceiro no meio do caminho, para o marco aparecer durante toda a viagem
	if xs.size() >= 2:
		xs.insert(1, (xs[0] + xs[1]) * 0.5)
	var lr := RandomNumberGenerator.new()
	lr.seed = hash(country["id"]) + 31
	for i in xs.size():
		var x: float = xs[i] + lr.randf_range(-6.0, 6.0)
		var flip := 1.0 if i % 2 == 0 else -1.0
		match kind:
			"pyramid":
				# pirâmide de degraus com templo em cima e escadaria (como Chichén Itzá)
				var stone := _haze(Color("#b7a585"))
				var top := _stepped(x, -42.0, -3.0, 22.0, 22.0, 9, 1.7, 0.075, stone)
				_visual_box(Vector3(x, top + 1.9, -42.0), Vector3(6.0, 3.8, 6.0), stone.darkened(0.05))
				_visual_box(Vector3(x, top + 1.3, -38.95), Vector3(1.6, 2.4, 0.2), Color("#3a3128"))
				for k in 9:
					var kk := 1.0 - 0.075 * k
					_visual_box(Vector3(x, -3.0 + 1.7 * k + 0.85, -42.0 + 11.0 * kk + 0.2), Vector3(3.4, 1.7, 0.4), stone.lightened(0.08))
			"tall_temple":
				# templo alto e estreito no meio da selva (como Tikal)
				var st := _haze(Color("#a49c8c"))
				var top2 := _stepped(x, -38.0, -3.0, 13.0, 11.0, 8, 2.6, 0.085, st)
				_visual_box(Vector3(x, top2 + 2.2, -38.0), Vector3(4.4, 4.4, 3.4), st.darkened(0.05))
				_visual_box(Vector3(x, top2 + 5.6, -38.3), Vector3(3.4, 2.6, 1.0), st)
				_volcano(x + 30.0 * flip, -70.0, 30.0, Color("#5b6b5a"), false, false)
			"stela":
				var st2 := _haze(Color("#8f9a7e"))
				var top3 := _stepped(x, -36.0, -3.0, 16.0, 12.0, 5, 1.5, 0.12, st2)
				_visual_box(Vector3(x, top3 + 1.5, -36.0), Vector3(5.0, 3.0, 4.0), st2)
				for k in 3:
					_place(NK + "statue_obelisk.glb", Vector3(x - 10.0 + k * 10.0, -1.5, -15.0), 0.0, Vector3.ONE * 4.0)
			"volcano_smoke":
				_volcano(x, -62.0, 32.0, Color("#4f6046"), false, true)
			"volcano_snow":
				_volcano(x, -66.0, 36.0, Color("#6b6f78"), true, false)
			"volcano":
				_volcano(x, -64.0, 28.0, Color("#3f5f3a"), false, false)
			"twin_volcanoes":
				_volcano(x - 9.0, -64.0, 30.0, Color("#4f6a46"), false, true)
				_volcano(x + 12.0, -68.0, 22.0, Color("#5a7050"), false, false)
				_water(x - 40.0, x + 40.0, -2.9, -40.0, -95.0, Color("#3f86a8"))
			"ship":
				# o Canal do Panamá: faixa de água e um navio cheio de contêineres
				var y0 := -2.6
				_visual_box(Vector3(x, y0 + 1.6, -42.0), Vector3(28.0, 3.2, 5.0), _haze(Color("#2b3a55")))
				_visual_box(Vector3(x, y0 + 3.3, -42.0), Vector3(28.4, 0.3, 5.2), _haze(Color("#b8322a")))
				var cols := [Color("#c0392b"), Color("#2e86c1"), Color("#f1c40f"), Color("#27ae60"), Color("#e67e22")]
				for cx in 8:
					for cy in 1 + (cx % 3):
						_visual_box(Vector3(x - 11.0 + cx * 2.7, y0 + 4.6 + cy * 2.4, -42.0), Vector3(2.5, 2.3, 4.2), _haze(cols[(cx + cy * 2) % cols.size()]))
				_visual_box(Vector3(x + 12.0, y0 + 6.5, -42.0), Vector3(3.2, 6.0, 4.6), _haze(Color("#f2f2ee")))
			"morro":
				_lighthouse(x - 6.0 * flip, -40.0, 14.0)
				_visual_box(Vector3(x + 6.0 * flip, -0.5, -40.0), Vector3(16.0, 5.0, 6.0), _haze(Color("#c9b48a")))
			"fort":
				var wall := _haze(Color("#c2ad84"))
				_visual_box(Vector3(x, -1.0, -38.0), Vector3(36.0, 4.0, 6.0), wall)
				_visual_box(Vector3(x, 1.4, -38.0), Vector3(36.0, 0.8, 6.4), wall.darkened(0.08))
				for gx in [-17.0, 0.0, 17.0]:
					_garita(x + gx, 1.8, -35.2, 1.3, wall)
			"church":
				var coral := _haze(Color("#d1b088"))
				_visual_box(Vector3(x, 1.5, -36.0), Vector3(16.0, 9.0, 9.0), coral)
				_visual_box(Vector3(x, 6.4, -36.0), Vector3(16.6, 0.8, 9.6), coral.darkened(0.1))
				_visual_box(Vector3(x + 9.0, 5.5, -35.0), Vector3(4.0, 17.0, 4.0), coral.lightened(0.05))
				var dome := SphereMesh.new()
				dome.radius = 2.0
				dome.height = 3.0
				_visual_mesh(dome, Vector3(x + 9.0, 14.3, -35.0), coral.lightened(0.1))
				_visual_box(Vector3(x - 2.0, -0.2, -31.4), Vector3(3.0, 5.0, 0.2), Color("#4a3a2c"))
			"wax_palms":
				# palmeiras-de-cera do Vale de Cocora: altíssimas
				for k in 7:
					_place(NK + "tree_palmTall.glb", Vector3(x - 15.0 + k * 5.0 + lr.randf_range(-1.5, 1.5), -1.5, lr.randf_range(-24.0, -16.0)),
						lr.randf() * TAU, Vector3(4.0, lr.randf_range(8.0, 11.0), 4.0))
			"tepui":
				# tepui (montanha de topo plano) com uma cachoeira enorme
				var rock := _haze(Color("#6e5a48"))
				_visual_mesh(_cyl(17.0, 20.0, 30.0), Vector3(x, 12.0, -64.0), rock)
				_visual_mesh(_cyl(17.0, 17.0, 1.2), Vector3(x, 27.6, -64.0), _haze(Color("#3f6b34")))
				var fall := _visual_box(Vector3(x + 4.0, 11.0, -45.6), Vector3(2.2, 28.0, 0.4), Color("#e8f4fa"))
				var fm := StandardMaterial3D.new()
				fm.albedo_color = Color("#eaf6fc")
				fm.emission_enabled = true
				fm.emission = Color("#cfe8f5")
				fm.emission_energy_multiplier = 0.5
				fall.material_override = fm
				for k in 4:
					var mist := SphereMesh.new()
					mist.radius = 2.4
					mist.height = 3.0
					_visual_mesh(mist, Vector3(x + 4.0 + (k - 1.5) * 2.4, -2.0, -45.0), Color("#eef6fa"))
			"terraces":
				# Machu Picchu: o pico verde ao fundo e terraços em degraus
				var green := _haze(Color("#4e7a3a"))
				_visual_mesh(_cyl(1.6, 11.0, 26.0), Vector3(x + 8.0 * flip, 10.0, -58.0), green)
				for k in 7:
					_visual_box(Vector3(x - 6.0 * flip, -2.4 + k * 1.3, -40.0 - k * 1.6), Vector3(24.0 - k * 2.0, 1.3, 2.2), green.lightened(0.04 * (k % 2)))
					_visual_box(Vector3(x - 6.0 * flip, -2.4 + k * 1.3, -38.85 - k * 1.6), Vector3(24.0 - k * 2.0, 1.3, 0.12), _haze(Color("#8d8577")))
				for k in 4:
					_visual_box(Vector3(x - 12.0 * flip + k * 3.2 * flip, 7.2, -51.0), Vector3(2.4, 1.8, 2.4), _haze(Color("#9a9286")))
			"moai":
				# moais da Ilha de Páscoa (Chile) em cima de uma base de pedra
				_visual_box(Vector3(x, -1.2, -16.0), Vector3(16.0, 0.8, 3.0), Color("#6d665c"))
				for k in 5:
					_place(NK + "statue_head.glb", Vector3(x - 6.0 + k * 3.0, -0.8, -16.0), 0.0, Vector3.ONE * 5.0)
				_volcano(x + 25.0 * flip, -70.0, 30.0, Color("#6b6f78"), true, false)
			"obelisk":
				# Obelisco de Buenos Aires
				var white := _haze(Color("#f0ede4"), 0.15)
				_visual_box(Vector3(x, -2.8, -36.0), Vector3(12.0, 0.4, 12.0), _haze(Color("#9a9a92")))
				_visual_box(Vector3(x, 7.0, -36.0), Vector3(2.4, 20.0, 2.4), white)
				var tip := _cyl(0.0, 1.7, 3.0)
				tip.radial_segments = 4
				var t := _visual_mesh(tip, Vector3(x, 18.5, -36.0), white)
				t.rotation.y = PI * 0.25
			"ruins":
				# ruínas jesuíticas em arenito vermelho, com arcos
				var sand := _haze(Color("#b0634a"))
				for k in 5:
					_visual_box(Vector3(x - 10.0 + k * 5.0, 1.5, -32.0), Vector3(1.6, 9.0, 2.0), sand)
					if k < 4:
						_visual_box(Vector3(x - 7.5 + k * 5.0, 5.6, -32.0), Vector3(3.6, 0.8, 1.8), sand.darkened(0.04))
				_visual_box(Vector3(x, 8.3, -32.0), Vector3(22.0, 1.0, 2.2), sand.darkened(0.08))
			"windmills":
				# moinhos de vento de La Mancha numa colina
				var hill := SphereMesh.new()
				hill.radius = 16.0
				hill.height = 32.0
				var hm := _visual_mesh(hill, Vector3(x, -10.0, -36.0), _haze(_grass_color().lerp(Color("#b59a5a"), 0.5)))
				hm.scale = Vector3(1.8, 0.6, 1.0)
				for k in 3:
					var w := _place(FT + "windmill.glb", Vector3(x - 12.0 + k * 12.0, -1.0 + (1.6 if k == 1 else 0.0), -36.0 + (k % 2) * 3.0), -0.3 + k * 0.25, Vector3.ONE * 4.5)
					w.rotation.y = PI * 0.1 * (k - 1)


## Mar no horizonte (países do Caribe, Uruguai e Guiné Equatorial) e o canal do Panamá.
func _build_far_water() -> void:
	if world.get("sea", false):
		_water(-120.0, level_end_x + 120.0, -2.9, -38.0, -140.0, Color("#2a7fb2"))
	if world.get("landmark", "") == "ship":
		_water(-120.0, level_end_x + 120.0, -2.9, -37.0, -48.0, Color("#3a7f9c"))
