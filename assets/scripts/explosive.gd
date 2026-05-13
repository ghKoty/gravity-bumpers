class_name Explosive
extends Node3D

@export var explosion_force: float = 20.0


func _ready() -> void:
    if is_multiplayer_authority():
        recover()
    else:
        $Area3D/CollisionShape3D.disabled = true
        $RigidBody3D/CollisionShape3D.disabled = true


func spawn() -> void:
    $Area3D/CollisionShape3D.disabled = false
    $RigidBody3D/CollisionShape3D.disabled = false
    spawn_rpc.rpc()

@rpc("authority", "call_local", "reliable") func spawn_rpc() -> void:
    $Cylinder.show()


func recover() -> void:
    $Area3D/CollisionShape3D.disabled = true
    $RigidBody3D/CollisionShape3D.disabled = true
    if is_multiplayer_authority():
        recover_rpc.rpc()

@rpc("authority", "call_local", "reliable") func recover_rpc() -> void:
    $Cylinder.hide()


func explode() -> void:
    recover()
    explode_rpc.rpc()
    for body in $ExplosionArea3D.get_overlapping_bodies():
        if body is Player:
            var direction = body.global_position - self.global_position
            var distance = direction.length()
            var force_strength = (1.0 - (distance / $ExplosionArea3D/CollisionShape3D.shape.radius)) * explosion_force
            var impulse = direction.normalized() * force_strength
            body.apply_impulse(impulse)

@rpc("authority", "call_local", "reliable") func explode_rpc() -> void:
    $AnimationPlayer.play("RESET")
    $AnimationPlayer.queue("explosion")


func _on_area_3d_body_entered(_body: Node3D) -> void:
    if is_multiplayer_authority():
        explode()


func dump_multiplayer_node_state() -> Dictionary:
    var data := {
        "state": $Cylinder.visible
    }
    
    return data


func replicate_multiplayer_node_state(data: Dictionary) -> void:
    if data["state"]:
        spawn_rpc()
    else:
        recover_rpc()
