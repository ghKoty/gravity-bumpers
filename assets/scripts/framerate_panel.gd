extends PanelContainer

func _process(_delta: float) -> void:
    if is_visible_in_tree():
        $FramerateLabel.text = "%d FPS\n%.1f ms" % [int(Performance.get_monitor(Performance.TIME_FPS)),
                Performance.get_monitor(Performance.TIME_PROCESS) * 1000]
