class_name Platform
extends RigidBody3D


func turn_ice() -> void:
    physics_material_override.friction = 0.2
    turn_ice_rpc.rpc()

@rpc("authority", "call_local", "reliable") func turn_ice_rpc() -> void:
    $AnimationPlayer.queue("turn_ice")


func recover() -> void:
    physics_material_override.friction = 1
    recover_rpc.rpc()

@rpc("authority", "call_local", "reliable") func recover_rpc() -> void:
    $AnimationPlayer.play("RESET")


func dissolve() -> void:
    dissolve_rpc.rpc()

@rpc("authority", "call_local", "reliable") func dissolve_rpc() -> void:
    $AnimationPlayer.queue("get_ready")
