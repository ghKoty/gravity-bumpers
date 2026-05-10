# Copyright (c) 2025 ghKoty(https://github.com/ghKoty)
# Distributed under the MIT License. See LICENSE file for full license information.

class_name MouseManager
extends Node

const DEFAULT_MOUSE_MODE: DisplayServer.MouseMode = DisplayServer.MOUSE_MODE_CAPTURED
const USED_MOUSE_MODE: DisplayServer.MouseMode = DisplayServer.MOUSE_MODE_VISIBLE

static var instances_using_mouse: Array = []

## Updates the mouse mode depending on whether any nodes require mouse input.
## Called automatically from [method use_mouse] and [method free_mouse].
static func update_mouse() -> void:
    instances_using_mouse = instances_using_mouse.filter(is_instance_valid)
    if instances_using_mouse.is_empty():
        DisplayServer.mouse_set_mode(DEFAULT_MOUSE_MODE)
    else:
        DisplayServer.mouse_set_mode(USED_MOUSE_MODE)


## Registers a node as requiring mouse input and makes mouse visible.
static func use_mouse(used_by_node: Node) -> void:
    if not used_by_node in instances_using_mouse:
        instances_using_mouse.append(used_by_node)
    update_mouse()


## Unregisters a node that no longer requires mouse input.
static func free_mouse(used_by_node: Node) -> void:
    instances_using_mouse.erase(used_by_node)
    update_mouse()
