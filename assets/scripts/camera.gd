extends SpringArm3D

@export var desired_distance: float = 1
@export var step: float = 0.5

var sensitivity: float
var rot: Vector2


func _ready() -> void:
    Main.camera_container = self
    sensitivity = GameConfig.get_key("sensitivity", 1)


func _process(_delta: float) -> void:
    spring_length = lerpf(spring_length, desired_distance, 0.25)
    
    rot.y = clamp(rot.y, -90, 90)
    rotation_degrees = Vector3(rot.y, rot.x, 0)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("zoom_up"):
        desired_distance -= step
        desired_distance = max(desired_distance, 0)
    elif event.is_action_pressed("zoom_down"):
        desired_distance += step
    
    if OS.has_feature("mobile"):
        if event is InputEventScreenDrag:
            rot.x += event.relative.x * -1 * sensitivity
            rot.y += event.relative.y * -1 * sensitivity
    elif event is InputEventMouseMotion:
        rot.x += event.relative.x * -1 * sensitivity
        rot.y += event.relative.y * -1 * sensitivity
