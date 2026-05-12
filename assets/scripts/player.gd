class_name Player
extends RigidBody3D
## Logic for the physics-based player character.

## Player`s movement speed.
@export var speed: float = 1
## Upward impulse force applied to player when jumping.
@export var jump_force: float = 7
## Frame-based cooldown to prevent jump spamming on the server.
@export var jump_cooldown_frames: int = 30
## Multiplier for movement forces applied while the player is in air.
@export var in_air_speed_multiplier: float = 0.1
## Strength of the dash impulse.
@export var dash_multiplier: float = 10
## Visual/UI cooldown for the client-side dash indicator.
@export var dash_client_cooldown: float = 2
## Actual server-side cooldown to prevent dash exploitation.
@export var dash_server_cooldown: float = 1.9
## Multiplier for the impulse applied when two players collide.
@export var push_multiplier: float = 1
@export var nickname_Label: Label3D
@export var light: Light3D
## A non-rotating node that will follow player position. Used for camera attachment and stable positioning.
@export var no_rotation: Node3D
@export var ground_trigger: Area3D

var player_color: Color
var input_vector: Vector2
var rotation_vector: Vector2
var old_input_vector: Vector2
var should_jump: bool
var should_dash: bool
var is_dash_in_server_cooldown: bool
var is_dash_in_client_cooldown: bool
var velocity_history: Array[Vector3]
var player_number: int = 0
var jump_cooldown: int = 0

@onready var dash_server_cooldown_timer = $DashServerCooldownTimer as Timer
@onready var host_authority = $HostAuthority as PlayerHostAuthority


func _ready() -> void:
    if Main.mp_peer.get_unique_id() != 1:
        freeze = true
    
    if is_multiplayer_authority():
        Main.dash_client_cooldown_timer.timeout.connect(_on_dash_client_cooldown_timeout)
        Main.camera_container.reparent(no_rotation)
    
    nickname_Label.text = Main.lobby_players_nicknames[get_multiplayer_authority()]
    nickname_Label.modulate = player_color
    light.light_color = player_color
    light.visible = GameConfig.get_key("dynamic_lights", false)
    var material = $MeshInstance3D.get_surface_override_material(0) as ShaderMaterial
    material.set_shader_parameter("color", player_color)
    material.next_pass.emission = player_color


func _process(_delta: float) -> void:
    if is_multiplayer_authority():
        $MeshInstance3D.visible = get_tree().root.get_camera_3d().global_position.distance_to(global_position) > 0.7
    
    no_rotation.global_position = global_position
    
    if is_multiplayer_authority():
        Main.dash_cooldown_indicator.visible = not Main.dash_client_cooldown_timer.is_stopped()
        Main.dash_cooldown_indicator.value = Main.dash_client_cooldown_timer.time_left
        
        input_vector = Input.get_vector("ui_up", "ui_down", "ui_right", "ui_left")
        input_vector = input_vector.rotated(-Main.camera_container.global_rotation.y)
        
        if ground_trigger.get_overlapping_bodies().size() > 0 and Input.is_action_just_pressed("ui_accept"):
            jump.rpc_id(1)
        
        if not is_dash_in_client_cooldown and Input.is_action_just_pressed("dash"):
            is_dash_in_client_cooldown = true
            dash.rpc_id(1)
            Main.dash_client_cooldown_timer.start(dash_client_cooldown)
        
        if input_vector != old_input_vector:
            old_input_vector = input_vector
            update_input.rpc_id(1, input_vector)


func _physics_process(_delta: float) -> void:
    if Main.mp_peer.get_unique_id() == 1:
        if jump_cooldown > 0:
            jump_cooldown -= 1
        
        velocity_history.push_back(linear_velocity)
        if velocity_history.size() > 2:
            velocity_history.pop_front()
        
        host_authority.update_transform.rpc(global_position, global_rotation)
        
        if position.y < -5:
            die()
        
        apply_torque(Vector3(rotation_vector.x, 0, rotation_vector.y))
        apply_central_force(Vector3(-rotation_vector.y, 0, rotation_vector.x) * in_air_speed_multiplier)
        
        if should_jump:
            should_jump = false
            apply_impulse(Vector3.UP * jump_force)
        
        if should_dash:
            is_dash_in_server_cooldown = true
            should_dash = false
            apply_central_impulse(Vector3(-rotation_vector.y, 0, rotation_vector.x) * dash_multiplier)
            dash_server_cooldown_timer.start(dash_server_cooldown)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    state.angular_velocity = state.angular_velocity.lerp(Vector3(rotation_vector.x, 0, rotation_vector.y), 0.2)


func _exit_tree() -> void:
    Main.dash_client_cooldown_timer.timeout.disconnect(_on_dash_client_cooldown_timeout)


func _on_visibility_changed() -> void:
    if is_multiplayer_authority():
        if is_visible_in_tree():
            Main.camera_container.reparent(no_rotation, false)
        else:
            Main.camera_container.reparent(GameInstance.default_camera_position, false)


func _on_body_entered(body):
    if body is Player and Main.mp_peer.get_unique_id() == 1:
        if velocity_history.is_empty() or body.velocity_history.is_empty():
            return
        var bounce_dir = self.global_position - body.global_position
        bounce_dir.y *= 0.1
        bounce_dir = bounce_dir.normalized()
        
        var closing_speed = body.velocity_history[-1].dot(bounce_dir)
        
        var impact_intensity = abs(closing_speed)
        if impact_intensity > 0.1:
            var final_force = impact_intensity * push_multiplier
            self.apply_central_impulse(bounce_dir * final_force)


func die() -> void:
    Main.alive_players_ids.erase(get_multiplayer_authority())
    host_authority.die_rpc.rpc()
    freeze = true
    %CollisionShape3D.disabled = true
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    position = Vector3(0, 1, 0)


func revive() -> void:
    dash_server_cooldown_timer.stop()
    _on_dash_server_cooldown_timeout()
    Main.alive_players_ids.append(get_multiplayer_authority())
    global_position = GameInstance.spawn_positions[player_number]
    host_authority.revive_rpc.rpc()
    %CollisionShape3D.disabled = false
    freeze = false


func _on_dash_client_cooldown_timeout() -> void:
    is_dash_in_client_cooldown = false


func _on_dash_server_cooldown_timeout() -> void:
    is_dash_in_server_cooldown = false


## Synchronizes movement inputs from the local client to the server.
@rpc("authority", "call_local", "reliable") func update_input(new_input_vector: Vector2) -> void:
    rotation_vector = new_input_vector.normalized() * speed


## Requests the server to perform a jump.
@rpc("authority", "call_local", "reliable") func jump() -> void:
    if jump_cooldown == 0:
        jump_cooldown = jump_cooldown_frames
        should_jump = true


## Requests the server to perform a dash.
@rpc("authority", "call_local", "reliable") func dash() -> void:
    if not is_dash_in_server_cooldown:
        should_dash = true
