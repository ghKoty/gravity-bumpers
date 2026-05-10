class_name CenterWindow
extends Window
## Centers subwindow inside main window.

func _ready() -> void:
    get_tree().root.size_changed.connect(update_position)
    update_position()


func update_position() -> void:
    move_to_center()


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        close_requested.emit()
