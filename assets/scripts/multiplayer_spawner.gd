extends MultiplayerSpawner

var PlayerScene = preload("res://assets/prefabs/player.tscn")
var players := {}
var players_counter: int = 0

func _ready() -> void:
    spawn_function = spawn_player


func spawn_player(id):
    var player = PlayerScene.instantiate()
    player.set_multiplayer_authority(id)
    players[id] = player
    player.name = str(id)
    player.player_color = Main.PLAYERS_COLORS[players_counter]
    player.player_number = players_counter
    players_counter += 1
    return player


func remove_player(id) -> void:
    var player = players[id]
    players.erase(id)
    player.queue_free()
