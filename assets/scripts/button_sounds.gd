extends Node
## Allows to play button click/hover sounds without need in creating another [AudioStreamPlayer]


func play_click_sound() -> void:
    Main.button_click_sound.play()


func play_hover_sound() -> void:
    Main.button_hover_sound.play()
