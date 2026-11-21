extends SceneTree

## Headless CLI entry point.
##
## Run:
##   godot --headless --path <project> -s res://cli/main.gd
## Optional batch file (single session):
##   godot --headless --path <project> -s res://cli/main.gd -- --file <path>

const CliSessionRes = preload("res://cli/cli_session.gd")
const CommandResultRes = preload("res://cli/command_result.gd")

## MainLoop entry: run the REPL/file once, then exit with a process code.
func _initialize() -> void:
	var user_args := OS.get_cmdline_user_args()
	var file_path := ""
	var file_argument_error := false
	var index := 0
	while index < user_args.size():
		if user_args[index] == "--file":
			if index + 1 < user_args.size():
				file_path = user_args[index + 1]
				index += 2
				continue
			file_argument_error = true
		index += 1

	if file_argument_error:
		print("error: --file requires a command file path")
		quit(1)
		return

	var session := CliSessionRes.new()
	var exit_code := 0
	if file_path != "":
		exit_code = _run_file(file_path, session)
	else:
		exit_code = _run_stdin(session)
	quit(exit_code)

## Execute a single-session command file.
func _run_file(path: String, session: CliSessionRes) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print(
			"error: cannot open command file '%s' (error %d)"
			% [path, FileAccess.get_open_error()]
		)
		return 1
	var text := file.get_as_text()
	file.close()
	_run_text(text, session)
	return 0

## Choose interactive console input or a piped/redirected stdin stream.
func _run_stdin(session: CliSessionRes) -> int:
	if OS.get_stdin_type() == OS.STD_HANDLE_CONSOLE:
		return _run_console(session)
	return _run_pipe(session)

## Line-by-line interactive prompt for a real terminal.
func _run_console(session: CliSessionRes) -> int:
	print("Natural Deduction CLI - type 'help' for commands, 'quit' to exit.")
	while true:
		printraw("> ")
		var line := OS.read_string_from_stdin(4096)
		if line.is_empty():
			print("")
			break
		var result := session.execute(line)
		_print_result(result)
		if result.quit_requested:
			break
	return 0

## Read piped/redirected stdin byte-by-byte so pty-backed terminals still
## behave like a line-oriented REPL while ordinary pipes finish at EOF.
func _run_pipe(session: CliSessionRes) -> int:
	print("Natural Deduction CLI - type 'help' for commands, 'quit' to exit.")
	printraw("> ")
	var pending := PackedByteArray()
	while true:
		var chunk := OS.read_buffer_from_stdin(1)
		if chunk.is_empty():
			break
		pending.append_array(chunk)
		while true:
			var newline_index := pending.find(10)
			if newline_index < 0:
				break
			var line_bytes := pending.slice(0, newline_index)
			pending = pending.slice(newline_index + 1)
			if _execute_line_bytes(line_bytes, session):
				print("")
				return 0
			printraw("> ")
	if not pending.is_empty():
		_execute_line_bytes(pending, session)
	print("")
	return 0

## Execute one raw stdin line; returns true when the session asked to quit.
func _execute_line_bytes(bytes: PackedByteArray, session: CliSessionRes) -> bool:
	if not bytes.is_empty() and bytes[bytes.size() - 1] == 13:
		bytes = bytes.slice(0, bytes.size() - 1)
	var line := bytes.get_string_from_utf8()
	if not line.is_empty() and line.unicode_at(0) == 0xFEFF:
		line = line.substr(1)
	var result := session.execute(line)
	_print_result(result)
	return result.quit_requested

## Execute every line in a block of text; comments and blanks are ignored.
func _run_text(text: String, session: CliSessionRes) -> void:
	if not text.is_empty() and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var normalized := text.replace("\r\n", "\n").replace("\r", "\n")
	for line in normalized.split("\n"):
		var result := session.execute(line)
		_print_result(result)
		if result.quit_requested:
			break

## Print the display lines produced by one command.
func _print_result(result: CommandResultRes) -> void:
	for line in result.lines:
		print(line)
