class_name SettingsWindow
extends CenterWindow

enum TABS {
    General,
    Graphics
}

func _ready() -> void:
    %SensitivitySlider.value = GameConfig.get_key("sensitivity", 1)
    %UIScaleSlider.value = GameConfig.get_key("ui_scale", 1)
    %RenderScaleSlider.value = GameConfig.get_key("render_scale", 1)
    
    %SensitivityLabel.text = "%.2f" % %SensitivitySlider.value
    %UIScaleLabel.text = "%d%%" % int(%UIScaleSlider.value*100)
    %RenderScaleLabel.text = "%d%%" % int(%RenderScaleSlider.value*100)
    
    get_tree().root.content_scale_factor = %UIScaleSlider.value
    get_tree().root.scaling_3d_scale = %RenderScaleSlider.value
    
    if OS.has_feature("mobile"):
        %FullscreenCheckButton.disabled = true
        %FullscreenCheckButton.button_pressed = true
    else:
        %FullscreenCheckButton.button_pressed = GameConfig.get_key("fullscreen", false)
    
    %AutoRestartCheckButton.button_pressed = GameConfig.get_key("auto_restart", false)
    %GlowCheckButton.button_pressed = GameConfig.get_key("glow", true)
    %DynamicLightsCheckButton.button_pressed = GameConfig.get_key("dynamic_lights", true)
    
    var show_fps: bool = GameConfig.get_key("show_fps", false)
    %FramerateCheckButton.button_pressed = show_fps
    %FrameratePanelContainer.visible = show_fps
    
    var antialiasing: int = GameConfig.get_key("antialiasing", 0)
    %AAMenuButton.select(antialiasing)
    set_antialiasing(antialiasing)
    
    var touch_controls_enabled = GameConfig.get_key("touch_controls")
    if touch_controls_enabled:
        %TouchControlsCheckButton.button_pressed = touch_controls_enabled
    elif DisplayServer.is_touchscreen_available():
        GameConfig.set_key("touch_controls", true)
        %TouchControlsCheckButton.button_pressed = true


func _on_sensitivity_slider_value_changed(value: float) -> void:
    if Main.camera_container and is_instance_valid(Main.camera_container):
        Main.camera_container.sensitivity = value
    GameConfig.set_key("sensitivity", value)
    %SensitivityLabel.text = "%.2f" % value


func _on_ui_scale_slider_drag_ended(_value_changed: bool) -> void:
    GameConfig.set_key("ui_scale", %UIScaleSlider.value)
    get_tree().root.content_scale_factor = %UIScaleSlider.value


func _on_ui_scale_slider_value_changed(value: float) -> void:
    %UIScaleLabel.text = "%d%%" % int(value*100)


func _on_fullscreen_check_button_toggled(toggled_on: bool) -> void:
    set_fullscreen(toggled_on)
    GameConfig.set_key("fullscreen", toggled_on)


func set_fullscreen(is_fullscreen: bool) -> void:
    if is_fullscreen:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_auto_restart_check_button_toggled(toggled_on: bool) -> void:
    GameConfig.set_key("auto_restart", toggled_on)


func _on_tab_bar_tab_selected(tab: int) -> void:
    match tab:
        TABS.General:
            %GeneralSettingsContainer.show()
            %GraphicsSettingsContainer.hide()
        TABS.Graphics:
            %GraphicsSettingsContainer.show()
            %GeneralSettingsContainer.hide()
    Main.button_click_sound.play()


func _on_tab_bar_tab_hovered(_tab: int) -> void:
    Main.button_hover_sound.play()


func _on_menu_button_item_focused(_index: int) -> void:
    Main.button_hover_sound.play()


func _on_menu_button_item_selected(index: int) -> void:
    set_antialiasing(index)
    GameConfig.set_key("antialiasing", index)
    Main.button_click_sound.play()


func set_antialiasing(aa_mode: int) -> void:
    get_tree().root.set_msaa_3d(aa_mode)


func _on_render_scale_slider_value_changed(value: float) -> void:
    %RenderScaleLabel.text = "%d%%" % int(value*100)


func _on_render_scale_slider_drag_ended(_value_changed: bool) -> void:
    GameConfig.set_key("render_scale", %RenderScaleSlider.value)
    get_tree().root.scaling_3d_scale = %RenderScaleSlider.value


func _on_glow_check_button_toggled(toggled_on: bool) -> void:
    set_glow(toggled_on)
    GameConfig.set_key("glow", toggled_on)


func set_glow(is_on: bool) -> void:
    if GameInstance.is_available():
        GameInstance.instance.environment.glow_enabled = is_on


func _on_dynamic_lights_check_button_toggled(toggled_on: bool) -> void:
    GameConfig.set_key("dynamic_lights", toggled_on)
    set_dynamic_lights(toggled_on)

func set_dynamic_lights(enabled: bool) -> void:
    for light in get_tree().get_nodes_in_group("PlayerLight"):
        light.visible = enabled


func _on_framerate_check_button_toggled(toggled_on: bool) -> void:
    %FrameratePanelContainer.visible = toggled_on
    GameConfig.set_key("show_fps", toggled_on)


func _on_touch_controls_check_button_toggled(toggled_on: bool) -> void:
    GameConfig.set_key("touch_controls", toggled_on)
    set_touch_controls(toggled_on)

func set_touch_controls(enabled: bool) -> void:
    if GameInstance.touch_controls and is_instance_valid(GameInstance.touch_controls):
        GameInstance.touch_controls.visible = enabled
