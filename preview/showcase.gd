extends Node3D

# Visualizador simples: coloca modelos GLB existentes em uma galeria 3D.
# Não altera os assets originais nem pretende ser um mapa já montado.

@export var max_models: int = 72
@export var columns: int = 9
@export var spacing: float = 9.0

var camera: Camera3D
var yaw := 0.0
var pitch := -0.55
var distance := 48.0
var target := Vector3.ZERO
var touch_points: Dictionary = {}
var last_pinch := 0.0

func _ready() -> void:
	_render_environment()
	_create_floor()
	_create_camera()
	_load_models()

func _render_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.76, 0.82)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.25
	add_child(sun)

func _create_floor() -> void:
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(180, 180)
	floor.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.19, 0.21)
	mat.roughness = 0.95
	floor.material_override = mat
	floor.position.y = -0.08
	add_child(floor)

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 65.0
	add_child(camera)
	_update_camera()

func _update_camera() -> void:
	if camera == null:
		return
	pitch = clampf(pitch, -1.25, -0.12)
	var direction := Vector3(
		cos(pitch) * sin(yaw),
		sin(pitch),
		cos(pitch) * cos(yaw)
	)
	camera.position = target + direction * distance
	camera.look_at(target, Vector3.UP)

func _load_models() -> void:
	var paths: Array[String] = []
	_collect_glb("res://buildings", paths)
	_collect_glb("res://props", paths)
	_collect_glb("res://environment/vegetation", paths)
	paths.sort()
	var count := mini(paths.size(), max_models)
	for i in range(count):
		var packed := load(paths[i]) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate()
		if not instance is Node3D:
			instance.queue_free()
			continue
		var node := instance as Node3D
		var col := i % columns
		var row := int(i / columns)
		node.position = Vector3((col - (columns - 1) * 0.5) * spacing, 0.0, row * spacing)
		add_child(node)
	var rows := ceili(float(count) / float(columns))
	target = Vector3(0, 0, maxf(0.0, (rows - 1) * spacing * 0.5))
	distance = maxf(34.0, columns * spacing * 1.05)
	_update_camera()

func _collect_glb(path: String, output: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_collect_glb(full, output)
		elif entry.to_lower().ends_with(".glb"):
			output.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
			last_pinch = 0.0
	elif event is InputEventScreenDrag:
		if touch_points.size() == 1:
			yaw -= event.relative.x * 0.008
			pitch -= event.relative.y * 0.005
			_update_camera()
		elif touch_points.size() >= 2:
			var pts: Array = touch_points.values()
			if pts.size() >= 2:
				var current_distance: float = pts[0].distance_to(pts[1])
				if last_pinch > 0.0:
					distance = clampf(distance * (last_pinch / maxf(current_distance, 1.0)), 12.0, 180.0)
					_update_camera()
				last_pinch = current_distance
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(12.0, distance * 0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(180.0, distance * 1.12)
		_update_camera()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.006
		pitch -= event.relative.y * 0.004
		_update_camera()
