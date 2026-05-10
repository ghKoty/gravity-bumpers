extends Button

@export_multiline("Help text to show") var help_text: String

func show_help() -> void:
    %HelpLabel.text = help_text
    %HelpPopupPanel.size.y = 0
    %HelpPopupPanel.popup_centered()
