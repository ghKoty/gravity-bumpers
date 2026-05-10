class_name LanLobbyPanel
extends PanelContainer

func initialize(new_ip_address: String, new_nickname: String) -> void:
    %RemoveTimer.start()
    %NicknameLabel.text = new_nickname
    %IPLabel.text = new_ip_address


func update(new_nickname: String) -> void:
    %RemoveTimer.start()
    %NicknameLabel.text = new_nickname


func _on_button_pressed() -> void:
    Main.instance.lan_connect(%IPLabel.text)
    Main.lan_join_window.hide()


func _on_button_down() -> void:
    Main.button_click_sound.play()


func _on_mouse_entered() -> void:
    Main.button_hover_sound.play()


func _on_remove_timer_timeout() -> void:
    Main.lan_join_window.lobbies_buttons.erase(%IPLabel.text)
    queue_free()
