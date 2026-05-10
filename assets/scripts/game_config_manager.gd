class_name GameConfig
extends RefCounted

## Path of the configuration file.
const CONFIG_FILE_PATH: String = "user://gameconfig.json"

#region Internal methods
# This variable will store all configuration data as a Dictionary[String, Variant] once initialized
static var _config


# This method will load/initialize config before it can be used
static func _try_init() -> void:
    if _config is not Dictionary:
        var file := FileAccess.open(CONFIG_FILE_PATH, FileAccess.READ)
        if file == null:
            Console.instance.print_to_console("GameConfig: Cannot load configuration file (%s): File does not exists!" % CONFIG_FILE_PATH, Console.WARNING_COLOR)
            _config = {}
            return
        var content := file.get_as_text()
        file.close()
        var parsed = JSON.parse_string(content)
        if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
            Console.instance.print_to_console("GameConfig: Cannot parce configuration file (%s)" % CONFIG_FILE_PATH, Console.ERROR_COLOR)
            _config = {}
            return
        _config = parsed


static func _save_config() -> void:
    var file = FileAccess.open(CONFIG_FILE_PATH, FileAccess.WRITE)
    var json := JSON.stringify(_config, "\t")
    file.store_string(json)
    file.close()
#endregion

#region Public methods
## Deletes [param key].
static func delete_key(key: String) -> void:
    _try_init()
    if not _config.has(key):
        return
        
    _config.erase(key)
    
    _save_config()


## Saves [param value] with [param key].
static func set_key(key: String, value) -> void:
    _try_init()
    if _config.has(key) and _config[key] == value:
        return
    
    _config[key] = value
    _save_config()


## Returns [param key] value from game config, returns [param default_value] if [param key] doesn`t exists.
static func get_key(key: String, default_value = null):
    _try_init()
    if key in _config:
        return _config[key]
    return default_value
#endregion
