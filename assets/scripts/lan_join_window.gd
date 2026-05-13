class_name LanJoinWindow
extends CenterWindow

var lan_UID: String
var udpc = PacketPeerUDP.new()
var udpb = PacketPeerUDP.new()
var lobbies_buttons: Dictionary[String, LanLobbyPanel] = {}
var discovery_available: bool

var LobbyPanelPrefab = preload("res://assets/prefabs/lan_lobby_button.tscn")

func _ready():
    super()
    lan_UID = "%d%d%s" % [randi(), Time.get_unix_time_from_system(),
        OS.get_unique_id() if OS.has_feature("web") else ""]
    
    var result := udpc.bind(Main.LAN_ADVERTISEMENT_PORT)
    if result == OK:
        discovery_available = true
    else:
        %LANDiscoveryFailedDialogLabel.text = "Lobby discovery unavailable\n"
        %LANDiscoveryFailedDialog.popup_centered()
        
    
    udpb.set_broadcast_enabled(true)
    result = udpb.set_dest_address("255.255.255.255", Main.LAN_ADVERTISEMENT_PORT)
    if result != OK:
        %LANDiscoveryFailedDialogLabel.text += "Lobby advertisement unavailable"
        %LANDiscoveryFailedDialog.popup_centered()


func _process(_delta):
    while udpc.get_available_packet_count() > 0:
        var data = udpc.get_packet().get_string_from_utf8()
        var ip = udpc.get_packet_ip()
        
        var lobby_info = JSON.parse_string(data)
        if lobby_info:
            if is_lobby_compatible(lobby_info) and lobby_info["uid"] != lan_UID:
                update_or_create_panel(ip, lobby_info["nickname"])


func broadcast_lobby() -> void:
    var data := Main.lobby_data.duplicate()
    data["nickname"] = Main.nickname
    data["uid"] = lan_UID
    udpb.put_packet(JSON.stringify(data).to_utf8_buffer())


func update_or_create_panel(ip: String, nickname: String) -> void:
    if ip in lobbies_buttons:
        lobbies_buttons[ip].update(nickname)
    else:
        var new_panel: LanLobbyPanel = LobbyPanelPrefab.instantiate()
        lobbies_buttons[ip] = new_panel
        %LobbiesPanelsContainer.add_child(new_panel)
        new_panel.initialize(ip, nickname)


func is_lobby_compatible(lobby_info: Dictionary) -> bool:
    for key in Main.lobby_data.keys():
        if not key in lobby_info or lobby_info[key] != Main.lobby_data[key]:
            return false
    
    if not "nickname" in lobby_info:
        return false
    
    return true


func _on_lobby_advertisement_timer_timeout() -> void:
    if Main.lobby_hosted:
        broadcast_lobby()
