extends CenterWindow

const INVALID_IP_COLOR: Color = Color.RED
const VALID_IP_COLOR: Color = Color.GREEN

@export var ip_line_edit_stylebox: StyleBoxFlat

func _on_ip_line_edit_text_changed(new_text: String) -> void:
    if Main.is_ipv4_valid(new_text):
        %JoinWindowJoinButton.disabled = false
        ip_line_edit_stylebox.border_color = VALID_IP_COLOR
    else:
        %JoinWindowJoinButton.disabled = true
        ip_line_edit_stylebox.border_color = INVALID_IP_COLOR


func _on_lan_join_button_pressed() -> void:
    Main.instance.lan_connect(%IPLineEdit.text)
    hide()


func _on_ip_line_edit_text_submitted(new_text: String) -> void:
    if Main.is_ipv4_valid(new_text):
        Main.instance.lan_connect(%IPLineEdit.text)
        hide()
