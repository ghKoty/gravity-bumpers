class_name ErrorWindow
extends CenterWindow

static var error_text: String = "Something bad happend and we don't know what"

func _ready() -> void:
    super()
    %Label.text = ErrorWindow.error_text


func _on_quit_button_pressed() -> void:
    get_tree().quit()
