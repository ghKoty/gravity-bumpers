class_name AnimationAutoPlay
extends AnimationPlayer
## Automatically starts animation in _ready()

## Name of animation to play.
@export var animation_name: String
## If set, animation will play from end.
@export var backwards: bool

func _ready() -> void:
    if not animation_name.is_empty():
        if backwards:
            play_backwards(animation_name)
            return
        
        play(animation_name)
