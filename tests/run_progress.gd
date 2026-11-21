extends SceneTree

## Headless checks for sequential unlocking, optional challenges, and
## progress persistence. Uses an in-memory store plus one temporary file.

const ProgressStoreRes = preload("res://ui/progress_store.gd")
const LevelBankRes = preload("res://ui/level_bank.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run()
	print("PROGRESS RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _run() -> void:
	var progress := ProgressStoreRes.new("")
	_check(LevelBankRes.CHAPTERS.size() == 7, "seven chapters available")
	_check(progress.is_chapter_unlocked("ch1"), "chapter 1 starts unlocked")
	_check(not progress.is_chapter_unlocked("ch2"), "chapter 2 starts locked")
	_check(progress.is_level_unlocked("ch1-1"), "first level starts unlocked")
	_check(not progress.is_level_unlocked("ch1-2"), "second level starts locked")
	_check(not progress.is_level_unlocked("ch1-star"), "challenge starts locked")
	_check(progress.next_playable_level().get("id", "") == "ch1-1", "PLAY starts at ch1-1")

	_check(progress.mark_completed("ch1-1"), "first completion is new")
	_check(not progress.mark_completed("ch1-1"), "repeat completion is not new")
	_check(progress.is_level_unlocked("ch1-2"), "solving ch1-1 unlocks ch1-2")
	_check(progress.next_playable_level().get("id", "") == "ch1-2", "PLAY advances to ch1-2")
	_check(progress.chapter_progress("ch1")["core_done"] == 1, "chapter progress counts one core")

	for level in ["ch1-2", "ch1-3", "ch1-4", "ch1-5", "ch1-6"]:
		progress.mark_completed(level)

	var ch1 := progress.chapter_progress("ch1")
	_check(ch1["core_done"] == 6, "all six core levels counted")
	_check(ch1["core_total"] == 6, "chapter core total is six")
	_check(not bool(ch1["challenge_done"]), "challenge is still incomplete")
	_check(progress.is_level_unlocked("ch1-star"), "challenge unlocks after core levels")
	_check(progress.is_level_unlocked("ch1-star2"), "second challenge unlocks after core levels")
	_check(progress.is_level_unlocked("ch1-star3"), "third challenge unlocks after core levels")
	_check(progress.is_chapter_unlocked("ch2"), "next chapter unlocks without the challenge")
	_check(progress.next_playable_level().get("id", "") == "ch2-1", "PLAY advances to ch2-1")

	progress.mark_completed("ch1-star")
	ch1 = progress.chapter_progress("ch1")
	_check(bool(ch1["challenge_done"]), "challenge completion is recorded")
	_check(progress.is_chapter_unlocked("ch2"), "challenge does not affect chapter unlock")
	_check(progress.is_level_unlocked("ch2-2") == false, "ch2 stays sequential")

	progress.mark_intro_seen("ch1")
	progress.set_last_level("ch1-star")
	_check(progress.has_seen_intro("ch1"), "seen intro is recorded")
	_check(progress.last_level_id == "ch1-star", "last level is recorded")

	# Old-save compatibility: completing the old ch6 core set unlocks ch7.
	var legacy := ProgressStoreRes.new("")
	for chapter in LevelBankRes.CHAPTERS:
		if str(chapter.get("id", "")) == "ch7":
			continue
		for level in chapter.get("levels", []):
			if not bool(level.get("optional", false)):
				legacy.mark_completed(str(level.get("id", "")))
	_check(legacy.is_chapter_unlocked("ch7"), "ch7 unlocks from old completed ch6")
	_check(legacy.is_level_unlocked("ch7-1"), "ch7-1 is playable for legacy progress")
	_check(not legacy.is_level_unlocked("ch7-2"), "ch7 stays sequential")
	_check(not legacy.is_level_unlocked("ch7-star"), "ch7 challenge stays locked until core")
	_check(
		legacy.next_playable_level().get("id", "") == "ch7-1",
		"PLAY advances legacy saves to ch7-1"
	)
	for level in LevelBankRes.chapter_levels("ch7", false):
		if str(level.get("id", "")) != "ch7-6":
			legacy.mark_completed(str(level.get("id", "")))
	legacy.mark_completed("ch7-6")
	_check(legacy.is_level_unlocked("ch7-star"), "ch7 challenge unlocks after its core")

	var file_path := "user://test_progress_%d.cfg" % Time.get_ticks_msec()
	var file_progress := ProgressStoreRes.new(file_path)
	_check(file_progress.mark_completed("ch1-1"), "file store marks a level")
	file_progress.mark_intro_seen("ch2")
	file_progress.set_last_level("ch1-1")
	file_progress.save()

	var loaded := ProgressStoreRes.new(file_path)
	_check(loaded.is_completed("ch1-1"), "completion survives save/load")
	_check(loaded.has_seen_intro("ch2"), "seen intro survives save/load")
	_check(loaded.last_level_id == "ch1-1", "last level survives save/load")

	loaded.reset()
	var empty := ProgressStoreRes.new(file_path)
	_check(not empty.is_completed("ch1-1"), "reset clears completion")
	_check(not empty.has_seen_intro("ch2"), "reset clears intros")
	_check(empty.last_level_id == "", "reset clears last level")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))

	progress.reset()
	_check(not progress.is_completed("ch1-1"), "in-memory reset clears completion")
	_check(progress.next_playable_level().get("id", "") == "ch1-1", "reset returns PLAY to ch1-1")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("PROGRESS CHECK FAILED: " + label)
