shader_type spatial;
// Chão: grama no topo (com uma "franja" que desce pela lateral) e terra nos lados.
// O topo tem relevo (montinhos), mais suave no caminho do jogador e mais alto ao fundo.
// As texturas (ambientCG, CC0) dão o detalhe sobre as cores de cada país.
// Tudo é calculado em coordenadas do mundo, então blocos vizinhos se emendam sem costura.
// IMPORTANTE: relief_h() precisa ser igual a _height() em level.gd (plantas e fios de grama usam).

uniform sampler2D top_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D side_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D top_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D side_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 top_color : source_color = vec3(0.3, 0.5, 0.2);
uniform vec3 side_color : source_color = vec3(0.45, 0.3, 0.2);
uniform float top_detail = 0.8;    // 0 = cor lisa, 1 = textura forte
uniform float side_detail = 0.75;
uniform float top_scale = 0.22;
uniform float side_scale = 0.3;
uniform float lip = 0.1;           // quanto a grama desce pela lateral
uniform float normal_depth = 0.5;
uniform float relief = 0.55;       // altura dos montinhos ao fundo
uniform float path_relief = 0.07;  // altura no caminho do jogador

varying vec3 wpos;
varying vec3 wnrm;
varying float top_y;

float relief_h(vec2 p) {
	float n = 0.5 * sin(p.x * 0.9 + sin(p.y * 0.7) * 1.3)
		+ 0.3 * sin(p.x * 2.3 + p.y * 1.7 + 1.3)
		+ 0.2 * sin(p.y * 1.3 - p.x * 0.6 + 2.0);
	float a = mix(path_relief, relief, 1.0 - smoothstep(-5.0, -1.8, p.y));
	return a * (0.55 + 0.45 * n);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// a malha é um cubo unitário escalado pelo nó: o topo fica em y + metade da escala
	float sy = length(MODEL_MATRIX[1].xyz);
	top_y = MODEL_MATRIX[3].y + 0.5 * sy;
	if (VERTEX.y > 0.499) {
		float h = relief_h(w.xz);
		VERTEX.y += h / sy;
		w.y += h;
		if (NORMAL.y > 0.5) {
			float e = 0.15;
			float dx = (relief_h(w.xz + vec2(e, 0.0)) - relief_h(w.xz - vec2(e, 0.0))) / (2.0 * e);
			float dz = (relief_h(w.xz + vec2(0.0, e)) - relief_h(w.xz - vec2(0.0, e))) / (2.0 * e);
			vec3 nw = normalize(vec3(-dx, 1.0, -dz));
			NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * nw);
		}
	}
	else if (abs(NORMAL.z) > 0.5) {
		// terra das laterais levemente irregular (abaulada), mais perto do topo fica reta
		float depth = top_y - w.y;
		float b = sin(w.x * 1.7 + w.y * 2.1 + w.z) + 0.6 * sin(w.x * 0.6 - w.y * 1.3 + w.z * 0.8);
		float amt = 0.05 * b * smoothstep(0.3, 1.0, depth);
		vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), sy, length(MODEL_MATRIX[2].xyz));
		VERTEX += NORMAL * amt / sc;
		w += normalize(mat3(MODEL_MATRIX) * NORMAL) * amt;
	}
	wpos = w;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// detalhe da textura em volta de 1.0 (clareia/escurece a cor sem trazer as cores da foto)
float detail(sampler2D t, vec2 uv, float amount, float mean) {
	return mix(1.0, lum(texture(t, uv).rgb) / mean, amount);
}

void fragment() {
	bool is_top = wnrm.y > 0.5;
	float d = top_y + relief_h(wpos.xz) - wpos.y;
	vec2 tuv = wpos.xz * top_scale;
	vec2 suv = (abs(wnrm.x) > abs(wnrm.z) ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y)) * side_scale;

	float wave = sin(wpos.x * 3.1 + wpos.z * 2.3) * 0.07 + sin(wpos.x * 8.3 + 1.7) * 0.04;
	float edge = lip + wave;
	float g = is_top ? 1.0 : 1.0 - step(edge, d);

	vec3 grass = top_color * detail(top_tex, is_top ? tuv : suv, top_detail, 0.32);
	// manchas grandes para o topo não ficar repetitivo (grama mais seca / mais verde)
	float patch = sin(wpos.x * 0.37) * sin(wpos.z * 0.53 + 1.0);
	grass *= 0.9 + 0.2 * patch;
	grass = mix(grass, grass * vec3(1.15, 1.05, 0.7), clamp(-patch, 0.0, 1.0) * 0.5);
	grass *= mix(1.0, detail(top_tex, (is_top ? wpos.xz : vec2(wpos.x, wpos.y)) * 0.06, 1.0, 0.32), 0.35);
	// os montinhos ficam um pouco mais claros no alto e mais escuros nos vales
	grass *= 0.9 + 0.35 * clamp(relief_h(wpos.xz) / max(relief, 0.01), 0.0, 1.0);

	vec3 dirt = side_color * detail(side_tex, suv, side_detail, 0.2);
	float layer = fract((d + sin(wpos.x * 0.7 + wpos.z) * 0.25) / 1.7);
	dirt *= layer < 0.5 ? 1.0 : 0.94;
	// sombra logo abaixo da franja de grama e terra mais escura no fundo
	dirt *= mix(0.55, 1.0, smoothstep(edge, edge + 0.35, d));
	dirt *= mix(1.0, 0.7, smoothstep(1.5, 7.0, d));
	grass *= is_top ? 1.0 : mix(1.0, 0.8, smoothstep(edge - 0.12, edge, d));

	ALBEDO = mix(dirt, grass, g);
	vec3 nm = is_top ? texture(top_nrm, tuv).rgb : mix(texture(side_nrm, suv).rgb, texture(top_nrm, suv).rgb, g);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = 0.95;
}
