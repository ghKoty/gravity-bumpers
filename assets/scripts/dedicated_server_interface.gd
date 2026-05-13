extends Node

var input_thread: Thread

func _ready() -> void:
    await get_tree().process_frame
    if Main.is_dedicated_server:
        input_thread = Thread.new()
        input_thread.start(_console_input_loop)
        if not "--skip-start" in OS.get_cmdline_args():
            Main.instance._on_start_button_pressed()


func _console_input_loop():
    while true:
        var input = OS.read_string_from_stdin().strip_edges()
        
        if input != "":
            _handle_command.call_deferred(input)
        
        OS.delay_msec(10)


func _handle_command(command: String):
    match command.to_lower():
        "help", "?":
            Console.instance.print_to_console("Available commands:\nstart; s - Start game\nleave; l - Leave lobby and create a new one\nhost; h - Host new lobby (if --skip-host startup arg is present)\nquit; q; exit; stop; shutdown - Stop server")
        "start", "s":
            if not Main.ingame:
                Main.instance._on_start_button_pressed()
        "leave", "l":
            Main.instance._on_leave_button_pressed()
        "host", "h":
            if Main.lan_mode:
                Main.instance._on_host_button_pressed()
        "quit", "q", "exit", "stop", "shutdown":
            Main.instance.quit()
        _:
            Console.instance.print_to_console("Unknown command: %s\nType help for list of available commands" % command)


func _exit_tree():
    if input_thread and input_thread.is_alive():
        pass
