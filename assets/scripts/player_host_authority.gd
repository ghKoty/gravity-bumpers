class_name PlayerHostAuthority
extends Node3D

@onready var player = get_parent() as Player


func _ready() -> void:
    set_multiplayer_authority(1)


# MultiplayerSynchronizer behaves unstable for me, so here`s simple code for position/rotation sync
@rpc("authority", "call_local", "unreliable") func update_transform(new_position: Vector3, new_rotation: Vector3) -> void:
    player.global_position = new_position
    player.global_rotation = new_rotation


@rpc("authority", "call_local", "reliable") func die_rpc() -> void:
    player.visible = false


@rpc("authority", "call_local", "reliable") func revive_rpc() -> void:
    player.visible = true
