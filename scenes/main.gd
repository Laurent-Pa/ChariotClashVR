extends Node3D

var xr_interface: XRInterface

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	var camera := $Player/XRCamera3D

	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialised succesfully")
		
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
		get_viewport().use_xr = true
		camera.transform.origin.y = 0.0
	else:
		print("OpenXR not initialised, please check if your headset is connected")
		camera.transform.origin.y = 1.7
	
	$Player.add_to_group("player")
