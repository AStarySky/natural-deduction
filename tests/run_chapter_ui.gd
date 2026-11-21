extends SceneTree

## Headless checks for the chapter page, progressive palette and ASSUME gating.

const LevelBankRes = preload("res://ui/level_bank.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	root.add_child(main)
	await process_frame
	await process_frame

	main._show_levels()
	await process_frame
	await process_frame

	var tabs := _chapter_tabs(main)
	_check(tabs.size() == 7, "chapter page renders seven chapter tabs")
	_check(_chapter_tab(main, "ch1").locked == false, "chapter 1 tab is unlocked")
	_check(_chapter_tab(main, "ch2").locked == true, "chapter 2 tab starts locked")
	_check(_level_cards(main).size() == 9, "chapter 1 shows six core levels and three challenges")
	_check(_level_card(main, "ch1-1").locked == false, "ch1-1 is playable")
	_check(_level_card(main, "ch1-2").locked == true, "ch1-2 starts locked")
	_check(_level_card(main, "ch1-star").locked == true, "challenge starts locked")
	_check(_level_card(main, "ch1-star2").locked == true, "second challenge starts locked")
	_check(_level_card(main, "ch1-star3").locked == true, "third challenge starts locked")

	# Locked chapters cannot be selected.
	main._level_page._select_chapter("ch2")
	_check(main._level_page._selected_chapter_id == "ch1", "locked chapter cannot be selected")

	# Solving the first level updates locks, completion and total progress.
	main._progress.mark_completed("ch1-1")
	main._level_page.refresh(main._progress)
	await process_frame
	await process_frame
	_check(_level_card(main, "ch1-1").completed, "completed level is marked DONE")
	_check(_level_card(main, "ch1-2").locked == false, "next level unlocks immediately")
	_check(_level_card(main, "ch1-3").locked == true, "later levels stay locked")
	_check(
		main._level_page._total_label.text.begins_with("CORE 1 / 42"),
		"total progress counts completed core levels"
	)

	# Finishing all core levels unlocks the chapter and challenge without the star.
	for level_id in ["ch1-2", "ch1-3", "ch1-4", "ch1-5", "ch1-6"]:
		main._progress.mark_completed(level_id)
	main._level_page.refresh(main._progress)
	await process_frame
	await process_frame
	_check(_chapter_tab(main, "ch2").locked == false, "chapter 2 unlocks after six core levels")
	_check(_level_card(main, "ch1-star").locked == false, "challenge unlocks after core levels")
	_check(_level_card(main, "ch1-star2").locked == false, "second challenge unlocks after core levels")
	_check(_level_card(main, "ch1-star3").locked == false, "third challenge unlocks after core levels")
	_check(_chapter_tab(main, "ch1").progress.get("core_done", 0) == 6, "chapter tab shows 6/6")

	# Selecting the newly unlocked chapter rebuilds the level grid.
	main._level_page._select_chapter("ch2")
	await process_frame
	await process_frame
	_check(main._level_page._selected_chapter_id == "ch2", "unlocked chapter can be selected")
	_check(_level_cards(main).size() == 9, "chapter 2 shows its own nine cards")
	_check(_level_card(main, "ch2-1") != null, "chapter 2 grid contains ch2-1")

	# The last core level reveals two destinations: the optional level 7 and
	# the next chapter. NEXT stays inside the chapter; NEXT CHAPTER crosses.
	main.open_level_by_id("ch1-6")
	await process_frame
	await process_frame
	main._on_goal_solved_changed(true)
	_check(not main._next_button.disabled, "solving the last core level enables NEXT")
	_check(main._next_button.text == "NEXT", "NEXT keeps its normal label")
	_check(main._next_chapter_button.visible, "last core level shows NEXT CHAPTER")
	main._on_next_level()
	await process_frame
	await process_frame
	_check(main._current_level_id == "ch1-star", "NEXT advances to optional level 7")
	main.open_level_by_id("ch1-6")
	await process_frame
	await process_frame
	_check(main._next_chapter_button.visible, "completed last core level still shows NEXT CHAPTER")
	main._on_next_chapter()
	await process_frame
	await process_frame
	_check(main._current_level_id == "ch2-1", "NEXT CHAPTER opens the next chapter")

	# Per-chapter palette and ASSUME gating.
	main.open_level_by_id("ch1-1")
	await process_frame
	await process_frame
	_check(main._current_chapter_id == "ch1", "level id selects its chapter")
	_check(main.get_tree().get_nodes_in_group("nd_rule_card").size() == 4, "ch1 palette has four cards")
	_check(not main._assume_button.visible, "ch1 hides ASSUME")

	main.open_level_by_id("ch2-1")
	await process_frame
	await process_frame
	_check(main._current_chapter_id == "ch2", "ch2 level selects its chapter")
	_check(main._assume_button.visible, "ch2 shows ASSUME")
	_check(main.get_tree().get_nodes_in_group("nd_rule_card").size() == 4, "ch2 keeps the same cards")

	main.open_level_by_id("ch6-1")
	await process_frame
	await process_frame
	_check(main.get_tree().get_nodes_in_group("nd_rule_card").size() == 9, "ch6 shows all nine cards")

	_check(_chapter_tab(main, "ch7") != null, "chapter 7 tab exists")
	main.open_level_by_id("ch7-1")
	await process_frame
	await process_frame
	_check(main._current_chapter_id == "ch7", "ch7 level selects its chapter")
	_check(main._assume_button.visible, "ch7 shows ASSUME")
	_check(main.get_tree().get_nodes_in_group("nd_rule_card").size() == 9, "ch7 shows all nine cards")

	var ch6_final := LevelBankRes.find_level("ch6-6")
	var ch6_optional: Dictionary = main._next_level_target(ch6_final)
	_check(str(ch6_optional.get("id", "")) == "ch6-star", "ch6-6 NEXT points at optional level 7")
	_check(
		str(main._next_chapter_target(ch6_final).get("id", "")) == "ch7-1",
		"ch6-6 NEXT CHAPTER points at ch7-1"
	)
	var ch7_final: Dictionary = LevelBankRes.find_level("ch7-6")
	_check(
		str(main._next_level_target(ch7_final).get("id", "")) == "ch7-star",
		"ch7-6 NEXT points at its optional level 7"
	)
	_check(main._next_chapter_target(ch7_final).is_empty(), "final chapter has no NEXT CHAPTER")

	main.queue_free()
	await process_frame
	print("CHAPTER UI RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _chapter_tabs(main) -> Array:
	return main.get_tree().get_nodes_in_group("nd_chapter_tab")

func _chapter_tab(main, chapter_id: String):
	for tab in _chapter_tabs(main):
		if tab.chapter_id == chapter_id:
			return tab
	return null

func _level_cards(main) -> Array:
	return main.get_tree().get_nodes_in_group("nd_level_card")

func _level_card(main, level_id: String):
	for card in _level_cards(main):
		if card.level_id == level_id:
			return card
	return null

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHAPTER UI CHECK FAILED: " + label)
