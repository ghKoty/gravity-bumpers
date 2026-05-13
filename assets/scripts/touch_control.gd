extends Control

func _ready() -> void:
    visible = GameConfig.get_key("touch_controls")
    $MovementVirtualJoystick.size.x = get_tree().root.size.x * 0.2 / $MovementVirtualJoystick.scale.x / get_tree().root.content_scale_factor
    $MovementVirtualJoystick.size.y = get_tree().root.size.y
