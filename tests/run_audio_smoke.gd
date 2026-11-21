extends SceneTree

const SfxRes = preload("res://audio/sfx.gd")
const MusicRes = preload("res://audio/music.gd")
const BgmStream = preload("res://audio/music/deduction_loop.ogg")

var checks := 0
var failures := 0

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("AUDIO CHECK FAILED: " + label)

func _initialize() -> void:
	_run()
	print("AUDIO SMOKE RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _run() -> void:
	for cue in SfxRes.CUES:
		var meta: Dictionary = SfxRes.CUES[cue]
		var variants: Array = SfxRes.cue_variants(str(cue))
		_check(not variants.is_empty(), "cue has a playable variant: " + str(cue))
		_check(float(meta.get("pitch", 1.0)) > 0.0, "cue pitch positive: " + str(cue))
		_check(int(meta.get("cool", 0)) >= 0, "cue cooldown valid: " + str(cue))
		for variant in variants:
			var data: Dictionary = variant
			_check(
				SfxRes.STREAMS.has(str(data.get("stream", ""))),
				"variant stream exists: %s -> %s" % [str(cue), str(data.get("stream", ""))]
			)
			_check(float(data.get("weight", 0.0)) > 0.0, "variant weight positive: " + str(cue))
			_check(float(data.get("pitch", 0.0)) > 0.0, "variant pitch positive: " + str(cue))
	for stream in SfxRes.STREAMS:
		_check(SfxRes.STREAMS[stream] is AudioStream, "stream loaded: " + str(stream))

	# Repeated interactions must cycle through several distinct takes.
	for cue in ["card_lift", "card_place", "socket_snap", "page_whoosh", "trash_delete"]:
		_check(SfxRes.cue_variants(str(cue)).size() >= 3, "cue has a varied pool: " + str(cue))
	_check(
		str(SfxRes.cue_variants("card_place")[0]["stream"]) == "card_place",
		"base stream stays candidate zero"
	)

	# Buttons, cards and keyboard use separate timbres.
	_check(SfxRes.cue_variants("button_hover").size() >= 2, "button hover has variants")
	_check(SfxRes.cue_variants("button_click").size() >= 3, "button click has variants")
	_check(
		SfxRes.CUES["button_hover"]["stream"] != SfxRes.CUES["card_hover"]["stream"],
		"button hover and card hover use different pools"
	)
	_check(
		SfxRes.CUES["button_click"]["stream"] != SfxRes.CUES["ui_click"]["stream"],
		"button click and card tap use different pools"
	)
	_check(
		SfxRes.CUES["switch_click"]["stream"].begins_with("button_click"),
		"side switches use the button timbre"
	)
	_check(
		SfxRes.CUES["card_hover"]["stream"].begins_with("card_slide"),
		"card hover keeps the paper timbre"
	)

	# Every alternate take must respect the action's characteristic length.
	for cue in SfxRes.CUE_VARIANTS:
		var meta: Dictionary = SfxRes.CUES[cue]
		var base_length: float = SfxRes.stream_length(str(meta["stream"]))
		var min_ratio := float(meta.get("length_min", 0.75))
		var max_ratio := float(meta.get("length_max", 1.30))
		_check(base_length > 0.0, "base length available: " + str(cue))
		for variant in SfxRes.cue_variants(str(cue)):
			var length := float(variant.get("length", 0.0))
			_check(length > 0.0, "variant length available: " + str(cue))
			if base_length > 0.0 and length > 0.0:
				var ratio := length / base_length
				_check(
					ratio >= min_ratio - 0.001 and ratio <= max_ratio + 0.001,
					"variant length matches %s: %.3f / %.3f" % [str(cue), length, base_length]
				)
	var hover_max := 0.0
	for cue in ["button_hover", "card_hover", "switch_click", "ui_zoom"]:
		for variant in SfxRes.cue_variants(str(cue)):
			hover_max = maxf(hover_max, float(variant["length"]))
	var lift_min := 99.0
	var place_max := 0.0
	for cue in ["card_lift", "card_place"]:
		for variant in SfxRes.cue_variants(str(cue)):
			lift_min = minf(lift_min, float(variant["length"]))
			place_max = maxf(place_max, float(variant["length"]))
	var open_min := 99.0
	for cue in ["scope_open", "builder_open"]:
		for variant in SfxRes.cue_variants(str(cue)):
			open_min = minf(open_min, float(variant["length"]))
	var delete_min := 99.0
	for cue in ["trash_delete", "scope_delete"]:
		for variant in SfxRes.cue_variants(str(cue)):
			delete_min = minf(delete_min, float(variant["length"]))
	_check(hover_max < 0.15, "hover takes stay short (max %.3fs)" % hover_max)
	_check(lift_min > 0.15 and place_max < 0.35, "lift/place takes stay near 0.2–0.3s")
	_check(open_min > 0.30, "open takes stay longer than 0.3s")
	_check(delete_min > 0.38, "delete takes stay longer than 0.38s")
	_check(hover_max < lift_min, "hover takes are shorter than lift takes")
	var typing_variants: Array = SfxRes.cue_variants("typing_key")
	var typing_max := 0.0
	for variant in typing_variants:
		typing_max = maxf(typing_max, float(variant["length"]))
	_check(typing_variants.size() >= 5, "typing has a varied key pool")
	_check(typing_max < 0.20, "typing keys stay shorter than 0.20s")

	var sfx = SfxRes.new()
	root.add_child(sfx)
	sfx.setup(null)
	_check(not sfx.enabled, "SFX is disabled in headless")
	var picks: Dictionary = {}
	var previous := ""
	var repeated := false
	for index in range(240):
		var variant: Dictionary = sfx.pick_variant("card_place")
		var stream_name := str(variant.get("stream", ""))
		if index > 0 and stream_name == previous:
			repeated = true
		picks[stream_name] = true
		previous = stream_name
	_check(picks.size() >= 3, "card_place draws several distinct takes")
	_check(not repeated, "card_place never repeats the previous take")
	var group_previous := ""
	var group_repeated := false
	for index in range(120):
		var cue := "card_lift" if index % 2 == 0 else "card_place"
		var stream_name := str(sfx.pick_variant(cue).get("stream", ""))
		if index > 0 and stream_name == group_previous:
			group_repeated = true
		group_previous = stream_name
	_check(not group_repeated, "drag cues do not repeat across lift/drop")
	_check(sfx.pick_variant("unknown_cue").is_empty(), "unknown cue has no variant")
	sfx.play("button_hover")
	sfx.set_muted(true)
	sfx.set_volume(0.4)
	_check(sfx.muted and is_equal_approx(sfx.volume, 0.4), "headless settings are harmless")
	sfx.queue_free()

	# BGM asset, Music bus and headless-safe music controller.
	_check(BgmStream is AudioStream, "BGM asset loads")
	_check(BgmStream is AudioStreamOggVorbis, "BGM is Ogg Vorbis")
	_check(BgmStream.get_length() > 70.0, "BGM contains the full 80-second arrangement")
	_check(BgmStream.get_length() < 90.0, "BGM is a compact loop")
	_check(bool(BgmStream.loop), "BGM import is loop-enabled")
	_check(AudioServer.get_bus_index("Music") >= 0, "Music bus exists")
	var music = MusicRes.new()
	root.add_child(music)
	music.setup(null)
	_check(not music.enabled, "music is disabled in headless")
	music.set_muted(true)
	music.set_volume(0.4)
	_check(music.muted and is_equal_approx(music.volume, 0.4), "music settings are harmless")
	music.queue_free()

	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	root.add_child(main)
	await process_frame
	await process_frame
	_check(main._sfx == null, "headless main has no audio runtime")
	_check(main._music == null, "headless main has no music runtime")
	_check(main._sound_control == null, "headless main has no sound control")
	main.play_sfx("button_hover")
	main.open_level(0)
	await process_frame
	main._on_reset()
	await process_frame
	_check(main.canvas != null, "headless UI still loads with audio hooks")
	main.queue_free()
