extends Node3D

var PlayerScene = preload("res://assets/prefabs/player.tscn")
## Colors that are not occupied by any player.
var free_colors: PackedColorArray


func _ready() -> void:
    if is_multiplayer_authority():
        free_colors = PackedColorArray(Main.PLAYERS_COLORS)


func spawn(id: int) -> Node:
    var color := free_colors[-1]
    free_colors.remove_at(free_colors.size() - 1)
    _spawn.rpc(id, color)
    return spawn_player_node(id, color)


@rpc("authority", "call_remote", "reliable") func _spawn(id: int, color: Color) -> void:
    spawn_player_node(id, color)


func spawn_player_node(id: int, color: Color) -> Node:
    var player = PlayerScene.instantiate()
    player.set_multiplayer_authority(id)
    player.player_color = color
    add_child(player)
    player.name = str(id)
    return player


func remove_player(id: int) -> void:
    free_colors.append(get_node(str(id)).player_color)
    _remove_player.rpc(id)


@rpc("authority", "call_local", "reliable") func _remove_player(id: int) -> void:
    var player = get_node(str(id))
    player.queue_free()
