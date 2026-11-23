extends Node
## Controla o jogo: menu com os 21 países, HUD, conversa com os moradores
## (o jogador responde com a palavra da região), dicionário de palavras desbloqueadas
## (salvo entre partidas), monstros e tela de fim de fase.

const GameData = preload("res://scripts/game_data.gd")
const LevelScript = preload("res://scripts/level.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")

const FlagDraw = preload("res://scripts/ui/flag.gd")
const Airmail = preload("res://scripts/ui/airmail.gd")
const StampFace = preload("res://scripts/ui/stamp_face.gd")
const Postmark = preload("res://scripts/ui/postmark.gd")
const Passport = preload("res://scripts/ui/passport.gd")
const Hearts = preload("res://scripts/ui/hearts.gd")
const F_DISPLAY := preload("res://assets/fonts/AlfaSlabOne-Regular.ttf")
const F_BODY := preload("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf")
const F_BOLD := preload("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf")
const LOGO := preload("res://assets/escola/logo_concept.png")

# paleta "cartão-postal de viagem"
const PAPER := Color("#f4ead5")       # papel creme
const PAPER_2 := Color("#e6d7b6")     # papel pressionado / trilho
const INK := Color("#1d2840")         # tinta azul-marinho (texto principal)
const INK_2 := Color("#55607a")       # texto secundário sobre papel
const STAMP := Color("#b8322a")       # vermelho de carimbo (palavra regional, nomes)
const GREEN := Color("#2f6f34")       # acerto
const NIGHT := Color("#142033")       # fundo do menu / escurecimento
const PAPER_DIM := Color("#d9d2c2")   # texto sobre fundo escuro
const PAPER_FAINT := Color("#a3acbf")
# as mesmas cores em texto, para o BBCode
const C_WORD := "#b8322a"
const C_MUTED := "#55607a"
const C_LOCKED := "#7a7466"
const C_GREEN := "#2f6f34"
const SLOTS := 3
const OLD_SAVE := "user://progreso.cfg"     # save antigo (antes dos 3 slots)
const SETTINGS_PATH := "user://ajustes.cfg"
const TEXT_SPEEDS := {"lenta": 24.0, "normal": 40.0, "rapida": 70.0}

var countries: Array = []
var word_origin := {}          # palavra -> nome do país
var current: Dictionary = {}
var level = null
var level_id := 0
var unlocked := {}             # "pais:palavra" -> true (salvo em disco)
var completed := {}            # id do país -> true (salvo em disco)
var monsters_defeated := 0
var answering := false
var talk_index := -1
var talk_npc: Dictionary = {}     # morador cuja palavra está em jogo nesta conversa
var talk_person: Dictionary = {}  # quem está falando (professor ou "pergunta")
var t_options: Array = []
var t_correct := ""                 # resposta certa da conversa atual
var t_tries := 0                    # erros na conversa atual
var first_try := {}                 # conversas acertadas de primeira nesta fase
var dict_return_to_game := false
var people: Array = []            # moradores da fase atual
var people_done := {}             # índice -> true (conversas concluídas nesta fase)
var choices: Array = []           # desafios "pule na palavra certa"
var choices_done := {}
var album_charges := 1            # consultas ao álbum durante a fase (1 por conversa)
var album_used_in_talk := false
var current_slot := 0          # 1..3 (0 = nenhuma partida aberta)
var type_speed := 40.0
var settings := {"voice": 80.0, "text": "normal", "quality": "auto", "touch": "auto", "fullscreen": false}

const QUIZ_NAMES_F := ["Carmen", "Elena", "Paola", "Ximena", "Isabel", "Camila", "Fernanda", "Gabriela", "Mariana", "Lorena"]
const QUIZ_NAMES_M := ["Jorge", "Pedro", "Carlos", "Miguel", "Tomás", "Raúl", "Héctor", "Emilio", "Joaquín", "Rubén"]
const QUIZ_GREETINGS := [
	"¡Hola, viajero! ¿Ya aprendiste cómo hablamos por aquí?",
	"¡Buenas! A ver si ya hablas como la gente de aquí...",
	"¡Bienvenido! Te tengo una preguntita.",
]

# máquina de escrever
var typing_node = null  # Label ou RichTextLabel
var typing_text := ""
var typing_pos := 0.0
var typing_pitch := 1.0
var typing_done := Callable()
var dlg_token := 0

var ui_root: Control
var menu: Control
var menu_counts := {}          # id do país -> Label
var menu_total: Label
var hud: Control
var hud_label: Label
var hud_flag: Control
var hud_counts := {}           # "Palabras"/"Personas"/"Monstruos" -> Label
var t_place: Label
var end_mark: Control
var title_layer: Control
var title_col: VBoxContainer
var title_margin: MarginContainer
var title_buttons: VBoxContainer
var title_load_btn: Button
var title_place: Label
var title_flag: Control
var slots_layer: Control
var slots_title: Label
var slots_sub: Label
var slots_row: HBoxContainer
var slots_mode := "play"
var settings_layer: Control
var settings_widgets := {}
var _quality_before := "auto"
var toast: PanelContainer
var toast_label: RichTextLabel
var toast_tween: Tween
var dlg: Control
var dlg_name_panel: PanelContainer
var dlg_name: Label
var dlg_line: RichTextLabel
var dlg_info: Label
var talk_layer: Control
var t_name: Label
var t_line: RichTextLabel
var t_ask: Label
var t_feedback: Label
var t_buttons: Array = []
var dict_layer: Control
var dict_title: Label
var dict_body: RichTextLabel
var end_layer: Control
var end_title: Label
var end_body: RichTextLabel
var voice: AudioStreamPlayer
var touch_ui: Control
var hud_hearts: Control
var hurt_tips := 0
var album_btn: Button
var t_album: Button


func _ready() -> void:
	_setup_input()
	countries = GameData.get_countries()
	for c in countries:
		for npc in c["npcs"]:
			word_origin[npc["word"]] = c["name"]
	_migrate_old_save()
	_load_settings()
	_build_audio()
	_build_ui()
	_apply_settings()
	_show_title()


func _process(delta: float) -> void:
	# com os botões de toque na tela, a caixa de diálogo sobe para não ficar por cima deles
	var shift := 170.0 if touch_ui.visible else 0.0
	dlg.offset_top = -210.0 - shift
	dlg.offset_bottom = -20.0 - shift

	if typing_node == null:
		return
	var before := int(typing_pos)
	typing_pos += type_speed * delta
	var now := mini(int(typing_pos), typing_text.length())
	for i in range(before, now):
		var ch := typing_text[i]
		if i % 2 == 0 and ch != " ":
			_blip(ch)
	typing_node.visible_characters = now
	if now >= typing_text.length():
		typing_node.visible_characters = -1
		typing_node = null
		var cb := typing_done
		typing_done = Callable()
		if cb.is_valid():
			cb.call()


# ---------------------------------------------------------------- progresso salvo

func _key(country_id: String, word: String) -> String:
	return country_id + ":" + word


func _slot_path(slot: int) -> String:
	return "user://partida_%d.cfg" % slot


## Quem jogou a versão antiga (um save só) encontra o progresso na Partida 1.
func _migrate_old_save() -> void:
	if FileAccess.file_exists(OLD_SAVE) and not FileAccess.file_exists(_slot_path(1)):
		DirAccess.rename_absolute(OLD_SAVE, _slot_path(1))


func _load_progress(slot: int) -> void:
	current_slot = slot
	unlocked = {}
	completed = {}
	var cfg := ConfigFile.new()
	if cfg.load(_slot_path(slot)) != OK:
		return
	for k in cfg.get_section_keys("palabras") if cfg.has_section("palabras") else []:
		unlocked[k] = true
	for k in cfg.get_section_keys("paises") if cfg.has_section("paises") else []:
		completed[k] = true


func _save_progress() -> void:
	if current_slot <= 0:
		return
	var cfg := ConfigFile.new()
	for k in unlocked.keys():
		cfg.set_value("palabras", k, true)
	for k in completed.keys():
		cfg.set_value("paises", k, true)
	cfg.set_value("info", "ultima_vez", int(Time.get_unix_time_from_system()))
	if not current.is_empty():
		cfg.set_value("info", "ultimo_pais", current["id"])
	cfg.save(_slot_path(current_slot))


## Resumo de um slot para a tela de partidas.
func _slot_info(slot: int) -> Dictionary:
	var info := {"exists": false, "words": 0, "done": {}, "last": 0, "last_country": ""}
	var cfg := ConfigFile.new()
	if cfg.load(_slot_path(slot)) != OK:
		return info
	info["exists"] = true
	info["words"] = cfg.get_section_keys("palabras").size() if cfg.has_section("palabras") else 0
	for k in cfg.get_section_keys("paises") if cfg.has_section("paises") else []:
		info["done"][k] = true
	info["last"] = cfg.get_value("info", "ultima_vez", 0)
	info["last_country"] = cfg.get_value("info", "ultimo_pais", "")
	return info


func _any_save() -> bool:
	for i in range(1, SLOTS + 1):
		if FileAccess.file_exists(_slot_path(i)):
			return true
	return false


func _delete_slot(slot: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path(slot)))
	if slot == current_slot:
		current_slot = 0


# ---------------------------------------------------------------- configurações

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cfg.get_value("ajustes", k, settings[k])


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("ajustes", k, settings[k])
	cfg.save(SETTINGS_PATH)


func _apply_settings() -> void:
	var v: float = settings["voice"]
	voice.volume_db = -80.0 if v <= 0.0 else linear_to_db(v / 100.0) - 6.0
	type_speed = TEXT_SPEEDS.get(settings["text"], 40.0)
	LevelScript.quality_mode = settings["quality"]
	TouchControls.mode = settings["touch"]
	if touch_ui != null:
		touch_ui.apply_mode()
	if not OS.has_feature("mobile"):
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)


func _count_unlocked(c: Dictionary) -> int:
	var n := 0
	for npc in c["npcs"]:
		if unlocked.has(_key(c["id"], npc["word"])):
			n += 1
	return n


func _total_words() -> int:
	var n := 0
	for c in countries:
		n += c["npcs"].size()
	return n


# ---------------------------------------------------------------- voz ("balbucio")

func _build_audio() -> void:
	var rate := 22050
	var n := int(rate * 0.065)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 45.0) * minf(1.0, t * 500.0)
		var s := (sin(TAU * 330.0 * t) + 0.5 * sin(TAU * 660.0 * t) + 0.3 * signf(sin(TAU * 330.0 * t))) * 0.3 * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	voice = AudioStreamPlayer.new()
	voice.stream = wav
	voice.volume_db = -6.0
	add_child(voice)


func _blip(ch: String) -> void:
	var vowel := "aeiouáéíóú".contains(ch.to_lower())
	voice.pitch_scale = typing_pitch * (0.9 + float(ch.unicode_at(0) % 5) * 0.06) * (1.12 if vowel else 1.0)
	voice.play()


func _type(node, plain: String, pitch: float, done := Callable()) -> void:
	if typing_node != null and typing_node != node:
		typing_node.visible_characters = -1
	typing_node = node
	typing_text = plain
	typing_pos = 0.0
	typing_pitch = pitch
	typing_done = done
	node.visible_characters = 0


# ---------------------------------------------------------------- controles

func _setup_input() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_keys("attack", [KEY_J, KEY_K, KEY_X, KEY_F])
	_add_joy_axis("move_left", -1.0)
	_add_joy_axis("move_right", 1.0)
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	InputMap.action_add_event("jump", jb)
	var jx := InputEventJoypadButton.new()
	jx.button_index = JOY_BUTTON_X
	InputMap.action_add_event("attack", jx)


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode
	if dict_layer.visible:
		if key == KEY_ESCAPE or key == KEY_TAB or key == KEY_I:
			_close_dictionary()
		return
	if settings_layer.visible or slots_layer.visible:
		if key == KEY_ESCAPE:
			_close_overlays()
		return
	if title_layer.visible:
		return
	if key == KEY_TAB or key == KEY_I:
		if talk_layer.visible:
			_open_album_in_talk()
		elif level != null and hud.visible:
			_open_album_from_hud()
		else:
			_open_dictionary()
	elif key == KEY_ESCAPE and menu.visible:
		_show_title()
	elif key == KEY_ESCAPE and level != null and hud.visible and not talk_layer.visible:
		# (no meio de uma conversa o Esc não tira a criança da fase sem querer)
		_show_menu()
	elif answering:
		match key:
			KEY_1, KEY_KP_1:
				_on_answer(0)
			KEY_2, KEY_KP_2:
				_on_answer(1)
			KEY_3, KEY_KP_3:
				_on_answer(2)


# ---------------------------------------------------------------- fluxo do jogo

func _hide_all() -> void:
	for layer in [menu, hud, dlg, talk_layer, dict_layer, end_layer, toast, title_layer, slots_layer, settings_layer]:
		layer.visible = false


func _show_menu() -> void:
	_clear_level()
	answering = false
	typing_node = null
	_refresh_menu()
	_hide_all()
	menu.visible = true
	hud.visible = false
	dlg.visible = false
	talk_layer.visible = false
	dict_layer.visible = false
	end_layer.visible = false
	toast.visible = false


func _clear_level() -> void:
	if level != null and is_instance_valid(level):
		# sai da árvore já: assim o chão antigo não empurra o jogador da fase nova
		if level.get_parent():
			level.get_parent().remove_child(level)
		level.queue_free()
	level = null


func _start_level(c: Dictionary) -> void:
	_clear_level()
	_hide_all()
	level_id += 1
	current = c
	monsters_defeated = 0
	answering = false
	typing_node = null

	people = _prepare_people(c)
	people_done = {}
	first_try = {}
	choices = _prepare_choices(c)
	choices_done = {}
	album_charges = 1

	level = Node3D.new()
	level.set_script(LevelScript)
	level.setup(c, people, choices)
	level.npc_talked.connect(_on_npc_talked)
	level.choice_landed.connect(_on_choice_landed)
	level.monster_defeated.connect(_on_monster_defeated)
	level.player_hurt.connect(_on_player_hurt)
	level.player_died.connect(func() -> void:
		_update_hearts()
		_show_toast("[center]¡Sin corazones! Vuelves al último punto seguro.[/center]", 2.5))
	level.hp_changed.connect(_update_hearts)
	level.goal_reached.connect(_on_goal_reached)
	level.player_fell.connect(func() -> void: _show_toast("[center]¡Ups! Volviste al último punto seguro.[/center]", 2.0))
	add_child(level)

	menu.visible = false
	end_layer.visible = false
	talk_layer.visible = false
	dict_layer.visible = false
	dlg.visible = false
	hud.visible = true
	_update_hud()
	_show_toast("[center][font=res://assets/fonts/AlfaSlabOne-Regular.ttf][font_size=30]%s[/font_size][/font]\n[color=%s]%s[/color][/center]" % [c["name"], C_MUTED, c["sotaque"]], 7.0)


func _update_hearts() -> void:
	if level != null and level.player != null:
		hud_hearts.set_hp(level.player.hp, level.player.MAX_HP)


func _on_player_hurt() -> void:
	_update_hearts()
	# as duas primeiras vezes, lembra como lutar
	if hurt_tips < 2:
		hurt_tips += 1
		var key := "ATACAR" if touch_ui.active else "J"
		_show_toast("[center]¡Ay! Golpea con la espada ([b]%s[/b]) o salta [b]encima[/b] del monstruo.[/center]" % key, 2.6)


func _update_hud() -> void:
	_update_hearts()
	hud_label.text = current["name"]
	hud_flag.set_country(current)
	hud_counts["Palabras"].text = "%d/%d" % [_count_unlocked(current), current["npcs"].size()]
	hud_counts["Personas"].text = "%d/%d" % [people_done.size(), people.size()]
	hud_counts["Monstruos"].text = "%d/%d" % [monsters_defeated, level.monster_count if level != null else 0]
	album_btn.text = "Álbum · %d" % album_charges
	album_btn.disabled = album_charges <= 0


## Moradores da fase: os 3 "professores" (ensinam uma palavra) e 3 moradores que
## perguntam palavras do país. Vila 1: professor 0, professor 1, pergunta (palavra 0).
## Vila 2: pergunta (palavra 1), professor 2, pergunta (palavra 2).
func _prepare_people(c: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(c["id"]) + 99
	var npcs: Array = c["npcs"]
	var list: Array = []
	var plan := [
		["teach", 0, 0, 9.0], ["teach", 1, 0, 19.0], ["quiz", 0, 0, 29.0],
		["quiz", 1, 1, 8.0], ["teach", 2, 1, 18.0], ["quiz", 2, 1, 29.0],
	]
	var used_names := {}
	for n in npcs:
		used_names[n["name"]] = true
	for p in plan:
		var word_npc: Dictionary = npcs[p[1]]
		var data: Dictionary
		if p[0] == "teach":
			data = word_npc
		else:
			var female := rng.randf() < 0.5
			var pool: Array = QUIZ_NAMES_F if female else QUIZ_NAMES_M
			var qname: String = pool[rng.randi() % pool.size()]
			while used_names.has(qname):
				qname = pool[rng.randi() % pool.size()]
			used_names[qname] = true
			var models: Array = GameData.FEMALE_MODELS if female else GameData.MALE_MODELS
			data = {
				"name": qname, "model": models[rng.randi() % models.size()],
				"pitch": (1.2 if female else 0.85) + rng.randf() * 0.2,
				"line": QUIZ_GREETINGS[rng.randi() % QUIZ_GREETINGS.size()],
			}
		list.append({"kind": p[0], "word_index": p[1], "village": p[2], "slot": p[3], "data": data})
	return list


## Desafios de plataforma: testam as palavras 0 e 1 (ensinadas na vila 1).
func _prepare_choices(c: Dictionary) -> Array:
	var list: Array = []
	for wi in [0, 1]:
		var npc: Dictionary = c["npcs"][wi]
		var saved := current
		current = c
		var wrong: Array = _distractors(npc, 1)
		current = saved
		list.append({"word_index": wi, "es": npc["es"], "pt": npc["pt"], "correct": npc["word"],
			"wrong": wrong[0] if wrong.size() > 0 else "???"})
	return list


func _on_choice_landed(index: int, correct: bool) -> void:
	var ch: Dictionary = choices[index]
	if correct:
		if not choices_done.has(index):
			choices_done[index] = true
			var npc: Dictionary = current["npcs"][ch["word_index"]]
			unlocked[_key(current["id"], npc["word"])] = true
			_save_progress()
			_update_hud()
		_show_toast("[center][b][color=%s]¡Correcto![/color][/b]  [b][color=%s]%s[/color][/b] = %s · [color=%s]%s[/color][/center]" % [C_GREEN, C_WORD, ch["correct"], ch["es"], C_MUTED, ch["pt"]], 3.0)
	else:
		_show_toast("[center]«[b]%s[/b]» se dice en %s, no aquí. [color=%s]Tente a outra![/color][/center]" % [ch["wrong"], word_origin.get(ch["wrong"], "?"), C_MUTED], 3.0)


func _on_monster_defeated() -> void:
	monsters_defeated += 1
	_update_hud()


func _highlight(line: String, word: String) -> String:
	var re := RegEx.create_from_string("(?i)(?<!\\p{L})" + word + "(?!\\p{L})")
	return re.sub(line, "[color=" + C_WORD + "][b]$0[/b][/color]", true)


func _hide_toast() -> void:
	if toast_tween:
		toast_tween.kill()
	toast.visible = false


## Chegou perto de um morador.
## Conversa ainda não concluída → conversa com resposta.
## Já concluída → só um balão rápido, sem parar o jogo.
func _on_npc_talked(index: int) -> void:
	if talk_layer.visible:
		return
	var person: Dictionary = people[index]
	level.get_npc(index).talk()
	_hide_toast()
	if people_done.has(index):
		_show_bubble(person)
	else:
		_open_talk(index)


func _show_bubble(person: Dictionary) -> void:
	var data: Dictionary = person["data"]
	var npc: Dictionary = current["npcs"][person["word_index"]]
	dlg_name.text = data["name"]
	if person["kind"] == "teach":
		dlg_line.text = _highlight(data["line"], npc["word"])
	else:
		dlg_line.text = "¡Gracias por la charla! Sigue adelante, viajero."
	dlg_info.text = ""
	dlg.visible = true
	dlg_token += 1
	var my_token := dlg_token
	_type(dlg_line, dlg_line.get_parsed_text(), data["pitch"], func() -> void:
		if person["kind"] == "teach":
			dlg_info.text = "Já está no seu álbum:  %s = %s" % [npc["word"], npc["pt"]]
		else:
			dlg_info.text = ""
		await get_tree().create_timer(4.0).timeout
		if my_token == dlg_token:
			dlg.visible = false)


func _open_talk(index: int) -> void:
	talk_index = index
	talk_person = people[index]
	talk_npc = current["npcs"][talk_person["word_index"]]
	var data: Dictionary = talk_person["data"]
	level.player.frozen = true
	dlg.visible = false
	dlg_token += 1
	album_used_in_talk = false
	t_album.disabled = false
	t_album.text = "Consultar álbum (1 vez)"

	t_tries = 0
	t_name.text = data["name"]
	t_place.text = "%s · %s" % [current["towns"][talk_person["village"]], current["name"]]
	if talk_person["kind"] == "teach":
		# quem ensina usa a palavra na frase; a pergunta é o SIGNIFICADO (sem tradução):
		# é preciso entender a frase, não só copiar a palavra
		t_line.text = _highlight(data["line"], talk_npc["word"])
		t_correct = talk_npc["es"]
		t_options = [t_correct] + _meaning_distractors(talk_npc, 2)
		t_ask.text = "¿Qué quiere decir «%s»?" % talk_npc["word"]
	else:
		# quem pergunta mostra a frase com um espaço vazio e sem dica:
		# as opções são palavras de OUTROS países que querem dizer a mesma coisa
		t_line.text = data["line"]
		t_correct = talk_npc["word"]
		t_options = [t_correct] + _distractors(talk_npc, 2)
		var blank := _blank(talk_npc["line"], talk_npc["word"])
		if blank != "":
			t_ask.text = "Completa como se dice aquí en %s:\n«%s»" % [current["name"], blank]
		else:
			t_ask.text = "¿Cómo se dice «%s» aquí en %s?" % [talk_npc["es"], current["name"]]
	t_options.shuffle()
	t_ask.modulate.a = 0.0
	t_feedback.text = ""
	_fill_answer_buttons()
	for b in t_buttons:
		b.disabled = true
		b.modulate = Color.WHITE
		b.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
		b.add_theme_stylebox_override("disabled", _style(Color("#fffaf0", 0.55), 10, 12, Color(INK, 0.35), 3, false))
	talk_layer.visible = true
	answering = false
	_type(t_line, t_line.get_parsed_text(), data["pitch"], func() -> void:
		create_tween().tween_property(t_ask, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t_feedback.text = "Escolha o significado certo." if talk_person["kind"] == "teach" else "Escolha a palavra que se usa aqui."
		t_feedback.add_theme_color_override("font_color", INK_2)
		for b in t_buttons:
			b.disabled = false
		answering = true)


## Opções erradas: palavras de OUTROS países, de preferência com o mesmo significado
## (ex.: para «chamba» aparecem «laburo» ou «brete»). Países vizinhos que usam as mesmas
## gírias ficam de fora para não confundir.
func _distractors(npc: Dictionary, count: int) -> Array:
	var concept: String = GameData.CONCEPTS.get(npc["es"], "")
	var same: Array = []
	var others: Array = []
	for c in countries:
		if c["id"] == current["id"] or GameData.are_neighbors(c["id"], current["id"]):
			continue
		for other in c["npcs"]:
			var w: String = other["word"]
			if w == npc["word"] or same.has(w) or others.has(w):
				continue
			if concept != "" and GameData.CONCEPTS.get(other["es"], "") == concept:
				same.append(w)
			else:
				others.append(w)
	same.shuffle()
	others.shuffle()
	return (same + others).slice(0, count)


## Significados errados para a pergunta do professor: outros significados do jogo,
## nunca um que caiba na mesma frase (mesmo "conceito" em GameData.CONCEPTS).
func _meaning_distractors(npc: Dictionary, count: int) -> Array:
	var mine: String = GameData.CONCEPTS.get(npc["es"], npc["es"])
	var pool: Array = []
	var used := {mine: true}
	for c in countries:
		for other in c["npcs"]:
			var es: String = other["es"]
			var concept: String = GameData.CONCEPTS.get(es, es)
			if used.has(concept) or es.length() > 16:
				continue
			used[concept] = true
			pool.append(es)
	pool.shuffle()
	return pool.slice(0, count)


## A frase com a palavra regional trocada por um espaço vazio.
func _blank(line: String, word: String) -> String:
	var re := RegEx.create_from_string("(?i)(?<!\\p{L})" + word + "(?!\\p{L})")
	if re.search(line) == null:
		return ""
	return re.sub(line, "_____", true)


func _fill_answer_buttons() -> void:
	for i in t_buttons.size():
		var b: Button = t_buttons[i]
		var txt: String = t_options[i]
		b.text = "%d   %s" % [i + 1, txt]
		# significados compridos ("sopa picante de pescado") cabem com letra menor
		b.add_theme_font_size_override("font_size", 26 if txt.length() <= 14 else (20 if txt.length() <= 18 else 17))


func _on_answer(i: int) -> void:
	if not answering or i >= t_options.size():
		return
	var choice: String = t_options[i]
	var npc_node = level.get_npc(talk_index)
	if choice != t_correct:
		# errou: os botões travam um pouco e as opções trocam de lugar
		# (não dá para sair apertando tudo até acertar)
		t_tries += 1
		answering = false
		npc_node.react_no()
		if talk_person["kind"] == "teach":
			t_feedback.text = "Não é «%s». Releia a frase de %s com calma." % [choice, talk_person["data"]["name"]]
		else:
			t_feedback.text = "«%s» se diz em %s. Aqui é diferente! Dica: consulte o álbum." % [choice, word_origin.get(choice, "outro país")]
		t_feedback.add_theme_color_override("font_color", STAMP)
		for b in t_buttons:
			b.disabled = true
		t_buttons[i].add_theme_stylebox_override("disabled", _style(Color(STAMP, 0.12), 10, 12, STAMP, 3, false))
		var my_level := level_id
		var my_index := talk_index
		await get_tree().create_timer(1.8).timeout
		if my_level != level_id or level == null or not talk_layer.visible or my_index != talk_index:
			return
		t_options.shuffle()
		_fill_answer_buttons()
		for b in t_buttons:
			b.add_theme_stylebox_override("disabled", _style(Color("#fffaf0", 0.55), 10, 12, Color(INK, 0.35), 3, false))
			b.disabled = false
		t_feedback.text = "Tente de novo: as opções mudaram de lugar."
		t_feedback.add_theme_color_override("font_color", INK_2)
		answering = true
		return

	answering = false
	npc_node.react_yes()
	for b in t_buttons:
		b.disabled = true
	# a resposta certa vira "carimbada" de verde
	t_buttons[i].add_theme_stylebox_override("disabled", _style(GREEN, 10, 12, GREEN, 3, false))
	t_buttons[i].add_theme_color_override("font_disabled_color", PAPER)
	var key := _key(current["id"], talk_npc["word"])
	var was_new := not unlocked.has(key)
	unlocked[key] = true
	people_done[talk_index] = true
	if t_tries == 0:
		first_try[talk_index] = true
		album_charges = 1   # acertar de primeira devolve a consulta ao álbum
	_save_progress()
	_update_hud()
	var bonus := "  De primeira!" if t_tries == 0 else ""
	if was_new:
		t_feedback.text = "¡Eso es! Palavra desbloqueada: «%s» = %s (%s).%s" % [talk_npc["word"], talk_npc["es"], talk_npc["pt"], bonus]
	else:
		t_feedback.text = "¡Muy bien! «%s» = %s (%s).%s" % [talk_npc["word"], talk_npc["es"], talk_npc["pt"], bonus]
	t_feedback.add_theme_color_override("font_color", GREEN)

	var my_level := level_id
	await get_tree().create_timer(1.8).timeout
	if my_level != level_id or level == null:
		return
	talk_layer.visible = false
	level.player.frozen = false
	if was_new:
		_show_toast("[center]Nova palavra no seu [b]Álbum[/b]![/center]", 2.5)


func _on_goal_reached() -> void:
	level.player.frozen = true
	dlg.visible = false
	completed[current["id"]] = true
	_save_progress()
	end_title.text = "%s!" % current["name"]
	var t := "[b]Palabras que aprendiste[/b]  [color=%s](%d de %d)[/color]\n" % [C_MUTED, _count_unlocked(current), current["npcs"].size()]
	t += "[table=3]"
	for npc in current["npcs"]:
		if unlocked.has(_key(current["id"], npc["word"])):
			t += "[cell][font_size=26][b][color=%s]%s[/color][/b][/font_size]   [/cell][cell]%s   [/cell][cell][color=%s]%s[/color][/cell]" % [C_WORD, npc["word"], npc["es"], C_MUTED, npc["pt"]]
		else:
			t += "[cell][font_size=26][color=%s]? ? ?[/color][/font_size]   [/cell][cell][color=%s]faltou conversar com %s[/color][/cell][cell] [/cell]" % [C_LOCKED, C_LOCKED, npc["name"]]
	t += "[/table]\n"
	t += "[color=%s]De primera: [b]%d/%d[/b]   ·   Desafíos: [b]%d/%d[/b]   ·   Monstruos: [b]%d/%d[/b][/color]\n\n" % [
		C_MUTED, first_try.size(), people.size(), choices_done.size(), choices.size(), monsters_defeated, level.monster_count]
	t += "%s\n[b]Curiosidade.[/b] %s" % [current["sotaque"], current["fact"]]
	end_body.text = t
	var town: String = current["towns"][1]
	end_mark.sub = town.to_upper() if town.length() <= 11 else ""
	end_mark.queue_redraw()
	hud.visible = false
	end_layer.visible = true


# ---------------------------------------------------------------- dicionário

## Álbum de palavras. No menu é livre; durante a fase dá para consultar
## UMA vez por conversa (o botão da conversa ou a carga do HUD, que volta a cada conversa concluída).
func _open_album_in_talk() -> void:
	if album_used_in_talk:
		return
	album_used_in_talk = true
	t_album.disabled = true
	t_album.text = "Álbum já consultado"
	_open_dictionary()


func _open_album_from_hud() -> void:
	if album_charges <= 0:
		_show_toast("[center]Você já usou o álbum. Converse com alguém para poder consultar de novo![/center]", 2.5)
		return
	album_charges -= 1
	_update_hud()
	_open_dictionary()


func _open_dictionary() -> void:
	dict_return_to_game = level != null and hud.visible
	if dict_return_to_game:
		level.player.frozen = true
	var total := 0
	for c in countries:
		total += _count_unlocked(c)
	dict_title.text = "%d de %d" % [total, _total_words()]
	var t := ""
	# durante uma fase, o país atual aparece primeiro no álbum
	var order: Array = countries.duplicate()
	if dict_return_to_game and not current.is_empty():
		order.erase(current)
		order.push_front(current)
	for c in order:
		var n := _count_unlocked(c)
		t += "[font=res://assets/fonts/AlfaSlabOne-Regular.ttf][font_size=22]%s[/font_size][/font]  [color=%s]%s · %d/%d[/color]\n" % [c["name"], C_MUTED, c["region"], n, c["npcs"].size()]
		t += "[table=3]"
		for npc in c["npcs"]:
			if unlocked.has(_key(c["id"], npc["word"])):
				t += "[cell][b][color=%s]%s[/color][/b]    [/cell][cell]%s    [/cell][cell][color=%s]%s[/color][/cell]" % [C_WORD, npc["word"], npc["es"], C_MUTED, npc["pt"]]
			else:
				t += "[cell][color=%s]? ? ?[/color]    [/cell][cell][color=%s]fale com %s[/color][/cell][cell] [/cell]" % [C_LOCKED, C_LOCKED, npc["name"]]
		t += "[/table]\n\n"
	dict_body.text = t
	dict_layer.visible = true


func _close_dictionary() -> void:
	dict_layer.visible = false
	if dict_return_to_game and level != null and not talk_layer.visible and not end_layer.visible:
		level.player.frozen = false


# ---------------------------------------------------------------- interface
## Visual de "cartão-postal de viagem": papel creme, tinta azul-marinho, faixas de
## correio aéreo e selos de passaporte. Títulos em Alfa Slab One, texto em Atkinson Hyperlegible.

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _make_theme()
	layer.add_child(ui_root)

	_build_hud()
	_build_toast()
	_build_dialogue()
	_build_talk()
	_build_end()
	_build_menu()
	_build_dictionary()
	_build_title()
	_build_slots()
	_build_settings()


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = F_BODY
	t.default_font_size = 22
	t.set_color("font_color", "Label", INK)
	t.set_font("normal_font", "RichTextLabel", F_BODY)
	t.set_font("bold_font", "RichTextLabel", F_BOLD)
	t.set_font("italics_font", "RichTextLabel", F_BODY)
	t.set_color("default_color", "RichTextLabel", INK)
	# barra de rolagem do álbum
	var track := StyleBoxFlat.new()
	track.bg_color = PAPER_2
	track.set_corner_radius_all(6)
	track.content_margin_left = 6
	track.content_margin_right = 6
	var grab := StyleBoxFlat.new()
	grab.bg_color = INK_2
	grab.set_corner_radius_all(6)
	var grab_hi: StyleBoxFlat = grab.duplicate()
	grab_hi.bg_color = INK
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	return t


func _style(color: Color, radius := 10, margin := 20, border := Color.TRANSPARENT, border_w := 2, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_size = 12
		sb.shadow_offset = Vector2(0, 5)
		sb.shadow_color = Color(0.05, 0.07, 0.12, 0.32)
	if border.a > 0.0:
		sb.set_border_width_all(border_w)
		sb.border_color = border
	return sb


func _label(text: String, size: int, color := INK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Tipos de botão: "ink" (principal, tinta escura), "paper" (secundário, papel com contorno),
## "answer" (resposta da conversa, grande, papel com contorno grosso).
func _button(text: String, kind := "ink", size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", F_BOLD)
	b.add_theme_font_size_override("font_size", size)
	var bg := INK
	var fg := PAPER
	var border := Color.TRANSPARENT
	var bw := 2
	match kind:
		"paper":
			bg = PAPER
			fg = INK
			border = INK
		"answer":
			bg = Color("#fffaf0")
			fg = INK
			border = INK
			bw = 3
		"stamp":
			bg = STAMP
		"ghost":
			bg = Color(PAPER, 0.07)
			border = Color(PAPER, 0.4)
	var hover := bg.darkened(0.06) if kind != "ink" else INK.lightened(0.14)
	var press := bg.darkened(0.12) if kind != "ink" else INK.darkened(0.2)
	var off := Color(bg, 0.55) if kind != "ink" else Color("#6d7385")
	match kind:
		"stamp":
			hover = STAMP.lightened(0.1)
			off = Color(STAMP, 0.45)
		"ghost":
			hover = Color(PAPER, 0.16)
			press = Color(PAPER, 0.24)
			off = Color(PAPER, 0.03)
	b.add_theme_stylebox_override("normal", _style(bg, 10, 12, border, bw))
	b.add_theme_stylebox_override("hover", _style(hover, 10, 12, border, bw))
	b.add_theme_stylebox_override("pressed", _style(press, 10, 12, border, bw, false))
	b.add_theme_stylebox_override("disabled", _style(off, 10, 12, Color(border, border.a * 0.35), bw, false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))
	b.custom_minimum_size.y = 52
	return b


func _overlay(dim := 0.5) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(c)
	var bg := ColorRect.new()
	bg.color = Color(NIGHT, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	return c


## Cartão-postal: papel creme com faixas de correio aéreo no topo e na base.
func _postcard(min_width: float, margin := 34) -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PAPER, 12, 0))
	panel.custom_minimum_size = Vector2(min_width, 0)
	var air := Control.new()
	air.set_script(Airmail)
	panel.add_child(air)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", margin)
	m.add_theme_constant_override("margin_right", margin)
	m.add_theme_constant_override("margin_top", 38)
	m.add_theme_constant_override("margin_bottom", 38)
	panel.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	m.add_child(vb)
	return [panel, vb]


func _centered_postcard(parent: Control, min_width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var pc := _postcard(min_width)
	center.add_child(pc[0])
	return pc[1]


## Etiqueta com o nome de quem fala (vermelho-carimbo).
func _name_tag() -> Array:
	var p := PanelContainer.new()
	var sb := _style(STAMP, 6, 0, Color.TRANSPARENT, 0, false)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label("", 20, PAPER, F_DISPLAY)
	p.add_child(l)
	return [p, l]


func _logo(height: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = LOGO
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(height * float(LOGO.get_width()) / LOGO.get_height(), height)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _spacer(h := 0.0) -> Control:
	var c := Control.new()
	if h > 0.0:
		c.custom_minimum_size.y = h
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(menu)
	var bg := ColorRect.new()
	bg.color = NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 36)
	m.add_theme_constant_override("margin_right", 36)
	m.add_theme_constant_override("margin_top", 24)
	m.add_theme_constant_override("margin_bottom", 18)
	menu.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	m.add_child(col)

	# topo: logo da escola + total de palavras + álbum
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	top.add_child(_logo(52))
	top.add_child(_spacer())
	menu_total = _label("", 20, PAPER_DIM)
	menu_total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(menu_total)
	var dict_btn := _button("Mi Álbum", "paper", 20)
	dict_btn.custom_minimum_size.x = 170
	dict_btn.pressed.connect(_open_dictionary)
	top.add_child(dict_btn)
	var home := _button("Inicio", "ghost", 18)
	home.custom_minimum_size.x = 110
	home.pressed.connect(_show_title)
	top.add_child(home)

	var mid := CenterContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mid)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	mid.add_child(vb)
	vb.add_child(_label("Viaje por el Español", 58, PAPER, F_DISPLAY))
	vb.add_child(_label("21 países, una lengua. Elige un país y habla con su gente.", 22, PAPER_DIM))
	vb.add_child(_label("Escolha um país e converse com os moradores.", 17, PAPER_FAINT))
	vb.add_child(_spacer(22))

	var grid_center := CenterContainer.new()
	vb.add_child(grid_center)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid_center.add_child(grid)
	for c in countries:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(156, 108)
		b.add_theme_stylebox_override("normal", _style(PAPER, 2, 0, Color.TRANSPARENT, 0, false))
		b.add_theme_stylebox_override("hover", _style(Color("#fffaf0"), 2, 0, Color.TRANSPARENT, 0, false))
		b.add_theme_stylebox_override("pressed", _style(PAPER_2, 2, 0, Color.TRANSPARENT, 0, false))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_start_level.bind(c))
		var inner := MarginContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("margin_left", 13)
		inner.add_theme_constant_override("margin_right", 10)
		inner.add_theme_constant_override("margin_top", 46)
		inner.add_theme_constant_override("margin_bottom", 8)
		b.add_child(inner)
		var tv := VBoxContainer.new()
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_theme_constant_override("separation", 0)
		inner.add_child(tv)
		var name_l := _label(c["name"], 16, INK, F_DISPLAY)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.add_theme_constant_override("line_spacing", -5)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(name_l)
		var reg := _label(c["region"], 14, INK_2)
		reg.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		reg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(reg)
		var face := Control.new()
		face.set_script(StampFace)
		face.country = c
		face.hole = NIGHT
		b.add_child(face)
		menu_counts[c["id"]] = face
		grid.add_child(b)

	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 2)
	col.add_child(foot)
	foot.add_child(_label("Andar: setas ou A / D   ·   Pular: SALTAR ou Espaço   ·   Atacar: ATACAR ou J   ·   Responder: toque ou 1, 2, 3   ·   Esc: menú", 15, PAPER_FAINT))
	foot.add_child(_label("Trabalho de Espanhol · Escola Concept Salvador", 14, PAPER_FAINT))


func _refresh_menu() -> void:
	var total := 0
	for c in countries:
		var n := _count_unlocked(c)
		total += n
		var face = menu_counts[c["id"]]
		face.got = n
		face.total = c["npcs"].size()
		face.done = completed.has(c["id"])
		face.queue_redraw()
	menu_total.text = "Partida %d  ·  %d de %d palabras" % [current_slot, total, _total_words()]


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hud)

	# etiqueta de bagagem: bandeira, país e contadores
	var panel := PanelContainer.new()
	var sb := _style(PAPER, 10, 0)
	sb.content_margin_left = 14
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	hud_flag = Control.new()
	hud_flag.set_script(FlagDraw)
	hud_flag.custom_minimum_size = Vector2(42, 28)
	hud_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hud_flag)
	hud_label = _label("", 24, INK, F_DISPLAY)
	row.add_child(hud_label)
	var hsep := ColorRect.new()
	hsep.color = Color(INK, 0.18)
	hsep.custom_minimum_size = Vector2(1, 34)
	hsep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hsep)
	hud_hearts = Control.new()
	hud_hearts.set_script(Hearts)
	hud_hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hud_hearts)
	for key in ["Palabras", "Personas", "Monstruos"]:
		var sep := ColorRect.new()
		sep.color = Color(INK, 0.18)
		sep.custom_minimum_size = Vector2(1, 34)
		sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sep)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", -5)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cell)
		var num := _label("", 22, INK, F_BOLD)
		cell.add_child(num)
		cell.add_child(_label(key, 13, INK_2))
		hud_counts[key] = num

	# botões do canto (funcionam com toque; no teclado, Tab e Esc fazem o mesmo)
	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -16
	right.offset_left = -16
	right.offset_top = 16
	right.add_theme_constant_override("separation", 10)
	hud.add_child(right)
	album_btn = _button("Álbum", "paper", 20)
	album_btn.custom_minimum_size.x = 140
	album_btn.pressed.connect(_open_album_from_hud)
	right.add_child(album_btn)
	var menu_btn := _button("Menú", "ink", 20)
	menu_btn.custom_minimum_size.x = 110
	menu_btn.pressed.connect(_show_menu)
	right.add_child(menu_btn)

	# botões de toque para celular/iPad (somem quando o teclado é usado)
	touch_ui = Control.new()
	touch_ui.set_script(TouchControls)
	hud.add_child(touch_ui)


func _build_toast() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 100
	holder.offset_bottom = 260
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(holder)
	toast = PanelContainer.new()
	var sb := _style(PAPER, 10, 0)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	toast.add_theme_stylebox_override("panel", sb)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(toast)
	toast_label = _rich(21)
	toast_label.custom_minimum_size = Vector2(680, 0)
	toast.add_child(toast_label)


func _show_toast(bbcode: String, duration := 3.5) -> void:
	toast_label.text = bbcode
	toast.visible = true
	if toast_tween:
		toast_tween.kill()
	toast.modulate.a = 0.0
	toast_tween = create_tween()
	toast_tween.tween_property(toast, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	toast_tween.tween_interval(duration)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.35)


func _build_dialogue() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -210
	holder.offset_bottom = -20
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(holder)
	dlg = holder

	var panel := PanelContainer.new()
	var sb := _style(PAPER, 12, 0)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(880, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_row)
	var tag := _name_tag()
	dlg_name_panel = tag[0]
	dlg_name = tag[1]
	name_row.add_child(dlg_name_panel)

	dlg_line = _rich(28)
	dlg_line.custom_minimum_size = Vector2(820, 0)
	vb.add_child(dlg_line)

	dlg_info = _label("", 19, GREEN, F_BOLD)
	dlg_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vb.add_child(dlg_info)


func _build_talk() -> void:
	talk_layer = _overlay(0.45)
	var vb := _centered_postcard(talk_layer, 900)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	vb.add_child(head)
	var tag := _name_tag()
	t_name = tag[1]
	head.add_child(tag[0])
	head.add_child(_spacer())
	t_place = _label("", 17, INK_2)
	t_place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t_place)

	t_line = _rich(30)
	t_line.custom_minimum_size = Vector2(830, 0)
	vb.add_child(t_line)

	var rule := ColorRect.new()
	rule.color = Color(INK, 0.15)
	rule.custom_minimum_size.y = 2
	vb.add_child(rule)

	t_ask = _label("", 22, INK, F_BOLD)
	t_ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t_ask.custom_minimum_size = Vector2(830, 0)
	vb.add_child(t_ask)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	for i in 3:
		var b := _button("", "answer", 26)
		b.custom_minimum_size = Vector2(260, 74)
		b.pressed.connect(_on_answer.bind(i))
		row.add_child(b)
		t_buttons.append(b)

	t_feedback = _label("", 20, INK_2)
	t_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t_feedback.custom_minimum_size = Vector2(830, 52)
	vb.add_child(t_feedback)

	var album_row := HBoxContainer.new()
	album_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(album_row)
	t_album = _button("Consultar álbum (1 vez)", "paper", 18)
	t_album.custom_minimum_size.x = 280
	t_album.pressed.connect(_open_album_in_talk)
	album_row.add_child(t_album)


func _build_dictionary() -> void:
	dict_layer = _overlay(0.7)
	var vb := _centered_postcard(dict_layer, 860)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 0)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tcol)
	var t := _label("Mi Álbum de Palabras", 34, INK, F_DISPLAY)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tcol.add_child(t)
	var tp := _label("As palavras que você coletou em cada país", 17, INK_2)
	tp.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tcol.add_child(tp)
	dict_title = _label("", 22, STAMP, F_BOLD)
	dict_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(dict_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(790, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	dict_body = _rich(20)
	dict_body.custom_minimum_size = Vector2(760, 0)
	dict_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dict_body.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(dict_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	var close := _button("Cerrar", "ink", 22)
	close.custom_minimum_size.x = 200
	close.pressed.connect(_close_dictionary)
	row.add_child(close)
	dict_layer.visible = false


func _build_end() -> void:
	end_layer = _overlay(0.6)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(center)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)
	var pc := _postcard(900)
	stack.add_child(pc[0])
	var vb: VBoxContainer = pc[1]

	# cabeçalho do cartão-postal: "¡Saludos desde" + país, com carimbo
	var head := HBoxContainer.new()
	vb.add_child(head)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", -6)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tcol)
	var hi := _label("¡Saludos desde", 22, STAMP, F_BOLD)
	hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tcol.add_child(hi)
	end_title = _label("", 50, INK, F_DISPLAY)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tcol.add_child(end_title)
	end_mark = Control.new()
	end_mark.set_script(Postmark)
	end_mark.text = "COMPLETADO"
	end_mark.radius = 50.0
	head.add_child(end_mark)

	end_body = _rich(20)
	end_body.custom_minimum_size = Vector2(830, 0)
	vb.add_child(end_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	vb.add_child(row)
	var back := _button("Elegir otro país", "ink", 22)
	back.custom_minimum_size.x = 250
	back.pressed.connect(_show_menu)
	row.add_child(back)
	var again := _button("Jugar otra vez", "paper", 22)
	again.custom_minimum_size.x = 210
	again.pressed.connect(func() -> void: _start_level(current))
	row.add_child(again)
	var dict_btn := _button("Mi Álbum", "paper", 22)
	dict_btn.custom_minimum_size.x = 170
	dict_btn.pressed.connect(_open_dictionary)
	row.add_child(dict_btn)

	var logo_row := CenterContainer.new()
	stack.add_child(logo_row)
	logo_row.add_child(_logo(40))


# ---------------------------------------------------------------- tela de início
## Fundo vivo: uma fase de verdade (país sorteado) com a câmera passeando devagar,
## coberta por um degradê azul-noite à esquerda, onde ficam o título e os botões.

func _show_title() -> void:
	_save_progress()
	answering = false
	typing_node = null
	_hide_all()
	title_load_btn.disabled = not _any_save()
	title_layer.visible = true
	_start_backdrop()
	# entrada: título e botões deslizam da esquerda (único movimento da tela)
	title_margin.modulate.a = 0.0
	title_margin.position.x = -40.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_margin, "modulate:a", 1.0, 0.6)
	tw.tween_property(title_margin, "position:x", 0.0, 0.9)


func _start_backdrop() -> void:
	_clear_level()
	var c: Dictionary = countries[randi() % countries.size()]
	var saved := current
	current = c
	var ppl := _prepare_people(c)
	var ch := _prepare_choices(c)
	current = saved
	level = Node3D.new()
	level.set_script(LevelScript)
	level.setup(c, ppl, ch)
	level.attract = true
	add_child(level)
	level.player.frozen = true
	level.player.visible = false
	title_place.text = "Vista: %s" % c["name"]
	title_flag.set_country(c)


func _close_overlays() -> void:
	var rebuild: bool = settings_layer.visible and settings["quality"] != _quality_before
	slots_layer.visible = false
	settings_layer.visible = false
	if rebuild and title_layer.visible:
		_start_backdrop()


func _title_button(text: String, hint: String, kind: String, size := 26) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	title_buttons.add_child(row)
	var b := _button(text, kind, size)
	b.custom_minimum_size = Vector2(320, 56)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(b)
	var h := _label(hint, 16, PAPER_FAINT)
	h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(h)
	return b


func _build_title() -> void:
	title_layer = Control.new()
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(title_layer)

	# degradê: noite opaca à esquerda, cena aparecendo à direita
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.38, 0.62, 1.0])
	grad.colors = PackedColorArray([Color(NIGHT, 0.97), Color(NIGHT, 0.9), Color(NIGHT, 0.35), Color(NIGHT, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 4
	var shade := TextureRect.new()
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(shade)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 64)
	m.add_theme_constant_override("margin_right", 40)
	m.add_theme_constant_override("margin_top", 30)
	m.add_theme_constant_override("margin_bottom", 22)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(m)
	title_margin = m
	title_col = VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 0)
	title_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(title_col)

	var logo_row := HBoxContainer.new()
	logo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.add_child(logo_row)
	logo_row.add_child(_logo(50))
	title_col.add_child(_vspace())

	for line in ["Viaje por", "el Español"]:
		var t := _label(line, 70, PAPER, F_DISPLAY)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		t.add_theme_constant_override("line_spacing", -10)
		title_col.add_child(t)
	var sub := _label("21 países, una lengua y muchas maneras de hablarla.", 22, PAPER_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_col.add_child(sub)
	var sub_pt := _label("21 países, uma língua e muitos jeitos de falar.", 17, PAPER_FAINT)
	sub_pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_col.add_child(sub_pt)
	title_col.add_child(_spacer(24))

	title_buttons = VBoxContainer.new()
	title_buttons.add_theme_constant_override("separation", 10)
	title_col.add_child(title_buttons)
	var play := _title_button("Jugar", "jogar", "stamp", 28)
	play.pressed.connect(_open_slots.bind("play"))
	title_load_btn = _title_button("Cargar partida", "carregar", "paper", 22)
	title_load_btn.pressed.connect(_open_slots.bind("load"))
	var conf := _title_button("Configuración", "configurações", "ghost", 22)
	conf.pressed.connect(_open_settings)
	if not OS.has_feature("web"):
		var q := _title_button("Salir", "sair", "ghost", 20)
		q.custom_minimum_size = Vector2(320, 48)
		q.pressed.connect(func() -> void: get_tree().quit())

	title_col.add_child(_vspace())
	title_col.add_child(_spacer(12))
	var foot := _label("Trabajo de Español · 7.º año · Escola Concept Salvador", 14, PAPER_FAINT)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_col.add_child(foot)

	# carimbo e etiqueta do país que aparece ao fundo
	var mark := Control.new()
	mark.set_script(Postmark)
	mark.text = "21 PAÍSES"
	mark.sub = "UNA LENGUA"
	mark.radius = 74.0
	mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mark.offset_left = -220
	mark.offset_right = -50
	mark.offset_top = 40
	mark.offset_bottom = 210
	title_layer.add_child(mark)

	var tag := PanelContainer.new()
	var sb := _style(PAPER, 8, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	tag.add_theme_stylebox_override("panel", sb)
	tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tag.offset_right = -32
	tag.offset_bottom = -28
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(tag)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 10)
	tag.add_child(tr)
	title_flag = Control.new()
	title_flag.set_script(FlagDraw)
	title_flag.custom_minimum_size = Vector2(30, 20)
	title_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(title_flag)
	title_place = _label("", 17, INK, F_BOLD)
	tr.add_child(title_place)


func _vspace() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ---------------------------------------------------------------- partidas (3 saves)

func _build_slots() -> void:
	slots_layer = _overlay(0.82)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	slots_layer.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	center.add_child(vb)
	slots_title = _label("", 44, PAPER, F_DISPLAY)
	vb.add_child(slots_title)
	slots_sub = _label("", 18, PAPER_FAINT)
	vb.add_child(slots_sub)
	vb.add_child(_spacer(20))
	slots_row = HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 22)
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(slots_row)
	vb.add_child(_spacer(22))
	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(back_row)
	var back := _button("Volver", "ghost", 20)
	back.custom_minimum_size.x = 180
	back.pressed.connect(_close_overlays)
	back_row.add_child(back)
	slots_layer.visible = false


## mode "play": vazio = nova partida, cheio = continuar. mode "load": só as que existem.
func _open_slots(mode: String) -> void:
	slots_mode = mode
	slots_title.text = "Elige tu partida" if mode == "play" else "Cargar partida"
	slots_sub.text = "Escolha um dos 3 saves. O progresso é salvo sozinho." if mode == "play" \
		else "Continue de onde parou."
	_fill_slots()
	slots_layer.visible = true


func _fill_slots() -> void:
	for ch in slots_row.get_children():
		ch.queue_free()
	for i in range(1, SLOTS + 1):
		slots_row.add_child(_slot_card(i))


func _slot_card(slot: int) -> Control:
	var info := _slot_info(slot)
	var has: bool = info["exists"]
	var pc := _postcard(300, 26)
	var vb: VBoxContainer = pc[1]
	vb.add_theme_constant_override("separation", 10)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := _label("Partida %d" % slot, 26, INK, F_DISPLAY)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if not has:
		head.add_child(_label("vacía", 16, INK_2))

	var pp := Control.new()
	pp.set_script(Passport)
	pp.countries = countries
	pp.done = info["done"]
	pp.custom_minimum_size = Vector2(248, 98)
	vb.add_child(pp)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 0)
	stats.custom_minimum_size.y = 74
	vb.add_child(stats)
	if has:
		var w := _label("%d de %d palabras" % [info["words"], _total_words()], 22, INK, F_BOLD)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats.add_child(w)
		var d := _label("%d de %d países completos" % [info["done"].size(), countries.size()], 17, INK_2)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats.add_child(d)
		var when := _label(_when_text(info), 15, INK_2)
		when.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats.add_child(when)
	else:
		var e := _label("Sin viajes todavía.", 20, INK_2, F_BOLD)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats.add_child(e)
		var e2 := _label("Nenhuma viagem ainda.", 16, INK_2)
		e2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats.add_child(e2)

	var go: Button
	if has:
		go = _button("Continuar", "ink", 22)
	elif slots_mode == "play":
		go = _button("Nueva partida", "stamp", 22)
	else:
		go = _button("Vacía", "paper", 20)
		go.disabled = true
	go.pressed.connect(_enter_slot.bind(slot))
	vb.add_child(go)

	if has:
		var del := _button("Borrar", "paper", 17)
		del.custom_minimum_size.y = 44
		del.pressed.connect(_on_delete_pressed.bind(del, slot))
		vb.add_child(del)
	else:
		vb.add_child(_spacer(44))
	return pc[0]


func _when_text(info: Dictionary) -> String:
	var ts: int = info["last"]
	if ts <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(ts + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	var t := "Última vez: %02d/%02d, %02d:%02d" % [d["day"], d["month"], d["hour"], d["minute"]]
	for c in countries:
		if c["id"] == info["last_country"]:
			t += " · " + c["name"]
	return t


## Borrar pede confirmação: o primeiro toque vira "¿Seguro?", o segundo apaga.
func _on_delete_pressed(btn: Button, slot: int) -> void:
	if not btn.has_meta("armed"):
		btn.set_meta("armed", true)
		btn.text = "¿Seguro? Toca otra vez"
		btn.add_theme_stylebox_override("normal", _style(STAMP, 10, 12, STAMP, 2))
		btn.add_theme_stylebox_override("hover", _style(STAMP.lightened(0.08), 10, 12, STAMP, 2))
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			btn.add_theme_color_override(st, PAPER)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(btn) and btn.has_meta("armed"):
				_fill_slots())
		return
	_delete_slot(slot)
	title_load_btn.disabled = not _any_save()
	_fill_slots()


func _enter_slot(slot: int) -> void:
	_load_progress(slot)
	current = {}
	_save_progress()      # cria o arquivo na hora (partida nova já aparece em "Cargar")
	_show_menu()


# ---------------------------------------------------------------- configurações

func _build_settings() -> void:
	settings_layer = _overlay(0.82)
	var vb := _centered_postcard(settings_layer, 720)
	vb.add_theme_constant_override("separation", 16)
	var t := _label("Configuración", 36, INK, F_DISPLAY)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vb.add_child(t)

	# volume das vozes
	var vrow := _setting_row(vb, "Volumen de las voces", "volume das vozes")
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.custom_minimum_size = Vector2(250, 44)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	_style_slider(slider)
	vrow.add_child(slider)
	var vlabel := _label("", 20, INK, F_BOLD)
	vlabel.custom_minimum_size.x = 60
	vrow.add_child(vlabel)
	settings_widgets["voice"] = [slider, vlabel]
	slider.value_changed.connect(func(v: float) -> void:
		vlabel.text = "%d%%" % int(v)
		if settings["voice"] != v:
			settings["voice"] = v
			_apply_settings()
			_save_settings()
			typing_pitch = 1.1
			_blip("a"))

	_segmented(vb, "text", "Velocidad del texto", "velocidade do texto",
		[["lenta", "Lenta"], ["normal", "Normal"], ["rapida", "Rápida"]])
	_segmented(vb, "quality", "Calidad gráfica", "qualidade gráfica",
		[["auto", "Auto"], ["high", "Alta"], ["low", "Ligera"]])
	_segmented(vb, "touch", "Botones táctiles", "botões de toque na tela",
		[["auto", "Auto"], ["always", "Siempre"], ["never", "Nunca"]])
	if not OS.has_feature("mobile"):
		_segmented(vb, "fullscreen", "Pantalla completa", "tela cheia", [[false, "No"], [true, "Sí"]])

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(row)
	var ok := _button("Listo", "ink", 22)
	ok.custom_minimum_size.x = 180
	ok.pressed.connect(_close_overlays)
	row.add_child(ok)
	settings_layer.visible = false


func _setting_row(parent: Control, text: String, hint: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var l := _label(text, 21, INK, F_BOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(l)
	var h := _label(hint, 15, INK_2)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(h)
	return row


## Botões lado a lado em que só um fica marcado (tinta escura = escolhido).
func _segmented(parent: Control, key: String, text: String, hint: String, options: Array) -> void:
	var row := _setting_row(parent, text, hint)
	var group := ButtonGroup.new()
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 6)
	row.add_child(seg)
	var buttons := []
	for o in options:
		var b := _button(o[1], "paper", 18)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(104, 48)
		b.add_theme_stylebox_override("pressed", _style(INK, 10, 12, INK, 2, false))
		b.add_theme_stylebox_override("hover_pressed", _style(INK.lightened(0.1), 10, 12, INK, 2, false))
		b.add_theme_color_override("font_pressed_color", PAPER)
		b.add_theme_color_override("font_hover_pressed_color", PAPER)
		b.set_meta("value", o[0])
		b.toggled.connect(func(on: bool) -> void:
			if on and settings[key] != o[0]:
				settings[key] = o[0]
				_apply_settings()
				_save_settings())
		seg.add_child(b)
		buttons.append(b)
	settings_widgets[key] = buttons


func _open_settings() -> void:
	_quality_before = settings["quality"]
	for key in settings_widgets.keys():
		var w: Array = settings_widgets[key]
		if key == "voice":
			w[0].value = settings["voice"]
			w[1].text = "%d%%" % int(settings["voice"])
		else:
			for b in w:
				b.set_pressed_no_signal(b.get_meta("value") == settings[key])
	settings_layer.visible = true


func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = PAPER_2
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := track.duplicate()
	fill.bg_color = STAMP
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var img := Image.create(30, 30, false, Image.FORMAT_RGBA8)
	for y in 30:
		for x in 30:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(15, 15))
			var a := clampf(14.0 - d, 0.0, 1.0)
			var inner := d < 9.5
			img.set_pixel(x, y, Color(PAPER if inner else INK, a))
	var tex := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", tex)
	s.add_theme_icon_override("grabber_highlight", tex)
