extends CenterWindow

const CHECK_URL = "https://api.github.com/repos/ghkoty/gravity-bumpers/releases/latest"
var release_url: String

func _ready() -> void:
    super()
    if GameConfig.get_key("update_check", true):
        check_for_updates()


func check_for_updates() -> void:
    $HTTPRequest.request(CHECK_URL)


func _on_http_request_request_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS:
        return
    
    var json = JSON.new()
    if json.parse(body.get_string_from_utf8()) != OK:
        return
    
    var response = json.get_data()
    if response["tag_name"] != "v%s" % ProjectSettings.get_setting("application/config/version"):
        release_url = response["html_url"]
        $VBoxContainer/Label.text = "Version %s is now on GitHub. It is highly recommended to update for the best experience." % response["tag_name"]
        visible = true


func _on_open_button_pressed() -> void:
    OS.shell_open(release_url)
