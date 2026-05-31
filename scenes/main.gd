extends Node3D

var xr_interface: XRInterface
@export var player_eye_height: float = 1.2
@export var xr_height_offset: float = 0.0
@export var death_fade_duration: float = 1.0

@onready var player_node: Node = $Player
@onready var health_bar: ProgressBar = _find_health_bar()
@onready var death_ui_vr: Control = get_node_or_null("Player/XRCamera3D/HUD/Viewport/HealthUI/DeathUI")
@onready var death_ui_2d: Control = get_node_or_null("UI/Root/DeathUI")
@onready var death_fade_vr: ColorRect = get_node_or_null("Player/XRCamera3D/HUD/Viewport/HealthUI/DeathUI/Fade")
@onready var death_fade_2d: ColorRect = get_node_or_null("UI/Root/DeathUI/Fade")
@onready var respawn_button_vr: Button = get_node_or_null("Player/XRCamera3D/HUD/Viewport/HealthUI/DeathUI/Panel/VBox/RespawnButton")
@onready var respawn_button_2d: Button = get_node_or_null("UI/Root/DeathUI/Panel/VBox/RespawnButton")

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	var camera := $Player/XRCamera3D

	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialised succesfully")
		
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
		get_viewport().use_xr = true
		camera.transform.origin.y = 0.0
		if xr_height_offset != 0.0:
			player_node.position.y += xr_height_offset
	else:
		print("OpenXR not initialised, please check if your headset is connected")
		camera.transform.origin.y = player_eye_height
	
	if player_node.has_signal("health_changed") and is_instance_valid(health_bar):
		player_node.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(player_node.get_health(), player_node.get_max_health())
	if player_node.has_signal("died"):
		player_node.died.connect(_on_player_died)
	if is_instance_valid(respawn_button_vr):
		respawn_button_vr.pressed.connect(_on_respawn_pressed)
	if is_instance_valid(respawn_button_2d):
		respawn_button_2d.pressed.connect(_on_respawn_pressed)

	_set_death_ui_visible(false)


func _on_player_health_changed(current: int, max_value: int) -> void:
	health_bar.max_value = max_value
	health_bar.value = current
	_apply_health_colors()


func _find_health_bar() -> ProgressBar:
	var vr_bar = get_node_or_null("Player/XRCamera3D/HUD/Viewport/HealthUI/HealthBar")
	if vr_bar:
		return vr_bar
	return get_node_or_null("UI/Root/HealthBar")



func _apply_health_colors() -> void:
	if not is_instance_valid(health_bar):
		return
	var fill = health_bar.get_theme_stylebox("fill")
	if not fill or not (fill is StyleBoxFlat):
		fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.25, 0.25)
	health_bar.add_theme_stylebox_override("fill", fill)

	var bg = health_bar.get_theme_stylebox("background")
	if not bg or not (bg is StyleBoxFlat):
		bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.6, 0.6, 0.6)
	health_bar.add_theme_stylebox_override("background", bg)


func _on_player_died() -> void:
	_set_death_ui_visible(true)
	_fade_in(death_fade_vr)
	_fade_in(death_fade_2d)


func _on_respawn_pressed() -> void:
	if player_node.has_method("respawn"):
		player_node.call("respawn")
	_reset_fade(death_fade_vr)
	_reset_fade(death_fade_2d)
	_set_death_ui_visible(false)


func _set_death_ui_visible(visible: bool) -> void:
	if is_instance_valid(death_ui_vr):
		death_ui_vr.visible = visible
	if is_instance_valid(death_ui_2d):
		death_ui_2d.visible = visible


func _fade_in(rect: ColorRect) -> void:
	if not is_instance_valid(rect):
		return
	var base = rect.color
	base.a = 0.0
	rect.color = base
	var target = base
	target.a = 1.0
	create_tween().tween_property(rect, "color", target, death_fade_duration)


func _reset_fade(rect: ColorRect) -> void:
	if not is_instance_valid(rect):
		return
	var color = rect.color
	color.a = 0.0
	rect.color = color
