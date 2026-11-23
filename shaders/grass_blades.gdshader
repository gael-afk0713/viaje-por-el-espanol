shader_type spatial;
render_mode cull_disabled, world_vertex_coords;
// Fios de grama: balançam com o vento e se abrem quando o jogador passa por cima.
// UV.y vai de 0 (raiz) a 1 (ponta). Cada fio é um triângulo (leve para celular/tablet).

uniform vec3 base_color : source_color = vec3(0.12, 0.25, 0.06);
uniform vec3 tip_color : source_color = vec3(0.45, 0.62, 0.2);
uniform vec3 player_pos = vec3(0.0, -100.0, 0.0);
uniform float wind_strength = 0.1;
uniform float push_radius = 0.85;

varying float tint;

void vertex() {
	// com world_vertex_coords, VERTEX já está em coordenadas do mundo
	vec3 root = MODEL_MATRIX[3].xyz;
	float k = UV.y;

	// vento: ondas que passam pelo campo
	float gust = sin(TIME * 0.9 + root.x * 0.25) * 0.5 + 0.5;
	float w = sin(TIME * 2.2 + root.x * 0.8 + root.z * 0.5) * (0.5 + gust) + sin(TIME * 4.1 + root.x * 2.3) * 0.2;
	vec3 off = vec3(w, 0.0, w * 0.35) * wind_strength;

	// o jogador empurra os fios para os lados
	vec3 to = root - player_pos;
	float dy = abs(to.y + 0.2);
	to.y = 0.0;
	float dist = length(to);
	float push = (1.0 - smoothstep(0.15, push_radius, dist)) * (1.0 - smoothstep(0.6, 1.4, dy));
	vec3 dir = dist > 0.001 ? to / dist : vec3(1.0, 0.0, 0.0);
	off += dir * push * 0.4;
	off.y -= push * 0.18;

	VERTEX += off * k;
	// normal "para cima": a grama recebe a luz igual dos dois lados
	NORMAL = vec3(0.0, 1.0, 0.0);
	tint = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = mix(base_color, tip_color, UV.y * UV.y * 0.6 + UV.y * 0.4);
	c *= 0.8 + 0.4 * tint;
	ALBEDO = c;
	ROUGHNESS = 0.8;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
}
