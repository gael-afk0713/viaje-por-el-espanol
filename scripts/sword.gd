extends RefCounted
## Espada longa feita só com malhas do Godot (sem arquivo de modelo):
## lâmina de dois gumes com sulco central e ponta, guarda com as pontas alargadas,
## cabo enrolado em couro e pomo redondo com a face achatada.
##
## Medidas em metros "de mundo". Eixo +Y = direção da lâmina; a origem fica no meio
## do cabo (onde a mão segura). Eixo X = largura da lâmina; Z = espessura.

const STEEL := Color("#b9c2cc")
const STEEL_EDGE := Color("#f6f8fb")
const STEEL_DARK := Color("#8d96a1")
const LEATHER := Color("#4b2e1e")
const LEATHER_DARK := Color("#33200f")

const GRIP_HALF := 0.1          # metade do comprimento do cabo
const GUARD_Y := 0.118          # centro da guarda
const BLADE_BASE := 0.135       # onde a lâmina começa
const BLADE_LEN := 0.8
const BLADE_W := 0.088
const BLADE_T := 0.02


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Espada"
	var steel := _mat(STEEL, 0.7, 0.38)
	var steel_dark := _mat(STEEL_DARK, 0.6, 0.35)
	var leather := _mat(LEATHER, 0.0, 0.85)
	var cord := _mat(LEATHER_DARK, 0.0, 0.9)

	# lâmina
	_add(root, _blade_mesh(), steel, Vector3.ZERO)

	# guarda (vista de frente: barra que alarga nas pontas, cortadas em ângulo)
	var guard := [
		Vector2(-0.172, 0.0), Vector2(-0.165, -0.024), Vector2(-0.132, -0.013),
		Vector2(0.132, -0.013), Vector2(0.165, -0.024), Vector2(0.172, 0.0),
		Vector2(0.165, 0.024), Vector2(0.132, 0.013), Vector2(-0.132, 0.013),
		Vector2(-0.165, 0.024),
	]
	_add(root, _prism(guard, 0.036), steel_dark, Vector3(0, GUARD_Y, 0))
	# reforço no centro da guarda
	var chape := BoxMesh.new()
	chape.size = Vector3(0.05, 0.044, 0.044)
	_add(root, chape, steel_dark, Vector3(0, GUARD_Y - 0.004, 0))

	# cabo de couro com o cordão enrolado
	var grip := CylinderMesh.new()
	grip.top_radius = 0.021
	grip.bottom_radius = 0.023
	grip.height = GRIP_HALF * 2.0
	grip.radial_segments = 10
	grip.rings = 1
	_add(root, grip, leather, Vector3.ZERO)
	for i in 9:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.019
		ring.outer_radius = 0.0265
		ring.rings = 12
		ring.ring_segments = 5
		_add(root, ring, cord, Vector3(0, -GRIP_HALF + 0.012 + i * 0.022, 0))

	# pomo redondo, achatado dos lados, com o disco na face (como nas espadas medievais)
	var pommel := SphereMesh.new()
	pommel.radius = 0.042
	pommel.height = 0.084
	pommel.radial_segments = 14
	pommel.rings = 8
	var pm := _add(root, pommel, steel_dark, Vector3(0, -GRIP_HALF - 0.036, 0))
	pm.scale = Vector3(1.0, 1.0, 0.78)
	for side in [-1.0, 1.0]:
		var disc := CylinderMesh.new()
		disc.top_radius = 0.024
		disc.bottom_radius = 0.026
		disc.height = 0.008
		disc.radial_segments = 14
		var d := _add(root, disc, steel, Vector3(0, -GRIP_HALF - 0.036, side * 0.031))
		d.rotation_degrees.x = 90.0
	return root


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.metallic_specular = 0.45
	return m


## Seção da lâmina: hexágono com o sulco (fuller) cavado no meio das duas faces.
## fuller = 0 (sem sulco) .. 1 (sulco inteiro).
static func _section(w: float, t: float, fuller: float) -> PackedVector2Array:
	var f := t * lerpf(0.5, 0.18, fuller)   # profundidade do sulco
	var pts := PackedVector2Array([
		Vector2(-w * 0.5, 0.0), Vector2(-w * 0.3, t * 0.5), Vector2(-w * 0.13, t * 0.5),
		Vector2(-w * 0.07, f), Vector2(w * 0.07, f), Vector2(w * 0.13, t * 0.5),
		Vector2(w * 0.3, t * 0.5), Vector2(w * 0.5, 0.0), Vector2(w * 0.3, -t * 0.5),
		Vector2(w * 0.13, -t * 0.5), Vector2(w * 0.07, -f), Vector2(-w * 0.07, -f),
		Vector2(-w * 0.13, -t * 0.5), Vector2(-w * 0.3, -t * 0.5),
	])
	return pts


static func _blade_mesh() -> ArrayMesh:
	# [altura, largura, espessura, sulco]
	var y0 := BLADE_BASE
	var L := BLADE_LEN
	var secs := [
		[y0, BLADE_W, BLADE_T, 1.0],
		[y0 + L * 0.62, BLADE_W * 0.86, BLADE_T * 0.9, 1.0],
		[y0 + L * 0.74, BLADE_W * 0.8, BLADE_T * 0.85, 0.0],
		[y0 + L * 0.9, BLADE_W * 0.45, BLADE_T * 0.6, 0.0],
		[y0 + L, 0.004, 0.003, 0.0],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # faces retas: o metal brilha em facetas
	var rings: Array = []
	for s in secs:
		var ring := []
		for p in _section(s[1], s[2], s[3]):
			ring.append(Vector3(p.x, s[0], p.y))
		rings.append(ring)
	for r in range(rings.size() - 1):
		var a: Array = rings[r]
		var b: Array = rings[r + 1]
		var n := a.size()
		for i in n:
			var j := (i + 1) % n
			st.add_vertex(a[i]); st.add_vertex(b[i]); st.add_vertex(b[j])
			st.add_vertex(a[i]); st.add_vertex(b[j]); st.add_vertex(a[j])
	# tampa da base (fica escondida na guarda, mas fecha a malha)
	var base: Array = rings[0]
	var c := Vector3(0, y0, 0)
	for i in base.size():
		st.add_vertex(c); st.add_vertex(base[(i + 1) % base.size()]); st.add_vertex(base[i])
	st.generate_normals()
	return st.commit()


## Prisma: um contorno 2D (plano XY) com espessura em Z.
static func _prism(outline: Array, depth: float) -> ArrayMesh:
	var poly := PackedVector2Array(outline)
	var tris := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var h := depth * 0.5
	for k in range(0, tris.size(), 3):
		var a := poly[tris[k]]
		var b := poly[tris[k + 1]]
		var c := poly[tris[k + 2]]
		st.add_vertex(Vector3(a.x, a.y, h)); st.add_vertex(Vector3(b.x, b.y, h)); st.add_vertex(Vector3(c.x, c.y, h))
		st.add_vertex(Vector3(a.x, a.y, -h)); st.add_vertex(Vector3(c.x, c.y, -h)); st.add_vertex(Vector3(b.x, b.y, -h))
	var n := poly.size()
	for i in n:
		var p := poly[i]
		var q := poly[(i + 1) % n]
		st.add_vertex(Vector3(p.x, p.y, h)); st.add_vertex(Vector3(p.x, p.y, -h)); st.add_vertex(Vector3(q.x, q.y, -h))
		st.add_vertex(Vector3(p.x, p.y, h)); st.add_vertex(Vector3(q.x, q.y, -h)); st.add_vertex(Vector3(q.x, q.y, h))
	st.generate_normals()
	return st.commit()
