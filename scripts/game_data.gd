extends RefCounted
## Conteúdo dos 21 países que falam espanhol.
##
## Cada país tem 2 vilas (towns) e 3 moradores (npcs). Os 2 primeiros moradores ficam na
## primeira vila e o terceiro na segunda. Entre as vilas o jogo monta sozinho os desafios
## (buracos, plataformas, monstros...).
##
## Morador: [nome, "f" ou "m", palavra regional, significado em espanhol, significado em
##           português, fala (a palavra regional precisa aparecer nela), extras opcionais]
## extras: {"wheelchair": true} = o morador usa cadeira de rodas
##
## look: [céu topo, céu horizonte, chão, grama/topo, plataforma, cor de destaque,
##        cenário de fundo (cactus/city/palms/mountains/hills), cor do cenário]

const FEMALE_MODELS := ["female-b", "female-c", "female-d", "female-e", "female-f"]
const MALE_MODELS := ["male-a", "male-b", "male-c", "male-d", "male-e", "male-g", "worker"]

## Palavras com o mesmo significado (usadas para escolher as opções erradas do diálogo).
## Também evita opções ambíguas na pergunta de significado (ex.: «mucho» e «un poquito»
## cabem na mesma frase, então nunca aparecem juntas).
const CONCEPTS := {
	"amigo": "amigo", "hermano": "amigo", "novio": "amigo",
	"niño": "niño", "chico": "niño", "bebé": "niño", "muchacho": "niño", "hijo": "niño",
	"dinero": "dinero", "trabajo": "trabajo", "autobús": "autobus",
	"genial": "genial", "aburrido": "genial", "¡caramba!": "exclamacion", "¡qué frío!": "exclamacion",
	"casa": "casa", "casa de reunión": "casa", "cosa": "cosa",
	"mucho": "cantidad", "un poquito": "cantidad",
	"café": "bebida", "mate frío": "bebida", "termo para el mate": "bebida",
	"pan de mandioca y queso": "comida", "tubérculo comestible": "comida", "sopa picante de pescado": "comida",
	"hondureño": "gentilicio", "puertorriqueño": "gentilicio",
	"¿entiendes?": "muletilla", "de acuerdo": "muletilla",
}

## Países vizinhos que compartilham gírias: não usamos palavras de um como "errada" no outro.
const NEIGHBORS := [
	["argentina", "uruguay", "paraguay"],
	["cuba", "rep_dominicana", "puerto_rico", "venezuela", "panama"],
	["guatemala", "honduras", "el_salvador", "nicaragua", "costa_rica"],
	["colombia", "venezuela", "ecuador", "panama"],
	["peru", "bolivia", "ecuador", "chile"],
]


static func get_countries() -> Array:
	var list := [
		_c("mexico", "México", "Norteamérica", ["Oaxaca", "Ciudad de México"],
			"Sotaque mexicano: entonação «cantada» e consoantes bem pronunciadas. O X de «México» soa como J.",
			"É o país com mais falantes de espanhol do mundo: mais de 120 milhões!",
			["#3f8fd6", "#f6c27a", "#b8653a", "#e9b44c", "#e8a33d", "#1f9e5a", "cactus", "#2f8f4e"],
			"v", ["#006847", "#ffffff", "#ce1126"], "", [
			["Lupita", "f", "chamba", "trabajo", "trabalho", "¡Órale! Hoy tengo un montón de chamba en el mercado."],
			["Don Beto", "m", "chido", "genial", "legal, bacana", "¡Qué chido que viniste a visitarnos, joven!"],
			["Memo", "m", "cuate", "amigo", "amigo", "Ese de ahí es mi cuate. Jugamos fútbol cada domingo."],
		]),
		_c("guatemala", "Guatemala", "Centroamérica", ["Antigua", "Ciudad de Guatemala"],
			"Sotaque guatemalteco: fala calma, R bem marcado e muito uso do «vos».",
			"Além do espanhol, na Guatemala se falam mais de 20 línguas maias!",
			["#3a8fd0", "#e8f0d0", "#5a3d2a", "#5fae4e", "#7fb6e0", "#2a6fb0", "mountains", "#4a6b5a"],
			"v", ["#4997D0", "#ffffff", "#4997D0"], "", [
			["Ana Lucía", "f", "chilero", "genial", "legal, bacana", "¡Qué chilero tu sombrero, vos!"],
			["Don Chepe", "m", "patojo", "niño", "menino, criança", "Ese patojo corre rapidísimo por el mercado."],
			["Doña Tina", "f", "pisto", "dinero", "dinheiro", "No traigo pisto para comprar tortillas."],
		]),
		_c("honduras", "Honduras", "Centroamérica", ["Copán", "Tegucigalpa"],
			"Sotaque hondurenho: «aspira» o S («ehto» em vez de «esto») e usa «vos» com os amigos.",
			"Os hondurenhos são chamados carinhosamente de «catrachos».",
			["#2ea0dc", "#d8f3ff", "#6b4b2f", "#56b04a", "#5fd0ee", "#0073a8", "palms", "#2e8b57"],
			"h", ["#00BCE4", "#ffffff", "#00BCE4"], "", [
			["Kevin", "m", "alero", "amigo", "amigo", "Él es mi alero desde que éramos chiquitos."],
			["Doña Lety", "f", "cipote", "niño", "menino, criança", "¡Ese cipote ya sabe leer y escribir!"],
			["Marvin", "m", "catracho", "hondureño", "hondurenho", "¡Soy catracho de corazón, vos!"],
		]),
		_c("el_salvador", "El Salvador", "Centroamérica", ["Santa Ana", "San Salvador"],
			"Sotaque salvadorenho: rápido e cantado, «aspira» o S e usa «vos».",
			"As pupusas (tortilhas recheadas) são o prato nacional e têm até um dia de comemoração!",
			["#3b7fd0", "#f0e6c8", "#5c3b26", "#6aaa48", "#7aa6e8", "#0F47AF", "mountains", "#556b5a"],
			"h", ["#0F47AF", "#ffffff", "#0F47AF"], "", [
			["Karla", "f", "chivo", "genial", "legal, bacana", "¡Qué chivo está el partido de hoy!"],
			["Don Toño", "m", "chero", "amigo", "amigo", "Vamos, chero, que se hace tarde."],
			["Doña Mila", "f", "bicho", "niño", "menino, criança", "Ese bicho ya sabe andar en bicicleta."],
		]),
		_c("nicaragua", "Nicaragua", "Centroamérica", ["Granada", "Managua"],
			"Sotaque nicaraguense: usa «vos» o tempo todo e «aspira» o S no fim das palavras.",
			"A Nicarágua tem o maior lago da América Central, com tubarões de água doce!",
			["#3592d8", "#e2f2ff", "#6a4a30", "#69b84e", "#6aa9e8", "#0067C6", "hills", "#4f9a3e"],
			"h", ["#0067C6", "#ffffff", "#0067C6"], "", [
			["Ernesto", "m", "chavalo", "muchacho", "garoto, rapaz", "Ese chavalo juega béisbol todas las tardes."],
			["Doña Chayo", "f", "chunche", "cosa", "coisa, treco", "Pasame ese chunche que está en la mesa."],
			["Yeri", "f", "tuani", "genial", "legal, bacana", "¡Qué tuani está tu casa nueva!"],
		]),
		_c("costa_rica", "Costa Rica", "Centroamérica", ["Limón", "San José"],
			"Sotaque costarriquenho: o R é suave e «arrastado», e usam muito «usted».",
			"«Pura vida» é o lema dos ticos: serve para oi, tchau, obrigado e tudo bem!",
			["#2b9bd6", "#e0f7e8", "#4a3424", "#3fae5a", "#e45a6a", "#002B7F", "hills", "#2f8f4e"],
			"h", ["#002B7F", "#ffffff", "#CE1126", "#CE1126", "#ffffff", "#002B7F"], "", [
			["Diego", "m", "mae", "amigo", "cara, mano", "¡Diay, mae! ¿Todo bien?"],
			["Sofía", "f", "pura vida", "genial", "tudo de bom", "¡Pura vida! Aquí todo está tranquilo."],
			["Don Rafa", "m", "brete", "trabajo", "trabalho", "Mañana tengo mucho brete en la finca."],
		]),
		_c("panama", "Panamá", "Centroamérica", ["Colón", "Ciudad de Panamá"],
			"Sotaque panamenho: rápido, «engole» o S e mistura palavras do inglês por causa do Canal.",
			"O Canal do Panamá liga os oceanos Atlântico e Pacífico.",
			["#2aa5e0", "#dff4ff", "#5d4530", "#5cb85c", "#f0c64a", "#D21034", "palms", "#2e8b57"],
			"h", ["#ffffff", "#D21034"], "#005293", [
			["Yaritza", "f", "buco", "mucho", "muito", "¡Hay buco de gente en la playa hoy!"],
			["Don Chalo", "m", "pelao", "niño", "menino, criança", "Ese pelao es muy inteligente."],
			["Iván", "m", "chantin", "casa", "casa", "Vamos pa' mi chantin a ver el partido."],
		]),
		_c("cuba", "Cuba", "Caribe", ["Trinidad", "La Habana"],
			"Sotaque cubano: «engolem» o S no fim das sílabas e às vezes trocam R por L: «¿cómo estás?» vira «¿cómo ehtá?».",
			"Em Cuba e em Porto Rico, ônibus é «guagua»; na Argentina é «bondi»: a mesma coisa, palavras diferentes!",
			["#1e9ad6", "#c9f0ff", "#c2a878", "#f3e2b3", "#ff8fab", "#002a8f", "palms", "#2e8b57"],
			"h", ["#002a8f", "#ffffff", "#002a8f", "#ffffff", "#002a8f"], "#cf142b", [
			["Yuni", "m", "asere", "amigo", "amigo", "¡Asere! ¿Qué bolá? ¿Todo bien, mi hermano?"],
			["Papo", "m", "guagua", "autobús", "ônibus", "La guagua pa' La Habana viene llenita, ¿oíte?"],
			["Abuela Caridad", "f", "guajiro", "campesino", "camponês", "Mi esposo es guajiro: trabaja en el campo desde niño."],
		]),
		_c("rep_dominicana", "República Dominicana", "Caribe", ["Puerto Plata", "Santo Domingo"],
			"Sotaque dominicano: corta o fim das palavras e às vezes troca R por I: «por favor» vira «poi favoi».",
			"Em Santo Domingo fica a primeira catedral construída nas Américas.",
			["#22a2db", "#d9f5ff", "#c2a878", "#f3e2b3", "#5ec4e8", "#CE1126", "palms", "#2e8b57"],
			"h", ["#002D62", "#ffffff", "#CE1126"], "", [
			["Juan Carlos", "m", "vaina", "cosa", "coisa, treco", "¡Qué vaina tan buena es este merengue!"],
			["Doña Fefa", "f", "chin", "un poquito", "um pouquinho", "Dame un chin de arroz, mi amor."],
			["Miguelina", "f", "tíguere", "persona astuta", "espertalhão", "Ese muchacho es un tíguere, lo sabe todo."],
		]),
		_c("puerto_rico", "Puerto Rico", "Caribe", ["Ponce", "San Juan"],
			"Sotaque porto-riquenho: troca o R por L no fim das sílabas («puerta» = «puelta») e usa palavras do inglês.",
			"Porto Rico é um território dos Estados Unidos, mas o espanhol é a língua do dia a dia.",
			["#1f9fe0", "#d6f3ff", "#bfa576", "#f1deb0", "#ffb347", "#0050F0", "palms", "#2f9e5f"],
			"h", ["#ED0000", "#ffffff", "#ED0000", "#ffffff", "#ED0000"], "#0050F0", [
			["Coralis", "f", "boricua", "puertorriqueño", "porto-riquenho", "¡Orgullosa de ser boricua!"],
			["Javier", "m", "janguear", "salir a divertirse", "sair, curtir", "Vamos a janguear a la playa, ¿vienes?"],
			["Don Pepe", "m", "chavos", "dinero", "dinheiro", "No tengo chavos pa' la guagua hoy."],
		]),
		_c("colombia", "Colombia", "Sudamérica", ["Medellín", "Bogotá"],
			"Sotaque colombiano (Bogotá): considerado um dos mais claros e pausados. Muita gente usa «usted» até com amigos.",
			"Na Colômbia, «tinto» é cafezinho — mas na Espanha, «tinto» é vinho tinto!",
			["#3aa0d8", "#e6f5d0", "#5a3a22", "#4caf50", "#fcd116", "#003893", "palms", "#2e7d32"],
			"h", ["#fcd116", "#fcd116", "#003893", "#ce1126"], "", [
			["Valentina", "f", "parce", "amigo", "amigo", "¡Quiubo, parce! ¿Cómo me le va?"],
			["Andrés", "m", "chévere", "genial", "legal, bacana", "¡Qué chévere que vino a Medellín!"],
			["Doña Rosa", "f", "tinto", "café", "cafezinho", "¿Le provoca un tinto? ¡El café colombiano es el mejor!"],
		]),
		_c("venezuela", "Venezuela", "Sudamérica", ["Mérida", "Caracas"],
			"Sotaque venezuelano: alegre e cantado, «aspira» o S e usa muito «chamo» e «pana».",
			"O Salto Ángel, na Venezuela, é a cachoeira mais alta do mundo.",
			["#3a9ad8", "#fff2c8", "#6b4a2f", "#7cc142", "#FFCC00", "#00247D", "hills", "#4f9a3e"],
			"h", ["#FFCC00", "#00247D", "#CF142B"], "", [
			["Luis", "m", "chamo", "chico", "garoto", "¡Epa, chamo! ¿Qué más?"],
			["María Gabriela", "f", "pana", "amigo", "amigo", "Tú eres mi pana, vale."],
			["Señor Ramón", "m", "burda", "mucho", "muito", "Esta arepa está burda de buena."],
		]),
		_c("ecuador", "Ecuador", "Sudamérica", ["Cuenca", "Quito"],
			"Sotaque equatoriano (serra): fala calma e bem pronunciada, com diminutivos para tudo: «ahorita», «cafecito».",
			"A linha do Equador passa pelo país: dá para ficar com um pé em cada hemisfério!",
			["#4a90d0", "#eef4ff", "#5a4636", "#8cbf5a", "#FFDD00", "#034EA2", "mountains", "#5f6a72"],
			"h", ["#FFDD00", "#FFDD00", "#034EA2", "#ED1C24"], "", [
			["Mateo", "m", "ñaño", "hermano", "irmão", "Mi ñaño vive en Quito con mi abuela."],
			["Doña Rosario", "f", "achachay", "¡qué frío!", "que frio!", "¡Achachay, qué frío hace en la sierra!"],
			["Daniela", "f", "chuta", "¡caramba!", "nossa!", "¡Chuta, se me olvidó el paraguas!"],
		]),
		_c("peru", "Perú", "Sudamérica", ["Cusco", "Lima"],
			"Sotaque peruano (Lima): claro e pausado, com entonação suave.",
			"Machu Picchu, a cidade inca no alto das montanhas, fica no Peru.",
			["#4a8fd6", "#f3ead8", "#7a5a43", "#b8b36a", "#e9e0cf", "#D91023", "mountains", "#7a6a5c"],
			"v", ["#D91023", "#ffffff", "#D91023"], "", [
			["Renzo", "m", "pata", "amigo", "amigo", "Él es mi pata del colegio."],
			["Doña Gladys", "f", "jato", "casa", "casa", "Vengan a mi jato a comer ceviche."],
			["Valeria", "f", "bacán", "genial", "legal, bacana", "¡Qué bacán está Machu Picchu!"],
		]),
		_c("bolivia", "Bolivia", "Sudamérica", ["Sucre", "La Paz"],
			"Sotaque boliviano (andino): fala pausada e bem pronunciada, com influência do quéchua e do aimará.",
			"La Paz é uma das capitais mais altas do mundo: fica a 3.600 metros de altitude!",
			["#5a9ae0", "#f2ecdc", "#8a6a4a", "#c9b77a", "#F9E300", "#007934", "mountains", "#7c7266"],
			"h", ["#D52B1E", "#F9E300", "#007934"], "", [
			["Don Freddy", "m", "cumpa", "amigo", "amigo", "¡Hola, cumpa! ¿Cómo estás?"],
			["Doña Juana", "f", "wawa", "bebé", "bebê", "La wawa está durmiendo, hablemos bajito."],
			["Rodrigo", "m", "chango", "chico", "garoto", "Ese chango juega muy bien al fútbol."],
		]),
		_c("chile", "Chile", "Sudamérica", ["Valparaíso", "Santiago"],
			"Sotaque chileno: falam bem rápido, «engolem» o S («¿cómo estái?») e põem «po» no fim das frases: «sí, po».",
			"O Chile é o país mais comprido e estreito do mundo: mais de 4.000 km de norte a sul!",
			["#5b8fd6", "#f2e3d0", "#7a5a43", "#a5b46a", "#e8e8e8", "#d52b1e", "mountains", "#6d6a75"],
			"h", ["#ffffff", "#d52b1e"], "#0039a6", [
			["Cata", "f", "cachai", "¿entiendes?", "entendeu?", "Mañana vamos a la playa, ¿cachai?"],
			["Nico", "m", "pololo", "novio", "namorado", "Mi hermana tiene pololo nuevo, ¡se llama Benja, po!"],
			["Tía Marta", "f", "fome", "aburrido", "chato, sem graça", "Este día de lluvia está muy fome, po.", {"wheelchair": true}],
		]),
		_c("argentina", "Argentina", "Cono Sur", ["Córdoba", "Buenos Aires"],
			"Sotaque rioplatense: LL e Y soam como «sh» («calle» = «cashe», «yo» = «sho»). E usam «vos» no lugar de «tú».",
			"Em Buenos Aires, o espanhol tem muita influência do italiano — até na entonação!",
			["#4f9fe0", "#d8ecfa", "#6b4a2f", "#7cc142", "#9fd0f0", "#f2b632", "hills", "#5f9a3e"],
			"h", ["#74acdf", "#ffffff", "#74acdf"], "", [
			["Facu", "m", "laburo", "trabajo", "trabalho", "Che, me voy al laburo. ¿Vos venís conmigo?"],
			["Sofi", "f", "pibe", "chico", "garoto", "¡Mirá a ese pibe! Juega al fútbol como Messi."],
			["Don Tito", "m", "bondi", "autobús", "ônibus", "Si vos querés ir al centro, tomá el bondi 152.", {"wheelchair": true}],
		]),
		_c("uruguay", "Uruguay", "Cono Sur", ["Colonia", "Montevideo"],
			"Sotaque uruguaio: parecido com o argentino («sh» no LL e no Y e uso do «vos»), mas muitos misturam com «tú».",
			"No Uruguai se toma mate em todo lugar: na rua, no ônibus, na praia!",
			["#5aa7e6", "#e4f2fb", "#6b4a2f", "#86c34f", "#9fc8f0", "#0038A8", "hills", "#5f9a3e"],
			"h", ["#ffffff", "#0038A8", "#ffffff", "#0038A8", "#ffffff"], "#FCD116", [
			["Santi", "m", "botija", "hijo", "filho", "Mi botija ya va a la escuela solito."],
			["Florencia", "f", "termo", "termo para el mate", "garrafa térmica", "Nunca salgo sin el termo y el mate."],
			["Don Nelson", "m", "gurí", "niño", "menino, guri", "El gurí juega al fútbol todo el día."],
		]),
		_c("paraguay", "Paraguay", "Cono Sur", ["Encarnación", "Asunción"],
			"Sotaque paraguaio: o espanhol se mistura com o guarani — muita gente usa as duas línguas na mesma frase.",
			"O Paraguai tem duas línguas oficiais: espanhol e guarani.",
			["#4a9ee0", "#f6efd8", "#a0522d", "#8fbf4a", "#f4d03f", "#0038A8", "hills", "#5f8f3a"],
			"h", ["#D52B1E", "#ffffff", "#0038A8"], "", [
			["Ramona", "f", "tereré", "mate frío", "chimarrão gelado", "¿Tomamos un tereré? ¡Hace mucho calor!"],
			["Don Blas", "m", "mitaí", "niño", "menino, criança", "Ese mitaí es muy travieso."],
			["Lorena", "f", "chipá", "pan de mandioca y queso", "pão de queijo de mandioca", "¡La chipá de mi abuela es la más rica del pueblo!"],
		]),
		_c("espana", "España", "Europa", ["Sevilla", "Madrid"],
			"Sotaque espanhol: o Z e o C antes de E/I soam como o «th» do inglês («gracias» = «grathias»). E usam «vosotros» com amigos.",
			"O espanhol nasceu aqui, em Castela — por isso também é chamado de «castellano».",
			["#2b6cb0", "#ffd27f", "#9c3d2a", "#e0a458", "#f3c13a", "#c8102e", "city", "#e8d5b7"],
			"h", ["#aa151b", "#f1bf00", "#f1bf00", "#aa151b"], "", [
			["Lucía", "f", "guay", "genial", "legal, bacana", "¡Qué guay que estéis aquí! ¿Os gusta Madrid?"],
			["Pablo", "m", "vale", "de acuerdo", "ok, combinado", "¿Quedamos a las seis en la plaza? ¡Vale, hasta luego!"],
			["Javi", "m", "tío", "amigo", "cara, mano", "¡Tío, este juego mola mogollón!"],
		]),
		_c("guinea", "Guinea Ecuatorial", "África", ["Bata", "Malabo"],
			"Sotaque equato-guineense: o espanhol convive com línguas africanas como o fang e o bubi; a pronúncia é clara e o R bem marcado.",
			"É o único país da África onde o espanhol é língua oficial!",
			["#2f9bd6", "#e6f7e0", "#6b3e26", "#3f9e4a", "#f2c14e", "#0073CE", "palms", "#2e7d32"],
			"h", ["#3E9A00", "#ffffff", "#E32118"], "#0073CE", [
			["Esperanza", "f", "malanga", "tubérculo comestible", "taioba", "Hoy comemos malanga con pescado."],
			["Don Ignacio", "m", "abaá", "casa de reunión", "casa comunitária", "En el abaá la comunidad se reúne para hablar."],
			["Pilar", "f", "pepesup", "sopa picante de pescado", "sopa apimentada de peixe", "¡El pepesup de mi madre es el mejor de Malabo!"],
		]),
	]
	return list


static func _c(id: String, name: String, region: String, towns: Array, sotaque: String, fact: String,
		look: Array, flag_dir: String, flag: Array, canton: String, npcs: Array) -> Dictionary:
	var d := {
		"id": id, "name": name, "region": region, "towns": towns,
		"sotaque": sotaque, "fact": fact,
		"sky_top": look[0], "sky_horizon": look[1], "ground": look[2], "top": look[3],
		"platform": look[4], "accent": look[5], "deco": look[6], "deco_color": look[7],
		"flag_dir": flag_dir, "flag": flag, "npcs": [],
	}
	if canton != "":
		d["flag_canton"] = canton
	for n in npcs:
		var npc := {
			"name": n[0], "word": n[2], "es": n[3], "pt": n[4], "line": n[5],
			"model": _pick(FEMALE_MODELS if n[1] == "f" else MALE_MODELS, n[0]),
			"pitch": (1.2 if n[1] == "f" else 0.82) + float(absi(hash(n[0])) % 20) / 100.0,
		}
		if n.size() > 6:
			npc.merge(n[6])
		d["npcs"].append(npc)
	return d


static func _pick(pool: Array, key: String) -> String:
	return pool[absi(hash(key)) % pool.size()]


static func are_neighbors(a: String, b: String) -> bool:
	for group in NEIGHBORS:
		if group.has(a) and group.has(b):
			return true
	return false
