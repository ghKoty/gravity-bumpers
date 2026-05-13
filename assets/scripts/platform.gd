class_name Platform
extends RigidBody3D

enum States {NORMAL, ICE, DISSOLVED}

var current_state: States = States.NORMAL


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
    $AnimationPlayer.queue("dissolve")


func dump_multiplayer_node_state() -> Dictionary:
    var data := {
        "state": current_state
    }
    
    return data


func replicate_multiplayer_node_state(data: Dictionary) -> void:
    current_state = data["state"]
    
    match current_state:
        States.ICE:
            $AnimationPlayer.play("turn_ice", -1, 100)
        States.DISSOLVED:
            $AnimationPlayer.play("dissolve", -1, 100)
