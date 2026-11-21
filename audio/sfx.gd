extends Node

## Controller-owned paper-first SFX pool. Never instantiated in headless mode.

const VOICE_COUNT := 12
const SFX_BUS := "SFX"
const SETTINGS_PATH := "user://audio_settings.cfg"

const STREAMS := {
	"card_slide": preload("res://audio/sfx/card_slide.wav"),
	"card_slide_short": preload("res://audio/sfx/card_slide_short.wav"),
	"card_lift": preload("res://audio/sfx/card_lift.wav"),
	"card_place": preload("res://audio/sfx/card_place.wav"),
	"card_place_soft": preload("res://audio/sfx/card_place_soft.wav"),
	"card_fan": preload("res://audio/sfx/card_fan.wav"),
	"card_shuffle": preload("res://audio/sfx/card_shuffle.wav"),
	"card_open": preload("res://audio/sfx/card_open.wav"),
	"page_whoosh": preload("res://audio/sfx/page_whoosh.wav"),
	"page_back": preload("res://audio/sfx/page_back.wav"),
	"paper_sweep": preload("res://audio/sfx/paper_sweep.wav"),
	"ui_click": preload("res://audio/sfx/ui_click.wav"),
	"error_soft": preload("res://audio/sfx/error_soft.wav"),
	"marimba_c4": preload("res://audio/sfx/marimba_c4.wav"),
	"marimba_c5": preload("res://audio/sfx/marimba_c5.wav"),
	"goal_valid": preload("res://audio/sfx/goal_valid.wav"),
	"level_complete": preload("res://audio/sfx/level_complete.wav"),
	"confirm_two": preload("res://audio/sfx/confirm_two.wav"),
	"socket_snap": preload("res://audio/sfx/socket_snap.wav"),
	"copy": preload("res://audio/sfx/copy.wav"),
	"trash_hover": preload("res://audio/sfx/trash_hover.wav"),
	"trash_delete": preload("res://audio/sfx/trash_delete.wav"),
	"builder_open": preload("res://audio/sfx/builder_open.wav"),
	"scope_open": preload("res://audio/sfx/scope_open.wav"),
	"scope_minimize": preload("res://audio/sfx/scope_minimize.wav"),
	"scope_delete": preload("res://audio/sfx/scope_delete.wav"),
	# Paper-foley variants (same CC0 sessions, different takes). Used through
	# CUE_VARIANTS so repeated drags never replay one identical recording.
	"paper_lift_a": preload("res://audio/sfx/paper/lift_a.wav"),
	"paper_lift_b": preload("res://audio/sfx/paper/lift_b.wav"),
	"paper_place_a": preload("res://audio/sfx/paper/place_a.wav"),
	"paper_place_b": preload("res://audio/sfx/paper/place_b.wav"),
	"paper_place_c": preload("res://audio/sfx/paper/place_c.wav"),
	"paper_soft_a": preload("res://audio/sfx/paper/soft_a.wav"),
	"paper_soft_b": preload("res://audio/sfx/paper/soft_b.wav"),
	"paper_slide_a": preload("res://audio/sfx/paper/slide_a.wav"),
	"paper_slide_b": preload("res://audio/sfx/paper/slide_b.wav"),
	"paper_slide_c": preload("res://audio/sfx/paper/slide_c.wav"),
	"paper_hover_a": preload("res://audio/sfx/paper/hover_a.wav"),
	"paper_hover_b": preload("res://audio/sfx/paper/hover_b.wav"),
	"paper_hover_c": preload("res://audio/sfx/paper/hover_c.wav"),
	"paper_snap_a": preload("res://audio/sfx/paper/snap_a.wav"),
	"paper_snap_b": preload("res://audio/sfx/paper/snap_b.wav"),
	"paper_open_a": preload("res://audio/sfx/paper/open_a.wav"),
	"paper_open_b": preload("res://audio/sfx/paper/open_b.wav"),
	"paper_fan_a": preload("res://audio/sfx/paper/fan_a.wav"),
	"paper_sweep_a": preload("res://audio/sfx/paper/sweep_a.wav"),
	"paper_sweep_b": preload("res://audio/sfx/paper/sweep_b.wav"),
	"paper_shuffle_a": preload("res://audio/sfx/paper/shuffle_a.wav"),
	"paper_shove_a": preload("res://audio/sfx/paper/shove_a.wav"),
	"paper_shove_b": preload("res://audio/sfx/paper/shove_b.wav"),
	"paper_tap_a": preload("res://audio/sfx/paper/tap_a.wav"),
	"paper_slide_long_a": preload("res://audio/sfx/paper/slide_long_a.wav"),
	"paper_slide_long_b": preload("res://audio/sfx/paper/slide_long_b.wav"),
	"paper_crumple_a": preload("res://audio/sfx/paper/crumple_a.wav"),
	"paper_crumple_b": preload("res://audio/sfx/paper/crumple_b.wav"),
	"paper_hover_d": preload("res://audio/sfx/paper/hover_d.wav"),
	# Dry keyboard ticks for the Formula Builder.
	"typing_key_a": preload("res://audio/sfx/typing/key_a.wav"),
	"typing_key_b": preload("res://audio/sfx/typing/key_b.wav"),
	"typing_key_c": preload("res://audio/sfx/typing/key_c.wav"),
	"typing_key_d": preload("res://audio/sfx/typing/key_d.wav"),
	"typing_key_e": preload("res://audio/sfx/typing/key_e.wav"),
	"typing_key_f": preload("res://audio/sfx/typing/key_f.wav"),
	"typing_key_g": preload("res://audio/sfx/typing/key_g.wav"),
	# UI button clicks and hover ticks (distinct from paper cards).
	"button_click_a": preload("res://audio/sfx/ui/button_click_a.wav"),
	"button_click_b": preload("res://audio/sfx/ui/button_click_b.wav"),
	"button_click_c": preload("res://audio/sfx/ui/button_click_c.wav"),
	"button_hover_a": preload("res://audio/sfx/ui/button_hover_a.wav"),
	"button_hover_b": preload("res://audio/sfx/ui/button_hover_b.wav"),
}

## Alternate takes for frequently repeated cues (paper foley and keyboard
## ticks). The base stream in CUES
## is always candidate zero; each entry here adds a take with a small loudness
## offset so the pool stays balanced. Consecutive plays never use the same take.
##
## Takes must also match the action's length: cue_variants keeps only takes
## whose duration is within 0.75x–1.30x of the base stream. That keeps hovers
## short (~60–100 ms), placements near 250 ms, opens near 400 ms and deletes
## long (~440–520 ms) instead of mixing a click into a page turn.
const CUE_VARIANTS := {
	"card_lift": [
		{"stream": "paper_lift_a", "db": 5.4},
		{"stream": "paper_place_a", "db": 5.5},
		{"stream": "paper_slide_a", "db": 4.9},
		{"stream": "paper_slide_b", "db": 4.7},
	],
	"card_detach": [
		{"stream": "paper_hover_a", "db": 0.7},
		{"stream": "paper_hover_b", "db": 3.9},
	],
	"card_place": [
		{"stream": "paper_place_a", "db": -5.4},
		{"stream": "paper_place_b", "db": -0.4},
		{"stream": "paper_place_c", "db": -1.8},
		{"stream": "paper_shove_b", "db": -2.9},
		{"stream": "paper_shove_a", "db": 1.9},
		{"stream": "paper_slide_c", "db": -3.5},
	],
	"soft_reject": [
		{"stream": "paper_soft_a", "db": 0.4},
		{"stream": "paper_soft_b", "db": 2.6},
		{"stream": "paper_lift_b", "db": 0.9},
	],
	"card_hover": [
		{"stream": "paper_hover_a", "db": 0.7},
		{"stream": "paper_hover_b", "db": 3.9},
		{"stream": "paper_hover_c", "db": 7.0},
	],
	"ui_zoom": [
		{"stream": "paper_hover_a", "db": 0.7},
		{"stream": "paper_hover_b", "db": 3.9},
	],
	"scope_move_start": [
		{"stream": "paper_hover_a", "db": 0.7},
		{"stream": "paper_hover_b", "db": 3.9},
	],
	"scope_move_end": [
		{"stream": "paper_hover_a", "db": 0.7},
		{"stream": "paper_hover_b", "db": 3.9},
	],
	"socket_snap": [
		{"stream": "paper_place_a", "db": -6.2},
		{"stream": "paper_place_b", "db": -1.2},
		{"stream": "paper_shove_b", "db": -3.7},
	],
	"goal_link": [
		{"stream": "paper_place_b", "db": -0.4},
		{"stream": "paper_place_c", "db": -1.8},
	],
	"copy_stamp": [
		{"stream": "paper_place_c", "db": 0.5},
		{"stream": "paper_place_b", "db": 0.9},
	],
	"trash_hover": [
		{"stream": "paper_hover_c", "db": 4.3},
		{"stream": "paper_hover_d", "db": -2.3},
		{"stream": "paper_snap_b", "db": 0.0},
	],
	"trash_delete": [
		{"stream": "paper_shuffle_a", "db": -2.8},
		{"stream": "paper_crumple_a", "db": -7.2},
		{"stream": "paper_crumple_b", "db": -6.5},
	],
	"scope_delete": [
		{"stream": "paper_shuffle_a", "db": -2.8},
		{"stream": "paper_crumple_a", "db": -7.2},
		{"stream": "paper_crumple_b", "db": -6.5},
	],
	"scope_open": [
		{"stream": "paper_open_a", "db": -1.9},
		{"stream": "paper_open_b", "db": -0.5},
	],
	"scope_resume": [
		{"stream": "paper_slide_long_a", "db": -3.4},
		{"stream": "paper_slide_long_b", "db": -4.2},
	],
	"scope_expand": [
		{"stream": "paper_slide_long_a", "db": -3.4},
		{"stream": "paper_slide_long_b", "db": -4.2},
	],
	"scope_minimize": [
		{"stream": "paper_fan_a", "db": 7.3},
		{"stream": "paper_sweep_b", "db": 3.2},
		{"stream": "paper_shuffle_a", "db": 3.3},
	],
	"builder_open": [
		{"stream": "paper_open_a", "db": -3.5},
		{"stream": "paper_open_b", "db": -2.1},
		{"stream": "paper_fan_a", "db": 3.1},
	],
	"page_whoosh": [
		{"stream": "paper_sweep_a", "db": -3.2},
		{"stream": "paper_sweep_b", "db": -2.5},
	],
	"page_back": [
		{"stream": "paper_sweep_b", "db": -2.5},
		{"stream": "paper_sweep_a", "db": -3.2},
	],
	"paper_sweep": [
		{"stream": "paper_sweep_a", "db": -4.6},
		{"stream": "paper_sweep_b", "db": -3.9},
		{"stream": "paper_shuffle_a", "db": -3.8},
	],
	"reset_sweep": [
		{"stream": "paper_sweep_a", "db": -4.6},
		{"stream": "paper_sweep_b", "db": -3.9},
		{"stream": "paper_shuffle_a", "db": -3.8},
	],
	"level_select": [
		{"stream": "paper_place_a", "db": -6.2},
		{"stream": "paper_place_b", "db": -1.2},
	],
	"start_confirm": [
		{"stream": "paper_open_a", "db": -1.9},
		{"stream": "paper_open_b", "db": -0.5},
	],
	"ui_click": [
		{"stream": "paper_tap_a", "db": -2.3},
		{"stream": "paper_snap_a", "db": -8.1},
		{"stream": "paper_hover_d", "db": -7.4},
	],
	"goal_check_empty": [
		{"stream": "paper_tap_a", "db": -2.3},
		{"stream": "paper_snap_a", "db": -8.1},
		{"stream": "paper_hover_d", "db": -7.4},
	],
	"formula_op": [
		{"stream": "paper_soft_a", "db": 0.4},
		{"stream": "paper_soft_b", "db": 2.6},
	],
	"preview_ok": [
		{"stream": "button_hover_b", "db": -5.9},
	],
	"preview_bad": [
		{"stream": "button_click_b", "db": -10.2},
	],
	"typing_key": [
		{"stream": "typing_key_b", "db": -1.7},
		{"stream": "typing_key_c", "db": 0.7},
		{"stream": "typing_key_d", "db": -0.9},
		{"stream": "typing_key_e", "db": -2.5},
		{"stream": "typing_key_f", "db": 0.1},
		{"stream": "typing_key_g", "db": -3.9},
	],
	"button_hover": [
		{"stream": "button_hover_b", "db": -5.9},
	],
	"button_click": [
		{"stream": "button_click_b", "db": -10.2},
		{"stream": "button_click_c", "db": -4.9},
	],
	"switch_click": [
		{"stream": "button_click_b", "db": -10.2},
		{"stream": "button_click_c", "db": -4.9},
	],
	"audio_toggle": [
		{"stream": "button_click_b", "db": -10.2},
	],
	"audio_slider_tick": [
		{"stream": "button_hover_b", "db": -5.9},
	],
	"cancel_down": [
		{"stream": "button_click_b", "db": -10.2},
	],
}

## stream, base dB, pitch, jitter, cooldown ms, priority, group.
const CUES := {
	"button_hover": {"stream": "button_hover_a", "db": -10.0, "pitch": 1.0, "jitter": 0.06, "gain_jitter": 0.8, "cool": 60, "priority": 1, "group": "hover", "length_min": 0.4, "length_max": 2.0},
	"button_click": {"stream": "button_click_a", "db": -12.0, "pitch": 1.0, "jitter": 0.05, "gain_jitter": 0.8, "cool": 45, "priority": 2, "group": "button", "length_min": 0.2, "length_max": 2.0},
	"card_hover": {"stream": "card_slide_short", "db": -17.0, "pitch": 1.02, "jitter": 0.06, "cool": 80, "priority": 1, "group": "hover"},
	"ui_click": {"stream": "ui_click", "db": -10.0, "pitch": 1.0, "jitter": 0.06, "cool": 55, "priority": 2, "group": "ui"},
	"switch_click": {"stream": "button_click_a", "db": -13.0, "pitch": 1.18, "jitter": 0.05, "gain_jitter": 0.8, "cool": 80, "priority": 2, "group": "ui", "length_min": 0.2, "length_max": 2.0},
	"ui_zoom": {"stream": "card_slide_short", "db": -20.0, "pitch": 1.45, "jitter": 0.05, "cool": 90, "priority": 1, "group": "zoom"},
	"page_whoosh": {"stream": "page_whoosh", "db": -12.0, "pitch": 1.0, "jitter": 0.05, "cool": 250, "priority": 3, "group": "nav"},
	"page_back": {"stream": "page_back", "db": -12.0, "pitch": 1.0, "jitter": 0.05, "cool": 250, "priority": 3, "group": "nav"},
	"start_confirm": {"stream": "scope_open", "db": -10.0, "pitch": 1.0, "jitter": 0.035, "cool": 400, "priority": 4, "group": "nav"},
	"level_select": {"stream": "socket_snap", "db": -12.0, "pitch": 1.02, "jitter": 0.04, "cool": 200, "priority": 3, "group": "nav"},
	"reset_sweep": {"stream": "paper_sweep", "db": -12.0, "pitch": 0.95, "jitter": 0.06, "cool": 300, "priority": 3, "group": "nav"},
	"card_lift": {"stream": "card_lift", "db": -10.0, "pitch": 1.0, "jitter": 0.08, "cool": 90, "priority": 2, "group": "drag"},
	"card_place": {"stream": "card_place", "db": -10.0, "pitch": 1.0, "jitter": 0.07, "cool": 70, "priority": 2, "group": "drag"},
	"card_detach": {"stream": "card_slide_short", "db": -14.0, "pitch": 0.9, "jitter": 0.08, "cool": 70, "priority": 2, "group": "drag"},
	"socket_snap": {"stream": "socket_snap", "db": -6.0, "pitch": 1.0, "jitter": 0.04, "cool": 100, "priority": 3, "group": "drag"},
	"soft_reject": {"stream": "card_place_soft", "db": -10.0, "pitch": 0.84, "jitter": 0.06, "cool": 200, "priority": 3, "group": "feedback"},
	"copy_stamp": {"stream": "copy", "db": -10.0, "pitch": 1.0, "jitter": 0.05, "cool": 150, "priority": 2, "group": "copy"},
	"trash_hover": {"stream": "trash_hover", "db": -16.0, "pitch": 0.9, "jitter": 0.05, "cool": 150, "priority": 1, "group": "drag"},
	"trash_delete": {"stream": "trash_delete", "db": -8.0, "pitch": 0.95, "jitter": 0.06, "cool": 250, "priority": 3, "group": "drag"},
	"goal_link": {"stream": "card_place", "db": -10.0, "pitch": 1.1, "jitter": 0.05, "cool": 120, "priority": 3, "group": "goal"},
	"rule_valid": {"stream": "marimba_c5", "db": -9.0, "pitch": 1.0, "jitter": 0.015, "cool": 130, "priority": 3, "group": "feedback"},
	"rule_error": {"stream": "error_soft", "db": -14.0, "pitch": 0.9, "jitter": 0.02, "cool": 280, "priority": 3, "group": "feedback"},
	"builder_open": {"stream": "builder_open", "db": -12.0, "pitch": 1.0, "jitter": 0.05, "cool": 250, "priority": 3, "group": "builder"},
	"formula_note": {"stream": "marimba_c4", "db": -12.0, "pitch": 1.0, "jitter": 0.01, "cool": 45, "priority": 2, "group": "token"},
	"formula_op": {"stream": "card_place_soft", "db": -14.0, "pitch": 1.2, "jitter": 0.05, "cool": 45, "priority": 2, "group": "token"},
	"typing_key": {"stream": "typing_key_a", "db": -6.0, "pitch": 1.0, "jitter": 0.10, "gain_jitter": 1.5, "cool": 18, "priority": 1, "group": "typing", "length_min": 0.85, "length_max": 1.15},
	"blip_down": {"stream": "marimba_c4", "db": -15.0, "pitch": 0.72, "jitter": 0.02, "cool": 60, "priority": 2, "group": "token"},
	"paper_sweep": {"stream": "paper_sweep", "db": -12.0, "pitch": 1.05, "jitter": 0.06, "cool": 150, "priority": 2, "group": "builder"},
	"preview_ok": {"stream": "button_hover_a", "db": -14.0, "pitch": 1.5, "jitter": 0.04, "gain_jitter": 0.5, "cool": 80, "priority": 2, "group": "feedback", "length_min": 0.4, "length_max": 2.0},
	"preview_bad": {"stream": "button_click_a", "db": -16.0, "pitch": 0.8, "jitter": 0.04, "gain_jitter": 0.5, "cool": 100, "priority": 2, "group": "feedback", "length_min": 0.2, "length_max": 2.0},
	"confirm_two": {"stream": "confirm_two", "db": -8.0, "pitch": 1.0, "jitter": 0.01, "cool": 200, "priority": 4, "group": "nav"},
	"cancel_down": {"stream": "button_click_a", "db": -14.0, "pitch": 0.85, "jitter": 0.05, "gain_jitter": 0.8, "cool": 120, "priority": 2, "group": "builder", "length_min": 0.2, "length_max": 2.0},
	"goal_valid": {"stream": "goal_valid", "db": -5.0, "pitch": 1.0, "jitter": 0.0, "cool": 700, "priority": 5, "group": "goal"},
	"goal_invalid": {"stream": "error_soft", "db": -12.0, "pitch": 0.84, "jitter": 0.02, "cool": 300, "priority": 3, "group": "goal"},
	"goal_check_empty": {"stream": "ui_click", "db": -15.0, "pitch": 1.12, "jitter": 0.05, "cool": 120, "priority": 2, "group": "goal"},
	"scope_open": {"stream": "scope_open", "db": -9.0, "pitch": 1.0, "jitter": 0.04, "cool": 220, "priority": 3, "group": "scope"},
	"scope_marker_open": {"stream": "scope_open", "db": -10.0, "pitch": 1.1, "jitter": 0.04, "cool": 220, "priority": 3, "group": "scope"},
	"scope_resume": {"stream": "card_slide", "db": -13.0, "pitch": 0.9, "jitter": 0.04, "cool": 180, "priority": 3, "group": "scope"},
	"scope_expand": {"stream": "card_slide", "db": -11.0, "pitch": 1.15, "jitter": 0.04, "cool": 180, "priority": 3, "group": "scope"},
	"scope_move_start": {"stream": "card_slide_short", "db": -20.0, "pitch": 1.08, "jitter": 0.04, "cool": 100, "priority": 1, "group": "scope"},
	"scope_move_end": {"stream": "card_slide_short", "db": -20.0, "pitch": 0.95, "jitter": 0.04, "cool": 100, "priority": 1, "group": "scope"},
	"scope_minimize": {"stream": "scope_minimize", "db": -8.0, "pitch": 1.0, "jitter": 0.04, "cool": 250, "priority": 4, "group": "scope"},
	"scope_delete": {"stream": "scope_delete", "db": -8.0, "pitch": 0.95, "jitter": 0.05, "cool": 250, "priority": 4, "group": "scope"},
	"scope_not_ready": {"stream": "error_soft", "db": -13.0, "pitch": 0.9, "jitter": 0.02, "cool": 300, "priority": 3, "group": "feedback"},
	"level_complete": {"stream": "level_complete", "db": -4.0, "pitch": 1.0, "jitter": 0.0, "cool": 1000, "priority": 5, "group": "goal"},
	"audio_toggle": {"stream": "button_click_a", "db": -12.0, "pitch": 1.08, "jitter": 0.05, "gain_jitter": 0.8, "cool": 80, "priority": 2, "group": "ui", "length_min": 0.2, "length_max": 2.0},
	"audio_slider_tick": {"stream": "button_hover_a", "db": -14.0, "pitch": 1.2, "jitter": 0.05, "gain_jitter": 0.8, "cool": 90, "priority": 1, "group": "ui", "length_min": 0.4, "length_max": 2.0},
}

var controller = null
var enabled := false
var muted := false
var volume := 0.8
## Music keeps its own level, but this node owns the shared settings file.
var music_volume := 0.8

var _players: Array[AudioStreamPlayer] = []
var _player_priority: Array[int] = []
var _player_started: Array[int] = []
var _last_cue: Dictionary = {}
var _last_group: Dictionary = {}
var _last_hover_ms := 0
var _recent_starts: Array[int] = []
var _last_variant: Dictionary = {}
var _last_group_stream: Dictionary = {}
var _settings := ConfigFile.new()
var _save_timer: Timer = null

func setup(p_controller) -> void:
	controller = p_controller
	enabled = DisplayServer.get_name() != "headless" and AudioServer.get_bus_index(SFX_BUS) >= 0
	if not enabled:
		# The convention is still useful in headless tests.
		if DisplayServer.get_name() == "headless":
			return
		_ensure_bus()
		enabled = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in range(VOICE_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_players.append(player)
		_player_priority.append(0)
		_player_started.append(0)
	_load_settings()
	_apply_volume()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.35
	_save_timer.timeout.connect(_save_settings)
	add_child(_save_timer)

func _ensure_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, SFX_BUS)
	AudioServer.set_bus_send(index, "Master")

func play(cue: String, options: Dictionary = {}) -> void:
	if not enabled or muted or not CUES.has(cue):
		return
	var meta: Dictionary = CUES[cue]
	var now := Time.get_ticks_msec()
	var cooldown := int(meta.get("cool", 0))
	if now - int(_last_cue.get(cue, -100000)) < cooldown:
		return
	var group := str(meta.get("group", ""))
	if group == "hover":
		if now - _last_hover_ms < 70:
			return
		_last_hover_ms = now
	elif not group.is_empty():
		if now - int(_last_group.get(group, -100000)) < 35:
			return
	var priority := int(meta.get("priority", 1))
	_recent_starts = _recent_starts.filter(func(t: int) -> bool: return now - t < 100)
	if _recent_starts.size() >= 6 and priority < 4:
		return

	var voice := _find_voice(priority, now)
	if voice < 0:
		return
	var variant := pick_variant(cue)
	if variant.is_empty():
		return
	var stream = STREAMS.get(str(variant.get("stream", "")))
	if stream == null:
		return
	var jitter := float(meta.get("jitter", 0.0))
	var pitch := (
		float(options.get("pitch", 1.0))
		* float(meta.get("pitch", 1.0))
		* float(variant.get("pitch", 1.0))
	)
	if jitter > 0.0:
		pitch *= 1.0 + randf_range(-jitter, jitter)
	pitch = clampf(pitch, 0.55, 2.0)
	var default_gain_jitter := 1.2 if CUE_VARIANTS.has(cue) else 0.5
	var gain_jitter := float(meta.get("gain_jitter", default_gain_jitter))
	var db := (
		float(meta.get("db", 0.0))
		+ float(variant.get("db", 0.0))
		+ float(options.get("volume_db", 0.0))
		+ randf_range(-gain_jitter, gain_jitter)
	)
	var player := _players[voice]
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = db
	player.play()
	_player_priority[voice] = priority
	_player_started[voice] = now
	_last_cue[cue] = now
	if not group.is_empty():
		_last_group[group] = now
	_recent_starts.append(now)

## Length of a named stream in seconds, or 0.0 when it is unavailable.
static func stream_length(stream_name: String) -> float:
	var stream = STREAMS.get(stream_name)
	if stream == null or not stream is AudioStream:
		return 0.0
	return stream.get_length()

## Playable variants for a cue: the base stream plus length-compatible paper
## alternates. Every entry is {stream, db, pitch, weight, length}; db/pitch are
## relative offsets. A take is only admitted when its duration stays within the
## cue's length window (default 0.75x–1.30x of the base recording), so each
## interaction keeps its characteristic action length.
static func cue_variants(cue: String) -> Array:
	if not CUES.has(cue):
		return []
	var meta: Dictionary = CUES[cue]
	var variants: Array = []
	var seen: Dictionary = {}
	var base := str(meta.get("stream", ""))
	var base_length := stream_length(base)
	if not base.is_empty() and STREAMS.has(base):
		variants.append({
			"stream": base,
			"db": 0.0,
			"pitch": 1.0,
			"weight": 1.0,
			"length": base_length,
		})
		seen[base] = true
	var min_ratio := float(meta.get("length_min", 0.75))
	var max_ratio := float(meta.get("length_max", 1.30))
	for entry in CUE_VARIANTS.get(cue, []):
		var data: Dictionary = entry
		var name := str(data.get("stream", ""))
		if name.is_empty() or not STREAMS.has(name) or seen.has(name):
			continue
		var length := stream_length(name)
		if base_length > 0.0 and length > 0.0:
			var ratio := length / base_length
			if ratio < min_ratio or ratio > max_ratio:
				continue
		seen[name] = true
		variants.append({
			"stream": name,
			"db": float(data.get("db", 0.0)),
			"pitch": float(data.get("pitch", 1.0)),
			"weight": maxf(float(data.get("weight", 1.0)), 0.0),
			"length": length,
		})
	return variants

## Choose a variant for a cue without playing it. Consecutive calls for the same
## cue never return the previous recording, so small pools alternate instead of
## replaying one sample. Returns {} for unknown or empty cues.
func pick_variant(cue: String) -> Dictionary:
	var variants := cue_variants(cue)
	if variants.is_empty():
		return {}
	var candidates: Array = variants
	var previous := str(_last_variant.get(cue, ""))
	if variants.size() > 1 and not previous.is_empty():
		var without_previous: Array = []
		for variant in variants:
			if str(variant["stream"]) != previous:
				without_previous.append(variant)
		if not without_previous.is_empty():
			candidates = without_previous
	# Also avoid repeating the last take heard in this interaction group, so a
	# lift followed by a drop does not use the same paper recording twice.
	var group := str(CUES[cue].get("group", ""))
	if candidates.size() > 1 and not group.is_empty():
		var group_previous := str(_last_group_stream.get(group, ""))
		if not group_previous.is_empty():
			var without_group_previous: Array = []
			for variant in candidates:
				if str(variant["stream"]) != group_previous:
					without_group_previous.append(variant)
			if not without_group_previous.is_empty():
				candidates = without_group_previous
	var total_weight := 0.0
	for variant in candidates:
		total_weight += float(variant["weight"])
	if total_weight <= 0.0:
		return {}
	var roll := randf() * total_weight
	var chosen: Dictionary = candidates[candidates.size() - 1]
	for variant in candidates:
		roll -= float(variant["weight"])
		if roll <= 0.0:
			chosen = variant
			break
	_last_variant[cue] = str(chosen["stream"])
	if not group.is_empty():
		_last_group_stream[group] = str(chosen["stream"])
	return chosen

func _find_voice(priority: int, now: int) -> int:
	for index in range(_players.size()):
		if not _players[index].playing:
			return index
	var oldest := -1
	var oldest_time := 9223372036854775807
	for index in range(_players.size()):
		if _player_priority[index] > priority:
			continue
		if _player_started[index] < oldest_time:
			oldest = index
			oldest_time = _player_started[index]
	return oldest

func set_muted(value: bool) -> void:
	muted = value
	if AudioServer.get_bus_index(SFX_BUS) >= 0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), muted)
	if muted:
		for player in _players:
			player.stop()
	_schedule_save()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_schedule_save()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_schedule_save()

func _apply_volume() -> void:
	var index := AudioServer.get_bus_index(SFX_BUS)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(index, muted)

func _load_settings() -> void:
	if _settings.load(SETTINGS_PATH) != OK:
		return
	muted = bool(_settings.get_value("audio", "muted", false))
	volume = clampf(float(_settings.get_value("audio", "volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(
		float(_settings.get_value("audio", "music_volume", volume)),
		0.0,
		1.0
	)

func _schedule_save() -> void:
	if _save_timer != null:
		_save_timer.start()

func _save_settings() -> void:
	_settings.set_value("audio", "muted", muted)
	_settings.set_value("audio", "volume", volume)
	_settings.set_value("audio", "music_volume", music_volume)
	_settings.save(SETTINGS_PATH)
