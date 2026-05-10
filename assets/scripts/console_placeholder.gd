class_name Console
extends Node
## Replaces LK Console.

const INFO_COLOR: Color = Color.GRAY
const WARNING_COLOR: Color = Color("ffff70")
const ERROR_COLOR: Color = Color("ff7070")

static var instance: Console


func _ready() -> void :
    Console.instance = self


## Prints [param text] to engine output with [param color].
func print_to_console(text, color: Color = INFO_COLOR) -> void :
    text = str(text)

    color = Color(color, 1.0)

    print_rich("[color=%s]%s[/color]" % [color.to_html(false), text])
