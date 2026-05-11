class_name GameInstance
extends Node3D

# platform_dissolve appears 3 times for additional weight in random
const EVENT_TYPES: Array = ["platform_dissolve", "platform_dissolve", "platform_dissolve", "explosives", "ice_floor"]

## Contains self.
static var instance: GameInstance
## Contains parent node of all players.
static var players: MultiplayerSpawner
static var default_camera_position: Marker3D
static var spawn_positions: PackedVector3Array
static var environment: Environment
static var touch_controls: Control

@export var min_event_time: float = 15
@export var max_event_time: float = 35

var round_ended: bool = true
var platforms: Array[Array]
var left_platforms: Array[Array]
var platforms_to_turn_ice: Array[Platform]

func _ready() -> void:
    default_camera_position = $DefaultCameraPosition
    instance = self
    players = $PlayersMultiplayerSpawner
    environment = $WorldEnvironment.environment
    touch_controls = $TouchControl
    
    environment.glow_enabled = GameConfig.get_key("glow", false)
    
    if is_multiplayer_authority():
        # For some reason i can`t just write %RoundEndWindow.close_requested.disconnect(hide_round_end_screen)
        var connections = %RoundEndWindow.close_requested.get_connections()
        for connection in connections:
            if connection["callable"].get_object() == self:
                %RoundEndWindow.close_requested.disconnect(connection["callable"])
        %HostButtonsHBoxContainer.show()
        %ClientButtonsHBoxContainer.hide()
    
        for i in 3:
            platforms.append([])
    
        for platform in $Platforms.get_children():
            platforms_to_turn_ice.append(platform)
            var platform_number = int(platform.name.lstrip("Platform"))
            if platform_number > 16:
                platforms[2].append(platform)
            elif platform_number > 4:
                platforms[1].append(platform)
            else:
                platforms[0].append(platform)
        
        left_platforms = platforms.duplicate(true)
        
        spawn_positions = []
        for child in $SpawnPositions.get_children():
            spawn_positions.append(child.global_position)
        
        restart_round.call_deferred()


func _physics_process(_delta: float) -> void:
    if is_multiplayer_authority():
        if not round_ended:
            if Main.lobby_players_ids.size() > 1 and Main.alive_players_ids.size() == 1:
                show_round_end_screen.rpc(false, Main.alive_players_ids[0])
                Main.spawned_players[Main.alive_players_ids[0]].die()
                stop_round()
            elif Main.alive_players_ids.is_empty():
                show_round_end_screen.rpc()
                stop_round()


func _exit_tree() -> void:
    instance = null
    players = null
    default_camera_position = null
    spawn_positions.clear()
    environment = null
    touch_controls = null


func go_visible() -> void:
    for child in get_children():
        if child.has_method("set_visible"):
            child.set_visible(true)
    process_mode = Node.PROCESS_MODE_INHERIT


func start_event_timer() -> void:
    $EventTimer.start(randf_range(min_event_time, max_event_time))


func clear_world() -> void:
    left_platforms = platforms.duplicate(true)
    
    for platform in $Platforms.get_children():
        platforms_to_turn_ice.append(platform)
        platform.recover()
    
    var explosives = $Explosives.get_children()
    for explosive in explosives:
        explosive.recover()


func restart_round() -> void:
    %RoundAutoRestartTimer.stop()
    clear_world()
    for player in Main.spawned_players:
        Main.spawned_players[player].revive()
    hide_round_end_screen.rpc()
    round_ended = false
    start_event_timer()


func stop_round() -> void:
    if GameConfig.get_key("auto_restart", false):
        %RoundAutoRestartTimer.start()
    $EventTimer.stop()
    round_ended = true


@rpc("authority", "call_local", "reliable") func show_round_end_screen(is_tie: bool = true, winner_player_id: int = -1) -> void:
    if is_tie:
        %RoundEndLabel.text = "Tie! (No one won)"
    else:
        %RoundEndLabel.text = "%s won!" % Main.lobby_players_nicknames[winner_player_id]
    fix_touch_joystick()
    for i in 2:
        await get_tree().process_frame
    %RoundEndWindow.popup_centered()
    MouseManager.use_mouse(%RoundEndWindow)


@rpc("authority", "call_local", "reliable") func hide_round_end_screen() -> void:
    %RoundEndWindow.hide()
    MouseManager.free_mouse(%RoundEndWindow)


func fix_touch_joystick() -> void:
    # HACK: Sends empty InputEventScreenTouch to unpress joystick
    var event: InputEventScreenTouch
    for i in range(10):
        event = InputEventScreenTouch.new()
        event.position = %MovementVirtualJoystick.position + %MovementVirtualJoystick.scale / get_tree().root.content_scale_factor / 2
        event.index = i
        Input.parse_input_event(event)


func _on_play_again_button_pressed() -> void:
    restart_round()


func _on_event_timer_timeout() -> void:
    var event_type = EVENT_TYPES.pick_random()
    
    if event_type == "platform_dissolve":
        var platforms_to_dissolve: Array
        if not left_platforms[2].is_empty():
            platforms_to_dissolve = left_platforms[2]
        elif not left_platforms[1].is_empty():
            platforms_to_dissolve = left_platforms[1]
        else:
            platforms_to_dissolve = left_platforms[0]
        
        for i in 3:
            if platforms_to_dissolve.is_empty():
                break
            var platform = platforms_to_dissolve.pick_random()
            platforms_to_dissolve.erase(platform)
            platforms_to_turn_ice.erase(platform)
            platform.dissolve()
    
    elif event_type == "explosives":
        var explosives = $Explosives.get_children()
        for i in 6:
            explosives.pick_random().spawn()
    
    elif event_type == "ice_floor":
        for i in 5:
            if platforms_to_turn_ice.is_empty():
                break
            var platform = platforms_to_turn_ice.pick_random()
            platforms_to_turn_ice.erase(platform)
            platform.turn_ice()
            
    
    start_event_timer()


func _on_disconnect_button_pressed() -> void:
    Main.instance.leave_lobby_and_host()


static func is_available() -> bool:
    return GameInstance.instance and is_instance_valid(GameInstance.instance)
