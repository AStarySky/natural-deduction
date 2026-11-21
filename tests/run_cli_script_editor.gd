@tool
extends EditorScript

## Editor-runnable entry for the Natural Deduction CLI acceptance suite.
##
## How to use:
##   1. Open this file in the Script workspace.
##   2. File > Run (or Ctrl+Shift+X).
##   3. Read the A-G summary in the editor's Output panel.
##
## This wrapper launches the existing headless runner
## (res://tests/run_cli_script.gd) as a subprocess, so there is only one
## implementation of the assertions. The interactive CLI (res://cli/main.gd)
## still requires a real terminal: the editor does not provide stdin.

const RUNNER_SCRIPT := "res://tests/run_cli_script.gd"

## File > Run calls this function inside the editor process.
func _run() -> void:
	var project_root := ProjectSettings.globalize_path("res://")
	var godot_binary := _resolve_godot_binary()
	print("Running Natural Deduction CLI acceptance suite...")
	print("Godot binary: " + godot_binary)
	print("Project: " + project_root)

	var arguments := PackedStringArray([
		"--headless",
		"--path", project_root,
		"-s", RUNNER_SCRIPT,
	])
	var captured: Array = []
	var exit_code := OS.execute(godot_binary, arguments, captured, true)
	for chunk in captured:
		print(str(chunk))
	print("EDITOR TEST EXIT: %d" % exit_code)
	if exit_code != 0:
		printerr("EDITOR TEST FAILED (exit %d)" % exit_code)

## Prefer the console build so stdout/stderr are reliably captured on Windows.
func _resolve_godot_binary() -> String:
	var executable := OS.get_executable_path()
	if executable.ends_with("_console.exe"):
		return executable
	var console_candidate := executable.get_basename() + "_console.exe"
	if FileAccess.file_exists(console_candidate):
		return console_candidate
	return executable
