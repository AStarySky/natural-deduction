extends RefCounted

## Chapter/level completion and unlock state. Path "" is an in-memory store,
## which is useful for headless tests; the real game uses user://progress.cfg.

const LevelBankRes = preload("res://ui/level_bank.gd")

const DEFAULT_PATH := "user://progress.cfg"
const VERSION := 1

var path: String = DEFAULT_PATH
var completed: Dictionary = {}
var seen_intros: Dictionary = {}
var last_level_id: String = ""

func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	if not path.is_empty():
		load_progress()

## Load a progress file, treating missing/corrupt data as an empty store.
func load_progress() -> void:
	completed.clear()
	seen_intros.clear()
	last_level_id = ""
	if path.is_empty():
		return
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var stored_completed = config.get_value("progress", "completed", {})
	if stored_completed is Dictionary:
		for key in stored_completed:
			if bool(stored_completed[key]):
				completed[str(key)] = true
	var stored_intros = config.get_value("progress", "seen_intros", {})
	if stored_intros is Dictionary:
		for key in stored_intros:
			if bool(stored_intros[key]):
				seen_intros[str(key)] = true
	last_level_id = str(config.get_value("progress", "last_level_id", ""))

## Persist the store immediately. Progress writes are infrequent.
func save() -> void:
	if path.is_empty():
		return
	var config := ConfigFile.new()
	config.set_value("progress", "version", VERSION)
	config.set_value("progress", "completed", completed)
	config.set_value("progress", "seen_intros", seen_intros)
	config.set_value("progress", "last_level_id", last_level_id)
	config.save(path)

## Clear all completion and intro state.
func reset() -> void:
	completed.clear()
	seen_intros.clear()
	last_level_id = ""
	save()

## Mark a level complete. Returns true only for a newly completed level.
func mark_completed(level_id: String) -> bool:
	if level_id.is_empty() or completed.has(level_id):
		return false
	completed[level_id] = true
	save()
	return true

func is_completed(level_id: String) -> bool:
	return completed.has(level_id)

func mark_intro_seen(chapter_id: String) -> void:
	if chapter_id.is_empty() or seen_intros.has(chapter_id):
		return
	seen_intros[chapter_id] = true
	save()

func has_seen_intro(chapter_id: String) -> bool:
	return seen_intros.has(chapter_id)

func set_last_level(level_id: String) -> void:
	if last_level_id == level_id:
		return
	last_level_id = level_id
	save()

## Ch1 is always open; later chapters need every core level of the previous one.
func is_chapter_unlocked(chapter_id: String) -> bool:
	var index := LevelBankRes.chapter_index(chapter_id)
	if index < 0:
		return false
	if index == 0:
		return true
	var previous: Dictionary = LevelBankRes.CHAPTERS[index - 1]
	for level in previous.get("levels", []):
		if bool(level.get("optional", false)):
			continue
		if not is_completed(str(level.get("id", ""))):
			return false
	return true

## Core levels unlock in order; the challenge opens after all six core levels.
func is_level_unlocked(level_id: String) -> bool:
	var level := LevelBankRes.find_level(level_id)
	if level.is_empty():
		return false
	if is_completed(level_id):
		return true
	var chapter_id := str(level.get("chapter_id", ""))
	if not is_chapter_unlocked(chapter_id):
		return false
	var core_ids: Array[String] = []
	for entry in LevelBankRes.chapter_levels(chapter_id, false):
		core_ids.append(str(entry.get("id", "")))
	if bool(level.get("optional", false)):
		for core_id in core_ids:
			if not is_completed(core_id):
				return false
		return true
	var position := core_ids.find(level_id)
	if position < 0:
		return false
	return position == 0 or is_completed(core_ids[position - 1])

## Progress summary for a chapter tab.
func chapter_progress(chapter_id: String) -> Dictionary:
	var core_done := 0
	var core_total := 0
	var challenge_done := false
	for level in LevelBankRes.chapter_levels(chapter_id, false):
		core_total += 1
		if is_completed(str(level.get("id", ""))):
			core_done += 1
	for level in LevelBankRes.chapter_levels(chapter_id, true):
		if is_completed(str(level.get("id", ""))):
			challenge_done = true
	return {
		"core_done": core_done,
		"core_total": core_total,
		"challenge_done": challenge_done,
		"unlocked": is_chapter_unlocked(chapter_id),
	}

## First unlocked, unfinished core level; challenges are never auto-selected.
func next_playable_level() -> Dictionary:
	for level in LevelBankRes.all_levels():
		if bool(level.get("optional", false)):
			continue
		var level_id := str(level.get("id", ""))
		if is_level_unlocked(level_id) and not is_completed(level_id):
			return level
	return {}
