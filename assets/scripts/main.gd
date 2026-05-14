class_name Main
extends Node3D
## The core controller for the multiplayer game instance.
## Handles Steam API initialization, ENet-based LAN fallbacks, 
## peer-to-peer authentication, and game state management.

## Human-readable names for Steam chat room enter responses.
const STEAM_CHAT_ROOM_ENTER_RESPONSE_NAMES = ["NONE", "CHAT_ROOM_ENTER_RESPONSE_SUCCESS", "CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST", "CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED", "CHAT_ROOM_ENTER_RESPONSE_FULL", "CHAT_ROOM_ENTER_RESPONSE_ERROR", "CHAT_ROOM_ENTER_RESPONSE_BANNED", "CHAT_ROOM_ENTER_RESPONSE_LIMITED", "CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED", "CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN", "CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU", "CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER", "CHAT_ROOM_ENTER_RESPONSE_RATE_LIMIT_EXCEEDED"]
const PLAYERS_COLORS = [Color("9e02ff"), Color("faff02"), Color("4102ff"), Color("ff00e5"), Color("ff8903"), Color("00ffff"), Color("55ff00"), Color("ff0000")]
const MAX_PLAYERS = 8
## Time in seconds allowed for a client to authenticate before being kicked.
const AUTHENTICATION_TIMEOUT: float = 2
## Standard port used for ENet LAN communication.
const LAN_PORT: int = 62535
## Port used for UDP broadcasting to discover lobbies on the local network.
const LAN_ADVERTISEMENT_PORT: int = 62536

## Contains [Main] instance (self).
static var instance: Main
## Contains all players peer IDs in the current session.
static var lobby_players_ids: PackedInt64Array = []
## Contains all players nicknames using next format: [code]{ peer_id: "nickname" }[/code]
static var lobby_players_nicknames: Dictionary[int, String] = {}
## Contains peer IDs of alive players.
static var alive_players_ids: PackedInt64Array = []
## The unique Steam ID of the local user. Defaults to -1 if Steam is not used.
static var steam_user_id: int = -1
## The local player's nickname.
static var nickname: String = ""
## The current Steam lobby ID. Defaults to -1.
static var lobby_id: int = -1
## The active [MultiplayerPeer] instance (either Steam or ENet).
static var mp_peer: MultiplayerPeer
## Information about the current Godot engine version.
static var engine_info: String
static var ingame := false
## Contains all [Player] node instances using next format: [code]{ peer_id: Player }[/code]
static var spawned_players: Dictionary[int, Player] = {}
## Contains active [GameInstance] node, null if there`s currently no instance.
static var game_instance: GameInstance
static var menu: Control
static var camera_container: Node3D
static var dash_client_cooldown_timer: Timer
## Flag indicating if the game is running in LAN mode.
static var lan_mode: bool
static var button_click_sound: AudioStreamPlayer
static var button_hover_sound: AudioStreamPlayer
static var lan_join_window: LanJoinWindow
## Cantains important data about hosted lobby.
static var lobby_data: Dictionary
## Flag indicating if the local player is currently hosting a lobby
## (used to determine if lobby should be advertised in LAN mode).
static var lobby_hosted: bool
## Reference to the Steam singleton (GodotSteam).
# We use dynamic typed variable to make script work even if GodotSteam is not available.
static var steam_singleton
## Is running in dedicated server mode
static var is_dedicated_server: bool

@onready var elements_to_hide_ingame = [%StartButton, %StartLabel, %NicknameLineEdit, $Menu, %LanHBoxContainer]
@onready var elements_to_show_ingame = [%LeaveButton, %ContinueButton]

var force_skip_host: bool
var authentication_timers: Dictionary[int, Timer] = {}
var ChatMessagePrefab = preload("res://assets/prefabs/chat_message.tscn")
var GamePrefab = preload("res://assets/prefabs/game.tscn")


func _ready() -> void:
    instance = self
    menu = $Menu
    dash_client_cooldown_timer = %DashClientCooldownTimer
    button_click_sound = %ButtonClickSound
    button_hover_sound = %ButtonHoverSound
    lan_join_window = %LanJoinWindow
    
    is_dedicated_server = OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless"
    
    lobby_data = {
        "name": ProjectSettings.get_setting("application/config/name"),
        "game_version": ProjectSettings.get_setting("application/config/version")
    }
    
    var engine_version_info = Engine.get_version_info()
    engine_info = "Godot Engine v%d.%d.%d.%s.%s" % [engine_version_info["major"], engine_version_info["minor"], engine_version_info["patch"], engine_version_info["status"], engine_version_info["build"]]
    Console.instance.print_to_console("%s v%s\n%s" % [ProjectSettings.get_setting("application/config/name"), ProjectSettings.get_setting("application/config/version"), engine_info])
    %CreditsLabel.text = "%s v%s by ghKoty\nPowered by %s%s" % [ProjectSettings.get_setting("application/config/name"),
            ProjectSettings.get_setting("application/config/version"), engine_info, %CreditsLabel.text]
    
    Console.instance.print_to_console("Launching with cmdlne args: %s" % str(OS.get_cmdline_args()))
    
    if "--force-lan" in OS.get_cmdline_args():
        Console.instance.print_to_console("Multiplayer: Steam initialization skipped because of --forcelan commandline argument")
        initialize_lan()
    elif Engine.has_singleton("Steam"):
        Console.instance.print_to_console("Multiplayer: Connecting to Steam...")
        steam_singleton = Engine.get_singleton("Steam")
        var steam_status: int = initialize_steam()
        if steam_status != OK:
            Console.instance.print_to_console("Multiplayer: Failed", Console.WARNING_COLOR)
            initialize_lan()
        else:
            mp_peer = ClassDB.instantiate("SteamMultiplayerPeer")
            steam_singleton.lobby_created.connect(_on_lobby_created)
            steam_singleton.lobby_joined.connect(_on_lobby_joined)
            steam_singleton.join_requested.connect(_on_join_requested)
            steam_user_id = steam_singleton.getSteamID()
            nickname = GameConfig.get_key("nickname", steam_singleton.getPersonaName())
            Console.instance.print_to_console("Multiplayer: Connected to Steam with steam_id %d" % steam_user_id)
            steam_singleton.setRichPresence("status", "Main menu")
    else:
        Console.instance.print_to_console("Multiplayer: Unable to find Steam class, running in LAN mode", Console.WARNING_COLOR)
        initialize_lan()
    
    %NicknameLineEdit.text = nickname
    
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    
    force_skip_host = lan_mode and "--skip-host" in OS.get_cmdline_args()
    
    if force_skip_host:
        %HostButton.show()
    else:
        host()


func _process(_delta: float) -> void:
    if ingame:
        if Input.is_action_just_pressed("ui_cancel"):
            menu.visible = not menu.visible
    
    if not lan_mode:
        steam_singleton.run_callbacks()


#region Initialization
func initialize_steam() -> int:
    var initialize_response: Dictionary = steam_singleton.steamInitEx(480)
    return initialize_response["status"]


func initialize_lan() -> void:
    lan_mode = true
    mp_peer = ENetMultiplayerPeer.new()
    nickname = GameConfig.get_key("nickname", "")
    %LanHBoxContainer.show()
    lan_join_window.process_mode = Node.PROCESS_MODE_INHERIT
#endregion


#region Lobby Management
## Disconnects the player, clears all session data, and returns to the main menu.
func leave_lobby() -> void:
    %StartButton.disabled = true
    if ingame:
        game_instance.name += "_being_freed"
        game_instance.queue_free()
        
        update_ui_elements(false)
    
    ingame = false
    lobby_players_ids.clear()
    spawned_players.clear()
    lobby_players_nicknames.clear()
    alive_players_ids.clear()
    
    if lobby_id != -1:
        lobby_id = -1
        steam_singleton.leaveLobby(lobby_id)
    
    mp_peer.close()
    multiplayer.set_multiplayer_peer(null)
    lobby_hosted = false
    
    %InLobbyDialog.hide()


func leave_lobby_and_host(should_await: bool = false) -> void:
    leave_lobby()
    
    if should_await:
        await get_tree().process_frame
    
    if not force_skip_host:
        host()


## Creates a new multiplayer lobby.
## In Steam mode, creates a Friends-Only lobby. In LAN mode, starts an ENet server on [member LAN_PORT].
func host() -> void:
    if lan_mode:
        var result = mp_peer.create_server(LAN_PORT, MAX_PLAYERS)
        if result != OK:
            show_error("Cannot create host peer: %s" % error_string(result))
            return
        lobby_hosted = true
        multiplayer.set_multiplayer_peer(mp_peer)
        print_to_chat("LAN Lobby created")
    else:
        steam_singleton.leaveLobby(lobby_id)
        steam_singleton.createLobby(steam_singleton.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)
    if not is_dedicated_server:
        lobby_players_ids = [1]
        lobby_players_nicknames = {1: nickname}
    %StartButton.disabled = false


## Attempts to connect to a LAN server at the specified [param address].
func lan_connect(address: String) -> void:
    if not is_ipv4_valid(address):
        print_to_chat("Invald IP address: %s" % address)
        return
    
    leave_lobby()
    
    print_to_chat("Connecting to LAN lobby %s" % address)
    
    %LANConnectTimeoutTimer.start()
    
    mp_peer.create_client(address, LAN_PORT)
    multiplayer.set_multiplayer_peer(mp_peer)


# Host-only
func update_lobby_info() -> void:
    update_lobby_info_rpc.rpc(lobby_players_ids, lobby_players_nicknames)

## Synchronizes the lobby player list and nicknames across all clients.
@rpc("authority", "call_remote", "reliable") func update_lobby_info_rpc(new_lobby_players_ids: PackedInt64Array, new_lobby_players_nicknames: Dictionary[int, String]) -> void:
    lobby_players_ids = new_lobby_players_ids
    lobby_players_nicknames = new_lobby_players_nicknames


## Kicks a player from the lobby with a specific [param reason].
func kick_from_lobby(id_to_kick: int, reason: String = "Disconnected: %s", reason_args: Array = ["Manual kick"]) -> void:
    var peer_id_to_kick: int
    if lan_mode:
        peer_id_to_kick = id_to_kick
    else:
        peer_id_to_kick = mp_peer.get_peer_id_for_steam_id(id_to_kick)
        
    disconnect_from_lobby.rpc_id(peer_id_to_kick, reason, reason_args)
    for i in range(3):
        await get_tree().physics_frame
    mp_peer.disconnect_peer(peer_id_to_kick)


## Handles the local disconnection logic when kicked by the host.
@rpc("authority", "call_remote", "reliable") func disconnect_from_lobby(reason: String, reason_args: Array = []) -> void:
    leave_lobby_and_host(true)
    %KickedDialogLabel.text = reason % reason_args
    %KickedDialog.popup_centered()
#endregion


#region Utils
## Returns username by steam_id of the player.
static func get_username_by_id(peer_id: int) -> String:
    if peer_id in lobby_players_nicknames:
        return lobby_players_nicknames[peer_id]
    if not lan_mode:
        var user_steam_id = mp_peer.get_steam_id_for_peer_id(peer_id)
        var username = steam_singleton.getFriendPersonaName(user_steam_id)
        if username == "" or username == "[unknown]":
            username = steam_singleton.getPlayerNickname(user_steam_id)
        if username:
            return username
    return str(peer_id)


static func is_ipv4_valid(addr_text: String) -> bool:
    if addr_text.is_empty():
        return false
    
    var ipv4_regex = RegEx.new()
    ipv4_regex.compile(r"^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$")
    
    if ipv4_regex.search(addr_text):
        for byte in addr_text.split("."):
            if int(byte) < 0 or int(byte) > 255:
                return false
        
        return true
    
    if addr_text == "localhost":
        return true
    return false


func show_error(error_text: String = ErrorWindow.error_text) -> void:
    ErrorWindow.error_text = error_text
    Console.instance.print_to_console(error_text)
    get_tree().change_scene_to_file("res://assets/scenes/error.tscn")


@rpc("authority", "call_local", "reliable") func print_to_chat(message: String, msg_args: Array = []) -> void:
    var new_chat_message = ChatMessagePrefab.instantiate() as Label
    new_chat_message.text = message % msg_args
    %ChatVBoxContainer.add_child(new_chat_message)
    
    Console.instance.print_to_console("Chat: " + message % msg_args, Color.PALE_GREEN)


func quit() -> void:
    get_tree().quit()


func update_ui_elements(is_ingame: bool) -> void:
    for element in elements_to_show_ingame:
        element.visible = is_ingame
    for element in elements_to_hide_ingame:
        element.visible = not is_ingame
#endregion


#region Game Flow
func start_game() -> void:
    start_game_rpc.rpc()
    for player_id in lobby_players_ids:
        spawn_player(player_id)


func spawn_player(player_id: int) -> Player:
    var player: Player = game_instance.players.spawn(player_id)
    spawned_players[player_id] = player
    return player


@rpc("authority", "call_local", "reliable") func start_game_rpc() -> void:
    %InLobbyDialog.hide()
    
    game_instance = GamePrefab.instantiate()
    add_child(game_instance)
    move_child(game_instance, 1) # Should be right above Menu node
    
    update_ui_elements(true)
    
    ingame = true
#endregion


@rpc("any_peer", "call_local", "reliable") func update_nickname(new_nickname) -> void:
    var player_id = multiplayer.get_remote_sender_id()
    if not player_id in lobby_players_ids:
        return
    
    if ingame:
        return
    
    if new_nickname in lobby_players_nicknames.values():
        return
    
    lobby_players_nicknames[player_id] = new_nickname


#region Steam Callbacks
func _on_join_requested(lobby_id_to_join: int, _steam_id: int) -> void:
    Console.instance.print_to_console("Multiplayer: Connecting to Steam lobby %d" % lobby_id_to_join)
    print_to_chat("Connecting to lobby...")
    steam_singleton.joinLobby(lobby_id_to_join)


func _on_lobby_created(connect_state: int, created_lobby_id) -> void:
    Console.instance.print_to_console("Multiplayer: Lobby created with id %d" % created_lobby_id)
    
    if connect_state == 1:
        lobby_id = created_lobby_id
        
        steam_singleton.setLobbyJoinable(lobby_id, true)
        
        for key in lobby_data.keys():
            steam_singleton.setLobbyData(lobby_id, key, lobby_data[key])
        steam_singleton.setLobbyData(lobby_id, "lobby_name", "dev")
        
        var result = mp_peer.create_host(0)
        if result != OK:
            multiplayer.set_multiplayer_peer(null)
            show_error("Cannot create host peer: %s" % error_string(result))
            return
        
        multiplayer.set_multiplayer_peer(mp_peer)
        
        print_to_chat("Lobby created")


func _on_lobby_joined(joined_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
    lobby_id = joined_lobby_id
    
    if response == steam_singleton.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
        var id = steam_singleton.getLobbyOwner(joined_lobby_id)
        if id != steam_user_id:
            leave_lobby()
            var result = mp_peer.create_client(id, 0)
            if result != OK:
                Console.instance.print_to_console("Multiplayer: Cannot connect to SteamMultiplayerPeer: %s" % error_string(result))
                print_to_chat("Lobby join failed")
                leave_lobby_and_host()
                return
            multiplayer.set_multiplayer_peer(mp_peer)
            lobby_players_ids = [mp_peer.get_unique_id()]
    else:
        Console.instance.print_to_console("Lobby join error: %s" % [STEAM_CHAT_ROOM_ENTER_RESPONSE_NAMES[response]])
#endregion


#region Multiplayer Generic
func _on_peer_connected(remote_peer_id: int) -> void:
    if is_multiplayer_authority() and not remote_peer_id in lobby_players_ids:
        Console.instance.print_to_console("Multiplayer:  Peer %d connected, waiting for authentication request..." % remote_peer_id)
        var authentication_timer = Timer.new()
        $AuthenticationTimers.add_child(authentication_timer)
        authentication_timers[remote_peer_id] = authentication_timer
        authentication_timer.timeout.connect(_on_authentication_timer_timeout.bind(remote_peer_id))
        authentication_timer.one_shot = true
        authentication_timer.start(AUTHENTICATION_TIMEOUT)
    if remote_peer_id == 1:
        %LANConnectTimeoutTimer.stop()
        print_to_chat("Connected to lobby")
        authenticate.rpc_id(1, ProjectSettings.get_setting("application/config/version"), nickname)


func _on_peer_disconnected(remote_peer_id: int) -> void:
    if not remote_peer_id in lobby_players_ids: # If player is not authenticated
        remove_authentication_timer(remote_peer_id)
        Console.instance.print_to_console("Multiplayer: Peer %d disconnected" % remote_peer_id)
        return
    
    if ingame:
        if remote_peer_id == 1:
            if not %KickedDialog.visible:
                disconnect_from_lobby("Disconnected: Host is not responding!")
            return
    
    if remote_peer_id == 1:
        print_to_chat("Lobby host left")
        leave_lobby_and_host()
    else:
        if is_multiplayer_authority():
            print_to_chat.rpc("%s left the lobby", [get_username_by_id(remote_peer_id)])
    
    if is_multiplayer_authority():
        lobby_players_ids.erase(remote_peer_id)
        lobby_players_nicknames.erase(remote_peer_id)
        if GameInstance.is_available():
            GameInstance.players.remove_player(remote_peer_id)
        spawned_players.erase(remote_peer_id)
        alive_players_ids.erase(remote_peer_id)
        update_lobby_info()


## Called on server every time new client joins middle-game.
func send_late_join_data(peer_id: int) -> void:
    var data := []
    for node in get_tree().get_nodes_in_group("LateJoinReplication"):
        if not node.has_method("dump_multiplayer_node_state"):
            continue
        
        var node_data = node.dump_multiplayer_node_state()
        node_data["parent_path"] = node.get_parent().get_path()
        node_data["name"] = node.name
        data.append(node_data)
    
    process_late_join_data.rpc_id(peer_id, data)


@rpc("authority", "call_remote", "reliable") func process_late_join_data(data: Array) -> void:
    for node_data: Dictionary in data:
        var node: Node
        node = get_node_or_null("%s/%s" % [node_data["parent_path"], node_data["name"]])
        
        if not node:
            if "file_path" in node_data:
                node = load(node_data["file_path"]).instantiate()
            else:
                continue
        
        if node.has_method("replicate_multiplayer_node_state"):
            node.replicate_multiplayer_node_state(node_data)
        
        if "file_path" in node_data:
            get_node(node_data["parent_path"]).add_child(node)
            node.name = node_data["name"]
#endregion


#region Authentication
func _on_authentication_timer_timeout(peer_id: int) -> void:
    kick_from_lobby(peer_id, "DISCONNECTED_KICKED", ["Authentication timeout"])
    remove_authentication_timer(peer_id)
    Console.instance.print_to_console("Auth: Peer %d authentication failed: timeout" % peer_id)


## Validates a connecting peer's version and nickname. [br]
## This is called via RPC from the client to the server during the handshake.
@rpc("any_peer", "call_remote", "reliable") func authenticate(remote_version: String, player_nickname: String) -> void:
    var peer_id = multiplayer.get_remote_sender_id()
    
    remove_authentication_timer(peer_id)
    
    if not is_multiplayer_authority() or peer_id in lobby_players_nicknames:
        return
    
    if remote_version != ProjectSettings.get_setting("application/config/version"):
        kick_from_lobby(peer_id, "DISCONECTED_VERSIONS_MISMATCH", [ProjectSettings.get_setting("application/config/version"), remote_version])
        Console.instance.print_to_console("Auth: Peer %d(%s) authentication failed: versions mismatch" % [peer_id, player_nickname])
        return
    
    if player_nickname in lobby_players_nicknames.values():
        kick_from_lobby(peer_id, "DISCONNECTED_PLAYER_WITH_SAME_NICKNAME")
        Console.instance.print_to_console("Auth: Peer %d(%s) authentication failed: player with the same nickname is already in the lobby" % [peer_id, player_nickname])
        return
    
    Console.instance.print_to_console("Auth: Peer %d authenticated, welcome %s!" % [peer_id, player_nickname])
    lobby_players_nicknames[peer_id] = player_nickname
    lobby_players_ids.append(peer_id)
    update_lobby_info()
    
    auth_success.rpc_id(peer_id)
    
    if ingame:
        start_game_rpc.rpc_id(peer_id)
        spawn_player(peer_id).die()
        send_late_join_data(peer_id)
    
    for player_id in lobby_players_ids:
        if player_id == peer_id:
            continue
        print_to_chat.rpc_id(player_id, "%s joined the lobby", [player_nickname])
        

@rpc("authority", "call_remote", "reliable") func auth_success() -> void:
    %InLobbyDialog.popup_centered()
    %StartButton.hide()


func remove_authentication_timer(peer_id: int) -> void:
    if authentication_timers.has(peer_id):
        authentication_timers[peer_id].stop()
        authentication_timers[peer_id].queue_free()
        authentication_timers.erase(peer_id)
#endregion


#region Signal Handlers
func _on_quit_button_pressed() -> void:
    leave_lobby()
    $AnimationPlayer.play("quit")


func _on_start_button_pressed() -> void:
    start_game()


func _on_menu_visibility_changed() -> void:
    if menu:
        if menu.visible:
            MouseManager.use_mouse(menu)
        else:
            MouseManager.free_mouse(menu)


func _on_host_button_pressed() -> void:
    leave_lobby()
    host()


func _on_nickname_line_edit_text_submitted(new_text: String) -> void:
    if new_text == nickname:
        return
    
    nickname = new_text
    print_to_chat("new nickname: %s" % nickname)
    
    if not lan_mode and (nickname == steam_singleton.getPersonaName() or nickname.is_empty()):
        GameConfig.delete_key("nickname")
        return
    
    GameConfig.set_key("nickname", nickname)


func _on_nickname_line_edit_focus_exited() -> void:
    _on_nickname_line_edit_text_submitted(%NicknameLineEdit.text)


func _on_lan_connect_timeout() -> void:
    print_to_chat("Connecting to LAN lobby failed: timed out")
    leave_lobby_and_host()


func _on_leave_button_pressed() -> void:
    leave_lobby_and_host()


func _on_join_button_pressed() -> void:
    if lan_join_window.discovery_available:
        lan_join_window.popup_centered()
    else:
        %LanManualJoinWindow.popup_centered()


func _on_credits_label_meta_clicked(meta: Variant) -> void:
    OS.shell_open(str(meta))
#endregion
